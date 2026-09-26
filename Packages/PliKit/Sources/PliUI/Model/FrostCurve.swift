import Foundation
import PliCore

/// The "frost by angle" curve of the Motion pane (spec 8.3): fold progress for each lid angle, from `FoldMapper`.
public enum FrostCurve {
    /// Used when no rest position is known yet (no sensor, first launch): a usual open lid.
    public static let nominalRest = 110.0

    public struct Point: Equatable, Sendable, Identifiable {
        public var angle: Double
        public var progress: Double
        public var id: Double { angle }
    }

    /// One point per `step` degrees across the protractor's range.
    public static func points(motion: MotionParameters, rest: Double, step: Double = 1) -> [Point] {
        let mapper = FoldMapper(motion: motion)
        return stride(from: ProtractorGeometry.angleRange.lowerBound, through: ProtractorGeometry.angleRange.upperBound, by: step)
            .map { Point(angle: $0, progress: mapper.progress(angle: $0, rest: rest)) }
    }
}
