import Foundation
import IOKit
import IOKit.hid
import Synchronization

/// The MacBook lid angle sensor (spec 10.3, 10.4): IOKit HID on a thread of its own, readable without any permission.
/// The latest sample is kept behind a mutex; angle and availability changes are signaled on `updates`.
@MainActor
public final class LidSensor: LidSensing {
    public nonisolated static let vendorID = 0x05AC
    public nonisolated static let productID = 0x8104
    public nonisolated static let usagePage = 0x0020
    public nonisolated static let usage = 0x008A
    /// Reads per second at rest, on top of pushed reports (spec 10.3). Early check R1 decides whether pushes alone
    /// are enough; on macOS 26.5 it pushed about once per second, even while the angle changed, so 10 stays.
    public nonisolated static let restPollingHz = 10.0
    public nonisolated static let reopenAttempts = 3
    public nonisolated static let reopenDelay = 0.2

    public let updates: AsyncStream<LidSensorUpdate>
    private let worker: LidSensorWorker
    private var started = false

    public init() {
        let (stream, continuation) = AsyncStream.makeStream(of: LidSensorUpdate.self, bufferingPolicy: .bufferingNewest(16))
        updates = stream
        worker = LidSensorWorker(continuation: continuation)
    }

    public var latest: LidSample? { worker.book.withLock { $0.latest } }
    public var isAvailable: Bool { worker.book.withLock { $0.isAvailable } }

    public func start() {
        guard !started else { return }
        started = true
        worker.start()
    }

    public func stop() {
        guard started else { return }
        started = false
        worker.stop()
    }

    public func setMode(_ mode: LidPollingMode) {
        worker.perform { $0.apply(mode) }
    }

    public func didWake() {
        worker.perform { $0.verifyAfterWake() }
    }

    /// The lid angle interface, found in the IOKit registry before anything is opened: never the accelerometer,
    /// gyroscope or light sensor that share its product ID (spec 10.4).
    public nonisolated static func findDevice() -> IOHIDDevice? {
        guard let matching = IOServiceMatching(kIOHIDDeviceKey) as NSMutableDictionary? else { return nil }
        matching[kIOHIDVendorIDKey] = vendorID
        matching[kIOHIDProductIDKey] = productID
        matching[kIOHIDPrimaryUsagePageKey] = usagePage
        matching[kIOHIDPrimaryUsageKey] = usage
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == KERN_SUCCESS else { return nil }
        defer { IOObjectRelease(iterator) }
        while case let service = IOIteratorNext(iterator), service != 0 {
            defer { IOObjectRelease(service) }
            if let device = IOHIDDeviceCreate(kCFAllocatorDefault, service) { return device }
        }
        return nil
    }
}

/// A run loop handed to other threads. CFRunLoop's perform, wake up and stop are safe from any thread.
struct RunLoopBox: @unchecked Sendable {
    let loop: CFRunLoop
}

/// Everything that runs on the sensor thread. The device and the timers are touched only on that thread; other
/// threads reach it through `perform` and read samples through `book`.
final class LidSensorWorker: @unchecked Sendable {
    let book = Mutex(LidSampleBook())
    private let continuation: AsyncStream<LidSensorUpdate>.Continuation
    private let runLoop = Mutex<RunLoopBox?>(nil)

    // Sensor thread only.
    private var device: IOHIDDevice?
    private var pollTimer: CFRunLoopTimer?
    private var keepAlive: CFRunLoopTimer?
    private var mode: LidPollingMode = .rest
    private var failures = 0
    private var featureReport = [UInt8](repeating: 0, count: LidReport.length)
    private let inputReport = UnsafeMutablePointer<UInt8>.allocate(capacity: 64)

    init(continuation: AsyncStream<LidSensorUpdate>.Continuation) {
        self.continuation = continuation
    }

    deinit {
        inputReport.deallocate()
    }

    /// Starts the thread and returns once its run loop exists.
    func start() {
        let ready = DispatchSemaphore(value: 0)
        let thread = Thread { [self] in run(ready: ready) }
        thread.name = "ch.rubencatalao.pli.lid-sensor"
        thread.qualityOfService = .userInteractive
        thread.start()
        ready.wait()
    }

    func stop() {
        perform { worker in
            worker.teardown()
            CFRunLoopStop(CFRunLoopGetCurrent())
        }
        runLoop.withLock { $0 = nil }
    }

    func perform(_ work: @escaping @Sendable (LidSensorWorker) -> Void) {
        guard let box = runLoop.withLock({ $0 }) else { return }
        CFRunLoopPerformBlock(box.loop, CFRunLoopMode.defaultMode.rawValue) { work(self) }
        CFRunLoopWakeUp(box.loop)
    }

