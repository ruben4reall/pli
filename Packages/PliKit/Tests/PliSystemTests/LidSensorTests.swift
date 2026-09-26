import Foundation
import Testing
@testable import PliSystem

@Suite struct LidSensorTests {
    @Test func theAngleIsALittleEndianWordAtBytesOneAndTwo() {
        #expect(LidReport.angle(from: [1, 0x68, 0x00]) == 104)
        #expect(LidReport.angle(from: [1, 0x2C, 0x01, 0, 0, 0, 0, 0]) == 300)
        #expect(LidReport.angle(from: [1, 0, 0]) == 0)
    }

    @Test func shortOrImpossibleReportsAreRejected() {
        #expect(LidReport.angle(from: [1, 0x68]) == nil)
        #expect(LidReport.angle(from: []) == nil)
        #expect(LidReport.angle(from: [1, 0xFF, 0xFF]) == nil)
    }

    @Test func everyReadIsFreshButOnlyChangesAreSignaled() {
        var book = LidSampleBook()
        let first = book.record(angle: 110, at: 1.0)
        let same = book.record(angle: 110, at: 1.1)
        #expect(first && !same)
        #expect(book.latest == LidSample(angle: 110, time: 1.1, sequence: 2))
        let moved = book.record(angle: 109, at: 1.2)
        #expect(moved && book.latest?.sequence == 3)
    }

    @Test func availabilityFlipsAreReportedOnce() {
        var book = LidSampleBook()
        #expect(!book.isAvailable)
        let on = book.setAvailable(true)
        let again = book.setAvailable(true)
        let off = book.setAvailable(false)
        #expect(on && !again && off)
        #expect(!book.isAvailable)
    }

    /// On a MacBook with the sensor (the owner's), the real thing: a first reading arrives within a second.
    @Test(.enabled(if: LidSensor.findDevice() != nil, "needs a MacBook with a lid angle sensor"))
    @MainActor func theRealSensorReads() async throws {
        let sensor = LidSensor()
        sensor.start()
        defer { sensor.stop() }
        for _ in 0..<50 where sensor.latest == nil {
            try await Task.sleep(for: .milliseconds(20))
        }
        let sample = try #require(sensor.latest)
        #expect(sensor.isAvailable)
        #expect((0...180).contains(sample.angle))
        sensor.setMode(.active(hz: 120))
        let before = sample.sequence
        try await Task.sleep(for: .milliseconds(200))
        #expect((sensor.latest?.sequence ?? 0) > before + 10)   // about 24 reads in 200 ms at 120 Hz
    }
}
