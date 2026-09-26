import Foundation
import Observation

/// Pli's two global shortcuts (spec 5.4).
public enum ShortcutAction: String, CaseIterable, Sendable, Hashable {
    case demo
    case animatedLock

    public var title: String { self == .demo ? Strings.demo : Strings.animatedLock }
    public var other: ShortcutAction { self == .demo ? .animatedLock : .demo }
}

/// What the running app knows right now. The app sends one after every change (a lid sample, a phase, a capability),
/// up to 120 times per second during a gesture.
public struct LiveSnapshot: Sendable, Equatable {
    /// The last sensor reading, whole degrees; nil before the first one or without a sensor.
    public var lidAngle: Double?
    /// The learned rest position (spec 6.2).
    public var restAngle: Double?
    public var sensorAvailable: Bool
    public var screenCaptureAllowed: Bool
    /// The permission was asked for in this session: a relaunch may be what it still needs (spec R5).
    public var permissionRequested: Bool
    /// A closed MacBook on an external display (spec 5.5).
    public var paused: Bool
    public var canLockNow: Bool
    public var lockScreenSurfaceAvailable: Bool
    public var cursorHidingAvailable: Bool
    public var reduceMotion: Bool
    /// Shortcuts macOS refused because another app holds them.
    public var refusedShortcuts: Set<ShortcutAction>
    /// Physical width of the display the effect plays on: the previews are its miniature.
    public var displayWidthMM: Double
    public var displayAspectRatio: Double

    public init(lidAngle: Double? = nil, restAngle: Double? = nil, sensorAvailable: Bool = true,
                screenCaptureAllowed: Bool = true, permissionRequested: Bool = false, paused: Bool = false,
                canLockNow: Bool = true, lockScreenSurfaceAvailable: Bool = true, cursorHidingAvailable: Bool = true,
                reduceMotion: Bool = false, refusedShortcuts: Set<ShortcutAction> = [], displayWidthMM: Double = 302,
                displayAspectRatio: Double = 1512.0 / 982.0) {
        self.lidAngle = lidAngle
        self.restAngle = restAngle
        self.sensorAvailable = sensorAvailable
        self.screenCaptureAllowed = screenCaptureAllowed
        self.permissionRequested = permissionRequested
        self.paused = paused
        self.canLockNow = canLockNow
        self.lockScreenSurfaceAvailable = lockScreenSurfaceAvailable
        self.cursorHidingAvailable = cursorHidingAvailable
        self.reduceMotion = reduceMotion
        self.refusedShortcuts = refusedShortcuts
        self.displayWidthMM = displayWidthMM
        self.displayAspectRatio = displayAspectRatio
    }
}

/// The live snapshot as observable properties: a view redraws only when what it reads changes, so the protractor
/// follows the lid while the General pane sleeps.
@MainActor @Observable
public final class LiveState {
    public private(set) var lidAngle: Double?
    public private(set) var restAngle: Double?
    public private(set) var sensorAvailable: Bool
    public private(set) var screenCaptureAllowed: Bool
    public private(set) var permissionRequested: Bool
    public private(set) var paused: Bool
    public private(set) var canLockNow: Bool
    public private(set) var lockScreenSurfaceAvailable: Bool
    public private(set) var cursorHidingAvailable: Bool
    public private(set) var reduceMotion: Bool
    public private(set) var refusedShortcuts: Set<ShortcutAction>
    public private(set) var displayWidthMM: Double
    public private(set) var displayAspectRatio: Double
    /// What the menu bar symbol draws: 5° steps, at most 30 changes per second (spec 8.2).
    public private(set) var symbolPose: MenuBarSymbol.Pose
    @ObservationIgnored private var throttle: SymbolThrottle

    public init(_ snapshot: LiveSnapshot = LiveSnapshot()) {
        lidAngle = snapshot.lidAngle
        restAngle = snapshot.restAngle
        sensorAvailable = snapshot.sensorAvailable
        screenCaptureAllowed = snapshot.screenCaptureAllowed
        permissionRequested = snapshot.permissionRequested
        paused = snapshot.paused
        canLockNow = snapshot.canLockNow
        lockScreenSurfaceAvailable = snapshot.lockScreenSurfaceAvailable
        cursorHidingAvailable = snapshot.cursorHidingAvailable
        reduceMotion = snapshot.reduceMotion
        refusedShortcuts = snapshot.refusedShortcuts
        displayWidthMM = snapshot.displayWidthMM
        displayAspectRatio = snapshot.displayAspectRatio
        let pose = MenuBarSymbol.pose(angle: snapshot.lidAngle, sensorAvailable: snapshot.sensorAvailable)
        symbolPose = pose
        throttle = SymbolThrottle(shown: pose)
    }

    public var snapshot: LiveSnapshot {
        LiveSnapshot(lidAngle: lidAngle, restAngle: restAngle, sensorAvailable: sensorAvailable,
                     screenCaptureAllowed: screenCaptureAllowed, permissionRequested: permissionRequested, paused: paused,
                     canLockNow: canLockNow, lockScreenSurfaceAvailable: lockScreenSurfaceAvailable,
                     cursorHidingAvailable: cursorHidingAvailable, reduceMotion: reduceMotion,
                     refusedShortcuts: refusedShortcuts, displayWidthMM: displayWidthMM,
                     displayAspectRatio: displayAspectRatio)
    }

    /// Takes a snapshot, touching only the properties that changed. Returns the time at which the menu bar symbol
    /// wants `flushSymbol(at:)`, when a redraw had to wait for the 30-per-second limit.
    @discardableResult
    public func apply(_ new: LiveSnapshot, at now: Double) -> Double? {
        if lidAngle != new.lidAngle { lidAngle = new.lidAngle }
        if restAngle != new.restAngle { restAngle = new.restAngle }
        if sensorAvailable != new.sensorAvailable { sensorAvailable = new.sensorAvailable }
        if screenCaptureAllowed != new.screenCaptureAllowed { screenCaptureAllowed = new.screenCaptureAllowed }
        if permissionRequested != new.permissionRequested { permissionRequested = new.permissionRequested }
        if paused != new.paused { paused = new.paused }
        if canLockNow != new.canLockNow { canLockNow = new.canLockNow }
        if lockScreenSurfaceAvailable != new.lockScreenSurfaceAvailable { lockScreenSurfaceAvailable = new.lockScreenSurfaceAvailable }
        if cursorHidingAvailable != new.cursorHidingAvailable { cursorHidingAvailable = new.cursorHidingAvailable }
        if reduceMotion != new.reduceMotion { reduceMotion = new.reduceMotion }
        if refusedShortcuts != new.refusedShortcuts { refusedShortcuts = new.refusedShortcuts }
        if displayWidthMM != new.displayWidthMM { displayWidthMM = new.displayWidthMM }
        if displayAspectRatio != new.displayAspectRatio { displayAspectRatio = new.displayAspectRatio }
        let flushAt = throttle.offer(MenuBarSymbol.pose(angle: new.lidAngle, sensorAvailable: new.sensorAvailable), at: now)
        publishPose()
        return flushAt
    }

    /// The deferred symbol redraw. Returns a later time if it still has to wait.
    @discardableResult
    public func flushSymbol(at now: Double) -> Double? {
        let next = throttle.flush(at: now)
        publishPose()
        return next
    }

    private func publishPose() {
        if symbolPose != throttle.shown { symbolPose = throttle.shown }
    }
}
