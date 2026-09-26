import AppKit

/// The app's delegate, handed to SwiftUI by the `@main` type in `App/`. The model is made on first use, when the scenes
/// read the interface for their first frame, and starts once AppKit has finished launching. The app target subclasses
/// it to bring its updater (`makeUpdater()`), because only the app target links Sparkle.
@MainActor
open class PliAppDelegate: NSObject, NSApplicationDelegate {
    public private(set) lazy var model = AppModel(updater: makeUpdater())

    /// The package has no updater; the app target returns Sparkle's.
    open func makeUpdater() -> any UpdateChecking {
        NoUpdates()
    }

    public override init() {
        super.init()
    }

    public func applicationDidFinishLaunching(_ notification: Notification) {
        model.start()
    }

    public func applicationWillTerminate(_ notification: Notification) {
        model.stop()
    }

    /// A `.pli` file double-clicked in Finder, also when it launches Pli (spec 10.8).
    public func application(_ application: NSApplication, open urls: [URL]) {
        model.openFiles(urls)
    }

    /// Pli opened again while running, from Finder or Spotlight: Settings, even with the menu bar symbol hidden
    /// (spec 8.1).
    public func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        model.reopen()
        return false
    }

    /// A menu bar app: closing Settings never quits it.
    public func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
