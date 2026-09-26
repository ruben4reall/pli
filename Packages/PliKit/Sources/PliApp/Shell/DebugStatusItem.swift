import AppKit

/// With PLI_LID_SIMULATOR=1 or PLI_DEBUG=1, the Debug menu gets a status item of its own beside Pli's symbol: the
/// panel is SwiftUI, and the Debug menu keeps its AppKit slider. Developer-only, so not localized.
@MainActor
final class DebugStatusItem {
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let debugMenu: DebugMenu

    init(menu: DebugMenu) {
        debugMenu = menu
        let image = NSImage(systemSymbolName: "ladybug", accessibilityDescription: "Pli Debug")
        image?.isTemplate = true
        item.button?.image = image
        item.menu = menu.menu
    }
}
