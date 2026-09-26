import AppKit
import Observation
import PliCore

/// A key pressed while recording, as the app's shortcut rules read it.
public enum ShortcutKeyResult: Equatable, Sendable {
    case combo(KeyCombo)
    /// Esc alone: keep the current shortcut.
    case cancel
    /// No ⌘, ⌃ or ⌥.
    case needsModifier
    /// ⌘ and a character: every app's own command (⌘Q, ⌘C).
    case appCommand
}

/// Shows and reads shortcuts the way macOS menus do. The app answers with PliSystem's rules and the keyboard layout
/// in use (PliUI does not depend on PliSystem, spec 10.2).
@MainActor
public protocol ShortcutInterpreting: AnyObject {
    func display(_ combo: KeyCombo) -> String
    func interpret(keyCode: UInt16, modifiers: NSEvent.ModifierFlags) -> ShortcutKeyResult
}

/// Why the last key was not taken, under the recorder that heard it.
public struct ShortcutProblem: Equatable, Sendable {
    public var action: ShortcutAction
    public var text: String
}

/// The two shortcut recorders of the Triggers pane (spec 8.3). While one records, Pli's global shortcuts are let go
/// (`suspend(true)`), so typing the current shortcut records it instead of playing the demo.
@MainActor @Observable
public final class ShortcutRecorderModel {
    public private(set) var recording: ShortcutAction?
    public private(set) var problem: ShortcutProblem?
    @ObservationIgnored public let interpreter: any ShortcutInterpreting
    @ObservationIgnored private let editor: SettingsEditor
    @ObservationIgnored private let suspend: @MainActor (Bool) -> Void

    public init(editor: SettingsEditor, interpreter: any ShortcutInterpreting, suspend: @escaping @MainActor (Bool) -> Void) {
        self.editor = editor
        self.interpreter = interpreter
        self.suspend = suspend
    }

    public static func keyPath(for action: ShortcutAction) -> WritableKeyPath<PliSettings, KeyCombo?> {
        switch action {
        case .demo: \.triggers.demoShortcut
        case .animatedLock: \.triggers.animatedLockShortcut
        }
    }

    public func combo(for action: ShortcutAction) -> KeyCombo? {
        editor.settings[keyPath: Self.keyPath(for: action)]
    }

    public func display(for action: ShortcutAction) -> String? {
        combo(for: action).map(interpreter.display)
    }

    public func begin(_ action: ShortcutAction) {
        if recording == nil { suspend(true) }
        recording = action
        problem = nil
    }

    public func cancel() {
        guard recording != nil else { return }
        recording = nil
        suspend(false)
    }

    /// A key typed while recording. True when the recording is over (a new shortcut, or Esc).
    @discardableResult
    public func key(keyCode: UInt16, modifiers: NSEvent.ModifierFlags, undoManager: UndoManager?) -> Bool {
        guard let action = recording else { return false }
        switch interpreter.interpret(keyCode: keyCode, modifiers: modifiers) {
        case .cancel:
            problem = nil
            cancel()
            return true
        case .needsModifier:
            problem = ShortcutProblem(action: action, text: Strings.shortcutNeedsModifier)
            return false
        case .appCommand:
            problem = ShortcutProblem(action: action, text: Strings.shortcutAppCommand)
            return false
        case .combo(let combo):
            if combo == self.combo(for: action.other) {
                problem = ShortcutProblem(action: action, text: Strings.shortcutUsedBy(action.other.title))
                return false
            }
            problem = nil
            recording = nil
            editor.set(Self.keyPath(for: action), to: combo, action: action.title, undoManager: undoManager)
            suspend(false)
            return true
        }
    }

    public func clear(_ action: ShortcutAction, undoManager: UndoManager?) {
        cancel()
        problem = nil
        editor.set(Self.keyPath(for: action), to: nil, action: Strings.clearShortcut, undoManager: undoManager)
    }
}
