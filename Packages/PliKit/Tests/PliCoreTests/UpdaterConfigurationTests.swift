import Foundation
import Testing

/// The update settings in App/Info.plist, generated from project.yml by XcodeGen (spec 8.4, 10.9, 13.3).
@Suite struct UpdaterConfigurationTests {
    static func infoPlist() throws -> [String: Any] {
        let data = try Data(contentsOf: GuardTests.repositoryRoot.appendingPathComponent("App/Info.plist"))
        return try #require(PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])
    }

    @Test func theFeedIsTheWebsitesAppcastOverHTTPS() throws {
        #expect(try Self.infoPlist()["SUFeedURL"] as? String == "https://getpli.vercel.app/appcast.xml")
    }

    @Test func updatesAreCheckedWithAnEdDSAKey() throws {
        let plist = try Self.infoPlist()
        let key = try #require(plist["SUPublicEDKey"] as? String)
        #expect(Data(base64Encoded: key)?.count == 32)
    }

    @Test func theFeedAndTheArchivesAreVerified() throws {
        let plist = try Self.infoPlist()
        #expect(plist["SURequireSignedFeed"] as? Bool == true)
        #expect(plist["SUVerifyUpdateBeforeExtraction"] as? Bool == true)
    }

    /// Sparkle asks on the second launch only when nothing decides for the person (spec 8.4).
    @Test func automaticChecksAreOfferedNotImposed() throws {
        let plist = try Self.infoPlist()
        #expect(plist["SUEnableAutomaticChecks"] == nil)
        #expect(plist["SUAutomaticallyUpdate"] == nil)
    }

    /// No telemetry (spec 10.9): Sparkle's anonymous system profile stays off.
    @Test func noSystemProfileIsSent() throws {
        #expect(try Self.infoPlist()["SUEnableSystemProfiling"] == nil)
    }

    /// Sparkle compares CFBundleVersion: it is the marketing version, so every release is newer by construction.
    @Test func theBuildNumberIsTheVersion() throws {
        #expect(try Self.infoPlist()["CFBundleVersion"] as? String == "$(CURRENT_PROJECT_VERSION)")
        let project = try String(contentsOf: GuardTests.repositoryRoot.appendingPathComponent("project.yml"), encoding: .utf8)
        #expect(project.contains("CURRENT_PROJECT_VERSION: $(MARKETING_VERSION)"))
    }
}
