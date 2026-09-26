import Testing
@testable import PliCore

@Suite struct GlassOpticsTests {
    let geometry = GlassGeometry(width: 1000, height: 600, pixelsPerMM: 5)

    private func optics(_ p: Double, _ tweak: (inout GlassParameters) -> Void = { _ in }) -> DerivedOptics {
        var parameters = GlassParameters.duo
        tweak(&parameters)
        return GlassOptics.derive(progress: p, parameters: parameters, geometry: geometry, reduceMotion: false)
    }

    @Test func zeroProgressIsTheIdentity() {
        let o = optics(0)
        for (x, y) in [(0.5, 0.5), (500.5, 300.5), (999.5, 10.5)] {
            let s = GlassOptics.sample(x: x, y: y, optics: o, geometry: geometry)
            #expect(abs(s.sourceX - x) < 1e-9 && abs(s.sourceY - y) < 1e-9)
            #expect(s.blurRadius == 0 && s.attenuation == 1 && s.coverage == 1 && !s.isBlack)
        }
    }

    @Test func derivedValuesAreInPixels() {
        let o = optics(0.5)
        #expect(abs(o.tiltRadians - 25 * Double.pi / 180) < 1e-12)
        #expect(o.eyeDistancePx == 450 * 5)
        #expect(o.eyeX == 500 && abs(o.eyeY - 180) < 1e-9)
        #expect(o.maxBlurPx == 18 * 5)
        #expect(abs(o.darkeningPerPx - 0.05 / 5) < 1e-12)
        #expect(o.edgeSoftnessPx == 15)
    }

    @Test func theHingeRowStaysSharp() {
        let s = GlassOptics.sample(x: 500.5, y: 599.5, optics: optics(0.8), geometry: geometry)
        #expect(s.blurRadius < 0.1)
        #expect(abs(s.sourceY - 599.5) < 1)
    }

    @Test func blurAndDarknessGrowTowardTheTop() {
        let o = optics(0.6)
        var lastRadius = -1.0
        var lastAttenuation = 2.0
        for y in stride(from: 590.5, through: 10.5, by: -40) {
            let s = GlassOptics.sample(x: 500.5, y: y, optics: o, geometry: geometry)
            #expect(s.blurRadius >= lastRadius)
            #expect(s.attenuation <= lastAttenuation + 1e-12)
            lastRadius = s.blurRadius
            lastAttenuation = s.attenuation
        }
    }

    @Test func theTopSlidesIntoBlack() {
        let s = GlassOptics.sample(x: 500.5, y: 0.5, optics: optics(1), geometry: geometry)
        #expect(s.isBlack || s.coverage < 1 || s.attenuation == 0)
    }

    @Test func noAnchorKeepsThePictureInPlace() {
        let o = optics(0.7) { $0.spatialAnchor = 0 }
        let s = GlassOptics.sample(x: 300.5, y: 200.5, optics: o, geometry: geometry)
        #expect(abs(s.sourceX - 300.5) < 1e-9 && abs(s.sourceY - 200.5) < 1e-9)
        #expect(s.blurRadius > 0)
    }

    @Test func reduceMotionForcesTheAnchorToZero() {
        let o = GlassOptics.derive(progress: 0.5, parameters: .duo, geometry: geometry, reduceMotion: true)
        #expect(o.spatialAnchor == 0)
    }

    @Test func blackoutRampsOverTheLastPart() {
        #expect(GlassOptics.blackout(progress: 0.5, amount: 0.12) == 1)
        #expect(GlassOptics.blackout(progress: 1, amount: 0.12) == 0)
        let mid = GlassOptics.blackout(progress: 0.94, amount: 0.12)
        #expect(mid > 0 && mid < 1)
        #expect(GlassOptics.blackout(progress: 1, amount: 0) == 1)   // no blackout at all
    }

    @Test func blurIsCappedAt18mm() {
        let o = optics(1) { $0.frost = 0.25; $0.maxTiltDegrees = 75 }
        let s = GlassOptics.sample(x: 500.5, y: 50.5, optics: o, geometry: geometry)
        #expect(s.blurRadius <= 18 * 5 + 1e-9)
    }
}
