import Testing
@testable import PliCore

@Suite struct DirectorSequenceTests {
    @Test func demoFoldsHoldsAndUnfolds() {
        var h = DirectorHarness()
        h.send(.demoRequested)
        h.run(for: 2.5) { _ in 110 }
        let p = h.renders(.desktop)
        #expect(p.max() == 1)
        #expect(p.last == 0)
        #expect(h.everShown == [.desktop])
        #expect(h.director.phase == .idle)
        #expect(h.lastCursorCommand == false)
        h.expectCapturesReleased()
    }

    @Test func demoCancelsWhenTheLidMoves() {
        var h = DirectorHarness()
        h.send(.demoRequested)
        h.run(for: 0.1) { _ in 110 }
        h.moveLid(to: 100, over: 0.2)
        #expect(h.director.phase == .idle)
        #expect(!h.director.isDesktopVisible)
        h.expectCapturesReleased()
    }

    @Test func demoIsIgnoredWhenBusyOrDisabled() {
        var h = DirectorHarness()
        h.moveLid(to: 50, over: 0.4)
        let captures = h.count(.captureDesktop)
        h.send(.demoRequested)
        #expect(h.count(.captureDesktop) == captures)
        var settings = PliSettings.default
        settings.triggers.demoEnabled = false
        var off = DirectorHarness(settings: settings)
        off.send(.demoRequested)
        #expect(off.log.isEmpty)
    }

    @Test func demoWithoutACaptureNeverShows() {
        var h = DirectorHarness()
        h.captureDelay = nil
        h.send(.demoRequested)
        h.run(for: 0.5) { _ in 110 }
        #expect(!h.everShown.contains(.desktop))
        #expect(h.director.phase == .idle)
        h.expectCapturesReleased()
    }

    @Test func animatedLockFoldsLocksAndUnfolds() {
        var h = DirectorHarness()
        h.send(.lockRequested)
        #expect(h.log.map(\.command).contains(.loadWallpaper))
        h.run(for: 1.0) { _ in 110 }
        #expect(h.count(.lockNow) == 1)
        h.send(.screenLocked)
        #expect(h.director.isLockSurfaceVisible)
        h.run(for: 1.0) { _ in 110 }
        #expect(h.commands().contains(.hide(.lockScreen, fade: 0.25)))
        #expect(h.director.phase == .awaitingUnlock)
        h.send(.screenUnlocked)
        h.run(for: 1.3) { _ in 110 }
        #expect(h.director.phase == .idle)
        #expect(!h.director.isDesktopVisible)
        h.expectCapturesReleased()
    }

    @Test func animatedLockNeedsTheLockCall() {
        var h = DirectorHarness(capabilities: Capabilities(canLockNow: false))
        h.send(.lockRequested)
        #expect(h.log.isEmpty)
    }

    @Test func aLockThatNeverLandsFadesOut() {
        var h = DirectorHarness()
        h.send(.lockRequested)
        h.run(for: 3.5) { _ in 110 }
        #expect(h.commands().contains(.hide(.desktop, fade: 0.3)))
        #expect(h.director.phase == .idle)
        h.expectCapturesReleased()
    }

    @Test func aFailedCaptureStillLocks() {
        var h = DirectorHarness()
        h.captureFails = true
        h.send(.lockRequested)
        h.run(for: 0.1) { _ in 110 }
        #expect(h.count(.lockNow) == 1)
        #expect(!h.everShown.contains(.desktop))
        h.expectCapturesReleased()
    }

    @Test func reduceMotionShortensTimedSequences() {
        var h = DirectorHarness(capabilities: Capabilities(reduceMotion: true))
        h.send(.demoRequested)
        h.run(for: 1.45) { _ in 110 }
        #expect(h.director.phase == .idle)
        h.expectCapturesReleased()
    }

    @Test func disablingPliHidesEverything() {
        var h = DirectorHarness()
        h.moveLid(to: 40, over: 0.4)
        #expect(h.director.isDesktopVisible)
        var off = PliSettings.default
        off.general.enabled = false
        h.send(.settingsChanged(off))
        #expect(!h.director.isDesktopVisible)
        #expect(h.director.phase == .inactive)
        h.moveLid(to: 10, over: 0.3)
        #expect(h.director.phase == .inactive)
        h.send(.settingsChanged(.default))
        #expect(h.director.phase == .idle)
        h.expectCapturesReleased()
    }

    @Test func losingTheBuiltInDisplayStopsTheGesture() {
        var h = DirectorHarness()
        h.moveLid(to: 40, over: 0.4)
        h.send(.capabilitiesChanged(Capabilities(builtInDisplayAvailable: false)))
        #expect(!h.director.isDesktopVisible)
        #expect(h.director.phase == .idle)
        let captures = h.count(.captureDesktop)
        h.moveLid(to: 5, over: 0.3)
        #expect(h.count(.captureDesktop) == captures)
        h.send(.capabilitiesChanged(Capabilities()))
        h.moveLid(to: 110, over: 0.3)
        #expect(h.director.lid.rest == 110)
        h.expectCapturesReleased()
    }

    @Test func losingThePermissionSwitchesToBasicAtTheNextGesture() {
        var h = DirectorHarness()
        h.moveLid(to: 40, over: 0.4)
        h.send(.capabilitiesChanged(Capabilities(screenCaptureAllowed: false)))
        #expect(h.director.isDesktopVisible)
        h.moveLid(to: 110, over: 0.4, hold: 0.3)
        let captures = h.count(.captureDesktop)
        h.moveLid(to: 40, over: 0.4)
        #expect(h.count(.captureDesktop) == captures)
        #expect(h.director.isDesktopVisible)
    }
}
