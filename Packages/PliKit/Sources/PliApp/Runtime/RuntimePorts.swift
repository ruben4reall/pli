import CoreGraphics
import PliCore
import PliRender
import PliSystem

/// Where the surfaces draw and how they look. The runtime sends a new one whenever any part changes.
public struct SurfaceConfiguration: Sendable, Equatable {
    /// The display the effect plays on (spec 5.4); nil while Pli is paused.
    public var display: DisplayDescription?
    public var glass: GlassParameters
    /// Basic mode (spec 7.3): no capture, the system blur instead.
    public var basic: Bool
    public var quality: RenderQuality
    /// Low Power Mode: half-resolution pyramid (spec 5.5).
    public var halfResolution: Bool
    public var reduceMotion: Bool

    public init(display: DisplayDescription?, glass: GlassParameters, basic: Bool, quality: RenderQuality,
                halfResolution: Bool, reduceMotion: Bool) {
        self.display = display
        self.glass = glass
        self.basic = basic
        self.quality = quality
        self.halfResolution = halfResolution
        self.reduceMotion = reduceMotion
    }
}

/// The overlay surfaces, as the runtime drives them (spec 10.6).
@MainActor
public protocol SurfacePresenting: AnyObject {
    /// Surfaces ordered in and not yet told to hide.
    var visibleSurfaces: Set<Surface> { get }
    func configure(_ configuration: SurfaceConfiguration)
    func setDesktopSnapshot(_ snapshot: DesktopSnapshot)
    func releaseDesktopSnapshot()
    func setLockWallpaper(_ wallpaper: WallpaperSource)
    func show(_ surface: Surface)
    func render(_ surface: Surface, progress: Double)
    func hide(_ surface: Surface, fade: Double)
    /// Every surface off at once: at launch, at quit, and as the watchdog's last resort.
    func hideAll()
}

/// Ticks paced by the display while the director wants frames, and nothing otherwise (spec 7.2, 10.3).
@MainActor
public protocol FrameClock: AnyObject {
    var isRunning: Bool { get }
    func start(display: CGDirectDisplayID?, maximumRate: Double, onFrame: @escaping @MainActor () -> Void)
    func stop()
}

@MainActor
public protocol Cancellable: AnyObject {
    func cancel()
}

/// Time and timers, so tests run the runtime on a virtual clock.
@MainActor
public protocol Scheduling: AnyObject {
    /// Host seconds, the clock of `CACurrentMediaTime()` and `HostClock`.
    var now: Double { get }
    @discardableResult func after(_ delay: Double, _ action: @escaping @MainActor () -> Void) -> any Cancellable
    @discardableResult func every(_ interval: Double, _ action: @escaping @MainActor () -> Void) -> any Cancellable
}

/// What this Mac is and allows right now.
public struct RuntimeEnvironment: Sendable, Equatable {
    public var displays: [DisplayDescription]
    public var isLaptop: Bool
    public var screenCaptureAllowed: Bool
    public var reduceMotion: Bool
    public var lowPowerMode: Bool
    public var darkAppearance: Bool
    /// The SkyLight space resolved and Metal works (spec 7.3, 10.7).
    public var lockScreenSurfaceAvailable: Bool
    public var canLockNow: Bool

    public init(displays: [DisplayDescription] = [], isLaptop: Bool = true, screenCaptureAllowed: Bool = true,
                reduceMotion: Bool = false, lowPowerMode: Bool = false, darkAppearance: Bool = false,
                lockScreenSurfaceAvailable: Bool = true, canLockNow: Bool = true) {
        self.displays = displays
        self.isLaptop = isLaptop
        self.screenCaptureAllowed = screenCaptureAllowed
        self.reduceMotion = reduceMotion
        self.lowPowerMode = lowPowerMode
        self.darkAppearance = darkAppearance
        self.lockScreenSurfaceAvailable = lockScreenSurfaceAvailable
        self.canLockNow = canLockNow
    }

    /// The built-in panel, or the main display of a Mac without one; nil for a closed MacBook (spec 5.4, 5.5).
    public var effectTarget: DisplayDescription? { DisplayInfo.effectTarget(in: displays, isLaptop: isLaptop) }

    public var builtInDisplay: DisplayDescription? { displays.first(where: \.isBuiltIn) }

    public func capabilities(lidSensorAvailable: Bool) -> Capabilities {
        Capabilities(
            hasLidSensor: lidSensorAvailable,
            builtInDisplayAvailable: builtInDisplay != nil,
            screenCaptureAllowed: screenCaptureAllowed,
            lockScreenSurfaceAvailable: lockScreenSurfaceAvailable && effectTarget != nil,
            canLockNow: canLockNow,
            reduceMotion: reduceMotion
        )
    }
}

@MainActor
public protocol EnvironmentReading: AnyObject {
    func read() -> RuntimeEnvironment
}
