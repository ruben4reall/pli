import Foundation

/// Everything Pli remembers (spec 10.8).
public struct PliSettings: Codable, Hashable, Sendable {
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    public var glass: GlassParameters
    public var motion: MotionParameters
    public var triggers: TriggerSettings
    public var general: GeneralSettings
    /// Built-in preset id ("duo", "subtle", ...) or a user preset's UUID string.
    public var activePresetID: String

    public init(
        schemaVersion: Int = PliSettings.currentSchemaVersion,
        glass: GlassParameters = .duo,
        motion: MotionParameters = .duo,
        triggers: TriggerSettings = .default,
        general: GeneralSettings = GeneralSettings(),
        activePresetID: String = "duo"
    ) {
        self.schemaVersion = schemaVersion
        self.glass = glass
        self.motion = motion
        self.triggers = triggers
        self.general = general
        self.activePresetID = activePresetID
    }

    public static let `default` = PliSettings()

    enum CodingKeys: String, CodingKey { case schemaVersion, glass, motion, triggers, general, activePresetID }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = PliSettings.default
        self.init(
            schemaVersion: c.value(.schemaVersion, default: d.schemaVersion),
            glass: c.value(.glass, default: d.glass),
            motion: c.value(.motion, default: d.motion),
            triggers: c.value(.triggers, default: d.triggers),
            general: c.value(.general, default: d.general),
            activePresetID: c.value(.activePresetID, default: d.activePresetID)
        )
    }
}
