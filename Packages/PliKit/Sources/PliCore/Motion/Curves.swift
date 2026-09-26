import Foundation

/// How fold progress follows the lid travel (spec 6.3).
public enum FoldCurve: String, Codable, CaseIterable, Sendable {
    case linear
    case smooth
    case fastStart
    case slowStart

    /// Maps linear progress, clamped to 0...1, through the curve.
    public func apply(_ x: Double) -> Double {
        let t = x.clamped(to: 0...1)
        switch self {
        case .linear: return t
        case .smooth: return t * t * (3 - 2 * t)
        case .fastStart: return 1 - (1 - t) * (1 - t)
        case .slowStart: return t * t
        }
    }
}

/// Easing for timed animations (spec 6.4).
public enum Easing {
    public static func inOutCubic(_ x: Double) -> Double {
        let t = x.clamped(to: 0...1)
        return t < 0.5 ? 4 * t * t * t : 1 - pow(-2 * t + 2, 3) / 2
    }

    public static func outCubic(_ x: Double) -> Double {
        let t = x.clamped(to: 0...1)
        return 1 - pow(1 - t, 3)
    }
}
