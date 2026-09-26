import AppKit
import Carbon.HIToolbox
import PliCore

/// One shortcut registered with macOS.
public struct HotKeyRegistration: Hashable, Sendable {
    public let id: UInt32

    public init(id: UInt32) {
        self.id = id
    }
}

/// Registers shortcuts with macOS; tests use a fake and never take a shortcut on the Mac.
@MainActor
public protocol HotKeyRegistrar: AnyObject {
    /// Nil when macOS refused it (another app holds it).
    func register(_ combo: KeyCombo, onPress: @escaping @MainActor () -> Void) -> HotKeyRegistration?
    func unregister(_ registration: HotKeyRegistration)
}

/// One shortcut at a time: setting another lets the first go, nil lets it go. RegisterEventHotKey needs no
/// Accessibility or Input Monitoring permission: it only hears its own shortcut. Adapted from Brainmerge.
@MainActor
public final class HotKey {
    private let registrar: any HotKeyRegistrar
    private let onPress: @MainActor () -> Void
    private var registration: HotKeyRegistration?
    /// The shortcut registered now.
    public private(set) var registered: KeyCombo?

    public init(registrar: any HotKeyRegistrar, onPress: @escaping @MainActor () -> Void) {
        self.registrar = registrar
        self.onPress = onPress
    }

    /// Registers `combo` in place of the current one, or none. False when macOS refused it: the previous one is
    /// registered again, so the shortcut keeps working.
    @discardableResult
    public func set(_ combo: KeyCombo?) -> Bool {
        guard combo != registered else { return true }
        let previous = registered
        release()
        guard let combo else { return true }
        if take(combo) { return true }
        if let previous { _ = take(previous) }
        return false
    }

    private func take(_ combo: KeyCombo) -> Bool {
        guard let registration = registrar.register(combo, onPress: onPress) else { return false }
        self.registration = registration
        registered = combo
        return true
    }

    private func release() {
        if let registration { registrar.unregister(registration) }
        registration = nil
        registered = nil
    }
}

/// Pli's two global shortcuts (spec 5.4, 8.4): Demo and Animated Lock.
@MainActor
public final class HotKeys {
    public enum Action: Hashable, Sendable {
        case demo
        case lock
    }

    private let demo: HotKey
    private let lock: HotKey

    public init(registrar: any HotKeyRegistrar, onPress: @escaping @MainActor (Action) -> Void) {
        demo = HotKey(registrar: registrar) { onPress(.demo) }
        lock = HotKey(registrar: registrar) { onPress(.lock) }
    }

    public var demoCombo: KeyCombo? { demo.registered }
    public var lockCombo: KeyCombo? { lock.registered }

    /// Registers the enabled, valid shortcuts of `triggers`. Returns the actions macOS refused.
    @discardableResult
    public func apply(_ triggers: TriggerSettings) -> Set<Action> {
        var refused: Set<Action> = []
        if !demo.set(Self.wanted(triggers.demoEnabled, triggers.demoShortcut)) { refused.insert(.demo) }
        if !lock.set(Self.wanted(triggers.animatedLockEnabled, triggers.animatedLockShortcut)) { refused.insert(.lock) }
        return refused
    }

    public func unregisterAll() {
        demo.set(nil)
        lock.set(nil)
    }

    private static func wanted(_ enabled: Bool, _ combo: KeyCombo?) -> KeyCombo? {
        guard enabled, let combo, combo.isValid, combo.keyCode < 128 else { return nil }
        return combo
    }
}

/// The real registrar: Carbon's RegisterEventHotKey, and one handler on the app's event target for its presses.
@MainActor
public final class CarbonHotKeyRegistrar: HotKeyRegistrar {
    /// "PLI!": marks Pli's shortcuts among the app's hot key events.
    static let signature: OSType = 0x504C_4921
    private var refs: [UInt32: EventHotKeyRef] = [:]
    private var presses: [UInt32: @MainActor () -> Void] = [:]
    private var nextID: UInt32 = 1
    private var handler: EventHandlerRef?

    public init() {}

    public func register(_ combo: KeyCombo, onPress: @escaping @MainActor () -> Void) -> HotKeyRegistration? {
        guard installHandler() else { return nil }
        let id = nextID
        nextID += 1
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(combo.keyCode, combo.modifiers, EventHotKeyID(signature: Self.signature, id: id),
                                         GetApplicationEventTarget(), 0, &ref)
        guard status == noErr, let ref else { return nil }
        refs[id] = ref
        presses[id] = onPress
        return HotKeyRegistration(id: id)
    }

    public func unregister(_ registration: HotKeyRegistration) {
        if let ref = refs.removeValue(forKey: registration.id) { UnregisterEventHotKey(ref) }
        presses[registration.id] = nil
    }

    fileprivate func pressed(_ id: EventHotKeyID) {
        guard id.signature == Self.signature else { return }
        presses[id.id]?()
    }

    /// Once: Carbon calls it on the main thread for each press of a shortcut this app registered.
    private func installHandler() -> Bool {
        guard handler == nil else { return true }
        var type = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let context = Unmanaged.passUnretained(self).toOpaque()
        let status = InstallEventHandler(GetApplicationEventTarget(), { _, event, context in
            guard let event, let context else { return OSStatus(eventNotHandledErr) }
            var id = EventHotKeyID()
            let read = GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil,
                                         MemoryLayout<EventHotKeyID>.size, nil, &id)
            guard read == noErr else { return read }
            let registrar = Unmanaged<CarbonHotKeyRegistrar>.fromOpaque(context).takeUnretainedValue()
            MainActor.assumeIsolated { registrar.pressed(id) }
            return noErr
        }, 1, &type, context, &handler)
        return status == noErr
    }
}

