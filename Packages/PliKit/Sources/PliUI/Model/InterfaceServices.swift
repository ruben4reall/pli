import Foundation
import PliCore

/// Open at Login, as SMAppService reports it (spec 8.1).
public enum LoginItemState: Sendable, Equatable {
    case enabled
    case disabled
    /// Registered, waiting for the person to allow it in System Settings, Login Items.
    case needsApproval
    /// Not possible for this copy of Pli (outside the Applications folder).
    case unavailable
}

/// What the interface asks of the running app. `AppModel` (PliApp) implements it with the runtime and the macOS
/// adapters; tests use a fake. PliUI never touches the system itself (spec 10.2).
@MainActor
public protocol InterfaceServices: AnyObject {
    /// New settings for the runtime and the shortcuts; saved when `persist` is true (false only during a drag).
    func apply(_ settings: PliSettings, persist: Bool)
    /// Reads the permission and the displays again (spec 10.5: on every activation; opening the panel counts).
    func refresh()
    func playDemo()
    func lockWithPli()
    /// The system prompt the first time, System Settings afterwards.
    func requestScreenRecording()
    func openScreenRecordingSettings()
    func relaunch()
    var openAtLogin: LoginItemState { get }
    func setOpenAtLogin(_ enabled: Bool) throws
    func openLoginItemsSettings()
    /// False until Sparkle is connected (Plan 6): the automatic check is then hidden.
    var supportsAutomaticUpdateChecks: Bool { get }
    var automaticallyChecksForUpdates: Bool { get set }
    func checkForUpdates()
    /// While a shortcut is recorded, the global shortcuts are let go.
    func suspendShortcuts(_ suspended: Bool)
    /// A picture of the effect's display for the previews: the capture when allowed, the wallpaper otherwise.
    func requestPreviewPicture(_ completion: @escaping @MainActor (PreviewPicture?) -> Void)
    /// Regular app (Dock, ⌘Tab) while a window is open; menu bar only otherwise (spec 8.1).
    func setRegularApp(_ regular: Bool)
    func open(_ url: URL)
    func quit()
}
