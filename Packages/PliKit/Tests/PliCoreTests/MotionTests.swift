import Testing
@testable import PliCore

@Suite struct MotionTests {
    // MARK: AngleFollower

    @Test func followerStartsAtTheFirstSample() {
        var f = AngleFollower(timeConstant: 0.045)
        #expect(f.value == nil)
        #expect(f.advance(toward: 100, dt: 1.0 / 120) == 100)
    }

    @Test func followerEasesAndConverges() {
        var f = AngleFollower(timeConstant: 0.045)
        f.snap(to: 100)
        let first = f.advance(toward: 99, dt: 1.0 / 120)
        #expect(first < 100 && first > 99)
        for _ in 0..<120 { f.advance(toward: 99, dt: 1.0 / 120) }
        #expect(f.value == 99)
    }

    @Test func zeroTimeConstantIsRaw() {
        var f = AngleFollower(timeConstant: 0)
        f.snap(to: 100)
        #expect(f.advance(toward: 50, dt: 1.0 / 120) == 50)
    }

    @Test func hugeFrameGapsAreBounded() {
        var f = AngleFollower(timeConstant: 0.045)
        f.snap(to: 100)
        let v = f.advance(toward: 0, dt: 30)   // e.g. after sleep: dt is capped at 0.1 s
        #expect(v > 0)
    }

    // MARK: RestTracker

    private func feed(_ tracker: inout RestTracker, from start: Double, seconds: Double, angle: (Double) -> Double) -> Double {
        var t = start
        var rest = 0.0
        while t < start + seconds {
            rest = tracker.update(angle: angle(t), at: t)
            t += 1.0 / 120
        }
        return rest
    }

    @Test func restRisesImmediately() {
        var r = RestTracker(settleSeconds: 0.8, fullFoldAngle: 20)
        #expect(r.update(angle: 100, at: 0) == 100)
        #expect(r.update(angle: 115, at: 0.01) == 115)
    }

    @Test func parkedLidIsAdoptedAfterSettling() {
        var r = RestTracker(settleSeconds: 0.8, fullFoldAngle: 20)
        _ = r.update(angle: 110, at: 0)
        let early = feed(&r, from: 0.01, seconds: 0.5) { _ in 60 }
        #expect(early == 110)
        let late = feed(&r, from: 0.51, seconds: 3) { _ in 60 }
        #expect(abs(late - 60) < 1)
    }

    @Test func jitterDoesNotPreventAdoption() {
        var r = RestTracker(settleSeconds: 0.8, fullFoldAngle: 20)
        _ = r.update(angle: 110, at: 0)
        let rest = feed(&r, from: 0.01, seconds: 4) { t in Int(t * 30) % 2 == 0 ? 60 : 61 }
        #expect(rest < 62)
    }

    @Test func slowContinuousCloseIsNotAdopted() {
        var r = RestTracker(settleSeconds: 0.8, fullFoldAngle: 20)
        _ = r.update(angle: 110, at: 0)
        // 10°/s for 6 s: never still, so the rest stays where the gesture began
        let rest = feed(&r, from: 0.01, seconds: 6) { t in 110 - 10 * t }
        #expect(rest == 110)
    }

    @Test func nearlyClosedLidStaysFolded() {
        var r = RestTracker(settleSeconds: 0.8, fullFoldAngle: 20)
        _ = r.update(angle: 110, at: 0)
        let rest = feed(&r, from: 0.01, seconds: 4) { _ in 12 }
        #expect(rest == 110)
    }

    // MARK: FoldMapper

    private let mapper = FoldMapper(startAngle: 90, deadZone: 6, fullFoldAngle: 20, curve: .linear)

    @Test func effectStartUsesTheLowerOfStartAngleAndThreshold() {
        #expect(mapper.effectStart(rest: 110) == 90)   // start angle wins
        #expect(mapper.effectStart(rest: 80) == 74)    // threshold under rest wins
        #expect(mapper.effectStart(rest: 33) == 30)    // very low rest: F + 10
        #expect(mapper.effectStart(rest: 25) == 25)    // rest below F + 10: starts at rest
    }

    @Test func progressIsLinearBetweenStartAndFull() {
        #expect(mapper.progress(angle: 110, rest: 110) == 0)
        #expect(mapper.progress(angle: 90, rest: 110) == 0)
        #expect(abs(mapper.progress(angle: 55, rest: 110) - 0.5) < 1e-12)
        #expect(mapper.progress(angle: 20, rest: 110) == 1)
        #expect(mapper.progress(angle: 3, rest: 110) == 1)
    }

    @Test func wideOpenThenUsualAngleNeverFrosts() {
        #expect(mapper.progress(angle: 100, rest: 130) == 0)
        #expect(mapper.progress(angle: 95, rest: 130) == 0)
    }

    @Test func everydayAdjustmentsNeverFrost() {
        // Lowering the lid by 15° from any usual rest position stays above the start angle.
        for rest in stride(from: 105.0, through: 130, by: 5) {
            #expect(mapper.progress(angle: rest - 15, rest: rest) == 0)
        }
    }

    @Test func degenerateBandIsAStep() {
        #expect(mapper.progress(angle: 20.5, rest: 20.5) == 0)
        #expect(mapper.progress(angle: 20, rest: 20.5) == 1)
    }

    @Test func preArmIsJustAboveTheStartButAlwaysBelowRest() {
        #expect(mapper.preArmAngle(rest: 110) == 98)    // S + 8
        #expect(mapper.preArmAngle(rest: 80) == 78)     // R − 2
    }
}
