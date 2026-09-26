import AppKit
import SwiftUI

/// Pli's scenes: the menu bar symbol and its panel, the Settings window, the welcome window (spec 8.1 to 8.5). The
/// app's `@main` shell only hands them the interface.
public struct PliScenes: Scene {
    let interface: InterfaceModel
    @Environment(\.openWindow) private var openWindow

    public init(interface: InterfaceModel) {
        self.interface = interface
    }

    public var body: some Scene {
        // Read here, not only in the binding: the scenes are drawn again when it changes, so Show in Menu Bar acts at once.
        let shown = interface.settings.general.showInMenuBar
        MenuBarExtra(isInserted: Binding(get: { shown }, set: { inserted in
            if !inserted { interface.menuBarSymbolRemoved() }
        })) {
            MenuBarPanel(interface: interface)
        } label: {
            MenuBarLabel(live: interface.live)
        }
        .menuBarExtraStyle(.window)

        Window(Strings.settingsWindowTitle, id: PliWindow.settings.id) {
            SettingsWindow(interface: interface)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultLaunchBehavior(.suppressed)
        .restorationBehavior(.disabled)
        .commands { PliCommands(interface: interface) }
        // `initial`: a request made before the scenes existed (a `.pli` file opened at launch) is honored.
        .onChange(of: interface.windows.request, initial: true) { _, request in
            guard let request else { return }
            openWindow(id: request.window.id)
            NSApplication.shared.activate()
        }

        Window(Strings.welcomeWindowTitle, id: PliWindow.onboarding.id) {
            OnboardingWindow(interface: interface)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultLaunchBehavior(interface.showsOnboardingAtLaunch ? .presented : .suppressed)
        .restorationBehavior(.disabled)
    }
}

/// The app menu while Pli is a regular app: ⌘, opens Settings, Check for Updates sits under About, no File > New.
struct PliCommands: Commands {
    let interface: InterfaceModel
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(replacing: .appSettings) {
            Button(Strings.settingsMenuItem) {
                openWindow(id: PliWindow.settings.id)
                NSApplication.shared.activate()
            }
            .keyboardShortcut(",", modifiers: .command)
        }
        CommandGroup(after: .appInfo) {
            Button(Strings.checkForUpdates) { interface.checkForUpdates() }
        }
        CommandGroup(replacing: .newItem) {}
    }
}
