import AppKit
import PliCore
import PliRender
import PliSystem

/// The overlay above the desktop (spec 10.6): the Metal glass on a capture, or Basic mode's system blur.
@MainActor
final class DesktopSurface {
    let window: OverlayWindow
    private let glass: GlassSurfaceView?
    private let basic: BasicOverlayView
    private var configuration: SurfaceConfiguration
    private(set) var isVisible = false

    init(display: DisplayDescription, renderer: GlassRenderer?, configuration: SurfaceConfiguration) {
        window = OverlayWindow(frame: display.frame)
        let bounds = CGRect(origin: .zero, size: display.frame.size)
        glass = renderer.flatMap { try? GlassSurfaceView(renderer: $0, frame: bounds) }
        basic = BasicOverlayView(frame: bounds)
        self.configuration = configuration
        let container = NSView(frame: bounds)
        for view in [glass, basic].compactMap({ $0 }) as [NSView] {
            view.autoresizingMask = [.width, .height]
            container.addSubview(view)
        }
        window.contentView = container
        apply(configuration)
    }

    /// Metal unless Basic mode is on or Metal is missing.
    var usesGlass: Bool { !configuration.basic && glass != nil }

    func apply(_ configuration: SurfaceConfiguration) {
        self.configuration = configuration
        glass?.isHidden = !usesGlass
        basic.isHidden = usesGlass
        basic.parameters = configuration.glass
    }

    func setSnapshot(_ snapshot: DesktopSnapshot) {
        do {
            try glass?.setSource(snapshot.pixelBuffer, halfResolution: configuration.halfResolution)
        } catch {
            glass?.clearSource()
            Log.surfaces.error("desktop picture refused: \(String(describing: error), privacy: .public)")
        }
    }

    func releaseSnapshot() {
        glass?.clearSource()
    }

    func show() {
        isVisible = true
        window.present()
    }

    func render(progress: Double) {
        guard let display = configuration.display else { return }
        if usesGlass, let glass {
            glass.draw(progress: progress, parameters: configuration.glass, pixelsPerMM: display.pixelsPerMM,
                       quality: configuration.quality, reduceMotion: configuration.reduceMotion)
        } else {
            basic.render(progress: progress)
        }
    }

    func hide(fade: Double) {
        isVisible = false
        window.dismiss(fade: fade) { [weak self] in self?.glass?.presentClear() }
    }

    func close() {
        isVisible = false
        window.orderOut(nil)
        window.close()
    }
}
