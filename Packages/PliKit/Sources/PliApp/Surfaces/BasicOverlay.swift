import AppKit
import PliCore

/// Basic mode at a fold progress, as numbers (spec 7.3): pure, so it is tested.
struct BasicOverlayLayout: Equatable {
    /// Opacity of the system blur (Frost).
    var frostOpacity: Double
    /// Share of the height the blur covers, from the top: the frost thickens toward the top (spec 5.1).
    var frostReach: Double
    /// Black at the top and at the bottom of the darkening gradient (Darkening).
    var darkTop: Double
    var darkBottom: Double
    /// Opacity of the final black (Final Blackout).
    var blackout: Double

    static func make(progress: Double, parameters: GlassParameters) -> BasicOverlayLayout {
        let p = progress.clamped(to: 0...1)
        let frost = parameters.frost / GlassParameters.Range.frost.upperBound
        let darkening = parameters.darkening / GlassParameters.Range.darkening.upperBound
        let darkTop = min(0.9, darkening * 1.2 * p)
        return BasicOverlayLayout(
            frostOpacity: frost > 0 ? min(1, p * 2) * (0.25 + 0.75 * frost) : 0,
            frostReach: p > 0 ? min(1, 0.15 + 0.85 * p) : 0,
            darkTop: darkTop,
            darkBottom: darkTop * 0.25,
            blackout: 1 - GlassOptics.blackout(progress: p, amount: parameters.finalBlackout)
        )
    }
}

/// Basic mode (spec 7.3): the system's blur behind the window, masked by a gradient that rises with the fold,
/// then a darkening gradient and the final black. For Macs without the Screen Recording permission.
@MainActor
final class BasicOverlayView: NSView {
    /// Height of the blur's soft lower edge, in points.
    static let softEdge: CGFloat = 120

    var parameters: GlassParameters = .duo
    private let frost = NSVisualEffectView()
    private let darkening = GradientView()
    private let blackout = NSView()
    private var progress = 0.0

    override init(frame: NSRect) {
        super.init(frame: frame)
        frost.material = .fullScreenUI
        frost.blendingMode = .behindWindow
        frost.state = .active
        frost.maskImage = Self.edgeMask(softEdge: Self.softEdge)
        blackout.wantsLayer = true
        blackout.layer?.backgroundColor = NSColor.black.cgColor
        for view in [frost, darkening, blackout] { addSubview(view) }
        render(progress: 0)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func layout() {
        super.layout()
        render(progress: progress)
    }

    func render(progress: Double) {
        self.progress = progress
        let layout = BasicOverlayLayout.make(progress: progress, parameters: parameters)
        let reach = bounds.height * layout.frostReach
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        frost.frame = CGRect(x: 0, y: bounds.height - reach - Self.softEdge, width: bounds.width, height: reach + Self.softEdge)
        frost.alphaValue = layout.frostOpacity
        frost.isHidden = layout.frostOpacity <= 0
        darkening.frame = bounds
        darkening.set(top: layout.darkTop, bottom: layout.darkBottom)
        blackout.frame = bounds
        blackout.alphaValue = layout.blackout
        CATransaction.commit()
    }

    /// Opaque above, clear over the bottom `softEdge` points; the cap insets keep the edge the same height at any size.
    static func edgeMask(softEdge: CGFloat) -> NSImage {
        let image = NSImage(size: NSSize(width: 1, height: softEdge + 2), flipped: false) { _ in
            NSGradient(starting: NSColor.black.withAlphaComponent(0), ending: .black)?
                .draw(in: NSRect(x: 0, y: 0, width: 1, height: softEdge), angle: 90)
            NSColor.black.setFill()
            NSRect(x: 0, y: softEdge, width: 1, height: 2).fill()
            return true
        }
        image.capInsets = NSEdgeInsets(top: 1, left: 0, bottom: softEdge, right: 0)
        image.resizingMode = .stretch
        return image
    }
}

/// A vertical black gradient, top to bottom.
@MainActor
private final class GradientView: NSView {
    private let gradient = CAGradientLayer()

    override init(frame: NSRect) {
        super.init(frame: frame)
        gradient.startPoint = CGPoint(x: 0.5, y: 1)
        gradient.endPoint = CGPoint(x: 0.5, y: 0)
        layer = gradient
        wantsLayer = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    func set(top: Double, bottom: Double) {
        gradient.colors = [NSColor(white: 0, alpha: top).cgColor, NSColor(white: 0, alpha: bottom).cgColor]
    }
}
