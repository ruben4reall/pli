import Foundation

/// A scripted lid movement: angles at times, linear in between.
public struct LidScript: Sendable, Equatable {
    public struct Keyframe: Sendable, Equatable {
        public var time: Double
        public var angle: Double

        public init(_ time: Double, _ angle: Double) {
            self.time = time
            self.angle = angle
        }
    }

    public var name: String
    /// Sorted by time; never empty.
    public var keyframes: [Keyframe]

    public init(name: String, keyframes: [Keyframe]) {
        self.name = name
        self.keyframes = keyframes.isEmpty ? [Keyframe(0, 110)] : keyframes.sorted { $0.time < $1.time }
    }

    public var duration: Double { keyframes[keyframes.count - 1].time }

    public func angle(at time: Double) -> Double {
        if time <= keyframes[0].time { return keyframes[0].angle }
        for (a, b) in zip(keyframes, keyframes.dropFirst()) where time <= b.time {
            let span = b.time - a.time
            return span <= 0 ? b.angle : a.angle + (b.angle - a.angle) * (time - a.time) / span
        }
        return keyframes[keyframes.count - 1].angle
    }

    public static let closeHalfwayAndReopen = LidScript(name: "Close Halfway, Then Reopen",
                                                        keyframes: [.init(0, 110), .init(0.8, 55), .init(1.6, 55), .init(2.4, 110)])
    public static let closeSlowly = LidScript(name: "Close Slowly", keyframes: [.init(0, 110), .init(3, 0)])
    public static let closeQuickly = LidScript(name: "Close Quickly", keyframes: [.init(0, 110), .init(1, 0)])
    public static let openFromClosed = LidScript(name: "Open From Closed", keyframes: [.init(0, 0), .init(1.2, 110)])
    public static let parkThenClose = LidScript(name: "Park at 60°, Then Close",
                                                keyframes: [.init(0, 110), .init(0.5, 60), .init(3, 60), .init(4, 0)])
    public static let adjustments = LidScript(name: "Adjust by 15°",
                                              keyframes: [.init(0, 110), .init(0.6, 95), .init(1.4, 95), .init(2, 110), .init(2.6, 125), .init(3.4, 110)])
    /// The Debug menu's scripts, in order.
    public static let library: [LidScript] = [closeHalfwayAndReopen, closeSlowly, closeQuickly, openFromClosed, parkThenClose, adjustments]
}

/// The developer's lid, the angle simulator: an angle set from the Debug menu or played from a script,
/// published like the real sensor, in whole degrees, fresh at the polling rate.
@MainActor
public final class SimulatedLidSensor: LidSensing {
    public let updates: AsyncStream<LidSensorUpdate>
    private let continuation: AsyncStream<LidSensorUpdate>.Continuation
    private let clock: () -> Double
    private var book = LidSampleBook()
    private var fixedAngle: Double
    private var script: LidScript?
    private var scriptStart = 0.0
    private var mode: LidPollingMode = .rest
    private var timer: Timer?

    public init(angle: Double = 110, clock: @escaping () -> Double = HostClock.now) {
        let (stream, continuation) = AsyncStream.makeStream(of: LidSensorUpdate.self, bufferingPolicy: .bufferingNewest(16))
        updates = stream
        self.continuation = continuation
        self.clock = clock
        fixedAngle = angle
    }

    public var latest: LidSample? { book.latest }
    public var isAvailable: Bool { book.isAvailable }
    public var isPlaying: Bool { script != nil }

    /// Where the simulated lid is now, before rounding.
    public var currentAngle: Double {
        guard let script else { return fixedAngle }
        return script.angle(at: clock() - scriptStart)
    }

    public func start() {
        if book.setAvailable(true) { continuation.yield(.availabilityChanged(true)) }
        tick()
        schedule()
    }

    public func stop() {
        timer?.invalidate()
        timer = nil
    }

    public func setMode(_ mode: LidPollingMode) {
        self.mode = mode
        if timer != nil { schedule() }
    }

    public func didWake() {}

    public func set(angle: Double) {
        script = nil
        fixedAngle = angle
        tick()
    }

    public func play(_ script: LidScript) {
        self.script = script
        scriptStart = clock()
        tick()
    }

    /// One reading, as the real sensor would make it. The timer calls it; tests call it directly.
    public func tick() {
        if let script, clock() - scriptStart >= script.duration {
            fixedAngle = script.angle(at: script.duration)
            self.script = nil
        }
        if book.record(angle: currentAngle.rounded(), at: clock()) { continuation.yield(.angleChanged) }
    }

    private func schedule() {
        timer?.invalidate()
        let hz: Double
        switch mode {
        case .rest: hz = 10
        case .active(let rate): hz = max(rate, 1)
        }
        let timer = Timer(timeInterval: 1 / hz, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }
}
