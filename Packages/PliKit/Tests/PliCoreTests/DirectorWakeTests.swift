import Testing
@testable import PliCore

/// Sleep and wake with real durations. The sensor may stay silent across sleep, while stall ticks reach the
/// director before the wake is handled, and while it reopens after the wake (spec 10.4): none of that is
/// stale samples. A sensor that never comes back still ends by a safeguard.
@Suite struct DirectorWakeTests {
    static let hour = 3600.0

    @Test func aLongSleepAndATickBeforeTheWakeStillUnfoldOnTheLockScreen() {
        var h = DirectorHarness()
        h.closeAndSleep(for: Self.hour)
        h.send(.tick)                                   // a frame reaches the director before the wake does
        h.send(.didWake(locked: true))
        #expect(h.director.phase == .lockUnfolding(nil))
        let wake = h.now
        h.moveLid(to: 110, over: 0.8, hold: 0.4)
        let lock = h.renders(.lockScreen, since: wake)
        #expect(lock.first == 1 && lock.last == 0)
        #expect(h.commands().contains(.hide(.lockScreen, fade: FoldDirector.lockSurfaceFade)))
        #expect(h.director.phase == .awaitingUnlock)
        h.send(.screenUnlocked)
        h.run(for: 1.3) { _ in 110 }
        #expect(h.director.phase == .idle && !h.director.isDesktopVisible)
        #expect(h.renders(.desktop).last == 0)
        #expect(!h.fadedOut)
        h.expectCapturesReleased()
    }

    @Test func stallTicksBeforeTheWakeDoNotFade() {
        var h = DirectorHarness()
        h.closeAndSleep(for: Self.hour)
        h.run(for: 0.6, step: 0.1)                      // 10 Hz stall ticks, the sensor silent
        #expect(h.director.phase == .folded)
        #expect(h.director.isDesktopVisible && h.director.isLockSurfaceVisible)
        h.send(.didWake(locked: true))
        #expect(h.director.phase == .lockUnfolding(nil))
        h.moveLid(to: 110, over: 0.8, hold: 0.4)
        #expect(h.renders(.lockScreen).last == 0)
        #expect(h.director.phase == .awaitingUnlock)
        #expect(!h.fadedOut)
    }

    @Test func aSensorThatReopensSlowlyStillUnfoldsTheLockScreen() {
        var h = DirectorHarness()
        h.closeAndSleep(for: Self.hour)
        h.send(.didWake(locked: true))
        h.run(for: 0.8)                                 // nothing from the sensor for 0.8 s after the wake
        #expect(h.director.phase == .lockUnfolding(nil))
        #expect(h.director.isLockSurfaceVisible)
        h.moveLid(to: 110, over: 0.8, hold: 0.4)
        #expect(h.renders(.lockScreen).last == 0)
        #expect(h.commands().contains(.hide(.lockScreen, fade: FoldDirector.lockSurfaceFade)))
        #expect(h.director.phase == .awaitingUnlock)
        #expect(!h.fadedOut)
    }

    @Test func theBasicModeWakeUnfoldsWithTheLid() {
        var h = DirectorHarness(capabilities: Capabilities(screenCaptureAllowed: false))
        h.closeAndSleep(for: Self.hour)
        h.send(.didWake(locked: false))
        let wake = h.now - 1e-6
        h.run(for: 0.8)                                 // the sensor reopens slowly
        #expect(h.director.isDesktopVisible)
        h.moveLid(to: 110, over: 0.8, hold: 0.4)
        let reveal = h.renders(.desktop, since: wake)
        #expect(reveal.first == 1 && reveal.last == 0)
        #expect(zip(reveal, reveal.dropFirst()).allSatisfy { $0 >= $1 - 1e-9 })   // unfolds, never folds back
        #expect(h.director.phase == .idle && !h.director.isDesktopVisible)
        #expect(!h.fadedOut)
        h.expectCapturesReleased()                      // Basic mode: no capture, so no release either
    }

    @Test func aCaptureLandingBeforeTheFirstSampleAfterWakeDoesNotFade() {
        var h = DirectorHarness()
        h.closeAndSleep(for: Self.hour)
        h.send(.didWake(locked: false))
        #expect(h.director.phase == .arming(since: h.now, afterWake: true))
        h.run(for: 0.8)                                 // the capture lands after 30 ms, the sensor after 0.8 s
        #expect(h.director.isDesktopVisible)
        h.moveLid(to: 110, over: 0.8, hold: 0.4)
        #expect(h.renders(.desktop).last == 0)
        #expect(h.director.phase == .idle && !h.director.isDesktopVisible)
        #expect(!h.fadedOut)
        h.expectCapturesReleased()
    }

