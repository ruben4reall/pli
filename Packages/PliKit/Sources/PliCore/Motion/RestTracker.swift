import Foundation

/// Learns where the lid rests, so adjustments and parked lids never frost the screen (spec 6.2).
public struct RestTracker: Sendable, Equatable {
    public static let stillTolerance = 1.5
    public static let stillWindow = 0.3
    public static let glideTimeConstant = 0.35
    public static let glideGap = 0.5

    struct Sample: Sendable, Equatable {
        var time: Double
        var angle: Double
    }

    public private(set) var rest: Double?
    public var settleSeconds: Double
    public var fullFoldAngle: Double

    private var history: [Sample] = []
    private var stillSince: Double?
    private var lastTime: Double?

    public init(settleSeconds: Double, fullFoldAngle: Double) {
        self.settleSeconds = settleSeconds
        self.fullFoldAngle = fullFoldAngle
    }

    public mutating func reset() {
        rest = nil
        history.removeAll()
        stillSince = nil
        lastTime = nil
    }

    /// True once the lid moved less than 1.5° over the last 0.3 s.
    public var isStill: Bool { stillSince != nil }

    @discardableResult
    public mutating func update(angle: Double, at time: Double) -> Double {
        let dt = lastTime.map { (time - $0).clamped(to: 0...0.1) } ?? 0
        lastTime = time
        history.append(Sample(time: time, angle: angle))
        if let firstKept = history.lastIndex(where: { time - $0.time > Self.stillWindow }) {
            history.removeFirst(firstKept)   // keep one sample older than the window, so coverage can be checked
        }

        guard let current = rest else {
            rest = angle
            return angle
        }
        if angle > current {
            rest = angle
            return angle
        }

        let recent = history.filter { time - $0.time <= Self.stillWindow }
        let span = (recent.map(\.angle).max() ?? angle) - (recent.map(\.angle).min() ?? angle)
        let coversWindow = (history.first.map { time - $0.time >= Self.stillWindow } ?? false)
        if span < Self.stillTolerance && coversWindow {
            if stillSince == nil { stillSince = time }
        } else {
            stillSince = nil
        }

        if let since = stillSince, time - since >= settleSeconds,
           angle < current - Self.glideGap, angle > fullFoldAngle {
            rest = current + (angle - current) * (1 - exp(-dt / Self.glideTimeConstant))
        }
        return rest ?? angle
    }
}
