import AppKit
import PliCore
@testable import PliUI

/// US-keyboard shortcut rules, like PliSystem's, without the system. Key codes: P 0x23, L 0x25, K 0x28, Q 0x0C,
/// Space 0x31, Esc 53.
@MainActor final class FakeInterpreter: ShortcutInterpreting {
    func display(_ combo: KeyCombo) -> String {
        let marks: [(UInt32, String)] = [(KeyCombo.control, "⌃"), (KeyCombo.option, "⌥"), (KeyCombo.shift, "⇧"), (KeyCombo.command, "⌘")]
        let names: [UInt32: String] = [0x23: "P", 0x25: "L", 0x28: "K", 0x31: "Space", 0x0C: "Q"]
        return marks.filter { combo.modifiers & $0.0 != 0 }.map(\.1).joined() + (names[combo.keyCode] ?? "Key \(combo.keyCode)")
    }

    func interpret(keyCode: UInt16, modifiers: NSEvent.ModifierFlags) -> ShortcutKeyResult {
        let held = modifiers.intersection([.command, .control, .option, .shift])
        if keyCode == 53, held.isEmpty { return .cancel }
        if held == .command, keyCode != 0x31 { return .appCommand }
        var bits: UInt32 = 0
        if held.contains(.command) { bits |= KeyCombo.command }
        if held.contains(.shift) { bits |= KeyCombo.shift }
        if held.contains(.option) { bits |= KeyCombo.option }
        if held.contains(.control) { bits |= KeyCombo.control }
        let combo = KeyCombo(keyCode: UInt32(keyCode), modifiers: bits)
        return combo.isValid ? .combo(combo) : .needsModifier
    }
}
