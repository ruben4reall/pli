import CoreVideo
import Foundation
import Observation
import PliCore

/// A picture of the screen for the previews (spec 8.3): the capture when allowed, the wallpaper otherwise. It lives
/// in memory only and is let go when Settings closes (spec 10.9).
public final class PreviewPicture: @unchecked Sendable {
    public enum Kind: Sendable, Equatable {
        case screen
        case wallpaper
    }

    /// Used when the display's size is unknown: the 14-inch MacBook Pro's panel.
    public static let fallbackWidthMM = 302.0

    /// IOSurface-backed BGRA pixels, as `GlassSurfaceView.setSource` takes them.
    public let pixelBuffer: CVPixelBuffer
    public let kind: Kind
    /// Physical width of the display the picture shows: a preview is its miniature, so the blur keeps its millimeters.
    public let displayWidthMM: Double

    public init(pixelBuffer: CVPixelBuffer, kind: Kind, displayWidthMM: Double) {
        self.pixelBuffer = pixelBuffer
        self.kind = kind
        self.displayWidthMM = displayWidthMM > 0 ? displayWidthMM : Self.fallbackWidthMM
    }

    public var width: Int { CVPixelBufferGetWidth(pixelBuffer) }
    public var height: Int { CVPixelBufferGetHeight(pixelBuffer) }
    public var aspectRatio: Double { height > 0 ? Double(width) / Double(height) : 1512.0 / 982.0 }
}

/// What the previews show (spec 8.3): the real lid ("Follow My Lid"), the ghost lid dragged on the protractor, or a
/// timed fold or unfold ("Play Fold", "Play Unfold"). Nothing here moves the real overlay.
@MainActor @Observable
public final class PreviewModel {
    public enum Mode: Equatable, Sendable {
        case followLid
        case ghost
        case fixed(Double)
        case playing(TimedAnimation)
    }

    public private(set) var mode: Mode = .ghost
    public private(set) var ghostAngle: Double
    public private(set) var picture: PreviewPicture?
    @ObservationIgnored private var playback = 0

    public init(ghostAngle: Double = PreviewModel.defaultGhostAngle(motion: .duo, rest: FrostCurve.nominalRest)) {
        self.ghostAngle = ghostAngle.clamped(to: ProtractorGeometry.angleRange)
    }

    /// Halfway between where the frost starts and where it is complete: a first look that shows the glass.
    nonisolated public static func defaultGhostAngle(motion: MotionParameters, rest: Double) -> Double {
        let marks = ProtractorMarks(motion: motion, rest: rest)
        return ((marks.start + marks.fullyFrosted) / 2).rounded()
    }

    public var followsLid: Bool { mode == .followLid }

    public var isPlaying: Bool {
        if case .playing = mode { return true }
        return false
    }

    public func setFollowLid(_ on: Bool) {
        if on {
            mode = .followLid
        } else if mode == .followLid {
            mode = .ghost
        }
    }

    /// A drag or the simulated lid slider: the ghost moves and the preview follows it.
    public func setGhost(angle: Double) {
        ghostAngle = angle.clamped(to: ProtractorGeometry.angleRange)
        mode = .ghost
    }

    /// Arrow keys and VoiceOver: whole degrees, 1 at a time (5 with Shift).
    public func nudgeGhost(by delta: Double) {
        setGhost(angle: (ghostAngle + delta).rounded())
    }

    /// Starts a timed fold or unfold with the demo's durations, 40% shorter under Reduce Motion (spec 5.5).
    /// Returns the playback's number and its duration, for `finishPlayback`.
    @discardableResult
    public func play(_ direction: TimedAnimation.Direction, motion: MotionParameters, reduceMotion: Bool,
                     at now: Double) -> (playback: Int, duration: Double) {
        let base = direction == .fold ? motion.demoFoldSeconds : motion.demoUnfoldSeconds
        let duration = reduceMotion ? base * 0.6 : base
        playback += 1
        mode = .playing(TimedAnimation(direction, start: now, duration: duration))
        return (playback, duration)
    }

    /// The end of a timed animation holds its last frame: folded, or open. A newer playback is left alone.
    public func finishPlayback(_ number: Int) {
        guard number == playback, case .playing(let animation) = mode else { return }
        mode = .fixed(animation.direction == .fold ? 1 : 0)
    }

    public func progress(at now: Double, motion: MotionParameters, rest: Double?, lidAngle: Double?) -> Double {
        let rest = rest ?? FrostCurve.nominalRest
        let mapper = FoldMapper(motion: motion)
        switch mode {
        case .followLid: return mapper.progress(angle: lidAngle ?? rest, rest: rest)
        case .ghost: return mapper.progress(angle: ghostAngle, rest: rest)
        case .fixed(let progress): return progress
        case .playing(let animation): return animation.progress(at: now)
        }
    }

    public func setPicture(_ picture: PreviewPicture?) {
        self.picture = picture
    }
}
