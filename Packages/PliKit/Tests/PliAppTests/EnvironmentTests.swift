import PliCore
import Testing
@testable import PliApp
@testable import PliSystem

@MainActor @Suite struct EnvironmentTests {
    @Test func aMacBookHasEveryCapability() {
        let capabilities = RuntimeEnvironment.macBook.capabilities(lidSensorAvailable: true)
        #expect(capabilities == Capabilities())
    }

    @Test func aClosedMacBookOnAnExternalDisplayPauses() {
        var main = DisplayDescription.studioDisplay
        main.isMain = true
        let clamshell = RuntimeEnvironment(displays: [main], isLaptop: true)
        #expect(clamshell.effectTarget == nil)
        let capabilities = clamshell.capabilities(lidSensorAvailable: true)
        #expect(!capabilities.builtInDisplayAvailable && !capabilities.lockScreenSurfaceAvailable)
    }

    @Test func aDesktopMacKeepsDemoLockAndRevealOnItsMainDisplay() {
        var main = DisplayDescription.studioDisplay
        main.isMain = true
        let desktop = RuntimeEnvironment(displays: [main], isLaptop: false)
        #expect(desktop.effectTarget?.id == 7)
        let capabilities = desktop.capabilities(lidSensorAvailable: false)
        #expect(!capabilities.hasLidSensor && !capabilities.builtInDisplayAvailable)
        #expect(capabilities.lockScreenSurfaceAvailable && capabilities.canLockNow)
    }

    @Test func missingPiecesTurnTheirCapabilityOff() {
        var environment = RuntimeEnvironment.macBook
        environment.screenCaptureAllowed = false
        environment.lockScreenSurfaceAvailable = false
        environment.canLockNow = false
        environment.reduceMotion = true
        let capabilities = environment.capabilities(lidSensorAvailable: true)
        #expect(!capabilities.screenCaptureAllowed && !capabilities.lockScreenSurfaceAvailable && !capabilities.canLockNow)
        #expect(capabilities.reduceMotion)
    }

    @Test func theVirtualSchedulerFiresInTimeOrder() {
        let scheduler = VirtualScheduler()
        var fired: [String] = []
        scheduler.after(0.35) { fired.append("late") }
        let repeating = scheduler.every(0.1) { fired.append("tick") }
        scheduler.after(0.15) { fired.append("early") }
        scheduler.advance(to: scheduler.now + 0.36)
        #expect(fired == ["tick", "early", "tick", "tick", "late"])
        repeating.cancel()
        scheduler.advance(to: scheduler.now + 1)
        #expect(fired.count == 5 && scheduler.pendingCount == 0)
    }
}
