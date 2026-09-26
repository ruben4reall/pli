import CoreGraphics
import PliCore
import PliSystem
import Testing
@testable import PliApp

@MainActor @Suite struct RuntimeSystemTests {
    private var clamshell: RuntimeEnvironment {
        var main = DisplayDescription.studioDisplay
        main.isMain = true
        return RuntimeEnvironment(displays: [main], isLaptop: true)
    }

    @Test func sleepPreparesTheLockSurfaceWithTheWallpaper() {
        let h = RuntimeHarness()
        h.moveLid(to: 0, over: 0.8, hold: 0.2)
        h.runtime.handle(.willSleep)
        #expect(h.wallpapers.requests == [1])
        #expect(h.surfaces.visibleSurfaces == [.desktop, .lockScreen])
        #expect(h.surfaces.renders(.lockScreen).last == 1)
        h.run(for: 0.1)
        #expect(h.surfaces.count(.wallpaper) == 1)
    }

    @Test func theAnimatedLockFoldsThenLocks() {
        let h = RuntimeHarness()
        h.runtime.requestLock()
        #expect(h.wallpapers.requests == [1])
        h.run(for: 1.0) { _ in 110 }
        #expect(h.locker.locks == 1)
        #expect(h.surfaces.renders(.desktop).max() == 1)
    }

    @Test func waitingForAnUnlockPollsUntilItComes() {
        var settings = PliSettings.default
        settings.triggers.onUnlock = .always
        let h = RuntimeHarness(settings: settings)
        h.lockState.locked = true
        h.runtime.handle(.screenLocked)
        #expect(h.phase == .awaitingUnlock)
        h.run(for: 1.0)
        #expect(h.snapshotter.requests.isEmpty)
        h.lockState.locked = false          // the unlock notification never comes
        h.run(for: Double(DirectorRuntime.lockPollInterval) + 0.01)
        #expect(h.snapshotter.requests.count == 1)
        h.run(for: 1.5) { _ in 110 }
        #expect(h.surfaces.visibleSurfaces.isEmpty)
        let reads = h.lockState.reads
        h.run(for: 1.0) { _ in 110 }
        #expect(h.lockState.reads == reads)   // polling stopped with the reveal
    }

    @Test func aLockedScreenKeepsTheOverlay() {
        var settings = PliSettings.default
        settings.triggers.onUnlock = .always
        let h = RuntimeHarness(settings: settings)
        h.lockState.locked = true
        h.runtime.handle(.screenLocked)
        h.run(for: 5)
        #expect(h.surfaces.visibleSurfaces == [.desktop])
        #expect(h.surfaces.count(.hideAll) == 1)   // only the one at launch
    }

    @Test func aTimedSequenceIsNeverCutShort() {
        let h = RuntimeHarness()
        h.runtime.requestDemo()
        h.run(for: 2.5) { _ in 110 }
        #expect(h.surfaces.renders(.desktop).max() == 1)
        #expect(h.surfaces.renders(.desktop).last == 0)
        #expect(h.surfaces.count(.hideAll) == 1)
    }


    @Test func aLockedWakeChecksTheSensorAndUnfoldsOnTheLockScreen() {
        let h = RuntimeHarness()
        h.moveLid(to: 0, over: 0.8, hold: 0.2)
        h.runtime.handle(.willSleep)
        h.lockState.locked = true
        let prewarms = h.snapshotter.prewarms
        h.runtime.handle(.didWake)
        #expect(h.sensor.wakeChecks == 1)
        #expect(h.snapshotter.invalidations == 1 && h.snapshotter.prewarms == prewarms + 1)
        #expect(h.phase == .lockUnfolding(nil))
        h.moveLid(to: 110, over: 0.8, hold: 0.4)
        #expect(h.surfaces.renders(.lockScreen).last == 0)
        #expect(!h.surfaces.visibleSurfaces.contains(.lockScreen))
        h.lockState.locked = false
        h.runtime.handle(.screenUnlocked)
        h.run(for: 1.5) { _ in 110 }
        #expect(h.phase == .idle && h.surfaces.visibleSurfaces.isEmpty)
    }

    @Test func aWakeWithoutPasswordRevealsTheDesktop() {
        let h = RuntimeHarness()
        h.moveLid(to: 0, over: 0.8, hold: 0.2)
        h.runtime.handle(.willSleep)
        h.setLid(110)
        h.runtime.handle(.didWake)
        h.run(for: 1.5) { _ in 110 }
        #expect(h.snapshotter.requests.count == 2)
        #expect(h.surfaces.renders(.desktop).last == 0)
        #expect(h.phase == .idle)
    }

    @Test func stallTicksBeforeTheWakeAndASlowSensorStillUnfoldOnTheLockScreen() {
        let h = RuntimeHarness()
        h.moveLid(to: 0, over: 0.8, hold: 0.2)
        h.runtime.handle(.willSleep)
        h.lockState.locked = true
        h.run(for: 0.6)                      // the sensor is silent; ticks may reach the director before the wake
        h.runtime.handle(.didWake)
        h.run(for: 0.8)                      // the sensor reopens slowly: nothing for 0.8 s after the wake
        #expect(h.phase == .lockUnfolding(nil))
        h.moveLid(to: 110, over: 0.8, hold: 0.4)
        #expect(h.surfaces.renders(.lockScreen).last == 0)
    }

