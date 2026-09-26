import Foundation

/// Smooths the sensor's 1° steps with an exponential ease (spec 6.1).
public struct AngleFollower: Sendable, Equatable {
    public private(set) var value: Double?
    /// Seconds; 0 means no smoothing.
    public var timeConstant: Double

    public init(timeConstant: Double) {
        self.timeConstant = timeConstant
    }

    public mutating func reset() { value = nil }

    public mutating func snap(to angle: Double) { value = angle }

    @discardableResult
    public mutating func advance(toward target: Double, dt: Double) -> Double {
        guard let current = value else {
            value = target
            return target
        }
        let step = dt.clamped(to: 0...0.1)
        var next = timeConstant <= 0 ? target : current + (target - current) * (1 - exp(-step / timeConstant))
        if abs(target - next) < 0.02 { next = target }
        value = next
        return next
    }
}
