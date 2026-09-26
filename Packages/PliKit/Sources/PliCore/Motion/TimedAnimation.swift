import Foundation

/// A fold or unfold that runs for a fixed duration, independent of the lid.
public struct TimedAnimation: Sendable, Equatable {
    public enum Direction: Sendable, Equatable {
        case fold
        case unfold
    }

    public let direction: Direction
    public let start: Double
    public let duration: Double

    public init(_ direction: Direction, start: Double, duration: Double) {
        self.direction = direction
        self.start = start
        self.duration = Swift.max(duration, 0.001)
    }

    /// Fold progress at `time`: 0 to 1 for a fold (ease in and out), 1 to 0 for an unfold (ease out).
    public func progress(at time: Double) -> Double {
        let t = ((time - start) / duration).clamped(to: 0...1)
        switch direction {
        case .fold: return Easing.inOutCubic(t)
        case .unfold: return 1 - Easing.outCubic(t)
        }
    }

    public func isFinished(at time: Double) -> Bool { time - start >= duration }

    public var end: Double { start + duration }
}
