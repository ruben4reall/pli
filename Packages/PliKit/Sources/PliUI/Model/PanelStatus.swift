import Foundation
import PliCore

/// The panel's status line and what it lets you do (spec 8.2). The rules of Plan 2's status menu, which this panel
/// replaces.
public struct PanelStatus: Equatable, Sendable {
    public var text: String
    public var canPlayDemo: Bool
    public var canLock: Bool
    /// Full rendering is wanted and the Screen Recording permission is missing.
    public var needsPermission: Bool
    /// The permission was asked for and is still missing: macOS may want a relaunch (spec R5).
    public var offerRelaunch: Bool

    public static func make(settings: PliSettings, live: LiveSnapshot) -> PanelStatus {
        let general = settings.general
        let triggers = settings.triggers
        let needsPermission = general.rendering == .automatic && !live.screenCaptureAllowed
        let text: String
        if !general.enabled || live.paused {
            text = Strings.statusPaused
        } else if !live.sensorAvailable {
            text = Strings.statusNoSensor
        } else if needsPermission {
            text = Strings.statusPermissionNeeded
        } else if let angle = live.lidAngle {
            text = Strings.statusActive(lidAt: Int(angle.rounded()))
        } else {
            text = Strings.statusActive
        }
        return PanelStatus(
            text: text,
            canPlayDemo: general.enabled && !live.paused && triggers.demoEnabled,
            canLock: general.enabled && live.canLockNow && triggers.animatedLockEnabled,
            needsPermission: needsPermission,
            offerRelaunch: needsPermission && live.permissionRequested
        )
    }
}
