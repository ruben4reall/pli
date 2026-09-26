import AppKit

/// The live menu bar symbol (spec 8.2): a MacBook in profile whose lid follows the real angle in 5° steps. A
/// template image, so macOS paints it for light and dark menu bars; static on a Mac without the sensor.
public enum MenuBarSymbol {
    public enum Pose: Hashable, Sendable {
        /// No sensor: the lid stays at `stillAngle`.
        case still
        case angle(Int)
    }

    public static let step = 5
    public static let maximumAngle = 135
    public static let stillAngle = 110
    public static let canvas = CGSize(width: 22, height: 16)
    static let hinge = CGPoint(x: 9, y: 12)
    static let lidLength: CGFloat = 11
    static let lidWidth: CGFloat = 2
    static let base = CGRect(x: 8.5, y: 12, width: 13, height: 2)

    public static func pose(angle: Double?, sensorAvailable: Bool) -> Pose {
        guard sensorAvailable, let angle, angle.isFinite else { return .still }
        return .angle(quantize(angle))
    }

    /// The nearest 5° step inside 0...135.
    public static func quantize(_ angle: Double) -> Int {
        let clamped = min(max(angle, 0), Double(maximumAngle))
        return Int((clamped / Double(step)).rounded()) * step
    }

    public static func angle(of pose: Pose) -> Int {
        switch pose {
        case .still: stillAngle
        case .angle(let degrees): degrees
        }
    }

    /// Where the lid ends, in the flipped canvas (y down): 0° lies on the base, 90° stands upright.
    public static func lidEnd(for pose: Pose) -> CGPoint {
        let radians = Double(angle(of: pose)) * .pi / 180
        return CGPoint(x: hinge.x + lidLength * cos(radians), y: hinge.y - lidLength * sin(radians))
    }

    public static func accessibilityLabel(for pose: Pose) -> String {
        switch pose {
        case .still: Strings.appName
        case .angle(let degrees): Strings.menuBarSymbol(lidAt: degrees)
        }
    }

    @MainActor private static var cache: [Pose: NSImage] = [:]

    /// One template image per pose, drawn again by AppKit at each display's scale.
    @MainActor public static func image(for pose: Pose) -> NSImage {
        if let cached = cache[pose] { return cached }
        let end = lidEnd(for: pose)
        let image = NSImage(size: canvas, flipped: true) { _ in
            NSColor.black.setFill()
            NSBezierPath(roundedRect: base, xRadius: 1, yRadius: 1).fill()
            let lid = NSBezierPath()
            lid.move(to: hinge)
            lid.line(to: end)
            lid.lineWidth = lidWidth
            lid.lineCapStyle = .round
            NSColor.black.setStroke()
            lid.stroke()
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = accessibilityLabel(for: pose)
        cache[pose] = image
        return image
    }
}

/// At most 30 symbol redraws per second (spec 8.2), and the latest pose always shown in the end. Times are compared
/// with the same sum the flush time is made of, so a flush at exactly that time is never refused by rounding.
public struct SymbolThrottle: Equatable, Sendable {
    public static let minimumInterval = 1.0 / 30

    public private(set) var shown: MenuBarSymbol.Pose
    private var pending: MenuBarSymbol.Pose?
    private var shownAt = -Double.infinity

    public init(shown: MenuBarSymbol.Pose) {
        self.shown = shown
    }

    /// A new pose. Shown now when the last redraw is old enough; otherwise kept, and the return value is when to
    /// call `flush(at:)` (nil when a flush is already due or nothing is waiting).
    public mutating func offer(_ pose: MenuBarSymbol.Pose, at now: Double) -> Double? {
        guard pose != shown else {
            pending = nil
            return nil
        }
        if now >= shownAt + Self.minimumInterval {
            show(pose, at: now)
            return nil
        }
        let alreadyWaiting = pending != nil
        pending = pose
        return alreadyWaiting ? nil : shownAt + Self.minimumInterval
    }

    /// Shows the waiting pose, or says when to try again.
    public mutating func flush(at now: Double) -> Double? {
        guard let pose = pending else { return nil }
        guard now >= shownAt + Self.minimumInterval else { return shownAt + Self.minimumInterval }
        show(pose, at: now)
        return nil
    }

    private mutating func show(_ pose: MenuBarSymbol.Pose, at now: Double) {
        shown = pose
        shownAt = now
        pending = nil
    }
}
