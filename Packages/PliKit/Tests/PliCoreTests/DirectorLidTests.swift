import Testing
@testable import PliCore

@Suite struct DirectorLidTests {
    @Test func adjustmentAboveTheStartAngleNeverShowsTheOverlay() {
        var h = DirectorHarness()
        h.moveLid(to: 95, over: 0.4, hold: 0.5)
        h.moveLid(to: 110, over: 0.4, hold: 0.5)
        #expect(!h.everShown.contains(.desktop))
        #expect(h.count(.setCursorHidden(true)) == 0)
        #expect(h.director.phase == .idle)
        h.expectCapturesReleased()
    }

    @Test func closingShowsTheOverlayAndReachesFolded() {
        var h = DirectorHarness()
        h.moveLid(to: 0, over: 1.0, hold: 0.2)
        #expect(h.everShown == [.desktop])
        #expect(h.count(.captureDesktop) == 1)
        let progress = h.renders(.desktop)
        #expect(progress.last == 1)
        #expect(zip(progress, progress.dropFirst()).allSatisfy { $0 <= $1 + 1e-9 })
        #expect(h.director.phase == .folded)
        #expect(h.count(.setCursorHidden(true)) == 1)
    }

    @Test func parkingTheLidClearsTheFrost() {
        var h = DirectorHarness()
        h.moveLid(to: 60, over: 0.4, hold: 4)
        #expect(h.everShown.contains(.desktop))
        #expect(!h.director.isDesktopVisible)
        #expect(h.director.phase == .idle)
        #expect(h.count(.setCursorHidden(false)) == 1)
        h.expectCapturesReleased()
    }

    @Test func reopeningUnwindsAndReturnsToIdle() {
        var h = DirectorHarness()
        h.moveLid(to: 40, over: 0.4)
        h.moveLid(to: 110, over: 0.4, hold: 0.3)
        #expect(h.director.phase == .idle)
        #expect(h.commands().contains(.hide(.desktop, fade: 0)))
        #expect(h.commands().contains(.releaseSnapshot(after: 1)))
        #expect(h.renders(.desktop).last == 0)
        h.expectCapturesReleased()
    }

    @Test(arguments: [false, true])
    func restingBetweenPreArmAndStartDoesNotLoopCaptures(idleSamplesOnChangeOnly: Bool) {
        var h = DirectorHarness()
        h.idleSamplesOnChangeOnly = idleSamplesOnChangeOnly
        h.moveLid(to: 95, over: 0.3, hold: 3)
        #expect(h.count(.captureDesktop) == 1)
        #expect(!h.everShown.contains(.desktop))
        h.expectCapturesReleased()
    }

    @Test func aCaptureThatNeverLandsSkipsTheGesture() {
        var h = DirectorHarness()
        h.captureDelay = nil
        h.moveLid(to: 40, over: 0.5, hold: 0.5)
        #expect(!h.everShown.contains(.desktop))
        #expect(h.director.phase == .idle)
        #expect(h.count(.captureDesktop) == 1)
        h.moveLid(to: 110, over: 0.5, hold: 0.2)
        h.captureDelay = 0.03
        h.moveLid(to: 40, over: 0.5)
        #expect(h.count(.captureDesktop) == 2)
        #expect(h.everShown.contains(.desktop))
    }

    @Test func aFailedCaptureSkipsTheGesture() {
        var h = DirectorHarness()
        h.captureFails = true
        h.moveLid(to: 30, over: 0.5, hold: 0.3)
        #expect(!h.everShown.contains(.desktop))
        #expect(h.director.phase == .idle)
        h.expectCapturesReleased()
    }

    @Test func lateCaptureIsReleased() {
        var h = DirectorHarness()
        h.captureDelay = 0.2
        h.moveLid(to: 95, over: 0.05)
        h.moveLid(to: 110, over: 0.05, hold: 0.3)
        #expect(!h.everShown.contains(.desktop))
        #expect(h.commands().filter { $0 == .releaseSnapshot(after: 0) }.count >= 1)
        h.expectCapturesReleased()
    }

