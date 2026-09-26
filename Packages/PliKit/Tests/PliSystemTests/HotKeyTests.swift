import AppKit
import PliCore
import Testing
@testable import PliSystem

/// Stands in for RegisterEventHotKey: tests never take a shortcut on the Mac.
@MainActor final class FakeRegistrar: HotKeyRegistrar {
    private(set) var live: [UInt32: (combo: KeyCombo, press: @MainActor () -> Void)] = [:]
    private(set) var log: [String] = []
    /// Shortcuts another app holds.
    var taken: Set<String> = []
    private var next: UInt32 = 1

    var registered: [KeyCombo] { live.keys.sorted().compactMap { live[$0]?.combo } }

    func register(_ combo: KeyCombo, onPress: @escaping @MainActor () -> Void) -> HotKeyRegistration? {
        log.append("register \(combo.display)")
        guard !taken.contains(combo.display) else { return nil }
        defer { next += 1 }
        live[next] = (combo, onPress)
        return HotKeyRegistration(id: next)
    }

    func unregister(_ registration: HotKeyRegistration) {
        guard let entry = live.removeValue(forKey: registration.id) else {
            Issue.record("unregistered twice: \(registration.id)")
            return
        }
        log.append("unregister \(entry.combo.display)")
    }

    /// The person presses a shortcut: only a registered one does anything.
    func press(_ display: String) {
        for entry in live.values where entry.combo.display == display { entry.press() }
    }
}

@MainActor @Suite struct HotKeyTests {
    // Carbon's modifier bits: command 256, shift 512, option 2048, control 4096.
    let commandOptionK = KeyCombo(keyCode: 40, modifiers: 256 + 2048)
    let controlSpace = KeyCombo(keyCode: 49, modifiers: 4096)

    final class Presses { var actions: [HotKeys.Action] = []; var count = 0 }

    @Test func combosShowAsMacMenusDo() {
        #expect(KeyCombo.defaultDemo.display == "⌃⌥⌘P")
        #expect(KeyCombo.defaultLock.display == "⌃⌥⌘L")
        #expect(commandOptionK.display == "⌥⌘K")
        #expect(controlSpace.display == "⌃Space")
        #expect(KeyCombo(keyCode: 0, modifiers: 256 + 512 + 2048 + 4096).display == "⌃⌥⇧⌘A")
        #expect(KeyCombo(keyCode: 200, modifiers: 256).display == "⌘Key 200")
    }

    @Test func menuItemsGetTheKeyAndItsModifiers() {
        #expect(KeyCombo.defaultDemo.menuKeyEquivalent == "p")
        #expect(KeyCombo.defaultDemo.menuModifiers == [.control, .option, .command])
        #expect(controlSpace.menuKeyEquivalent == "")
    }

    // MARK: One shortcut

    @Test func aShortcutIsRegisteredOnceAndItsPressIsHeard() {
        let fake = FakeRegistrar(), presses = Presses()
        let hotKey = HotKey(registrar: fake) { presses.count += 1 }
        #expect(hotKey.set(commandOptionK))
        #expect(hotKey.set(commandOptionK))
        #expect(fake.log == ["register ⌥⌘K"])
        fake.press("⌥⌘K")
        #expect(presses.count == 1)
        #expect(hotKey.registered == commandOptionK)
    }

    @Test func changingTheShortcutUnregistersTheOldOne() {
        let fake = FakeRegistrar()
        let hotKey = HotKey(registrar: fake) {}
        hotKey.set(commandOptionK)
        hotKey.set(controlSpace)
        #expect(fake.log == ["register ⌥⌘K", "unregister ⌥⌘K", "register ⌃Space"])
        #expect(fake.registered == [controlSpace])
    }

    @Test func turningItOffUnregisters() {
        let fake = FakeRegistrar(), presses = Presses()
        let hotKey = HotKey(registrar: fake) { presses.count += 1 }
        hotKey.set(commandOptionK)
        #expect(hotKey.set(nil))
        #expect(fake.registered.isEmpty && hotKey.registered == nil)
        fake.press("⌥⌘K")
        #expect(presses.count == 0)
        hotKey.set(nil)
        #expect(fake.log == ["register ⌥⌘K", "unregister ⌥⌘K"])
    }

