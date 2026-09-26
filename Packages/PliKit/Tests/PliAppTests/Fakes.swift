import CoreGraphics
import CoreVideo
import PliCore
@testable import PliApp
@testable import PliSystem

/// Virtual time: timers fire when the test advances the clock, in time order.
@MainActor final class VirtualScheduler: Scheduling {
    final class Timer: Cancellable {
        let id: Int
        var due: Double
        let interval: Double?
        let action: @MainActor () -> Void
        var cancelled = false

        init(id: Int, due: Double, interval: Double?, action: @escaping @MainActor () -> Void) {
            self.id = id
            self.due = due
            self.interval = interval
            self.action = action
        }

        func cancel() { cancelled = true }
    }

    private(set) var now = 1000.0
    private var timers: [Timer] = []
    private var nextID = 0

    var pendingCount: Int { timers.filter { !$0.cancelled }.count }

    @discardableResult
    func after(_ delay: Double, _ action: @escaping @MainActor () -> Void) -> any Cancellable {
        add(due: now + max(delay, 0), interval: nil, action)
    }

    @discardableResult
    func every(_ interval: Double, _ action: @escaping @MainActor () -> Void) -> any Cancellable {
        add(due: now + interval, interval: max(interval, 0.001), action)
    }

    /// Moves time to `time`, firing every timer that falls due on the way.
    func advance(to time: Double) {
        while let next = timers.filter({ !$0.cancelled && $0.due <= time }).min(by: { ($0.due, $0.id) < ($1.due, $1.id) }) {
            now = max(now, next.due)
            if let interval = next.interval { next.due += interval } else { next.cancelled = true }
            next.action()
        }
        timers.removeAll { $0.cancelled }
        now = max(now, time)
    }

    private func add(due: Double, interval: Double?, _ action: @escaping @MainActor () -> Void) -> Timer {
        nextID += 1
        let timer = Timer(id: nextID, due: due, interval: interval, action: action)
        timers.append(timer)
        return timer
    }
}

@MainActor final class ManualClock: FrameClock {
    private(set) var isRunning = false
    private(set) var starts: [(display: CGDirectDisplayID?, rate: Double)] = []
    private var onFrame: (@MainActor () -> Void)?
    /// A display link that stopped firing (display asleep, screen gone).
    var stalled = false

    func start(display: CGDirectDisplayID?, maximumRate: Double, onFrame: @escaping @MainActor () -> Void) {
        isRunning = true
        starts.append((display, maximumRate))
        self.onFrame = onFrame
    }

    func stop() {
        isRunning = false
        onFrame = nil
    }

    func fire() {
        guard !stalled else { return }
        onFrame?()
    }
}

@MainActor final class FakeLidSensor: LidSensing {
    let updates: AsyncStream<LidSensorUpdate>
    private let continuation: AsyncStream<LidSensorUpdate>.Continuation
    private var book = LidSampleBook()
    private(set) var modes: [LidPollingMode] = []
    private(set) var wakeChecks = 0
    private(set) var running = false

    init(available: Bool = true) {
        (updates, continuation) = AsyncStream.makeStream(of: LidSensorUpdate.self)
        if available { _ = book.setAvailable(true) }
    }

    var latest: LidSample? { book.latest }
    var isAvailable: Bool { book.isAvailable }
    var mode: LidPollingMode { modes.last ?? .rest }

    func start() { running = true }
    func stop() { running = false }
    func setMode(_ mode: LidPollingMode) { modes.append(mode) }
    func didWake() { wakeChecks += 1 }

    /// One reading, as the sensor thread publishes it. True when the angle changed (and was signaled).
    @discardableResult
    func publish(_ angle: Double, at time: Double) -> Bool {
        let changed = book.record(angle: angle, at: time)
        if changed { continuation.yield(.angleChanged) }
        return changed
    }

    func setAvailable(_ available: Bool) {
        if book.setAvailable(available) { continuation.yield(.availabilityChanged(available)) }
    }
}

enum TestPictures {
    static func snapshot(display: CGDirectDisplayID = 1) -> DesktopSnapshot {
        DesktopSnapshot(pixelBuffer: PixelBuffers.make(width: 8, height: 5)!, displayID: display, requestedAt: 0)
    }

    static func wallpaper(display: CGDirectDisplayID = 1) -> WallpaperSource {
        WallpaperSource(pixelBuffer: PixelBuffers.make(width: 8, height: 5)!, displayID: display)
    }
}

@MainActor final class FakeSnapshotter: DesktopCapturing {
    enum Behavior { case succeed(after: Double), fail(CaptureError), never }
    var behavior: Behavior = .succeed(after: 0.03)
    private(set) var requests: [CGDirectDisplayID] = []
    private(set) var invalidations = 0
    private(set) var prewarms = 0
    private let scheduler: VirtualScheduler

