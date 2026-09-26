import CoreGraphics
import Foundation
import PliCore

/// The three angles the protractor marks (spec 8.3): the rest position, where the frost starts, and where it is
/// complete. The frosted arc runs between the last two.
public struct ProtractorMarks: Equatable, Sendable {
    public var rest: Double
    public var start: Double
    public var fullyFrosted: Double

    public init(rest: Double, start: Double, fullyFrosted: Double) {
        self.rest = rest
        self.start = start
        self.fullyFrosted = fullyFrosted
    }

    /// The marks the engine would use: `FoldMapper`'s effect start for this rest position (spec 6.3).
    public init(motion: MotionParameters, rest: Double) {
        self.init(rest: rest, start: FoldMapper(motion: motion).effectStart(rest: rest), fullyFrosted: motion.fullFoldAngle)
    }
}

/// The protractor's drawing space: a MacBook in profile, the hinge at the center of the angles, the base toward the
/// right, the lid rising counterclockwise. Angles in degrees (0 closed, 90 upright), points in a flipped space (y down,
/// SwiftUI's).
public struct ProtractorGeometry: Equatable, Sendable {
    public static let angleRange: ClosedRange<Double> = 0...135
    /// How far the lid reaches left of the hinge at 135°, and the base's length, as fractions of the lid.
    static let reachBehind = cos(45 * Double.pi / 180)
    static let baseLength = 1.0
    static let baseThickness = 0.06

    public let size: CGSize
    public let hinge: CGPoint
    /// The lid's length in points.
    public let radius: Double

    /// Fits the MacBook, lid at any angle, in `size` with `inset` points to spare on every side, centered.
    /// `overshoot` reserves room past the lid's reach, as a fraction of the lid (the marks drawn beyond it).
    public init(size: CGSize, inset: CGFloat = 12, overshoot: Double = 0) {
        self.size = size
        let width = max(Double(size.width - 2 * inset), 1)
        let height = max(Double(size.height - 2 * inset), 1)
        let reach = 1 + max(overshoot, 0)
        let spanX = Self.reachBehind * reach + max(Self.baseLength, reach)
        let spanY = reach + Self.baseThickness
        let radius = min(width / spanX, height / spanY)
        self.radius = radius
        let slackX = (width - radius * spanX) / 2
        let slackY = (height - radius * spanY) / 2
        hinge = CGPoint(x: Double(inset) + slackX + radius * Self.reachBehind * reach, y: Double(inset) + slackY + radius * reach)
    }

    public func point(angle: Double, distance: Double? = nil) -> CGPoint {
        let radians = angle * .pi / 180
        let length = distance ?? radius
        return CGPoint(x: Double(hinge.x) + length * cos(radians), y: Double(hinge.y) - length * sin(radians))
    }

    /// The angle `location` points at, clamped to `angleRange`: under the base on the right reads as closed, behind
    /// and under the hinge as the widest opening.
    public func angle(at location: CGPoint) -> Double {
        let dx = Double(location.x - hinge.x)
        let dy = Double(hinge.y - location.y)
        guard dx != 0 || dy != 0 else { return 0 }
        var degrees = atan2(dy, dx) * 180 / .pi
        if degrees < -90 { degrees += 360 }
        return degrees.clamped(to: Self.angleRange)
    }

    /// The base under the hinge, toward the right.
    public var base: CGRect {
        CGRect(x: Double(hinge.x), y: Double(hinge.y), width: radius * Self.baseLength, height: radius * Self.baseThickness)
    }

    /// The annular sector between two angles: the frosted arc.
    public func sector(from start: Double, to end: Double, inner: Double, outer: Double) -> CGPath {
        let low = min(start, end) * .pi / 180
        let high = max(start, end) * .pi / 180
        let path = CGMutablePath()
        // Flipped space: a counterclockwise angle on screen is a negative angle for CGPath.
        path.addArc(center: hinge, radius: outer, startAngle: -low, endAngle: -high, clockwise: true)
        path.addArc(center: hinge, radius: inner, startAngle: -high, endAngle: -low, clockwise: false)
        path.closeSubpath()
        return path
    }
}
