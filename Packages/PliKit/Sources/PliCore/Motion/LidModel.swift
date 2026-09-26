import Foundation

/// The lid as Pli sees it: smoothed angle, learned rest, fold progress, and how long the sensor has been silent.
public struct LidModel: Sendable, Equatable {
    public private(set) var rawAngle: Double?
    /// How long the sensor has been silent, in frame time: the sum of the frame steps given to
    /// `advance(to:dt:)` since the last sample, each counted up to 0.1 s like the smoothing. Only frames
    /// count, so a stretch without frames (the Mac asleep) is never silence. Nil before the first sample.
    public private(set) var silence: Double?
    public private(set) var mapper: FoldMapper
    private var follower: AngleFollower
    private var restTracker: RestTracker

    public init(motion: MotionParameters) {
        mapper = FoldMapper(motion: motion)
        follower = AngleFollower(timeConstant: motion.smoothingMS / 1000)
        restTracker = RestTracker(settleSeconds: motion.settleSeconds, fullFoldAngle: motion.fullFoldAngle)
    }

    public mutating func apply(_ motion: MotionParameters) {
        mapper = FoldMapper(motion: motion)
        follower.timeConstant = motion.smoothingMS / 1000
        restTracker.settleSeconds = motion.settleSeconds
        restTracker.fullFoldAngle = motion.fullFoldAngle
    }

    /// A sensor sample: the new raw angle, and the silence starts again from zero.
    public mutating func receive(angle: Double) {
        rawAngle = angle
        silence = 0
    }

    /// One frame: smoothing, then rest learning from the smoothed angle. The step also counts as silence
    /// until the next sample.
    public mutating func advance(to time: Double, dt: Double) {
        guard let raw = rawAngle else { return }
        silence = (silence ?? 0) + dt.clamped(to: 0...0.1)
        let smoothed = follower.advance(toward: raw, dt: dt)
        restTracker.update(angle: smoothed, at: time)
    }

    /// Without frames (idle): snap smoothing to the raw angle and learn the rest from it.
    public mutating func settleIdle(at time: Double) {
        guard let raw = rawAngle else { return }
        follower.snap(to: raw)
        restTracker.update(angle: raw, at: time)
    }

    /// Counts the silence from zero again, as if a sample had just arrived (the angle itself is unchanged).
    public mutating func resetSilence() {
        if silence != nil { silence = 0 }
    }

    public mutating func resetRest() { restTracker.reset() }

    public var angle: Double? { follower.value }

    public var rest: Double? { restTracker.rest }

    public var progress: Double {
        guard let angle, let rest else { return 0 }
        return mapper.progress(angle: angle, rest: rest)
    }

    public var isLowered: Bool {
        guard let angle, let rest else { return false }
        return angle < mapper.effectStart(rest: rest)
    }

    public var preArmAngle: Double? { rest.map { mapper.preArmAngle(rest: $0) } }
}