    /// Another app holds the new one: the old shortcut keeps working.
    @Test func aRefusedShortcutKeepsTheOldOne() {
        let fake = FakeRegistrar()
        fake.taken = ["⌃Space"]
        let hotKey = HotKey(registrar: fake) {}
        hotKey.set(commandOptionK)
        #expect(!hotKey.set(controlSpace))
        #expect(fake.registered == [commandOptionK])
        #expect(hotKey.registered == commandOptionK)
    }

    // MARK: Recording

    @Test func aRecordedKeyNeedsCommandControlOrOption() {
        func record(_ code: UInt16, _ modifiers: NSEvent.ModifierFlags) -> KeyCombo.Recording {
            KeyCombo.record(keyCode: code, modifiers: modifiers)
        }
        #expect(record(40, [.command, .option]) == .combo(commandOptionK))
        #expect(record(35, [.control, .option, .command]) == .combo(.defaultDemo))
        #expect(record(40, []) == .needsModifier)
        #expect(record(40, [.shift]) == .needsModifier)
        #expect(record(53, []) == .cancel)
        // ⌘ and a character is every app's own command (⌘Q, ⌘C): taking it would break them everywhere.
        #expect(record(12, [.command]) == .appCommand)
        #expect(record(18, [.command]) == .appCommand)
        #expect(record(49, [.command]) == .combo(KeyCombo(keyCode: 49, modifiers: 256)))
        #expect(record(12, [.command, .control]) == .combo(KeyCombo(keyCode: 12, modifiers: 256 + 4096)))
        // The function keys carry their own flags, which are not modifiers.
        #expect(record(122, [.function, .control]) == .combo(KeyCombo(keyCode: 122, modifiers: 4096)))
        #expect(record(125, [.function, .numericPad, .command]) == .combo(KeyCombo(keyCode: 125, modifiers: 256)))
        #expect(record(200, [.control]) == .needsModifier)
    }

    // MARK: Pli's two shortcuts

    @Test func theDefaultsRegisterDemoAndLock() {
        let fake = FakeRegistrar(), presses = Presses()
        let hotKeys = HotKeys(registrar: fake) { presses.actions.append($0) }
        #expect(hotKeys.apply(.default).isEmpty)
        #expect(fake.registered == [.defaultDemo, .defaultLock])
        fake.press("⌃⌥⌘L")
        fake.press("⌃⌥⌘P")
        #expect(presses.actions == [.lock, .demo])
    }

    @Test func disabledClearedOrInvalidShortcutsAreNotRegistered() {
        let fake = FakeRegistrar()
        let hotKeys = HotKeys(registrar: fake) { _ in }
        var triggers = TriggerSettings.default
        triggers.demoEnabled = false
        triggers.animatedLockShortcut = KeyCombo(keyCode: 37, modifiers: KeyCombo.shift)
        hotKeys.apply(triggers)
        #expect(fake.registered.isEmpty)
        triggers.demoEnabled = true
        triggers.demoShortcut = nil
        hotKeys.apply(triggers)
        #expect(fake.registered.isEmpty)
    }

    @Test func aShortcutAnotherAppHoldsIsReported() {
        let fake = FakeRegistrar()
        fake.taken = ["⌃⌥⌘L"]
        let hotKeys = HotKeys(registrar: fake) { _ in }
        #expect(hotKeys.apply(.default) == [.lock])
        #expect(fake.registered == [.defaultDemo])
        hotKeys.unregisterAll()
        #expect(fake.registered.isEmpty)
    }
}

@MainActor @Suite struct LoginItemTests {
    @Test func statusesMapToWhatSettingsShows() {
        #expect(LoginItem.status(from: .enabled) == .enabled)
        #expect(LoginItem.status(from: .notRegistered) == .disabled)
        #expect(LoginItem.status(from: .requiresApproval) == .needsApproval)
        #expect(LoginItem.status(from: .notFound) == .unavailable)
    }
}
