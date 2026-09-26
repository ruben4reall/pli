import CoreGraphics
import PliCore
import Testing
@testable import PliUI

@Suite struct ProtractorGeometryTests {
    let geometry = ProtractorGeometry(size: CGSize(width: 300, height: 200), inset: 12)

    @Test func anglesRoundTripThroughPoints() {
        for angle in stride(from: 0.0, through: 135, by: 7.5) {
            #expect(abs(geometry.angle(at: geometry.point(angle: angle)) - angle) < 1e-9, "\(angle)")
        }
    }

    @Test func ninetyDegreesStandsUpright() {
        let top = geometry.point(angle: 90)
        #expect(abs(top.x - geometry.hinge.x) < 1e-9 && top.y < geometry.hinge.y)
        let closed = geometry.point(angle: 0)
        #expect(abs(closed.y - geometry.hinge.y) < 1e-9 && closed.x > geometry.hinge.x)
    }

    @Test func pointsOutsideTheRangeAreClamped() {
        let hinge = geometry.hinge
        #expect(geometry.angle(at: CGPoint(x: hinge.x + 50, y: hinge.y + 20)) == 0)
        #expect(geometry.angle(at: CGPoint(x: hinge.x - 50, y: hinge.y + 20)) == 135)
        #expect(geometry.angle(at: CGPoint(x: hinge.x - 50, y: hinge.y - 10)) == 135)
        #expect(geometry.angle(at: hinge) == 0)
    }

    @Test func theMacBookFitsAtEveryAngle() {
        for size in [CGSize(width: 300, height: 200), CGSize(width: 120, height: 90), CGSize(width: 600, height: 160)] {
            let g = ProtractorGeometry(size: size, inset: 10)
            for angle in stride(from: 0.0, through: 135, by: 5) {
                let tip = g.point(angle: angle)
                #expect(tip.x >= 10 - 1e-6 && tip.x <= size.width - 10 + 1e-6 && tip.y >= 10 - 1e-6, "\(size) \(angle)")
            }
            #expect(g.base.maxX <= size.width - 10 + 1e-6 && g.base.maxY <= size.height - 10 + 1e-6)
        }
    }

    /// With room reserved for the marks, a mark at any angle stays inside the frame.
    @Test func marksFitWithTheirOvershoot() {
        let size = CGSize(width: 250, height: 170)
        let g = ProtractorGeometry(size: size, inset: 20, overshoot: 0.12)
        for angle in stride(from: 0.0, through: 135, by: 5) {
            let mark = g.point(angle: angle, distance: g.radius * 1.12)
            #expect(mark.x >= 20 - 1e-6 && mark.x <= size.width - 20 + 1e-6 && mark.y >= 20 - 1e-6, "\(angle)")
        }
    }

    @Test func theFrostedSectorCoversTheAnglesBetweenItsEnds() {
        let path = geometry.sector(from: 20, to: 90, inner: geometry.radius * 0.5, outer: geometry.radius)
        #expect(path.contains(geometry.point(angle: 55, distance: geometry.radius * 0.75)))
        #expect(!path.contains(geometry.point(angle: 110, distance: geometry.radius * 0.75)))
        #expect(!path.contains(geometry.point(angle: 55, distance: geometry.radius * 0.25)))
    }

    @Test func marksFollowTheEngine() {
        let marks = ProtractorMarks(motion: .duo, rest: 110)
        #expect(marks == ProtractorMarks(rest: 110, start: 90, fullyFrosted: 20))
        #expect(ProtractorMarks(motion: .duo, rest: 80).start == 74)
    }
}

@Suite struct FrostCurveTests {
    @Test func theCurveFallsFromFrostedToClear() {
        let points = FrostCurve.points(motion: .duo, rest: 110)
        #expect(points.count == 136)
        #expect(zip(points, points.dropFirst()).allSatisfy { $0.progress >= $1.progress })
        #expect(points.first { $0.angle == 20 }?.progress == 1)
        #expect(points.first { $0.angle == 90 }?.progress == 0)
        #expect(abs((points.first { $0.angle == 55 }?.progress ?? 0) - 0.5) < 1e-9)
    }

