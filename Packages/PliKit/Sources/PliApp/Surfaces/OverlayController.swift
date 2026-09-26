import AppKit
import PliCore
import PliRender
import PliSystem

/// The real surfaces: the desktop overlay and the lock screen surface, rebuilt when the target display changes
/// (spec 10.6, 11).
@MainActor
public final class OverlayController: SurfacePresenting {
    private let renderer: GlassRenderer?
    private let lockSpace: LockScreenSpace?
    private var configuration: SurfaceConfiguration?
    private var desktop: DesktopSurface?
    private var lock: LockScreenSurface?
    private var wakeObserver: (any NSObjectProtocol)?

    public init(renderer: GlassRenderer?, lockSpace: LockScreenSpace?) {
        self.renderer = renderer
        self.lockSpace = lockSpace
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.screensDidWakeNotification,
                                                                         object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.lock?.adopt() }
        }
    }

    public var visibleSurfaces: Set<Surface> {
        var visible: Set<Surface> = []
        if desktop?.isVisible == true { visible.insert(.desktop) }
        if lock?.isVisible == true { visible.insert(.lockScreen) }
        return visible
    }

    public func configure(_ new: SurfaceConfiguration) {
        let old = configuration
        configuration = new
        guard old?.display != new.display else {
            desktop?.apply(new)
            lock?.apply(new)
            return
        }
        desktop?.close()
        lock?.close()
        desktop = nil
        lock = nil
        guard let display = new.display else { return }
        desktop = DesktopSurface(display: display, renderer: renderer, configuration: new)
        lock = LockScreenSurface(display: display, renderer: renderer, space: lockSpace, configuration: new)
        Log.surfaces.info("surfaces on display \(display.id), \(display.pixelWidth)x\(display.pixelHeight)")
    }

    public func setDesktopSnapshot(_ snapshot: DesktopSnapshot) { desktop?.setSnapshot(snapshot) }
    public func releaseDesktopSnapshot() { desktop?.releaseSnapshot() }
    public func setLockWallpaper(_ wallpaper: WallpaperSource) { lock?.setWallpaper(wallpaper) }

    public func show(_ surface: Surface) {
        switch surface {
        case .desktop: desktop?.show()
        case .lockScreen: lock?.show()
        }
    }

    public func render(_ surface: Surface, progress: Double) {
        switch surface {
        case .desktop: desktop?.render(progress: progress)
        case .lockScreen: lock?.render(progress: progress)
        }
    }

    public func hide(_ surface: Surface, fade: Double) {
        switch surface {
        case .desktop: desktop?.hide(fade: fade)
        case .lockScreen: lock?.hide(fade: fade)
        }
    }

    public func hideAll() {
        desktop?.hide(fade: 0)
        lock?.hide(fade: 0)
    }
}
