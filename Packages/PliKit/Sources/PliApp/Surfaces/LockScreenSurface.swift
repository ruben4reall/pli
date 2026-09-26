import AppKit
import PliCore
import PliRender
import PliSystem

/// The window above the lock screen (spec 5.2, 10.6), in a SkyLight space at lock screen level. It draws the
/// wallpaper and nothing else: its only way to receive a picture takes a `WallpaperSource`, so screen content can
/// never reach the lock screen. Always Metal (spec 7.3); without Metal or SkyLight there is no lock surface.
@MainActor
final class LockScreenSurface {
    let window: OverlayWindow
    private let glass: GlassSurfaceView
    private let space: LockScreenSpace
    private var configuration: SurfaceConfiguration
    private(set) var isVisible = false

    init?(display: DisplayDescription, renderer: GlassRenderer?, space: LockScreenSpace?, configuration: SurfaceConfiguration) {
        let bounds = CGRect(origin: .zero, size: display.frame.size)
        guard let renderer, let space, let glass = try? GlassSurfaceView(renderer: renderer, frame: bounds) else { return nil }
        window = OverlayWindow(frame: display.frame)
        glass.autoresizingMask = [.width, .height]
        window.contentView = glass
        self.glass = glass
        self.space = space
        self.configuration = configuration
    }

    func apply(_ configuration: SurfaceConfiguration) {
        self.configuration = configuration
    }

    func setWallpaper(_ wallpaper: WallpaperSource) {
        do {
            try glass.setSource(wallpaper.pixelBuffer, halfResolution: configuration.halfResolution)
        } catch {
            Log.surfaces.error("wallpaper refused: \(String(describing: error), privacy: .public)")
        }
    }

    func show() {
        isVisible = true
        window.present()
        adopt()
    }

    /// Moves the window into the lock screen space again. After every order front, and after a wake (spec R3).
    func adopt() {
        guard isVisible else { return }
        if !space.adopt(window) { Log.surfaces.error("the lock screen space refused the window") }
    }

    /// Without a wallpaper yet, black: the fold is complete, and nothing else may show.
    func render(progress: Double) {
        guard let display = configuration.display else { return }
        glass.draw(progress: progress, parameters: configuration.glass, pixelsPerMM: display.pixelsPerMM,
                   quality: configuration.quality, reduceMotion: configuration.reduceMotion)
    }

    func hide(fade: Double) {
        isVisible = false
        window.dismiss(fade: fade) { [weak self] in
            self?.glass.presentClear()
            self?.glass.clearSource()
        }
    }

    func close() {
        isVisible = false
        window.orderOut(nil)
        window.close()
    }
}
