import Foundation

/// Where the About pane and the update check lead. They open in the browser: the app itself never connects
/// (spec 10.9).
public enum Links {
    public static let website = URL(string: "https://getpli.vercel.app")!
    public static let repository = URL(string: "https://github.com/ruben4reall/pli")!
    public static let newIssue = URL(string: "https://github.com/ruben4reall/pli/issues/new")!
    /// Until Sparkle is wired in (Plan 6), Check for Updates opens the latest release.
    public static let latestRelease = URL(string: "https://github.com/ruben4reall/pli/releases/latest")!

    /// Appendix C of the spec.
    public struct Credit: Identifiable, Sendable, Equatable {
        public let id: String
        public let text: String
        public let url: URL
    }

    public static let credits: [Credit] = [
        Credit(id: "optics", text: Strings.creditOptics, url: URL(string: "https://github.com/marcoazeem/duo-open")!),
        Credit(id: "skylight", text: Strings.creditSkyLight, url: URL(string: "https://github.com/Lakr233/SkyLightWindow")!),
        Credit(id: "sensor", text: Strings.creditSensor, url: URL(string: "https://github.com/samhenrigold/LidAngleSensor")!),
    ]
}
