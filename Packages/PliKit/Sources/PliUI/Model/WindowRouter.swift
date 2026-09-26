import Foundation
import Observation

/// Pli's two windows. The menu bar panel is not one: it comes and goes with the menu bar symbol.
public enum PliWindow: String, CaseIterable, Sendable {
    case settings
    case onboarding

    public var id: String { "pli-\(rawValue)" }
}

/// A request to open a window, numbered so the same window asked for twice still opens (a closed Settings window
/// reopened from the Dock, from a `.pli` file, from a relaunch).
public struct WindowRequest: Equatable, Sendable {
    public let window: PliWindow
    public let serial: Int
}

/// Which windows are open, and the menu bar app's activation rule (spec 8.1): Pli is a regular app, with a Dock icon
/// and ⌘Tab, exactly while one of its windows is open.
@MainActor @Observable
public final class WindowRouter {
    public private(set) var request: WindowRequest?
    public private(set) var openWindows: Set<PliWindow> = []

    public init() {}

    public func open(_ window: PliWindow) {
        request = WindowRequest(window: window, serial: (request?.serial ?? 0) + 1)
    }

    public func isOpen(_ window: PliWindow) -> Bool {
        openWindows.contains(window)
    }

    /// A window appeared. Returns the new activation state when it changes (true: regular app).
    public func didOpen(_ window: PliWindow) -> Bool? {
        update { $0.insert(window) }
    }

    /// A window closed. Returns the new activation state when it changes (false: back to the menu bar).
    public func didClose(_ window: PliWindow) -> Bool? {
        update { $0.remove(window) }
    }

    public static func isRegularApp(with windows: Set<PliWindow>) -> Bool {
        !windows.isEmpty
    }

    private func update(_ change: (inout Set<PliWindow>) -> Void) -> Bool? {
        let before = Self.isRegularApp(with: openWindows)
        var windows = openWindows
        change(&windows)
        if windows != openWindows { openWindows = windows }
        let after = Self.isRegularApp(with: openWindows)
        return before == after ? nil : after
    }
}
