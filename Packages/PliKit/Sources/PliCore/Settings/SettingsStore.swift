import Foundation

public struct LoadedSettings: Sendable {
    public let settings: PliSettings
    /// True when a value was stored but could not be read as settings (not JSON data, nor a JSON string, of an
    /// object); the app logs it.
    public let wasUnreadable: Bool
}

/// Keeps `PliSettings` as one JSON value in UserDefaults.
/// @unchecked Sendable is safe: UserDefaults is thread-safe for the single get/set calls this type makes,
/// and the struct holds no other mutable state.
public struct SettingsStore: @unchecked Sendable {
    public let defaults: UserDefaults
    public let key: String

    public init(defaults: UserDefaults = .standard, key: String = "settings") {
        self.defaults = defaults
        self.key = key
    }

    public func load() -> LoadedSettings {
        guard let value = defaults.object(forKey: key) else {
            return LoadedSettings(settings: .default, wasUnreadable: false)
        }
        // Pli stores Data; a JSON string (`defaults write <domain> settings '{...}'`) is read too.
        let data = value as? Data ?? (value as? String).map { Data($0.utf8) }
        if let data, let settings = try? JSONDecoder().decode(PliSettings.self, from: data) {
            return LoadedSettings(settings: settings, wasUnreadable: false)
        }
        return LoadedSettings(settings: .default, wasUnreadable: true)
    }

    /// Stores the settings in the current schema, whatever version they were loaded from: a newer schema's
    /// unknown fields are not kept, so its number must not be written back.
    @discardableResult
    public func save(_ settings: PliSettings) -> Bool {
        var copy = settings
        copy.schemaVersion = PliSettings.currentSchemaVersion
        copy.glass = copy.glass.clamped()
        copy.motion = copy.motion.clamped()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(copy) else { return false }
        defaults.set(data, forKey: key)
        return true
    }
}
