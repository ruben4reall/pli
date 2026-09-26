import Foundation
import Testing
@testable import PliSystem

@MainActor @Suite struct SimulatedLidSensorTests {
    final class FakeClock { var now = 100.0 }

    @Test func scriptsInterpolateAndHoldTheirEnds() {
        let script = LidScript.closeHalfwayAndReopen
        #expect(script.angle(at: -1) == 110)
        #expect(script.angle(at: 0.4) == 82.5)
        #expect(script.angle(at: 1.2) == 55)
        #expect(script.angle(at: 99) == 110)
        #expect(script.duration == 2.4)
        #expect(LidScript(name: "Empty", keyframes: []).angle(at: 3) == 110)
    }

    @Test func menuNamesAreShortAndPlain() {
        for script in LidScript.library {
            #expect(!script.name.contains("\u{2014}") && script.name.count <= 30, "\(script.name)")
        }
    }

    @Test func aSetAngleIsPublishedInWholeDegrees() {
        let clock = FakeClock()
        let sensor = SimulatedLidSensor(angle: 110, clock: { clock.now })
        sensor.start()
        defer { sensor.stop() }
        #expect(sensor.isAvailable && sensor.latest?.angle == 110)
        sensor.set(angle: 63.4)
        #expect(sensor.latest?.angle == 63)
        let sequence = sensor.latest?.sequence ?? 0
        sensor.tick()
        #expect(sensor.latest?.sequence == sequence + 1)   // fresh even when still
    }

    @Test func aScriptPlaysAgainstTheClockThenStays() {
        let clock = FakeClock()
        let sensor = SimulatedLidSensor(angle: 110, clock: { clock.now })
        sensor.start()
        defer { sensor.stop() }
        sensor.play(.closeSlowly)
        clock.now += 1.5
        sensor.tick()
        #expect(sensor.latest?.angle == 55)
        clock.now += 5
        sensor.tick()
        #expect(sensor.latest?.angle == 0 && !sensor.isPlaying)
        clock.now += 1
        sensor.tick()
        #expect(sensor.latest?.angle == 0)
    }

    @Test func changesAreSignaledOnTheStream() async {
        let clock = FakeClock()
        let sensor = SimulatedLidSensor(angle: 110, clock: { clock.now })
        sensor.start()
        defer { sensor.stop() }
        sensor.tick()           // same angle: no signal
        sensor.set(angle: 90)
        var updates = sensor.updates.makeAsyncIterator()
        #expect(await updates.next() == .availabilityChanged(true))
        #expect(await updates.next() == .angleChanged)   // the first reading
        #expect(await updates.next() == .angleChanged)   // 90°
    }
}
