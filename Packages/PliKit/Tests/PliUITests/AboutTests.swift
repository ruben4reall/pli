import Testing
@testable import PliUI

@Suite struct AboutTests {
    @Test func aboutShowsTheBundleVersion() {
        #expect(AppVersion.from(["CFBundleShortVersionString": "1.0", "CFBundleVersion": "3"]).text == "Version 1.0 (3)")
        #expect(AppVersion.from(nil).text == "Version 0.0 (0)")
    }
}
