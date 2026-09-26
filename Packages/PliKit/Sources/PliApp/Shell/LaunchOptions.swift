import Foundation

/// Developer switches, read from the environment at launch:
/// `PLI_LID_SIMULATOR=1` replaces the lid sensor with the simulator and shows the Debug menu;
/// `PLI_DEBUG=1` shows the Debug menu with the real sensor.
public struct LaunchOptions: Sendable, Equatable {
    public var simulateLid: Bool
    public var debugMenu: Bool

    public init(simulateLid: Bool = false, debugMenu: Bool = false) {
        self.simulateLid = simulateLid
        self.debugMenu = debugMenu
    }

    public static func from(environment: [String: String]) -> LaunchOptions {
        let simulate = environment["PLI_LID_SIMULATOR"] == "1"
        return LaunchOptions(simulateLid: simulate, debugMenu: simulate || environment["PLI_DEBUG"] == "1")
    }

    public static var current: LaunchOptions { from(environment: ProcessInfo.processInfo.environment) }
}