    @Test func staleSamplesFadeTheOverlayOut() {
        var h = DirectorHarness()
        h.moveLid(to: 50, over: 0.4)
        #expect(h.director.isDesktopVisible)
        h.run(for: 1.0)   // the sensor goes silent
        #expect(!h.director.isDesktopVisible)
        #expect(h.commands().contains(.hide(.desktop, fade: 0.3)))
        h.expectCapturesReleased()
    }

    @Test func openingWiderNeverTriggers() {
        var h = DirectorHarness()
        h.moveLid(to: 130, over: 0.5, hold: 0.5)
        #expect(h.count(.captureDesktop) == 0)
        h.expectCapturesReleased()
    }

    @Test func lidCloseDisabledIgnoresTheLid() {
        var settings = PliSettings.default
        settings.triggers.lidClose = false
        var h = DirectorHarness(settings: settings)
        h.moveLid(to: 10, over: 0.8)
        #expect(h.log.isEmpty)
    }

    @Test func noSensorIgnoresTheLid() {
        var h = DirectorHarness(capabilities: Capabilities(hasLidSensor: false))
        h.moveLid(to: 10, over: 0.8)
        #expect(h.log.isEmpty)
    }

    @Test func basicModeNeverCaptures() {
        var h = DirectorHarness(capabilities: Capabilities(screenCaptureAllowed: false))
        h.moveLid(to: 10, over: 0.8)
        #expect(h.count(.captureDesktop) == 0)
        #expect(h.everShown == [.desktop])
    }

    @Test func cursorStaysVisibleWhenTheSettingIsOff() {
        var settings = PliSettings.default
        settings.general.hideCursor = false
        var h = DirectorHarness(settings: settings)
        h.moveLid(to: 10, over: 0.8)
        #expect(h.count(.setCursorHidden(true)) == 0)
    }

    @Test func aCaptureFromAnAbortedArmServesTheNextGesture() {
        var h = DirectorHarness()
        h.captureDelay = 0.2
        h.moveLid(to: 95, over: 0.05)       // arms (pre-arm is 98)
        h.moveLid(to: 110, over: 0.05)      // disarms before the capture lands
        h.moveLid(to: 50, over: 0.08)       // closes again while that capture is still on its way
        h.run(for: 0.4) { _ in 50 }
        #expect(h.count(.captureDesktop) == 1)
        #expect(h.director.isDesktopVisible)
        #expect(!h.commands().contains(.releaseSnapshot(after: 0)))
    }

    @Test func aLostCaptureDoesNotBlockLaterGestures() {
        var h = DirectorHarness()
        h.captureDelay = nil
        h.moveLid(to: 60, over: 0.3, hold: 0.3)   // the capture never lands: gesture skipped
        h.moveLid(to: 110, over: 0.3, hold: 0.8)
        h.captureDelay = 0.03
        h.moveLid(to: 60, over: 0.3)
        #expect(h.count(.captureDesktop) == 2)
        #expect(h.director.isDesktopVisible)
    }

    @Test func aCaptureLandingAfterTheTimeoutServesTheNextGesture() {
        var h = DirectorHarness()
        h.captureDelay = 0.4
        h.moveLid(to: 60, over: 0.1)          // arms near 98; the capture is slow
        h.run(for: 0.2) { _ in 60 }           // the 250 ms timeout passes: gesture skipped
        h.moveLid(to: 110, over: 0.03)        // back above the pre-arm angle
        h.moveLid(to: 60, over: 0.03)         // closes again before the slow capture lands
        h.run(for: 0.3) { _ in 60 }
        #expect(h.count(.captureDesktop) == 1)
        #expect(h.director.isDesktopVisible)
        #expect(!h.commands().contains(.releaseSnapshot(after: 0)))
    }

    // MARK: Captures that never showed (the overlay stayed hidden) are still released

    @Test(arguments: [false, true])
    func aNearMissReleasesItsCapture(idleSamplesOnChangeOnly: Bool) {
        var h = DirectorHarness()                  // rest 110: pre-arm 98, effect start 90
        h.idleSamplesOnChangeOnly = idleSamplesOnChangeOnly
        h.moveLid(to: 95, over: 0.3, hold: 1)
        #expect(!h.everShown.contains(.desktop))
        #expect(h.count(.captureDesktop) == 1)
        #expect(h.releases == [FoldDirector.snapshotRelease])
        #expect(h.director.phase == .idle)
        h.expectCapturesReleased()
    }

