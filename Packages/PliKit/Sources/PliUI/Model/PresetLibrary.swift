import Foundation
import Observation
import PliCore

/// Which preset the settings come from, and whether they changed since (spec 7.5: "Name (Modified)").
public struct PresetState: Equatable, Sendable {
    /// The active preset; Duo when the stored id names no preset any more.
    public var preset: Preset
    public var isModified: Bool

    public init(preset: Preset, isModified: Bool) {
        self.preset = preset
        self.isModified = isModified
    }

    public var name: String { Strings.presetName(preset) }
    public var title: String { isModified ? Strings.modifiedPreset(name) : name }
}

/// The seven built-in presets and the person's own, kept by `PresetStore` in Application Support (spec 10.8).
@MainActor @Observable
public final class PresetLibrary {
    public private(set) var userPresets: [Preset] = []
    @ObservationIgnored public let store: PresetStore

    public init(store: PresetStore) {
        self.store = store
        reload()
    }

    public var builtIns: [Preset] { BuiltInPresets.all }
    public var all: [Preset] { builtIns + userPresets }

    /// Reads the folder again (a corrupt file is set aside by the store, never deleted).
    public func reload() {
        userPresets = store.loadAll()
    }

    public func preset(id: String) -> Preset? {
        BuiltInPresets.preset(id: id) ?? userPresets.first { $0.id == id }
    }

    public func state(for settings: PliSettings) -> PresetState {
        let preset = preset(id: settings.activePresetID) ?? BuiltInPresets.duo
        return PresetState(preset: preset, isModified: !preset.matches(glass: settings.glass, motion: settings.motion))
    }

    @discardableResult
    public func saveAsPreset(named name: String, from settings: PliSettings) throws -> Preset {
        let preset = try store.add(name: name, glass: settings.glass, motion: settings.motion)
        reload()
        return preset
    }

    /// Writes the current look into one of the person's presets.
    @discardableResult
    public func saveChanges(to id: String, from settings: PliSettings) throws -> Preset {
        guard var preset = userPresets.first(where: { $0.id == id }) else { throw PresetStoreError.notFound }
        preset.glass = settings.glass
        preset.motion = settings.motion
        try store.save(preset)
        reload()
        return preset
    }

    @discardableResult
    public func rename(_ id: String, to name: String) throws -> Preset {
        let preset = try store.rename(id: id, to: name)
        reload()
        return preset
    }

    @discardableResult
    public func duplicate(_ preset: Preset) throws -> Preset {
        let copy = try store.add(name: Strings.copyName(Strings.presetName(preset)), glass: preset.glass, motion: preset.motion)
        reload()
        return copy
    }

    public func delete(_ id: String) throws {
        try store.delete(id: id)
        reload()
    }

    /// A preset read from a `.pli` file (it arrives with a fresh id), added to My Presets.
    @discardableResult
    public func add(imported preset: Preset) throws -> Preset {
        try store.save(preset)
        reload()
        return preset
    }
}