extension KeyCombo {
    /// ⌃⌥⇧⌘ then the key, in the order Mac menus write them.
    public var display: String {
        let marks: [(UInt32, String)] = [(KeyCombo.control, "⌃"), (KeyCombo.option, "⌥"), (KeyCombo.shift, "⇧"), (KeyCombo.command, "⌘")]
        return marks.filter { modifiers & $0.0 != 0 }.map(\.1).joined() + Self.keyName(for: keyCode)
    }

    /// For an NSMenuItem: the key's character, or "" for keys without one (the menu then shows no shortcut).
    public var menuKeyEquivalent: String { Self.characters[Int(keyCode)]?.lowercased() ?? "" }

    public var menuModifiers: NSEvent.ModifierFlags {
        var flags: NSEvent.ModifierFlags = []
        if modifiers & KeyCombo.control != 0 { flags.insert(.control) }
        if modifiers & KeyCombo.option != 0 { flags.insert(.option) }
        if modifiers & KeyCombo.shift != 0 { flags.insert(.shift) }
        if modifiers & KeyCombo.command != 0 { flags.insert(.command) }
        return flags
    }

    public enum Recording: Equatable, Sendable {
        case combo(KeyCombo)
        case cancel
        case needsModifier
        case appCommand
    }

    /// What a key pressed while recording a shortcut gives (the recorder arrives with Settings): Esc alone cancels,
    /// a key without ⌘, ⌃ or ⌥ is refused, and so is ⌘ with a character, every app's own command (⌘Q, ⌘C).
    public static func record(keyCode: UInt16, modifiers: NSEvent.ModifierFlags) -> Recording {
        let held = modifiers.intersection([.command, .control, .option, .shift])
        if keyCode == UInt16(kVK_Escape), held.isEmpty { return .cancel }
        if held == .command, namedKeys[Int(keyCode)] == nil { return .appCommand }
        var bits: UInt32 = 0
        if held.contains(.command) { bits |= KeyCombo.command }
        if held.contains(.shift) { bits |= KeyCombo.shift }
        if held.contains(.option) { bits |= KeyCombo.option }
        if held.contains(.control) { bits |= KeyCombo.control }
        let combo = KeyCombo(keyCode: UInt32(keyCode), modifiers: bits)
        return combo.isValid && keyCode < 128 ? .combo(combo) : .needsModifier
    }

    public static func keyName(for keyCode: UInt32) -> String {
        namedKeys[Int(keyCode)] ?? characters[Int(keyCode)] ?? "Key \(keyCode)"
    }

    /// Keys that type nothing.
    static let namedKeys: [Int: String] = [
        kVK_Space: "Space", kVK_Return: "Return", kVK_ANSI_KeypadEnter: "Enter", kVK_Tab: "Tab", kVK_Delete: "Delete",
        kVK_ForwardDelete: "⌦", kVK_Escape: "Esc", kVK_LeftArrow: "←", kVK_RightArrow: "→", kVK_DownArrow: "↓", kVK_UpArrow: "↑",
        kVK_Home: "Home", kVK_End: "End", kVK_PageUp: "Page Up", kVK_PageDown: "Page Down",
        kVK_F1: "F1", kVK_F2: "F2", kVK_F3: "F3", kVK_F4: "F4", kVK_F5: "F5", kVK_F6: "F6",
        kVK_F7: "F7", kVK_F8: "F8", kVK_F9: "F9", kVK_F10: "F10", kVK_F11: "F11", kVK_F12: "F12",
    ]

    /// Letters and digits by key position, as a US keyboard prints them. The Settings recorder will show the
    /// character the person's own layout typed.
    static let characters: [Int: String] = [
        kVK_ANSI_A: "A", kVK_ANSI_B: "B", kVK_ANSI_C: "C", kVK_ANSI_D: "D", kVK_ANSI_E: "E", kVK_ANSI_F: "F", kVK_ANSI_G: "G",
        kVK_ANSI_H: "H", kVK_ANSI_I: "I", kVK_ANSI_J: "J", kVK_ANSI_K: "K", kVK_ANSI_L: "L", kVK_ANSI_M: "M", kVK_ANSI_N: "N",
        kVK_ANSI_O: "O", kVK_ANSI_P: "P", kVK_ANSI_Q: "Q", kVK_ANSI_R: "R", kVK_ANSI_S: "S", kVK_ANSI_T: "T", kVK_ANSI_U: "U",
        kVK_ANSI_V: "V", kVK_ANSI_W: "W", kVK_ANSI_X: "X", kVK_ANSI_Y: "Y", kVK_ANSI_Z: "Z",
        kVK_ANSI_0: "0", kVK_ANSI_1: "1", kVK_ANSI_2: "2", kVK_ANSI_3: "3", kVK_ANSI_4: "4",
        kVK_ANSI_5: "5", kVK_ANSI_6: "6", kVK_ANSI_7: "7", kVK_ANSI_8: "8", kVK_ANSI_9: "9",
    ]
}
