import Foundation
import Testing
@testable import PliCore

@Suite struct SettingsTests {
    @Test func defaultsMatchSpec() {
        let t = TriggerSettings.default
        #expect(t.lidClose && t.unfoldOnLockScreen && t.onUnlock == .afterLidClose)
        #expect(t.demoEnabled && t.demoShortcut == KeyCombo.defaultDemo)
        #expect(t.animatedLockEnabled && t.animatedLockShortcut == KeyCombo.defaultLock)
        let g = GeneralSettings()
        #expect(g.enabled && g.showInMenuBar && g.rendering == .automatic)
        #expect(g.followReduceMotion && g.hideCursor && g.lighterInLowPower && !g.hasCompletedOnboarding)
        let s = PliSettings.default
        #expect(s.schemaVersion == 1 && s.activePresetID == "duo")
        #expect(s.glass == .duo && s.motion == .duo)
    }

    @Test func defaultShortcutsAreControlOptionCommand() {
        let mods = KeyCombo.control | KeyCombo.option | KeyCombo.command
        #expect(KeyCombo.defaultDemo == KeyCombo(keyCode: 0x23, modifiers: mods))   // P
        #expect(KeyCombo.defaultLock == KeyCombo(keyCode: 0x25, modifiers: mods))   // L
        #expect(KeyCombo.defaultDemo.isValid)
        #expect(!KeyCombo(keyCode: 0x23, modifiers: KeyCombo.shift).isValid)
    }

    @Test func aClearedShortcutSurvivesARoundTrip() throws {
        var s = PliSettings.default
        s.triggers.demoShortcut = nil
        let data = try JSONEncoder().encode(s)
        let back = try JSONDecoder().decode(PliSettings.self, from: data)
        #expect(back.triggers.demoShortcut == nil)
        #expect(back.triggers.animatedLockShortcut == KeyCombo.defaultLock)
        #expect(back == s)
    }

    @Test func partialAndNewerFilesStillLoad() throws {
        let json = #"{"schemaVersion": 9, "general": {"enabled": false, "rendering": "sparkly"}, "glass": {"frost": 0.2}, "future": [1, 2]}"#
        let s = try JSONDecoder().decode(PliSettings.self, from: Data(json.utf8))
        #expect(s.schemaVersion == 9)
        #expect(!s.general.enabled)
        #expect(s.general.rendering == .automatic)
        #expect(s.glass.frost == 0.2)
        #expect(s.motion == .duo)
        #expect(s.triggers == .default)
    }

    private func freshDefaults() -> UserDefaults {
        let name = "pli.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    @Test func storeRoundTrips() {
        let store = SettingsStore(defaults: freshDefaults())
        #expect(store.load().settings == .default)
        #expect(!store.load().wasUnreadable)
        var s = PliSettings.default
        s.glass.frost = 0.2
        s.activePresetID = "night"
        store.save(s)
        #expect(store.load().settings == s)
    }

    @Test func unreadableDataFallsBackToDefaults() {
        let defaults = freshDefaults()
        defaults.set(Data("not json".utf8), forKey: "settings")
        let loaded = SettingsStore(defaults: defaults).load()
        #expect(loaded.settings == .default)
        #expect(loaded.wasUnreadable)
    }

    @Test func saveReturnsTrue() {
        let store = SettingsStore(defaults: freshDefaults())
        var s = PliSettings.default
        s.glass.frost = 0.2
        let didSave = store.save(s)
        #expect(didSave)
        #expect(store.load().settings == s)
    }

    @Test func nanFrostStillSaves() {
        let store = SettingsStore(defaults: freshDefaults())
        var s = PliSettings.default
        s.glass.frost = Double.nan
        let didSave = store.save(s)
        #expect(didSave)
        let loaded = store.load().settings
        #expect(loaded.glass.frost == 0)  // NaN is clamped to lower bound
    }

    private func storedJSON(_ defaults: UserDefaults) throws -> [String: Any] {
        let data = try #require(defaults.data(forKey: "settings"))
        return try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    @Test func aStoredValueThatIsNotDataIsReportedUnreadable() {
        let defaults = freshDefaults()
        for value in [["glass": ["frost": 0.2]] as Any, 42 as Any, "not json" as Any] {   // hand-written with `defaults write`
            defaults.set(value, forKey: "settings")
            let loaded = SettingsStore(defaults: defaults).load()
            #expect(loaded.settings == .default, "\(value)")
            #expect(loaded.wasUnreadable, "\(value)")
        }
    }

    @Test func aJSONStringWrittenByHandIsRead() {
        let defaults = freshDefaults()
        defaults.set(#"{"glass": {"frost": 0.2}, "general": {"hideCursor": false}}"#, forKey: "settings")
        let loaded = SettingsStore(defaults: defaults).load()
        #expect(!loaded.wasUnreadable)
        #expect(loaded.settings.glass.frost == 0.2 && !loaded.settings.general.hideCursor)
    }

    @Test func saveWritesTheCurrentSchemaVersion() throws {
        let defaults = freshDefaults()
        let store = SettingsStore(defaults: defaults)
        defaults.set(Data(#"{"schemaVersion": 9, "glass": {"frost": 0.2}, "future": true}"#.utf8), forKey: "settings")
        let loaded = store.load().settings
        #expect(loaded.schemaVersion == 9)
        store.save(loaded)                          // the newer schema's unknown fields are gone: do not claim it
        #expect(try storedJSON(defaults)["schemaVersion"] as? Int == PliSettings.currentSchemaVersion)
        #expect(store.load().settings.glass.frost == 0.2)
    }

    @Test func anOlderSchemaMigratesToTheCurrentOne() throws {
        let defaults = freshDefaults()
        let store = SettingsStore(defaults: defaults)
        defaults.set(Data(#"{"schemaVersion": 0, "glass": {"frost": 0.2}, "triggers": {"onUnlock": "always"}, "activePresetID": "night"}"#.utf8), forKey: "settings")
        let loaded = store.load()
        #expect(!loaded.wasUnreadable)
        #expect(loaded.settings.glass.frost == 0.2 && loaded.settings.triggers.onUnlock == .always)
        #expect(loaded.settings.activePresetID == "night")
        #expect(loaded.settings.motion == .duo && loaded.settings.general == GeneralSettings())   // missing groups default
        store.save(loaded.settings)
        #expect(try storedJSON(defaults)["schemaVersion"] as? Int == PliSettings.currentSchemaVersion)
        var migrated = loaded.settings
        migrated.schemaVersion = PliSettings.currentSchemaVersion
        #expect(store.load().settings == migrated)
    }
}
