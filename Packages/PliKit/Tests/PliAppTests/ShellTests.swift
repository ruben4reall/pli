import PliCore
import Testing
@testable import PliApp

@Suite struct LaunchOptionsTests {
    @Test func theSimulatorBringsTheDebugMenu() {
        #expect(LaunchOptions.from(environment: [:]) == LaunchOptions())
        #expect(LaunchOptions.from(environment: ["PLI_LID_SIMULATOR": "1"]) == LaunchOptions(simulateLid: true, debugMenu: true))
        #expect(LaunchOptions.from(environment: ["PLI_DEBUG": "1"]) == LaunchOptions(simulateLid: false, debugMenu: true))
        #expect(LaunchOptions.from(environment: ["PLI_LID_SIMULATOR": "yes"]) == LaunchOptions())
    }
}