    @Test func theCurveShapeFollowsTheSetting() {
        var motion = MotionParameters.duo
        motion.curve = .fastStart
        let fast = FrostCurve.points(motion: motion, rest: 110).first { $0.angle == 72 }!.progress
        let linear = FrostCurve.points(motion: .duo, rest: 110).first { $0.angle == 72 }!.progress
        #expect(fast > linear)
    }
}

@MainActor @Suite struct PreviewModelTests {
    @Test func theFirstLookShowsTheGlassHalfway() {
        #expect(PreviewModel.defaultGhostAngle(motion: .duo, rest: 110) == 55)
        let preview = PreviewModel()
        #expect(preview.mode == .ghost && preview.ghostAngle == 55)
        #expect(abs(preview.progress(at: 0, motion: .duo, rest: 110, lidAngle: 104) - 0.5) < 1e-9)
    }

    @Test func followingTheLidUsesTheRealAngle() {
        let preview = PreviewModel()
        preview.setFollowLid(true)
        #expect(preview.progress(at: 0, motion: .duo, rest: 110, lidAngle: 104) == 0)
        #expect(abs(preview.progress(at: 0, motion: .duo, rest: 110, lidAngle: 55) - 0.5) < 1e-9)
        #expect(preview.progress(at: 0, motion: .duo, rest: nil, lidAngle: nil) == 0)
    }

    @Test func movingTheGhostStopsFollowing() {
        let preview = PreviewModel()
        preview.setFollowLid(true)
        preview.setGhost(angle: 30)
        #expect(!preview.followsLid && preview.ghostAngle == 30)
    }

    @Test func arrowKeysMoveTheGhostInWholeDegreesInsideTheRange() {
        let preview = PreviewModel(ghostAngle: 55)
        preview.nudgeGhost(by: 1)
        #expect(preview.ghostAngle == 56)
        preview.nudgeGhost(by: -5)
        #expect(preview.ghostAngle == 51)
        let open = PreviewModel(ghostAngle: 134)
        open.nudgeGhost(by: 5)
        #expect(open.ghostAngle == 135)
        let closed = PreviewModel(ghostAngle: 0)
        closed.nudgeGhost(by: -1)
        #expect(closed.ghostAngle == 0)
    }

    @Test func playFoldRunsTheDemoFoldThenHoldsFolded() {
        let preview = PreviewModel()
        let run = preview.play(.fold, motion: .duo, reduceMotion: false, at: 100)
        #expect(run.duration == 0.8 && preview.isPlaying)
        #expect(preview.progress(at: 100, motion: .duo, rest: 110, lidAngle: nil) == 0)
        #expect(abs(preview.progress(at: 100.4, motion: .duo, rest: 110, lidAngle: nil) - 0.5) < 1e-9)
        preview.finishPlayback(run.playback)
        #expect(preview.mode == .fixed(1))
    }

    @Test func playUnfoldEndsOpenAndReduceMotionIsShorter() {
        let preview = PreviewModel()
        let run = preview.play(.unfold, motion: .duo, reduceMotion: true, at: 0)
        #expect(abs(run.duration - 0.6) < 1e-9)
        preview.finishPlayback(run.playback)
        #expect(preview.mode == .fixed(0))
    }

    @Test func anOlderPlaybackNeverEndsANewerOne() {
        let preview = PreviewModel()
        let first = preview.play(.fold, motion: .duo, reduceMotion: false, at: 0)
        let second = preview.play(.unfold, motion: .duo, reduceMotion: false, at: 0.5)
        preview.finishPlayback(first.playback)
        #expect(preview.isPlaying)
        preview.finishPlayback(second.playback)
        #expect(preview.mode == .fixed(0))
    }
}
