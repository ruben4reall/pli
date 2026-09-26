import Foundation
import Testing
@testable import PliCore

@Suite struct DirectorScenarioTests {
    @Test(arguments: [false, true])
    func aFullNightEndsWithNothingOnScreen(idleSamplesOnChangeOnly: Bool) {
        var h = DirectorHarness()
        h.idleSamplesOnChangeOnly = idleSamplesOnChangeOnly
        h.moveLid(to: 0, over: 2.0, hold: 0.3)
        h.send(.willSleep)
        h.send(.didWake(locked: true))
        h.moveLid(to: 70, over: 0.5)
        h.send(.screenUnlocked)          // Touch ID while the lid is still opening
        h.run(for: 0.05) { _ in 70 }
        h.moveLid(to: 115, over: 0.5, hold: 1.0)
        #expect(h.director.phase == .idle)
        #expect(!h.director.isDesktopVisible && !h.director.isLockSurfaceVisible)
        #expect(h.lastCursorCommand == false)
        #expect(h.count(.stopLockPolling) == h.count(.startLockPolling))
        h.expectCapturesReleased()
    }

    @Test(arguments: [false, true])
    func fidgetingForAMinuteNeverShowsTheOverlay(idleSamplesOnChangeOnly: Bool) {
        var h = DirectorHarness(rest: 115)
        h.idleSamplesOnChangeOnly = idleSamplesOnChangeOnly
        h.run(for: 60) { t in 115 + 15 * sin(t * 1.7) * cos(t * 0.37) }
        #expect(!h.everShown.contains(.desktop))
        h.expectCapturesReleased()
    }

    @Test(arguments: [false, true])
    func everyShownSurfaceIsHiddenAgain(idleSamplesOnChangeOnly: Bool) {
        for closeSeconds in [0.3, 0.8, 2.0] {
            var h = DirectorHarness()
            h.idleSamplesOnChangeOnly = idleSamplesOnChangeOnly
            h.moveLid(to: 30, over: closeSeconds, hold: 0.2)
            h.moveLid(to: 110, over: closeSeconds, hold: 0.5)
            h.send(.demoRequested)
            h.run(for: 2.5) { _ in 110 }
            #expect(!h.director.isDesktopVisible, "close over \(closeSeconds) s")
            #expect(h.count(.show(.desktop)) == h.log.filter { if case .hide(.desktop, _) = $0.command { return true } else { return false } }.count)
            h.expectCapturesReleased()
        }
    }
}
