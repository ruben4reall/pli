import Foundation
import PliCore
import Testing
@testable import PliUI

@MainActor @Suite struct PresetLibraryTests {
    @Test func builtInsComeFirstAndMyPresetsFollow() throws {
        let library = PresetLibrary(store: Fixtures.store())
        #expect(library.all.map(\.id) == BuiltInPresets.all.map(\.id))
        let mine = try library.saveAsPreset(named: "Mine", from: .default)
        #expect(library.all.last == mine && library.userPresets == [mine])
    }

    @Test func aBuiltInPresetUntouchedShowsItsName() {
        let library = PresetLibrary(store: Fixtures.store())
        var settings = PliSettings.default
        settings.look = Look(preset: BuiltInPresets.deepFrost)
        let state = library.state(for: settings)
        #expect(state.preset.id == "deepFrost" && !state.isModified && state.title == "Deep Frost")
    }

    @Test func editingABuiltInPresetMakesItModified() {
        let library = PresetLibrary(store: Fixtures.store())
        var settings = PliSettings.default
        settings.glass.frost = 0.2
        #expect(library.state(for: settings).title == "Duo (Modified)")
        settings.motion.curve = .smooth
        settings.glass.frost = 0.09
        #expect(library.state(for: settings).isModified)
    }

    @Test func triggersAndGeneralNeverMakeAPresetModified() {
        let library = PresetLibrary(store: Fixtures.store())
        var settings = PliSettings.default
        settings.triggers.lidClose = false
        settings.general.rendering = .alwaysBasic
        #expect(!library.state(for: settings).isModified)
    }

    @Test func myPresetsSaveRenameDuplicateAndDelete() throws {
        let library = PresetLibrary(store: Fixtures.store())
        var settings = PliSettings.default
        settings.glass.frost = 0.2
        let mine = try library.saveAsPreset(named: "  Soft  ", from: settings)
        #expect(mine.name == "Soft" && mine.glass.frost == 0.2)
        settings.activePresetID = mine.id
        #expect(!library.state(for: settings).isModified)
        settings.glass.grain = 0.9
        #expect(library.state(for: settings).title == "Soft (Modified)")
        try library.saveChanges(to: mine.id, from: settings)
        #expect(!library.state(for: settings).isModified)
        let renamed = try library.rename(mine.id, to: "Silk")
        #expect(renamed.name == "Silk")
        let copy = try library.duplicate(renamed)
        #expect(copy.name == "Silk Copy" && copy.id != renamed.id)
        try library.delete(renamed.id)
        #expect(library.userPresets.map(\.name) == ["Silk Copy"])
    }

    @Test func aDuplicateOfABuiltInKeepsItsDisplayName() throws {
        let library = PresetLibrary(store: Fixtures.store())
        let copy = try library.duplicate(BuiltInPresets.cinema)
        #expect(copy.name == "Cinema Copy" && !copy.isBuiltIn)
    }

    @Test func builtInPresetsCannotBeChanged() {
        let library = PresetLibrary(store: Fixtures.store())
        #expect(throws: PresetStoreError.notFound) { try library.saveChanges(to: "duo", from: .default) }
        #expect(throws: PresetStoreError.self) { try library.delete("duo") }
    }

    /// Review Focus: a preset id that names nothing (deleted outside Pli, a hand-edited file) falls back to Duo.
    @Test func anUnknownPresetIDFallsBackToDuo() {
        let library = PresetLibrary(store: Fixtures.store())
        var settings = PliSettings.default
        settings.activePresetID = "5B3A6C1E-0000-4000-8000-000000000000"
        #expect(library.state(for: settings).preset.id == "duo")
        #expect(!library.state(for: settings).isModified)
        settings.glass.frost = 0.2
        #expect(library.state(for: settings).title == "Duo (Modified)")
    }

    @Test func aPresetFileRemovedOutsidePliDisappearsOnReload() throws {
        let store = Fixtures.store()
        let library = PresetLibrary(store: store)
        let mine = try library.saveAsPreset(named: "Mine", from: .default)
        try FileManager.default.removeItem(at: store.directory.appendingPathComponent(mine.id + ".json"))
        library.reload()
        #expect(library.userPresets.isEmpty)
    }
}
