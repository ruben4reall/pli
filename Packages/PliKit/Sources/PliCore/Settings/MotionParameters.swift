import Foundation

/// The Motion group of the interface (spec 6 and 7.4).
public struct MotionParameters: Codable, Hashable, Sendable {
    public var startAngle: Double
    public var deadZoneDegrees: Double
    public var fullFoldAngle: Double
    public var curve: FoldCurve
    public var smoothingMS: Double
    public var settleSeconds: Double
    public var unlockRevealSeconds: Double
    public var demoFoldSeconds: Double
    public var demoHoldSeconds: Double
    public var demoUnfoldSeconds: Double
    public var lockScreenUnfoldSeconds: Double

    public enum Range {
        public static let startAngle: ClosedRange<Double> = 40...130
        public static let deadZoneDegrees: ClosedRange<Double> = 0...20
        public static let fullFoldAngle: ClosedRange<Double> = 5...60
        public static let smoothingMS: ClosedRange<Double> = 0...150
        public static let settleSeconds: ClosedRange<Double> = 0.3...3
        public static let unlockRevealSeconds: ClosedRange<Double> = 0.3...2
        public static let demoFoldSeconds: ClosedRange<Double> = 0.3...2
        public static let demoHoldSeconds: ClosedRange<Double> = 0...1
        public static let demoUnfoldSeconds: ClosedRange<Double> = 0.3...2
        public static let lockScreenUnfoldSeconds: ClosedRange<Double> = 0.3...2
    }

    public init(
        startAngle: Double, deadZoneDegrees: Double, fullFoldAngle: Double, curve: FoldCurve,
        smoothingMS: Double, settleSeconds: Double, unlockRevealSeconds: Double,
        demoFoldSeconds: Double, demoHoldSeconds: Double, demoUnfoldSeconds: Double,
        lockScreenUnfoldSeconds: Double
    ) {
        self.startAngle = startAngle
        self.deadZoneDegrees = deadZoneDegrees
        self.fullFoldAngle = fullFoldAngle
        self.curve = curve
        self.smoothingMS = smoothingMS
        self.settleSeconds = settleSeconds
        self.unlockRevealSeconds = unlockRevealSeconds
        self.demoFoldSeconds = demoFoldSeconds
        self.demoHoldSeconds = demoHoldSeconds
        self.demoUnfoldSeconds = demoUnfoldSeconds
        self.lockScreenUnfoldSeconds = lockScreenUnfoldSeconds
    }

    public static let duo = MotionParameters(
        startAngle: 90, deadZoneDegrees: 6, fullFoldAngle: 20, curve: .linear,
        smoothingMS: 45, settleSeconds: 0.8, unlockRevealSeconds: 0.9,
        demoFoldSeconds: 0.8, demoHoldSeconds: 0.35, demoUnfoldSeconds: 1.0,
        lockScreenUnfoldSeconds: 0.8
    )

    public func clamped() -> MotionParameters {
        MotionParameters(
            startAngle: startAngle.clamped(to: Range.startAngle),
            deadZoneDegrees: deadZoneDegrees.clamped(to: Range.deadZoneDegrees),
            fullFoldAngle: fullFoldAngle.clamped(to: Range.fullFoldAngle),
            curve: curve,
            smoothingMS: smoothingMS.clamped(to: Range.smoothingMS),
            settleSeconds: settleSeconds.clamped(to: Range.settleSeconds),
            unlockRevealSeconds: unlockRevealSeconds.clamped(to: Range.unlockRevealSeconds),
            demoFoldSeconds: demoFoldSeconds.clamped(to: Range.demoFoldSeconds),
            demoHoldSeconds: demoHoldSeconds.clamped(to: Range.demoHoldSeconds),
            demoUnfoldSeconds: demoUnfoldSeconds.clamped(to: Range.demoUnfoldSeconds),
            lockScreenUnfoldSeconds: lockScreenUnfoldSeconds.clamped(to: Range.lockScreenUnfoldSeconds)
        )
    }

    enum CodingKeys: String, CodingKey {
        case startAngle, deadZoneDegrees, fullFoldAngle, curve, smoothingMS, settleSeconds
        case unlockRevealSeconds, demoFoldSeconds, demoHoldSeconds, demoUnfoldSeconds, lockScreenUnfoldSeconds
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = MotionParameters.duo
        self.init(
            startAngle: c.value(.startAngle, default: d.startAngle),
            deadZoneDegrees: c.value(.deadZoneDegrees, default: d.deadZoneDegrees),
            fullFoldAngle: c.value(.fullFoldAngle, default: d.fullFoldAngle),
            curve: c.value(.curve, default: d.curve),
            smoothingMS: c.value(.smoothingMS, default: d.smoothingMS),
            settleSeconds: c.value(.settleSeconds, default: d.settleSeconds),
            unlockRevealSeconds: c.value(.unlockRevealSeconds, default: d.unlockRevealSeconds),
            demoFoldSeconds: c.value(.demoFoldSeconds, default: d.demoFoldSeconds),
            demoHoldSeconds: c.value(.demoHoldSeconds, default: d.demoHoldSeconds),
            demoUnfoldSeconds: c.value(.demoUnfoldSeconds, default: d.demoUnfoldSeconds),
            lockScreenUnfoldSeconds: c.value(.lockScreenUnfoldSeconds, default: d.lockScreenUnfoldSeconds)
        )
        self = clamped()
    }
}
