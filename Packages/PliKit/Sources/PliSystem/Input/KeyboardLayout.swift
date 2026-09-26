import Carbon.HIToolbox
import Foundation
import PliCore

/// The keyboard layout in use: which character a key types, for the shortcut recorder (Plan 2 stores shortcuts by
/// key position only).
public enum KeyboardLayout {
    /// The character the current layout prints on `keyCode`, uppercased; nil for keys that type nothing.
    public static func character(for keyCode: UInt32) -> String? {
        guard let source = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
              let property = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else { return nil }
        let data = Unmanaged<CFData>.fromOpaque(property).takeUnretainedValue() as Data
        return data.withUnsafeBytes { raw -> String? in
            guard let layout = raw.baseAddress?.assumingMemoryBound(to: UCKeyboardLayout.self) else { return nil }
            var deadKeys: UInt32 = 0
            var length = 0
            var characters = [UniChar](repeating: 0, count: 4)
            let status = UCKeyTranslate(layout, UInt16(keyCode), UInt16(kUCKeyActionDisplay), 0, UInt32(LMGetKbdType()),
                                        OptionBits(kUCKeyTranslateNoDeadKeysMask), &deadKeys, characters.count, &length,
                                        &characters)
            guard status == noErr, length > 0 else { return nil }
            let text = String(utf16CodeUnits: characters, count: length)
                .trimmingCharacters(in: .whitespacesAndNewlines.union(.controlCharacters))
            return text.isEmpty ? nil : text.uppercased()
        }
    }
}

extension KeyCombo {
    /// Like `display`, with the letter the person's own layout prints on the key: an AZERTY keyboard shows A where a
    /// US keyboard has Q. Named keys (Space, arrows, F1) read the same everywhere.
    public var layoutDisplay: String {
        let marks: [(UInt32, String)] = [(KeyCombo.control, "⌃"), (KeyCombo.option, "⌥"), (KeyCombo.shift, "⇧"), (KeyCombo.command, "⌘")]
        let key = Self.namedKeys[Int(keyCode)] ?? KeyboardLayout.character(for: keyCode) ?? Self.keyName(for: keyCode)
        return marks.filter { modifiers & $0.0 != 0 }.map(\.1).joined() + key
    }
}
