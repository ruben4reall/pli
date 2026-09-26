import Foundation

/// A drawing surface Pli controls.
public enum Surface: Sendable, Hashable {
    /// The overlay above the desktop (built-in display, or the main display on a Mac without one).
    case desktop
    /// The window above the lock screen. It only ever shows the wallpaper.
    case lockScreen
}

/// What this Mac can do right now. The runtime refreshes it whenever something changes.
public struct Capabilities: Sendable, Equatable {
    public var hasLidSensor: Bool
    public var builtInDisplayAvailable: Bool
    public var screenCaptureAllowed: Bool
    public var lockScreenSurfaceAvailable: Bool
    public var canLockNow: Bool
    public var reduceMotion: Bool

    public init(
        hasLidSensor: Bool = true,
        builtInDisplayAvailable: Bool = true,
        screenCaptureAllowed: Bool = true,
        lockScreenSurfaceAvailable: Bool = true,
        canLockNow: Bool = true,
        reduceMotion: Bool = false
    ) {
        self.hasLidSensor = hasLidSensor
        self.builtInDisplayAvailable = builtInDisplayAvailable
        self.screenCaptureAllowed = screenCaptureAllowed
        self.lockScreenSurfaceAvailable = lockScreenSurfaceAvailable
        self.canLockNow = canLockNow
        self.reduceMotion = reduceMotion
    }
}

/// Everything that can happen to Pli (spec 6.5).
public enum DirectorEvent: Sendable, Equatable {
    case angle(Double)
    case tick
    case captureReady
    case captureFailed
    case willSleep
    case didWake(locked: Bool)
    case screenLocked
    case screenUnlocked
    case lockStatePolled(locked: Bool)
    case demoRequested
    case lockRequested
    case settingsChanged(PliSettings)
    case capabilitiesChanged(Capabilities)
}

/// What the runtime must do. Fades and delays are in seconds.
public enum DirectorCommand: Sendable, Equatable {
    case captureDesktop
    case loadWallpaper
    case show(Surface)
    case render(Surface, progress: Double)
    case hide(Surface, fade: Double)
    case releaseSnapshot(after: Double)
    case setCursorHidden(Bool)
    case lockNow
    case startLockPolling
    case stopLockPolling
}

public enum DirectorPhase: Sendable, Equatable {
    case inactive
    case idle
    case arming(since: Double, afterWake: Bool)
    case folding
    case folded
    case lockUnfolding(TimedAnimation?)
    case awaitingUnlock
    case revealing(requestedAt: Double, animation: TimedAnimation?)
    case demo(requestedAt: Double, startAngle: Double?, startedAt: Double?)
    case lockFolding(requestedAt: Double, fold: TimedAnimation?, lockIssuedAt: Double?)
}