    @Test func aSensorSilentForeverAfterAWakeEndsByTheCap() {
        let cases: [(name: String, capabilities: Capabilities, locked: Bool)] = [
            ("locked wake", Capabilities(), true),
            ("wake without a password", Capabilities(), false),
            ("wake without a password in Basic mode", Capabilities(screenCaptureAllowed: false), false),
        ]
        for c in cases {
            var h = DirectorHarness(capabilities: c.capabilities)
            h.closeAndSleep(for: Self.hour)
            h.send(.didWake(locked: c.locked))
            let wake = h.now
            h.run(for: 7)                               // the sensor never comes back
            #expect(h.director.phase == .idle, "\(c.name)")
            #expect(!h.director.isDesktopVisible && !h.director.isLockSurfaceVisible, "\(c.name)")
            let faded = h.log.first { if case .hide(_, fade: FoldDirector.failFade) = $0.command { return true } else { return false } }
            let after = (faded?.time ?? 0) - wake
            #expect(after > FoldDirector.sequenceCap && after < FoldDirector.sequenceCap + 0.2, "\(c.name): faded \(after) s after the wake")
            h.expectCapturesReleased()
        }
    }

    @Test func aSensorThatStopsDuringTheLockScreenUnfoldHandsOverAfterHalfASecond() {
        var h = DirectorHarness()
        h.closeAndSleep(for: Self.hour)
        h.send(.didWake(locked: true))
        h.moveLid(to: 60, over: 0.4)                    // samples resume after the wake, then the sensor stops
        let lastSample = h.now
        h.run(for: 1.5)
        let hidden = h.log.first { $0.command == .hide(.lockScreen, fade: FoldDirector.lockSurfaceFade) }?.time
        let after = (hidden ?? .infinity) - lastSample
        #expect(abs(after - FoldDirector.staleSampleLimit) < 0.02, "hidden \(after) s after the last sample")   // within a frame
        #expect(h.director.phase == .awaitingUnlock)   // the real lock screen, the overlay black under it
        #expect(h.director.isDesktopVisible && !h.director.isLockSurfaceVisible)
        #expect(!h.fadedOut)
    }

    // MARK: Sleep during a timed sequence: folded, then the wake rules apply (spec 11)

    @Test func theAnimatedLockThenClosingTheLidThenALockedWakeUnfoldsTheLockScreen() {
        var h = DirectorHarness()
        h.send(.lockRequested)
        h.run(for: 1.0) { _ in 110 }                    // the fold, then the lock
        h.send(.screenLocked)
        h.run(for: 1.0) { _ in 110 }                    // the timed lock screen unfold
        #expect(h.director.phase == .awaitingUnlock)
        h.moveLid(to: 0, over: 0.8, hold: 0.2)          // closed while locked: samples, no frames
        h.sleep(for: Self.hour)
        #expect(h.director.phase == .folded)
        #expect(h.director.isDesktopVisible && h.director.isLockSurfaceVisible)
        h.send(.didWake(locked: true))
        #expect(h.director.phase == .lockUnfolding(nil))
        let wake = h.now
        h.moveLid(to: 110, over: 0.8, hold: 0.4)
        let lock = h.renders(.lockScreen, since: wake)
        #expect(lock.first == 1 && lock.last == 0)
        #expect(h.director.phase == .awaitingUnlock)
        h.send(.screenUnlocked)
        h.run(for: 1.3) { _ in 110 }
        #expect(h.director.phase == .idle && !h.director.isDesktopVisible)
        #expect(h.count(.startLockPolling) == h.count(.stopLockPolling))
        #expect(!h.fadedOut)
        h.expectCapturesReleased()
    }

    @Test func sleepDuringATimedPhaseFoldsThenALockedWakeUnfolds() {
        let setups: [(name: String, setup: (inout DirectorHarness) -> Void)] = [
            ("demo", { h in
                h.send(.demoRequested)
                h.run(for: 0.5) { _ in 110 }
            }),
            ("arming", { h in
                h.captureDelay = 0.2
                h.moveLid(to: 60, over: 0.1)            // the capture is still on its way
            }),
            ("lock fold", { h in
                h.send(.lockRequested)
                h.run(for: 0.4) { _ in 110 }
            }),
            ("lock screen unfold", { h in
                h.send(.lockRequested)
                h.run(for: 1.0) { _ in 110 }
                h.send(.screenLocked)
                h.run(for: 0.3) { _ in 110 }
            }),
            ("unlock reveal", { h in
                h.send(.lockRequested)
                h.run(for: 1.0) { _ in 110 }
                h.send(.screenLocked)
                h.run(for: 1.0) { _ in 110 }
                h.send(.screenUnlocked)
                h.run(for: 0.3) { _ in 110 }
            }),
        ]
        for (name, setup) in setups {
            var h = DirectorHarness()
            setup(&h)
            h.sleep(for: Self.hour)
            #expect(h.director.phase == .folded, "\(name)")
            #expect(h.director.isLockSurfaceVisible, "\(name)")
            h.send(.didWake(locked: true))
            #expect(h.director.phase == .lockUnfolding(nil), "\(name)")
            h.moveLid(to: 110, over: 0.3, hold: 0.5)
            #expect(h.commands().contains(.hide(.lockScreen, fade: FoldDirector.lockSurfaceFade)), "\(name)")
            h.send(.screenUnlocked)
            h.run(for: 1.5) { _ in 110 }
            #expect(h.director.phase == .idle, "\(name)")
            #expect(!h.director.isDesktopVisible && !h.director.isLockSurfaceVisible, "\(name)")
            #expect(h.count(.startLockPolling) == h.count(.stopLockPolling), "\(name)")
            #expect(!h.fadedOut, "\(name)")
            h.expectCapturesReleased()
        }
    }

