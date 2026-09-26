import Testing
@testable import PliCore

@Suite struct LidModelTests {
    @Test func unknownUntilTheFirstSample() {
        let lid = LidModel(motion: .duo)
        #expect(lid.angle == nil && lid.rest == nil && lid.progress == 0 && !lid.isLowered)
        #expect(lid.silence == nil)
    }

    @Test func idleSettlingLearnsTheRestWithoutFrames() {
        var lid = LidModel(motion: .duo)
        lid.receive(angle: 112)
        lid.settleIdle(at: 0)
        #expect(lid.angle == 112 && lid.rest == 112)
        #expect(lid.preArmAngle == 98)
    }

    @Test func framesSmoothAndMapProgress() {
        var lid = LidModel(motion: .duo)
        lid.receive(angle: 110)
        lid.settleIdle(at: 0)
        lid.receive(angle: 55)
        var t = 0.01
        for _ in 0..<60 {
            t += 1.0 / 120
            lid.advance(to: t, dt: 1.0 / 120)
        }
        #expect(lid.angle == 55)
        #expect(abs(lid.progress - 0.5) < 1e-9)
        #expect(lid.isLowered)
        #expect(abs((lid.silence ?? 0) - 60.0 / 120) < 1e-9)   // 60 frames since the last sample
    }

    @Test func applyingMotionUpdatesEveryPart() {
        var lid = LidModel(motion: .duo)
        var m = MotionParameters.duo
        m.startAngle = 100
        m.smoothingMS = 0
        m.fullFoldAngle = 30
        lid.apply(m)
        #expect(lid.mapper.startAngle == 100 && lid.mapper.fullFoldAngle == 30)
        lid.receive(angle: 120)
        lid.settleIdle(at: 0)
        lid.receive(angle: 65)
        lid.advance(to: 0.02, dt: 0.01)
        #expect(lid.angle == 65)   // no smoothing
        #expect(abs(lid.progress - 0.5) < 1e-9)
    }

    @Test func resetRestRelearns() {
        var lid = LidModel(motion: .duo)
        lid.receive(angle: 120)
        lid.settleIdle(at: 0)
        lid.resetRest()
        lid.receive(angle: 100)
        lid.settleIdle(at: 1)
        #expect(lid.rest == 100)
    }

    @Test func silenceCountsFrameTimeOnly() {
        var lid = LidModel(motion: .duo)
        lid.receive(angle: 110)
        #expect(lid.silence == 0)
        lid.advance(to: 0.01, dt: 0.01)
        lid.advance(to: 0.02, dt: 0.01)
        #expect(abs((lid.silence ?? 0) - 0.02) < 1e-12)
        lid.advance(to: 3600, dt: 3600)        // a frame after a long gap (sleep) counts at most 0.1 s
        #expect(abs((lid.silence ?? 0) - 0.12) < 1e-12)
        lid.receive(angle: 109)
        #expect(lid.silence == 0)
        lid.advance(to: 3600.01, dt: 0.01)
        lid.resetSilence()
        #expect(lid.silence == 0)
    }
}
