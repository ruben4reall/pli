import PliCore
import PliSystem
import Testing
@testable import PliApp

@MainActor @Suite struct RuntimeCadenceTests {
    @Test func atRestNothingTicks() {
        let h = RuntimeHarness()
        h.run(for: 5) { _ in 110 }
        #expect(h.clock.starts.isEmpty)
        #expect(h.sensor.mode == .rest)
        #expect(h.scheduler.pendingCount == 0)   // no timer at all: only the sensor thread is alive (spec 10.3)
    }

    @Test func framesAndFastReadsRunOnlyDuringTheGesture() {
        let h = RuntimeHarness()
        h.moveLid(to: 40, over: 0.5)
        #expect(h.clock.isRunning && h.clock.starts.last?.rate == 120 && h.clock.starts.last?.display == 1)
        #expect(h.sensor.mode == .active(hz: 120))
        h.moveLid(to: 110, over: 0.4, hold: 1.2)
        #expect(!h.clock.isRunning)
        #expect(h.sensor.mode == .rest)
        #expect(h.scheduler.pendingCount == 0)
    }

    @Test func lowPowerModeCapsAt60AndLightensTheRendering() {
        var environment = RuntimeEnvironment.macBook
        environment.lowPowerMode = true
        let h = RuntimeHarness(environment: environment)
        h.moveLid(to: 40, over: 0.5)
        #expect(h.clock.starts.last?.rate == 60)
        #expect(h.sensor.mode == .active(hz: 60))
        #expect(h.surfaces.configurations.last?.quality == .light)
        #expect(h.surfaces.configurations.last?.halfResolution == true)
    }

    @Test func lowPowerIsIgnoredWhenTheSettingIsOff() {
        var environment = RuntimeEnvironment.macBook
        environment.lowPowerMode = true
        var settings = PliSettings.default
        settings.general.lighterInLowPower = false
        let h = RuntimeHarness(settings: settings, environment: environment)
        h.moveLid(to: 40, over: 0.5)
        #expect(h.clock.starts.last?.rate == 120)
        #expect(h.surfaces.configurations.last?.quality == .full)
    }

    @Test func aSilentSensorFadesTheOverlay() {
        let h = RuntimeHarness()
        h.moveLid(to: 50, over: 0.4)
        #expect(h.surfaces.visibleSurfaces == [.desktop])
        h.run(for: 1.0)   // no fresh sample: the same old one is never sent twice
        #expect(h.surfaces.count(.hide(.desktop, 0.3)) == 1)
        #expect(h.surfaces.visibleSurfaces.isEmpty)
    }

    @Test func atRestAnAngleChangeReachesTheDirectorWithoutFrames() {
        let h = RuntimeHarness()
        h.setLid(118)
        #expect(h.runtime.director.lid.rawAngle == 118)
        #expect(h.runtime.director.lid.rest == 118)
        #expect(h.clock.starts.isEmpty)
    }

    @Test func theSensorStreamIsConsumed() async {
        let h = RuntimeHarness()
        h.sensor.publish(121, at: h.now)   // signaled on the stream only
        for _ in 0..<100 where h.runtime.director.lid.rawAngle != 121 { await Task.yield() }
        #expect(h.runtime.director.lid.rawAngle == 121)
    }
}
