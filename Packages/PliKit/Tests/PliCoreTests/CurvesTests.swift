import Testing
@testable import PliCore

@Suite struct CurvesTests {
    @Test(arguments: FoldCurve.allCases)
    func endpointsAreFixed(curve: FoldCurve) {
        #expect(curve.apply(0) == 0)
        #expect(curve.apply(1) == 1)
    }

    @Test(arguments: FoldCurve.allCases)
    func inputIsClamped(curve: FoldCurve) {
        #expect(curve.apply(-0.5) == 0)
        #expect(curve.apply(1.5) == 1)
    }

    @Test(arguments: FoldCurve.allCases)
    func isMonotonic(curve: FoldCurve) {
        var previous = -1.0
        for step in 0...200 {
            let value = curve.apply(Double(step) / 200)
            #expect(value >= previous)
            previous = value
        }
    }

    @Test func shapesDiffer() {
        #expect(FoldCurve.linear.apply(0.25) == 0.25)
        #expect(FoldCurve.fastStart.apply(0.25) > 0.25)
        #expect(FoldCurve.slowStart.apply(0.25) < 0.25)
        #expect(abs(FoldCurve.smooth.apply(0.5) - 0.5) < 1e-12)
    }

    @Test func easingEndpoints() {
        #expect(Easing.inOutCubic(0) == 0)
        #expect(Easing.inOutCubic(1) == 1)
        #expect(abs(Easing.inOutCubic(0.5) - 0.5) < 1e-12)
        #expect(Easing.outCubic(0) == 0)
        #expect(Easing.outCubic(1) == 1)
    }

    @Test func foldGoesFromZeroToOne() {
        let fold = TimedAnimation(.fold, start: 10, duration: 0.8)
        #expect(fold.progress(at: 9) == 0)
        #expect(fold.progress(at: 10) == 0)
        #expect(abs(fold.progress(at: 10.4) - 0.5) < 1e-9)
        #expect(fold.progress(at: 10.8) == 1)
        #expect(fold.progress(at: 20) == 1)
        #expect(!fold.isFinished(at: 10.79))
        #expect(fold.isFinished(at: 10.8))
        #expect(abs(fold.end - 10.8) < 1e-12)
    }

    @Test func unfoldGoesFromOneToZero() {
        let unfold = TimedAnimation(.unfold, start: 0, duration: 1)
        #expect(unfold.progress(at: 0) == 1)
        #expect(unfold.progress(at: 1) == 0)
        #expect(unfold.progress(at: 0.5) < 0.5)   // ease-out: most of the reveal happens early
    }

    @Test func zeroDurationDoesNotDivideByZero() {
        let instant = TimedAnimation(.fold, start: 0, duration: 0)
        #expect(instant.progress(at: 1) == 1)
    }
}
