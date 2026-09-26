import Testing
@testable import PliCore

@Suite struct DirectorLockTests {
    @Test func sleepPreparesTheLockSurface() {
        var h = DirectorHarness()
        h.closeAndSleep()
        let after = h.commands(since: h.now - 1e-6)
        #expect(after.contains(.loadWallpaper))
        #expect(after.contains(.show(.lockScreen)))
        #expect(after.contains(.render(.lockScreen, progress: 1)))
        #expect(h.director.phase == .folded)
    }

    @Test func lockedWakeUnfoldsTheWallpaperWithTheLid() {
        var h = DirectorHarness()
        h.closeAndSleep()
        h.send(.didWake(locked: true))
        #expect(h.director.phase == .lockUnfolding(nil))
        h.moveLid(to: 110, over: 0.8, hold: 0.4)
        let lock = h.renders(.lockScreen)
        #expect(lock.last == 0)
        #expect(h.commands().contains(.hide(.lockScreen, fade: 0.25)))
        #expect(h.director.phase == .awaitingUnlock)
        #expect(h.director.isDesktopVisible)
        #expect(h.count(.startLockPolling) == 1)
        #expect(h.lastCursorCommand == false)
    }

    @Test func unlockRevealsTheDesktop() {
        var h = DirectorHarness()
        h.closeAndSleep()
        h.send(.didWake(locked: true))
        h.moveLid(to: 110, over: 0.8, hold: 0.4)
        let mark = h.now
        h.send(.screenUnlocked)
        h.run(for: 1.3)
        let after = h.commands(since: mark - 1e-6)
        #expect(after.contains(.captureDesktop))
        #expect(after.contains(.stopLockPolling))
        let reveal = h.renders(.desktop).suffix(20)
        #expect(reveal.last == 0)
        #expect(h.director.phase == .idle)
        #expect(!h.director.isDesktopVisible)
        #expect(h.lastCursorCommand == false)
        h.expectCapturesReleased()
    }

    @Test func unlockWhileTheLidIsStillOpeningFollowsTheLid() {
        var h = DirectorHarness()
        h.closeAndSleep()
        h.send(.didWake(locked: true))
        h.moveLid(to: 50, over: 0.3)
        h.send(.screenUnlocked)
        h.run(for: 0.1) { _ in 50 }
        #expect(h.director.phase == .folding)
        h.moveLid(to: 110, over: 0.5, hold: 0.4)
        #expect(h.director.phase == .idle)
        #expect(!h.director.isDesktopVisible)
        h.expectCapturesReleased()
    }

    @Test func wakeWithoutAPasswordRevealsTheDesktop() {
        var h = DirectorHarness()
        h.closeAndSleep()
        h.setLid(110)
        h.send(.didWake(locked: false))
        #expect(h.commands(since: h.now - 1e-6).contains(.hide(.lockScreen, fade: 0)))
        h.run(for: 1.3) { _ in 110 }
        #expect(h.director.phase == .idle)
        #expect(h.renders(.desktop).last == 0)
        h.expectCapturesReleased()
    }

    @Test func neverModeSkipsTheReveal() {
        var settings = PliSettings.default
        settings.triggers.onUnlock = .never
        var h = DirectorHarness(settings: settings)
        h.closeAndSleep()
        h.send(.didWake(locked: true))
        #expect(!h.director.isDesktopVisible)
        h.moveLid(to: 110, over: 0.8, hold: 0.4)
        #expect(h.director.phase == .idle)
        let mark = h.now
        h.send(.screenUnlocked)
        #expect(!h.commands(since: mark - 1e-6).contains(.captureDesktop))
        h.expectCapturesReleased()
    }

    @Test func alwaysModeRevealsAfterAnyLock() {
        var settings = PliSettings.default
        settings.triggers.onUnlock = .always
        var h = DirectorHarness(settings: settings)
        h.send(.screenLocked)
        #expect(h.director.phase == .awaitingUnlock)
        #expect(h.log.map(\.command).contains(.render(.desktop, progress: 1)))
        #expect(h.count(.setCursorHidden(true)) == 0)
        h.send(.screenUnlocked)
        h.run(for: 1.3) { _ in 110 }
        #expect(h.director.phase == .idle)
        #expect(h.renders(.desktop).last == 0)
        h.expectCapturesReleased()
    }

    @Test func aMissedUnlockIsCaughtByPolling() {
        var settings = PliSettings.default
        settings.triggers.onUnlock = .always
        var h = DirectorHarness(settings: settings)
        h.send(.screenLocked)
        h.send(.lockStatePolled(locked: true))
        #expect(h.director.phase == .awaitingUnlock)
        h.send(.lockStatePolled(locked: false))
        #expect(h.log.last?.command == .captureDesktop)
    }

    @Test func aRevealWithoutACaptureFadesOut() {
        var settings = PliSettings.default
        settings.triggers.onUnlock = .always
        var h = DirectorHarness(settings: settings)
        h.captureDelay = nil
        h.send(.screenLocked)
        h.send(.screenUnlocked)
        h.run(for: 0.6) { _ in 110 }
        #expect(h.commands().contains(.hide(.desktop, fade: 0.3)))
        #expect(h.director.phase == .idle)
        h.expectCapturesReleased()
    }

    @Test func lockSurfaceOffGoesStraightToWaitingForUnlock() {
        var settings = PliSettings.default
        settings.triggers.unfoldOnLockScreen = false
        var h = DirectorHarness(settings: settings)
        h.closeAndSleep()
        #expect(!h.everShown.contains(.lockScreen))
        h.send(.didWake(locked: true))
        #expect(h.director.phase == .awaitingUnlock)
    }

    @Test func noLockSurfaceCapabilityBehavesTheSame() {
        var h = DirectorHarness(capabilities: Capabilities(lockScreenSurfaceAvailable: false))
        h.closeAndSleep()
        #expect(!h.everShown.contains(.lockScreen))
        h.send(.didWake(locked: true))
        #expect(h.director.phase == .awaitingUnlock)
    }

    @Test func theLockSurfaceNeverOutlivesTheCap() {
        var h = DirectorHarness()
        h.closeAndSleep()
        h.send(.didWake(locked: true))
        h.run(for: 7)   // the sensor stays silent, the lid never opens
        #expect(!h.director.isLockSurfaceVisible)
        #expect(h.director.phase == .idle)
        h.expectCapturesReleased()
    }

    @Test func aLockDuringTheAnimatedLockCaptureRendersNothing() {
        var h = DirectorHarness()
        h.captureDelay = nil                            // the capture is slow: nothing is shown yet
        h.send(.lockRequested)
        h.run(for: 0.1) { _ in 110 }
        h.send(.screenLocked)                           // the Mac locked before the fold could start
        #expect(h.renders(.desktop).isEmpty)
        #expect(!h.everShown.contains(.desktop))
    }
}
