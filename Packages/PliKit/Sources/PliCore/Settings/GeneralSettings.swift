import Foundation

/// Full rendering needs the Screen Recording permission; Basic never captures (spec 7.3).
public enum RenderingMode: String, Codable, CaseIterable, Sendable {
    case automatic
    case alwaysBasic
}

/// The General pane (spec 8.4). Open at Login is owned by the system, so it is not stored here.
public struct GeneralSettings: Codable, Hashable, Sendable {
    public var enabled: Bool
    public var showInMenuBar: Bool
    public var rendering: RenderingMode
    public var followReduceMotion: Bool
    public var hideCursor: Bool
    public var lighterInLowPower: Bool
    public var hasCompletedOnboarding: Bool

    public init(
        enabled: Bool = true,
        showInMenuBar: Bool = true,
        rendering: RenderingMode = .automatic,
        followReduceMotion: Bool = true,
        hideCursor: Bool = true,
        lighterInLowPower: Bool = true,
        hasCompletedOnboarding: Bool = false
    ) {
        self.enabled = enabled
        self.showInMenuBar = showInMenuBar
        self.rendering = rendering
        self.followReduceMotion = followReduceMotion
        self.hideCursor = hideCursor
        self.lighterInLowPower = lighterInLowPower
        self.hasCompletedOnboarding = hasCompletedOnboarding
    }

    enum CodingKeys: String, CodingKey {
        case enabled, showInMenuBar, rendering, followReduceMotion, hideCursor, lighterInLowPower, hasCompletedOnboarding
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = GeneralSettings()
        self.init(
            enabled: c.value(.enabled, default: d.enabled),
            showInMenuBar: c.value(.showInMenuBar, default: d.showInMenuBar),
            rendering: c.value(.rendering, default: d.rendering),
            followReduceMotion: c.value(.followReduceMotion, default: d.followReduceMotion),
            hideCursor: c.value(.hideCursor, default: d.hideCursor),
            lighterInLowPower: c.value(.lighterInLowPower, default: d.lighterInLowPower),
            hasCompletedOnboarding: c.value(.hasCompletedOnboarding, default: d.hasCompletedOnboarding)
        )
    }
}
