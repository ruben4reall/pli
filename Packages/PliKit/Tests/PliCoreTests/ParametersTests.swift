import Foundation
import Testing
@testable import PliCore

@Suite struct ParametersTests {
    @Test func duoMatchesSpecTable() {
        let g = GlassParameters.duo
        #expect(g.frost == 0.09 && g.grain == 0.30 && g.darkening == 0.05)
        #expect(g.tintColor == .white && g.tintAmount == 0 && g.saturation == 1)
        #expect(g.edgeSheen == 0 && g.prism == 0)
        #expect(g.eyeDistanceMM == 450 && g.eyeHeight == 0.30 && g.spatialAnchor == 1)
        #expect(g.maxTiltDegrees == 50 && g.finalBlackout == 0.12 && g.edgeSoftnessMM == 3)
        let m = MotionParameters.duo
        #expect(m.startAngle == 90 && m.deadZoneDegrees == 6 && m.fullFoldAngle == 20)
        #expect(m.curve == .linear && m.smoothingMS == 45 && m.settleSeconds == 0.8)
        #expect(m.unlockRevealSeconds == 0.9 && m.lockScreenUnfoldSeconds == 0.8)
        #expect(m.demoFoldSeconds == 0.8 && m.demoHoldSeconds == 0.35 && m.demoUnfoldSeconds == 1.0)
    }

    @Test func rangesMatchSpecTable() {
        #expect(GlassParameters.Range.frost == 0...0.25)
        #expect(GlassParameters.Range.eyeDistanceMM == 250...900)
        #expect(GlassParameters.Range.maxTiltDegrees == 20...75)
        #expect(GlassParameters.Range.finalBlackout == 0...0.3)
        #expect(MotionParameters.Range.startAngle == 40...130)
        #expect(MotionParameters.Range.demoFoldSeconds == 0.3...2)
        #expect(MotionParameters.Range.demoHoldSeconds == 0...1)
        #expect(MotionParameters.Range.demoUnfoldSeconds == 0.3...2)
    }

    @Test func roundTripsThroughJSON() throws {
        var g = GlassParameters.duo
        g.tintColor = .night
        g.tintAmount = 0.35
        let data = try JSONEncoder().encode(g)
        #expect(try JSONDecoder().decode(GlassParameters.self, from: data) == g)
        var m = MotionParameters.duo
        m.curve = .fastStart
        let mData = try JSONEncoder().encode(m)
        #expect(try JSONDecoder().decode(MotionParameters.self, from: mData) == m)
    }

    @Test func handEditedValuesAreClampedAndDefaulted() throws {
        let json = #"{"frost": 9, "grain": "lots", "eyeDistanceMM": 10, "tintColor": {"red": 2, "green": -1}, "unknown": true}"#
        let g = try JSONDecoder().decode(GlassParameters.self, from: Data(json.utf8))
        #expect(g.frost == 0.25)
        #expect(g.grain == GlassParameters.duo.grain)
        #expect(g.eyeDistanceMM == 250)
        #expect(g.tintColor == RGBColor(red: 1, green: 0, blue: 1))
        #expect(g.maxTiltDegrees == GlassParameters.duo.maxTiltDegrees)
    }

    @Test func unknownCurveFallsBackToDuo() throws {
        let m = try JSONDecoder().decode(MotionParameters.self, from: Data(#"{"curve": "wobbly", "startAngle": 500}"#.utf8))
        #expect(m.curve == .linear)
        #expect(m.startAngle == 130)
    }
}