    @Test(arguments: [false, true])
    func aNearMissAfterOpeningWideReleasesItsCapture(idleSamplesOnChangeOnly: Bool) {
        var h = DirectorHarness()
        h.idleSamplesOnChangeOnly = idleSamplesOnChangeOnly
        h.moveLid(to: 130, over: 0.4, hold: 0.5)   // the rest follows the lid up to 130
        h.moveLid(to: 96, over: 0.5, hold: 1)
        #expect(!h.everShown.contains(.desktop))
        #expect(h.count(.captureDesktop) == 1)
        #expect(h.releases == [FoldDirector.snapshotRelease])
        h.expectCapturesReleased()
    }

    @Test(arguments: [false, true])
    func fiveNearMissesReleaseFiveCaptures(idleSamplesOnChangeOnly: Bool) {
        var h = DirectorHarness()
        h.idleSamplesOnChangeOnly = idleSamplesOnChangeOnly
        for _ in 0..<5 {
            h.moveLid(to: 95, over: 0.3, hold: 0.5)
            h.moveLid(to: 110, over: 0.3, hold: 0.5)
        }
        #expect(!h.everShown.contains(.desktop))
        #expect(h.count(.captureDesktop) == 5)
        #expect(h.releases == Array(repeating: FoldDirector.snapshotRelease, count: 5))
        h.expectCapturesReleased()
    }

    @Test func sleepBeforeTheOverlayShowsReleasesTheCapture() {
        var h = DirectorHarness()
        h.moveLid(to: 95, over: 0.05)              // arms; the capture lands 30 ms later
        h.run(for: 0.05) { _ in 95 }               // folding at p = 0: nothing on screen yet
        #expect(h.director.phase == .folding && !h.director.isDesktopVisible)
        h.send(.willSleep)
        #expect(h.director.phase == .idle)
        #expect(h.releases == [FoldDirector.snapshotRelease])
        h.expectCapturesReleased()
    }

    @Test func samplesAtRestOnlyOnChangeStillFollowTheLidUp() {
        var h = DirectorHarness()
        h.idleSamplesOnChangeOnly = true
        let before = h.samplesSent
        h.run(for: 1) { _ in 110 }
        #expect(h.samplesSent == before)           // a still lid sends nothing while no frames run
        h.moveLid(to: 115, over: 0.2, hold: 0.5)
        #expect(h.samplesSent - before == 5)       // one per degree
        #expect(h.director.lid.rest == 115)
        h.expectCapturesReleased()
    }

    // MARK: The sensor goes away mid-gesture (spec 12.1)

    @Test func losingTheSensorMidGestureEndsIt() {
        var h = DirectorHarness()
        h.moveLid(to: 40, over: 0.4)
        #expect(h.director.isDesktopVisible)
        h.send(.capabilitiesChanged(Capabilities(hasLidSensor: false)))
        #expect(h.director.phase == .idle)
        #expect(!h.director.isDesktopVisible)
        #expect(h.lastCursorCommand == false)
        let captures = h.count(.captureDesktop)
        h.moveLid(to: 10, over: 0.3)               // whatever the lid does now is ignored
        #expect(h.count(.captureDesktop) == captures)
        #expect(!h.director.isDesktopVisible)
        h.send(.demoRequested)                     // the demo still works without the sensor (spec 5.5)
        h.run(for: 2.5)
        #expect(h.renders(.desktop).last == 0)
        #expect(h.director.phase == .idle && !h.director.isDesktopVisible)
        h.expectCapturesReleased()
    }

    @Test func losingTheSensorDuringTheLockScreenUnfoldEndsIt() {
        var h = DirectorHarness()
        h.closeAndSleep()
        h.send(.didWake(locked: true))
        h.moveLid(to: 50, over: 0.3)
        #expect(h.director.phase == .lockUnfolding(nil))
        h.send(.capabilitiesChanged(Capabilities(hasLidSensor: false)))
        #expect(h.director.phase == .idle)
        #expect(!h.director.isLockSurfaceVisible && !h.director.isDesktopVisible)
        #expect(h.count(.startLockPolling) == h.count(.stopLockPolling))
        h.expectCapturesReleased()
    }
}