    @Test func aFoldHeldForTheWakeWithTheLidOpenIsNotAStuckOverlay() {
        let h = RuntimeHarness()
        h.runtime.requestDemo()
        h.run(for: 0.5) { _ in 110 }
        h.runtime.handle(.willSleep)         // the Mac sleeps during the demo, lid open
        h.lockState.locked = true
        let hides = h.surfaces.count(.hideAll)
        h.run(for: 2.0) { _ in 110 }         // stall ticks and the watchdog run before the wake is handled
        #expect(h.phase == .folded)
        #expect(h.surfaces.count(.hideAll) == hides)
        h.runtime.handle(.didWake)
        #expect(h.phase == .lockUnfolding(nil))
    }

    @Test func aCaptureThatLandsAfterTheDirectorGaveUpIsNeverInstalled() {
        let h = RuntimeHarness()
        h.snapshotter.behavior = .succeed(after: 1.5)
        h.moveLid(to: 60, over: 0.4, hold: 1.0)     // the capture is still out after 1 s: the director moved on
        #expect(h.surfaces.count(.snapshot) == 0)
        h.run(for: 0.5) { _ in 60 }                 // the late picture lands now
        #expect(h.surfaces.count(.snapshot) == 0)
        #expect(h.surfaces.count(.release) == 0)
    }

    @Test func aDisplayChangeDuringAGestureRestsAndMovesTheSurfaces() {
        let h = RuntimeHarness()
        h.moveLid(to: 40, over: 0.5)
        var resized = DisplayDescription.macBookPanel
        resized.frame = CGRect(x: 0, y: 0, width: 1800, height: 1169)   // "More Space"
        h.environment.value.displays = [resized]
        h.runtime.handle(.displaysChanged)
        #expect(h.surfaces.count(.hide(.desktop, DirectorRuntime.watchdogFade)) == 1)
        #expect(h.surfaces.configurations.last?.display == resized)
        #expect(h.snapshotter.invalidations == 1)
        #expect(!h.cursor.hidden)
        h.moveLid(to: 30, over: 0.3)   // the lid keeps closing: a fresh capture on the new display
        #expect(h.snapshotter.requests.count == 2 && h.surfaces.visibleSurfaces == [.desktop])
    }

    @Test func aClosedMacBookOnAnExternalDisplayPauses() {
        let h = RuntimeHarness()
        h.environment.value = clamshell
        h.runtime.handle(.displaysChanged)
        #expect(!h.runtime.director.capabilities.builtInDisplayAvailable)
        #expect(h.surfaces.configurations.last?.display == nil)
        h.runtime.requestDemo()
        h.run(for: 1)
        #expect(h.snapshotter.requests.isEmpty)
        h.runtime.requestLock()
        #expect(h.locker.locks == 1)   // no fold to show, but the shortcut still locks
    }

    @Test func aDesktopMacPlaysTheDemoOnItsMainDisplay() {
        var main = DisplayDescription.studioDisplay
        main.isMain = true
        let h = RuntimeHarness(environment: RuntimeEnvironment(displays: [main], isLaptop: false), sensorAvailable: false, rest: nil)
        h.runtime.requestDemo()
        h.run(for: 2.5)
        #expect(h.snapshotter.requests == [7])
        #expect(h.surfaces.renders(.desktop).max() == 1)
        #expect(h.clock.starts.first?.display == 7)
    }

    @Test func losingTheSensorTurnsTheLidOff() {
        let h = RuntimeHarness()
        h.sensor.setAvailable(false)
        h.runtime.sensorUpdated(.availabilityChanged(false))
        #expect(!h.runtime.director.capabilities.hasLidSensor)
        h.moveLid(to: 20, over: 0.5)
        #expect(h.snapshotter.requests.isEmpty)
        h.runtime.requestDemo()   // the demo still works without the sensor (spec 5.5)
        h.run(for: 0.2)
        #expect(h.snapshotter.requests.count == 1)
    }

    @Test func reduceMotionAndPermissionAreReadAgainOnTheirEvents() {
        let h = RuntimeHarness()
        h.environment.value.reduceMotion = true
        h.runtime.handle(.accessibilityChanged)
        #expect(h.surfaces.configurations.last?.reduceMotion == true)
        #expect(h.runtime.director.capabilities.reduceMotion)
        h.environment.value.screenCaptureAllowed = false
        h.runtime.handle(.appActivated)
        #expect(h.surfaces.configurations.last?.basic == true)
        var settings = PliSettings.default
        settings.general.followReduceMotion = false
        h.runtime.apply(settings: settings)
        #expect(h.surfaces.configurations.last?.reduceMotion == false)
    }

    @Test func lowPowerModeTurningOnMidGestureSlowsTheFrames() {
        let h = RuntimeHarness()
        h.moveLid(to: 40, over: 0.5)
        h.environment.value.lowPowerMode = true
        h.runtime.handle(.powerStateChanged)
        #expect(h.clock.starts.last?.rate == 60)
        #expect(h.sensor.mode == .active(hz: 60))
    }

    @Test func theLockShortcutDoesNothingWhenTurnedOff() {
        var settings = PliSettings.default
        settings.triggers.animatedLockEnabled = false
        let h = RuntimeHarness(settings: settings)
        h.runtime.requestLock()
        h.run(for: 1)
        #expect(h.locker.locks == 0 && h.snapshotter.requests.isEmpty)
    }
}
