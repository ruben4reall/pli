import Foundation

/// Turns the lid angle into fold progress (spec 6.3).
public struct FoldMapper: Sendable, Equatable {
    public static let preArmMargin = 8.0
    public static let minimumLowering = 2.0

    public var startAngle: Double
    public var deadZone: Double
    public var fullFoldAngle: Double
    public var curve: FoldCurve

    public init(startAngle: Double, deadZone: Double, fullFoldAngle: Double, curve: FoldCurve) {
        self.startAngle = startAngle
        self.deadZone = deadZone
        self.fullFoldAngle = fullFoldAngle
        self.curve = curve
    }

    public init(motion: MotionParameters) {
        self.init(startAngle: motion.startAngle, deadZone: motion.deadZoneDegrees, fullFoldAngle: motion.fullFoldAngle, curve: motion.curve)
    }

    /// `S = max(min(R − D, A), min(R, F + 10))`.
    public func effectStart(rest: Double) -> Double {
        Swift.max(Swift.min(rest - deadZone, startAngle), Swift.min(rest, fullFoldAngle + 10))
    }

    /// The capture is requested below this angle, a little before the effect starts.
    public func preArmAngle(rest: Double) -> Double {
        Swift.min(effectStart(rest: rest) + Self.preArmMargin, rest - Self.minimumLowering)
    }

    public func progress(angle: Double, rest: Double) -> Double {
        let start = effectStart(rest: rest)
        if start - fullFoldAngle < 1 { return angle <= fullFoldAngle ? 1 : 0 }
        return curve.apply((start - angle) / (start - fullFoldAngle))
    }
}