    private func run(ready: DispatchSemaphore) {
        let loop = CFRunLoopGetCurrent()!
        runLoop.withLock { $0 = RunLoopBox(loop: loop) }
        // Keeps the run loop alive even when the sensor is gone, so later wakes can reopen it.
        let keepAlive = CFRunLoopTimerCreateWithHandler(kCFAllocatorDefault, CFAbsoluteTimeGetCurrent() + 1e9, 0, 0, 0) { _ in }
        CFRunLoopAddTimer(loop, keepAlive, .defaultMode)
        self.keepAlive = keepAlive
        ready.signal()
        if !openDevice() {
            Log.sensor.info("no lid angle sensor")
        }
        apply(.rest)
        CFRunLoopRun()
    }

    // MARK: - Sensor thread

    func apply(_ mode: LidPollingMode) {
        self.mode = mode
        stopPolling()
        guard device != nil else { return }
        let hz: Double
        switch mode {
        case .rest: hz = LidSensor.restPollingHz
        case .active(let rate): hz = rate
        }
        guard hz > 0 else { return }
        let interval = 1 / hz
        let timer = CFRunLoopTimerCreateWithHandler(kCFAllocatorDefault, CFAbsoluteTimeGetCurrent() + interval, interval, 0, 0) { [unowned self] _ in
            poll()
        }
        if case .rest = mode { CFRunLoopTimerSetTolerance(timer, interval / 2) }
        CFRunLoopAddTimer(CFRunLoopGetCurrent(), timer, .defaultMode)
        pollTimer = timer
        if case .active = mode { poll() }
    }

    func verifyAfterWake() {
        failures = 0
        if device == nil || !read() { recover() }
    }

    /// A report the sensor pushed on its own. Measured on macOS 26.5 it has the feature report's layout
    /// (`01 5d 00` for 93°); anything else is only a cue to read the feature report.
    fileprivate func pushed(_ bytes: [UInt8]) {
        if bytes.first == UInt8(LidReport.reportID), let angle = LidReport.angle(from: bytes) {
            publish(angle)
        } else {
            CFRunLoopPerformBlock(CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue) { [self] in poll() }
        }
    }

    private func poll() {
        if !read(), failures >= LidSensor.reopenAttempts { recover() }
    }

    /// One feature report read. Publishes the sample; true on success.
    @discardableResult
    private func read() -> Bool {
        guard let device else { return false }
        var length = CFIndex(featureReport.count)
        let result = featureReport.withUnsafeMutableBufferPointer { buffer in
            IOHIDDeviceGetReport(device, kIOHIDReportTypeFeature, LidReport.reportID, buffer.baseAddress!, &length)
        }
        guard result == kIOReturnSuccess, let angle = LidReport.angle(from: Array(featureReport.prefix(max(Int(length), 0)))) else {
            failures += 1
            return false
        }
        failures = 0
        publish(angle)
        return true
    }

    private func publish(_ angle: Double) {
        let now = HostClock.now()
        let (changed, flipped) = book.withLock { book in (book.record(angle: angle, at: now), book.setAvailable(true)) }
        if flipped { continuation.yield(.availabilityChanged(true)) }
        if changed { continuation.yield(.angleChanged) }
    }

    /// Reopens the sensor: 3 attempts, 200 ms apart, then the "No lid sensor" state (spec 10.4).
    private func recover() {
        for attempt in 1...LidSensor.reopenAttempts {
            if openDevice() {
                apply(mode)
                Log.sensor.info("lid sensor reopened, attempt \(attempt)")
                return
            }
            Thread.sleep(forTimeInterval: LidSensor.reopenDelay)
        }
        closeDevice()
        if book.withLock({ $0.setAvailable(false) }) { continuation.yield(.availabilityChanged(false)) }
        Log.sensor.error("lid sensor not answering after \(LidSensor.reopenAttempts) attempts")
    }

    private func openDevice() -> Bool {
        closeDevice()
        failures = 0
        guard let found = LidSensor.findDevice(),
              IOHIDDeviceOpen(found, IOOptionBits(kIOHIDOptionsTypeNone)) == kIOReturnSuccess else { return false }
        IOHIDDeviceScheduleWithRunLoop(found, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)
        let context = Unmanaged.passUnretained(self).toOpaque()
        IOHIDDeviceRegisterInputReportCallback(found, inputReport, 64, { context, _, _, _, _, report, length in
            guard let context, length > 0 else { return }
            let bytes = Array(UnsafeBufferPointer(start: report, count: length))
            Unmanaged<LidSensorWorker>.fromOpaque(context).takeUnretainedValue().pushed(bytes)
        }, context)
        device = found
        return read()
    }

    private func stopPolling() {
        if let pollTimer { CFRunLoopTimerInvalidate(pollTimer) }
        pollTimer = nil
    }

    private func closeDevice() {
        stopPolling()
        guard let device else { return }
        IOHIDDeviceRegisterInputReportCallback(device, inputReport, 64, nil, nil)
        IOHIDDeviceUnscheduleFromRunLoop(device, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)
        IOHIDDeviceClose(device, IOOptionBits(kIOHIDOptionsTypeNone))
        self.device = nil
    }

    private func teardown() {
        closeDevice()
        if let keepAlive { CFRunLoopTimerInvalidate(keepAlive) }
        keepAlive = nil
    }
}