    init(scheduler: VirtualScheduler) { self.scheduler = scheduler }

    func capture(display: CGDirectDisplayID, completion: @escaping @MainActor (Result<DesktopSnapshot, CaptureError>) -> Void) {
        requests.append(display)
        switch behavior {
        case .succeed(let delay): scheduler.after(delay) { completion(.success(TestPictures.snapshot(display: display))) }
        case .fail(let error): scheduler.after(0.01) { completion(.failure(error)) }
        case .never: break
        }
    }

    func invalidate() { invalidations += 1 }
    func prewarm() { prewarms += 1 }
}

@MainActor final class FakeWallpapers: WallpaperProviding {
    private(set) var requests: [CGDirectDisplayID] = []
    private let scheduler: VirtualScheduler

    init(scheduler: VirtualScheduler) { self.scheduler = scheduler }

    func load(for display: DisplayDescription, darkAppearance: Bool, completion: @escaping @MainActor (WallpaperSource) -> Void) {
        requests.append(display.id)
        scheduler.after(0.05) { completion(TestPictures.wallpaper(display: display.id)) }
    }
}

@MainActor final class FakeSurfaces: SurfacePresenting {
    enum Call: Equatable {
        case snapshot, release, wallpaper, hideAll
        case show(Surface)
        case render(Surface, Double)
        case hide(Surface, Double)
    }

    private(set) var calls: [(time: Double, call: Call)] = []
    private(set) var configurations: [SurfaceConfiguration] = []
    private var shown: Set<Surface> = []
    /// Surfaces that stay on screen whatever they are told, until `hideAll()`: a surface bug the watchdog must catch.
    var stuck: Set<Surface> = []
    private let scheduler: VirtualScheduler

    init(scheduler: VirtualScheduler) { self.scheduler = scheduler }

    var visibleSurfaces: Set<Surface> { shown.union(stuck) }

    func configure(_ configuration: SurfaceConfiguration) { configurations.append(configuration) }
    func setDesktopSnapshot(_ snapshot: DesktopSnapshot) { log(.snapshot) }
    func releaseDesktopSnapshot() { log(.release) }
    func setLockWallpaper(_ wallpaper: WallpaperSource) { log(.wallpaper) }
    func show(_ surface: Surface) { shown.insert(surface); log(.show(surface)) }
    func render(_ surface: Surface, progress: Double) { log(.render(surface, progress)) }
    func hide(_ surface: Surface, fade: Double) { shown.remove(surface); log(.hide(surface, fade)) }

    func hideAll() {
        shown.removeAll()
        stuck.removeAll()
        log(.hideAll)
    }

    func count(_ call: Call) -> Int { calls.filter { $0.call == call }.count }

    func renders(_ surface: Surface) -> [Double] {
        calls.compactMap { if case .render(surface, let p) = $0.call { return p } else { return nil } }
    }

    func time(of call: Call) -> Double? { calls.first { $0.call == call }?.time }

    private func log(_ call: Call) { calls.append((scheduler.now, call)) }
}

@MainActor final class FakeCursor: CursorControlling {
    private(set) var hidden = false
    private(set) var changes: [Bool] = []
    func setHidden(_ hidden: Bool) {
        changes.append(hidden)
        self.hidden = hidden
    }
}

@MainActor final class FakeLocker: ScreenLocking {
    var isAvailable = true
    private(set) var locks = 0
    @discardableResult func lockNow() -> Bool {
        guard isAvailable else { return false }
        locks += 1
        return true
    }
}

@MainActor final class FakeLockState: LockStateReading {
    var locked = false
    private(set) var reads = 0
    func isLocked() -> Bool {
        reads += 1
        return locked
    }
}

@MainActor final class FakeEnvironment: EnvironmentReading {
    var value: RuntimeEnvironment
    init(_ value: RuntimeEnvironment) { self.value = value }
    func read() -> RuntimeEnvironment { value }
}

extension DisplayDescription {
    /// The owner's MacBook Pro 14-inch panel.
    static let macBookPanel = DisplayDescription(id: 1, isBuiltIn: true, isMain: true, frame: CGRect(x: 0, y: 0, width: 1512, height: 982),
                                                 backingScale: 2, physicalSizeMM: CGSize(width: 301.2, height: 195.6))
    static let studioDisplay = DisplayDescription(id: 7, isBuiltIn: false, isMain: false, frame: CGRect(x: 1512, y: 0, width: 2560, height: 1440),
                                                  backingScale: 2, physicalSizeMM: CGSize(width: 597, height: 336))
}

extension RuntimeEnvironment {
    static var macBook: RuntimeEnvironment { RuntimeEnvironment(displays: [.macBookPanel], isLaptop: true) }
}