    @Test func sleepDuringTheDemoThenAWakeWithoutAPasswordReveals() {
        var h = DirectorHarness()
        h.send(.demoRequested)
        h.run(for: 0.5) { _ in 110 }
        h.sleep(for: Self.hour)
        #expect(h.director.phase == .folded)
        h.send(.didWake(locked: false))
        h.run(for: 1.5) { _ in 110 }
        #expect(h.count(.captureDesktop) == 2)          // captured again on wake
        #expect(h.renders(.desktop).last == 0)
        #expect(h.director.phase == .idle && !h.director.isDesktopVisible)
        h.expectCapturesReleased()
    }

    @Test func waitingForTheUnlockWithTheLidUpSurvivesSleep() {
        var h = DirectorHarness()
        h.send(.lockRequested)
        h.run(for: 1.0) { _ in 110 }
        h.send(.screenLocked)
        h.run(for: 1.0) { _ in 110 }
        #expect(h.director.phase == .awaitingUnlock)
        h.sleep(for: Self.hour)                         // the Mac sleeps with the lid open
        h.send(.didWake(locked: true))
        #expect(h.director.phase == .awaitingUnlock)
        h.send(.screenUnlocked)
        h.run(for: 1.3) { _ in 110 }
        #expect(h.director.phase == .idle && !h.director.isDesktopVisible)
        h.expectCapturesReleased()
    }

    // MARK: Between the sleep and the wake, the fold holds

    @Test func ticksBeforeTheWakeHoldTheFoldEvenWithTheLidOpen() {
        var h = DirectorHarness()
        h.send(.demoRequested)
        h.run(for: 0.5) { _ in 110 }
        h.sleep(for: Self.hour)                         // the Mac slept during the demo, lid open
        h.run(for: 0.6, step: 0.1) { _ in 110 }         // stall ticks and samples before the wake is handled
        #expect(h.director.phase == .folded)
        #expect(h.director.isLockSurfaceVisible)
        #expect(h.director.isWaitingForWake)
        h.send(.didWake(locked: true))
        #expect(!h.director.isWaitingForWake)
        #expect(h.director.phase == .lockUnfolding(nil))
        h.run(for: 0.5) { _ in 110 }
        #expect(h.commands().contains(.hide(.lockScreen, fade: FoldDirector.lockSurfaceFade)))
        #expect(h.director.phase == .awaitingUnlock)
        #expect(!h.fadedOut)
    }

    @Test func theLidOpeningBeforeTheWakeIsHandledStillUnfoldsTheLockScreen() {
        var h = DirectorHarness()
        h.closeAndSleep(for: Self.hour)
        h.moveLid(to: 110, over: 0.5, hold: 0.3)        // the sensor reports before the wake notification
        #expect(h.director.phase == .folded)
        #expect(h.director.isDesktopVisible && h.director.isLockSurfaceVisible)
        h.send(.didWake(locked: true))
        #expect(h.director.phase == .lockUnfolding(nil))
        h.run(for: 0.5) { _ in 110 }
        #expect(h.renders(.lockScreen).last == 0)
        #expect(h.director.phase == .awaitingUnlock)
        #expect(!h.fadedOut)
    }

    @Test func sleepDuringArmingNeverShowsTheDesktopWithoutACapture() {
        var h = DirectorHarness()
        h.captureDelay = nil                            // the capture never lands
        h.moveLid(to: 60, over: 0.1)
        #expect(h.director.phase == .arming(since: h.log.first { $0.command == .captureDesktop }?.time ?? -1, afterWake: false))
        h.sleep(for: Self.hour)
        h.run(for: 0.6, step: 0.1) { _ in 60 }
        #expect(!h.everShown.contains(.desktop))
        h.send(.didWake(locked: true))
        h.moveLid(to: 110, over: 0.4, hold: 0.5)
        #expect(!h.everShown.contains(.desktop))
        #expect(h.director.phase == .idle && !h.director.isLockSurfaceVisible)
        h.expectCapturesReleased()
    }

    @Test func aWakeThatGoesUnnoticedEndsAfterTheCap() {
        var h = DirectorHarness()
        h.closeAndSleep(for: Self.hour)
        h.moveLid(to: 110, over: 0.8)                   // frames and samples, but no didWake
        #expect(h.director.phase == .folded)
        #expect(h.director.isWaitingForWake)
        h.run(for: FoldDirector.sequenceCap) { _ in 110 }
        #expect(!h.director.isWaitingForWake)
        #expect(h.director.phase == .idle)
        #expect(!h.director.isDesktopVisible && !h.director.isLockSurfaceVisible)
        h.expectCapturesReleased()
    }
}
