import Foundation

/// The conductor (spec 6.5): a pure, deterministic state machine. Events in, commands out.
public struct FoldDirector: Sendable {
    public static let disarmMargin = 1.0
    public static let captureTimeout = 0.25
    public static let revealCaptureTimeout = 0.4
    public static let zeroHold = 0.15
    public static let staleSampleLimit = 0.5
    public static let sequenceCap = 6.0
    public static let lockTimeout = 2.0
    public static let demoCancelDegrees = 3.0
    public static let lockSurfaceFade = 0.25
    public static let failFade = 0.3
    public static let snapshotRelease = 1.0
    public static let reduceMotionFactor = 0.6
    /// A capture that has not landed after this long is considered lost.
    public static let captureLostAfter = 1.0

    /// When a new lid gesture may start.
    enum ArmGate: Sendable, Equatable {
        /// Arm as soon as the lid goes below the pre-arm angle.
        case open
        /// A gesture just ended with the lid still low: arm again only for a real close (below the effect start).
        case waitForLidBelowStart
        /// A capture failed: nothing until the lid comes back up.
        case waitForLidAboveArm
    }

    /// Whether sensor silence counts (spec 11: a gesture without a sample for 0.5 s fades out). It does not
    /// from `willSleep` until the first sample after `didWake`: the sensor may be silent across sleep, while
    /// stall ticks run before the wake is handled, and while it reopens after the wake (spec 10.4).
    enum SensorWatch: Sendable, Equatable {
        case watching
        /// Between `willSleep` and `didWake`.
        case asleep
        /// From `didWake` to the first sample; the wake phases are bounded by the cap or a capture timeout.
        case waitingForSample
    }

    public private(set) var phase: DirectorPhase
    public private(set) var settings: PliSettings
    public private(set) var capabilities: Capabilities
    public private(set) var lid: LidModel

    var armGate: ArmGate = .open
    var sensorWatch: SensorWatch = .watching
    private var lastTick: Double?
    private var zeroSince: Double?
    private var sequenceStart: Double?
    private var desktopVisible = false
    private var lockVisible = false
    private var cursorHidden = false
    private var lockPolling = false
    /// When the capture still on its way was requested; one capture in flight at a time.
    private var captureRequestedAt: Double?
    /// True from the moment a capture is accepted until its release is announced: the picture stays in
    /// memory whether the overlay ever showed it or not, so every exit to rest must release it (spec 10.9).
    private var holdsSnapshot = false
    /// Frame time since `willSleep` without a `didWake`: frames only run while the Mac is awake.
    private var framesWhileAsleep = 0.0

    public init(settings: PliSettings = .default, capabilities: Capabilities = Capabilities()) {
        self.settings = settings
        self.capabilities = capabilities
        self.lid = LidModel(motion: settings.motion)
        self.phase = settings.general.enabled ? .idle : .inactive
    }

    /// True while the runtime should send a `.tick` every display frame.
    public var wantsFrames: Bool {
        switch phase {
        case .inactive, .idle, .awaitingUnlock: return false
        default: return true
        }
    }

    public var isDesktopVisible: Bool { desktopVisible }
    public var isLockSurfaceVisible: Bool { lockVisible }
    /// True from `.willSleep` until `.didWake` (or until the cap says the wake went unnoticed): a fold held at
    /// `p = 1` meanwhile is justified whatever the lid does.
    public var isWaitingForWake: Bool { sensorWatch == .asleep }

    /// Handles one event and returns what the runtime must do, in order.
    ///
    /// `now` is the host's monotonic time in seconds, from any origin. Whether it keeps running during sleep
    /// does not matter: sensor silence is counted in frame time (each tick's step, at most 0.1 s) and does not
    /// count from `.willSleep` to the first sample after `.didWake`, a fold holds at p = 1 from `.willSleep` to
    /// `.didWake`, and every wake phase is bounded by a capture timeout or by the 6 s cap started at the wake.
    public mutating func handle(_ event: DirectorEvent, at now: Double) -> [DirectorCommand] {
        var out: [DirectorCommand] = []
        switch event {
        case .settingsChanged(let new):
            applySettings(new, now: now, into: &out)
        case .capabilitiesChanged(let new):
            applyCapabilities(new, now: now, into: &out)
        case .angle(let value):
            lid.receive(angle: value)
            if sensorWatch == .waitingForSample { sensorResumed() }
            if phase != .inactive { onAngle(value, now: now, into: &out) }
        case .tick:
            if phase != .inactive { onTick(now: now, into: &out) }
        case .captureReady:
            if phase == .inactive { out.append(.releaseSnapshot(after: 0)) } else { onCaptureReady(now: now, into: &out) }
        case .captureFailed:
            if phase != .inactive { onCaptureFailed(now: now, into: &out) }
        case .willSleep:
            if phase != .inactive { onWillSleep(now: now, into: &out) }
            sensorWatch = .asleep
            framesWhileAsleep = 0
        case .didWake(let locked):
            sensorWatch = .waitingForSample
            lid.resetSilence()
            if phase != .inactive { onDidWake(locked: locked, now: now, into: &out) }
        case .screenLocked:
            if phase != .inactive { onScreenLocked(now: now, into: &out) }
        case .screenUnlocked:
            if phase != .inactive { onUnlocked(now: now, into: &out) }
        case .lockStatePolled(let locked):
            if phase != .inactive, !locked { onUnlocked(now: now, into: &out) }
        case .demoRequested:
            if phase != .inactive { onDemoRequested(now: now, into: &out) }
        case .lockRequested:
            if phase != .inactive { onLockRequested(now: now, into: &out) }
        }
        return out
    }

    // MARK: - Conditions

    private var lidFeaturesOn: Bool {
        settings.triggers.lidClose && capabilities.hasLidSensor && capabilities.builtInDisplayAvailable
    }

    private var usesCapture: Bool {
        capabilities.screenCaptureAllowed && settings.general.rendering == .automatic
    }

    private func scaled(_ seconds: Double) -> Double {
        capabilities.reduceMotion && settings.general.followReduceMotion ? seconds * Self.reduceMotionFactor : seconds
    }

    // MARK: - Lid gesture

    private mutating func onAngle(_ value: Double, now: Double, into out: inout [DirectorCommand]) {
        switch phase {
        case .idle:
            lid.settleIdle(at: now)
            guard lidFeaturesOn, let angle = lid.angle, let rest = lid.rest, let preArm = lid.preArmAngle else { return }
            switch armGate {
            case .open:
                if angle < preArm { beginLidGesture(now: now, into: &out) }
            case .waitForLidBelowStart:
                if angle >= preArm + Self.disarmMargin {
                    armGate = .open
                } else if angle < lid.mapper.effectStart(rest: rest) {
                    armGate = .open
                    beginLidGesture(now: now, into: &out)
                }
            case .waitForLidAboveArm:
                if angle >= preArm + Self.disarmMargin { armGate = .open }
            }
        case .demo(_, let startAngle?, _):
            if abs(value - startAngle) > Self.demoCancelDegrees { goIdle(fade: 0, into: &out) }
        case .awaitingUnlock:
            lid.settleIdle(at: now)   // no frames while waiting: keep the lid model current, as in idle
        default:
            break
        }
    }

    private mutating func beginLidGesture(now: Double, into out: inout [DirectorCommand]) {
        zeroSince = nil
        lastTick = now
        sensorWatch = .watching   // a fresh sample started this gesture, even if a wake went unnoticed
        if usesCapture {
            phase = .arming(since: now, afterWake: false)
            requestCapture(now: now, into: &out)
        } else {
            phase = .folding
        }
    }

    private mutating func onTick(now: Double, into out: inout [DirectorCommand]) {
        let dt = lastTick.map { (now - $0).clamped(to: 0...0.1) } ?? 0
        lastTick = now
        lid.advance(to: now, dt: dt)
        if let start = sequenceStart, now - start > Self.sequenceCap {
            goIdle(fade: Self.failFade, into: &out)
            return
        }
        if sensorWatch == .asleep {
            framesWhileAsleep += dt
            if framesWhileAsleep > Self.sequenceCap { missedWake(into: &out) }
        }
        switch phase {
        case .inactive, .idle, .awaitingUnlock:
            break
        case .arming(let since, let afterWake):
            tickArming(since: since, afterWake: afterWake, now: now, into: &out)
        case .folding, .folded:
            // Folded for sleep: p stays 1 until the wake rules apply, whatever the lid does meanwhile.
            if sensorWatch != .asleep { followLid(now: now, into: &out) }
        case .lockUnfolding(let animation):
            tickLockUnfolding(animation, now: now, into: &out)
        case .revealing(let requestedAt, let animation):
            tickRevealing(requestedAt: requestedAt, animation: animation, now: now, into: &out)
        case .demo(let requestedAt, _, let startedAt):
            tickDemo(requestedAt: requestedAt, startedAt: startedAt, now: now, into: &out)
        case .lockFolding(let requestedAt, let fold, let lockIssuedAt):
            tickLockFolding(requestedAt: requestedAt, fold: fold, lockIssuedAt: lockIssuedAt, now: now, into: &out)
        }
    }

    private mutating func tickArming(since: Double, afterWake: Bool, now: Double, into out: inout [DirectorCommand]) {
        if !afterWake, let angle = lid.angle, let preArm = lid.preArmAngle, angle >= preArm + Self.disarmMargin {
            // Do not release: the in-flight capture (tracked by captureRequestedAt) may still be
            // reused by a gesture that starts again before it is considered lost.
            phase = .idle
            return
        }
        guard now - since > Self.captureTimeout else { return }
        if afterWake {
            goIdle(fade: Self.failFade, into: &out)
        } else {
            // Do not release: the in-flight capture (tracked by captureRequestedAt) may still be
            // reused by a gesture that starts again before it is considered lost.
            phase = .idle
            armGate = .waitForLidAboveArm
        }
    }

    private mutating func followLid(now: Double, into out: inout [DirectorCommand]) {
        if sensorWatch == .watching, let silence = lid.silence, silence > Self.staleSampleLimit {
            goIdle(fade: Self.failFade, into: &out)
            return
        }
        let p = lid.progress
        if p > 0 { showDesktop(into: &out) }
        render(.desktop, progress: p, into: &out)
        phase = p >= 0.999 ? .folded : .folding
        if holdsZero(p, now: now) { goIdle(fade: 0, into: &out) }
    }

    private mutating func holdsZero(_ p: Double, now: Double) -> Bool {
        guard p <= 0 else {
            zeroSince = nil
            return false
        }
        guard let since = zeroSince else {
            zeroSince = now
            return false
        }
        return now - since >= Self.zeroHold
    }

    private mutating func onCaptureReady(now: Double, into out: inout [DirectorCommand]) {
        captureRequestedAt = nil
        switch phase {
        case .arming(_, false):
            holdsSnapshot = true
            phase = .folding
            zeroSince = nil
            followLid(now: now, into: &out)
        case .arming(_, true), .revealing(_, nil):
            holdsSnapshot = true
            startReveal(now: now, into: &out)
        case .demo(_, _, nil):
            holdsSnapshot = true
            startDemo(now: now, into: &out)
        case .lockFolding(_, nil, nil):
            holdsSnapshot = true
            startLockFold(now: now, into: &out)
        default:
            out.append(.releaseSnapshot(after: 0))
        }
    }

    private mutating func onCaptureFailed(now: Double, into out: inout [DirectorCommand]) {
        captureRequestedAt = nil
        switch phase {
        case .arming(_, false):
            phase = .idle
            armGate = .waitForLidAboveArm
        case .arming(_, true), .revealing(_, nil):
            goIdle(fade: Self.failFade, into: &out)
        case .demo(_, _, nil):
            phase = .idle
        case .lockFolding(_, nil, nil):
            phase = .idle
            out.append(.lockNow)
        default:
            break
        }
    }

    // MARK: - Sleep, wake, lock

    private mutating func onWillSleep(now: Double, into out: inout [DirectorCommand]) {
        switch phase {
        case .folding where desktopVisible, .folded, .arming, .demo, .revealing, .lockFolding, .lockUnfolding:
            foldForSleep(into: &out)
        case .awaitingUnlock where lid.isLowered:
            foldForSleep(into: &out)
        case .idle, .awaitingUnlock, .inactive:
            break
        case .folding:
            goIdle(fade: 0, into: &out)   // the lid only neared the start: nothing was shown
        }
    }

    /// Sleep during a gesture or a timed sequence: everything waits at `p = 1`, then the wake rules apply
    /// (spec 11). The lock surface is prepared for a locked wake.
    private mutating func foldForSleep(into out: inout [DirectorCommand]) {
        phase = .folded
        zeroSince = nil
        sequenceStart = nil
        setLockPolling(false, into: &out)
        render(.desktop, progress: 1, into: &out)
        if settings.triggers.unfoldOnLockScreen, capabilities.lockScreenSurfaceAvailable {
            if !lockVisible { out.append(.loadWallpaper) }
            showLock(into: &out)
            render(.lockScreen, progress: 1, into: &out)
        }
    }

    private mutating func onDidWake(locked: Bool, now: Double, into out: inout [DirectorCommand]) {
        guard phase == .folded else { return }
        lastTick = now
        zeroSince = nil
        if locked {
            restoreCursor(into: &out)
            if settings.triggers.onUnlock == .never { hideDesktop(fade: 0, into: &out) }
            if lockVisible, lidFeaturesOn {
                phase = .lockUnfolding(nil)
                sequenceStart = now
                setLockPolling(true, into: &out)
            } else {
                hideLock(fade: 0, into: &out)
                if desktopVisible {
                    phase = .awaitingUnlock
                    setLockPolling(true, into: &out)
                } else {
                    goIdle(fade: 0, into: &out)
                }
            }
        } else {
            hideLock(fade: 0, into: &out)
            if usesCapture {
                phase = .arming(since: now, afterWake: true)
                requestCapture(now: now, into: &out)
            } else {
                startReveal(now: now, into: &out)
            }
        }
    }

    /// Frames have run for the cap since `willSleep` without a `didWake`: the Mac is awake and the wake went
    /// unnoticed. The fold follows the lid again, or ends if there is nothing to unfold on the desktop.
    private mutating func missedWake(into out: inout [DirectorCommand]) {
        sensorWatch = .watching
        if phase == .folded, !desktopVisible { goIdle(fade: Self.failFade, into: &out) }
    }

    /// The first sample after a wake: silence counts again, and a fold that follows the lid is no longer capped.
    private mutating func sensorResumed() {
        sensorWatch = .watching
        if phase == .folding || phase == .folded { sequenceStart = nil }
    }

    private mutating func onScreenLocked(now: Double, into out: inout [DirectorCommand]) {
        switch phase {
        case .idle:
            guard settings.triggers.onUnlock == .always else { return }
            showDesktop(hidingCursor: false, into: &out)
            render(.desktop, progress: 1, into: &out)
            phase = .awaitingUnlock
            setLockPolling(true, into: &out)
        case .lockFolding:
            render(.desktop, progress: 1, into: &out)
            restoreCursor(into: &out)
            setLockPolling(true, into: &out)
            if settings.triggers.unfoldOnLockScreen, capabilities.lockScreenSurfaceAvailable {
                showLock(into: &out)
                render(.lockScreen, progress: 1, into: &out)
                phase = .lockUnfolding(TimedAnimation(.unfold, start: now, duration: scaled(settings.motion.lockScreenUnfoldSeconds)))
                sequenceStart = now
            } else {
                phase = .awaitingUnlock
                sequenceStart = nil
            }
        case .demo, .revealing, .arming:
            goIdle(fade: 0, into: &out)
        default:
            break
        }
    }

    private mutating func onUnlocked(now: Double, into out: inout [DirectorCommand]) {
        switch phase {
        case .lockUnfolding, .awaitingUnlock:
            hideLock(fade: 0, into: &out)
            setLockPolling(false, into: &out)
            guard desktopVisible else {
                goIdle(fade: 0, into: &out)
                return
            }
            if usesCapture {
                phase = .revealing(requestedAt: now, animation: nil)
                sequenceStart = now
                requestCapture(now: now, into: &out)
            } else {
                startReveal(now: now, into: &out)
            }
        default:
            break
        }
    }

    private mutating func tickLockUnfolding(_ animation: TimedAnimation?, now: Double, into out: inout [DirectorCommand]) {
        if let animation {
            render(.lockScreen, progress: animation.progress(at: now), into: &out)
            if animation.isFinished(at: now) { finishLockUnfold(into: &out) }
        } else {
            if sensorWatch == .watching, let silence = lid.silence, silence > Self.staleSampleLimit {
                finishLockUnfold(into: &out)   // the sensor stopped after the wake: show the real lock screen
                return
            }
            let p = lid.progress
            render(.lockScreen, progress: p, into: &out)
            if holdsZero(p, now: now) { finishLockUnfold(into: &out) }
        }
    }

    private mutating func tickRevealing(requestedAt: Double, animation: TimedAnimation?, now: Double, into out: inout [DirectorCommand]) {
        guard let animation else {
            if now - requestedAt > Self.revealCaptureTimeout { goIdle(fade: Self.failFade, into: &out) }
            return
        }
        render(.desktop, progress: animation.progress(at: now), into: &out)
        if animation.isFinished(at: now) { goIdle(fade: 0, into: &out) }
    }

    /// After unlock or wake, with a fresh capture (or in Basic mode): follow the lid if it is still low,
    /// otherwise play the timed reveal.
    private mutating func startReveal(now: Double, into out: inout [DirectorCommand]) {
        zeroSince = nil
        if lidFeaturesOn, lid.isLowered {
            phase = .folding
            // Right after a wake the sensor may not have spoken yet: until it does, the cap bounds the fold.
            sequenceStart = sensorWatch == .watching ? nil : now
            followLid(now: now, into: &out)
        } else {
            let animation = TimedAnimation(.unfold, start: now, duration: scaled(settings.motion.unlockRevealSeconds))
            phase = .revealing(requestedAt: now, animation: animation)
            sequenceStart = now
            showDesktop(into: &out)
            render(.desktop, progress: 1, into: &out)
        }
    }

    private mutating func finishLockUnfold(into out: inout [DirectorCommand]) {
        hideLock(fade: Self.lockSurfaceFade, into: &out)
        zeroSince = nil
        sequenceStart = nil
        if desktopVisible {
            phase = .awaitingUnlock
            setLockPolling(true, into: &out)
        } else {
            goIdle(fade: 0, into: &out)
        }
    }

    // MARK: - Demo and animated lock

    private mutating func onDemoRequested(now: Double, into out: inout [DirectorCommand]) {
        guard phase == .idle, settings.triggers.demoEnabled else { return }
        zeroSince = nil
        lastTick = now
        if usesCapture {
            phase = .demo(requestedAt: now, startAngle: nil, startedAt: nil)
            requestCapture(now: now, into: &out)
        } else {
            startDemo(now: now, into: &out)
        }
    }

    private mutating func startDemo(now: Double, into out: inout [DirectorCommand]) {
        phase = .demo(requestedAt: now, startAngle: lid.rawAngle, startedAt: now)
        sequenceStart = now
        showDesktop(into: &out)
        render(.desktop, progress: 0, into: &out)
    }

    private mutating func tickDemo(requestedAt: Double, startedAt: Double?, now: Double, into out: inout [DirectorCommand]) {
        guard let startedAt else {
            if now - requestedAt > Self.captureTimeout { goIdle(fade: 0, into: &out) }
            return
        }
        let fold = scaled(settings.motion.demoFoldSeconds)
        let hold = scaled(settings.motion.demoHoldSeconds)
        let unfold = scaled(settings.motion.demoUnfoldSeconds)
        let t = now - startedAt
        let p: Double
        if t < fold {
            p = TimedAnimation(.fold, start: startedAt, duration: fold).progress(at: now)
        } else if t < fold + hold {
            p = 1
        } else {
            p = TimedAnimation(.unfold, start: startedAt + fold + hold, duration: unfold).progress(at: now)
        }
        render(.desktop, progress: p, into: &out)
        if t >= fold + hold + unfold { goIdle(fade: 0, into: &out) }
    }

    private mutating func onLockRequested(now: Double, into out: inout [DirectorCommand]) {
        guard phase == .idle, settings.triggers.animatedLockEnabled, capabilities.canLockNow else { return }
        zeroSince = nil
        lastTick = now
        if settings.triggers.unfoldOnLockScreen, capabilities.lockScreenSurfaceAvailable {
            out.append(.loadWallpaper)
        }
        if usesCapture {
            phase = .lockFolding(requestedAt: now, fold: nil, lockIssuedAt: nil)
            requestCapture(now: now, into: &out)
        } else {
            startLockFold(now: now, into: &out)
        }
    }

    private mutating func startLockFold(now: Double, into out: inout [DirectorCommand]) {
        let fold = TimedAnimation(.fold, start: now, duration: scaled(settings.motion.demoFoldSeconds))
        phase = .lockFolding(requestedAt: now, fold: fold, lockIssuedAt: nil)
        sequenceStart = now
        showDesktop(into: &out)
        render(.desktop, progress: 0, into: &out)
    }

    private mutating func tickLockFolding(requestedAt: Double, fold: TimedAnimation?, lockIssuedAt: Double?, now: Double, into out: inout [DirectorCommand]) {
        if let lockIssuedAt {
            if now - lockIssuedAt > Self.lockTimeout { goIdle(fade: Self.failFade, into: &out) }
            return
        }
        guard let fold else {
            if now - requestedAt > Self.captureTimeout {
                phase = .idle            // no capture: lock anyway, without the fold
                out.append(.lockNow)
            }
            return
        }
        render(.desktop, progress: fold.progress(at: now), into: &out)
        if fold.isFinished(at: now) {
            phase = .lockFolding(requestedAt: requestedAt, fold: fold, lockIssuedAt: now)
            out.append(.lockNow)
        }
    }

    // MARK: - Settings and capabilities

    private mutating func applySettings(_ new: PliSettings, now: Double, into out: inout [DirectorCommand]) {
        settings = new
        lid.apply(new.motion)
        if !new.general.enabled {
            if phase != .inactive { goIdle(fade: 0, into: &out) }
            phase = .inactive
            return
        }
        if phase == .inactive {
            phase = .idle
            armGate = .open
            return
        }
        if !new.triggers.lidClose {
            switch phase {
            case .arming(_, false), .folding, .folded: goIdle(fade: 0, into: &out)
            default: break
            }
        }
    }

    private mutating func applyCapabilities(_ new: Capabilities, now: Double, into out: inout [DirectorCommand]) {
        let old = capabilities
        capabilities = new
        guard phase != .inactive else { return }
        if old.builtInDisplayAvailable != new.builtInDisplayAvailable {
            if phase != .idle { goIdle(fade: 0, into: &out) }
            lid.resetRest()
            armGate = .open
        } else if old.hasLidSensor, !new.hasLidSensor {
            switch phase {
            case .arming, .folding, .folded, .lockUnfolding(nil): goIdle(fade: 0, into: &out)
            default: break
            }
        }
    }

    // MARK: - Surfaces

    /// Asks for a desktop capture unless one is already on its way (and not yet considered lost):
    /// the pending one will serve the current request, so a late duplicate can never race it.
    private mutating func requestCapture(now: Double, into out: inout [DirectorCommand]) {
        if let requestedAt = captureRequestedAt, now - requestedAt < Self.captureLostAfter { return }
        captureRequestedAt = now
        out.append(.captureDesktop)
    }

    /// A frame for a surface on screen; a hidden surface never gets one.
    private func render(_ surface: Surface, progress: Double, into out: inout [DirectorCommand]) {
        let visible = surface == .desktop ? desktopVisible : lockVisible
        if visible { out.append(.render(surface, progress: progress)) }
    }

    private mutating func showDesktop(hidingCursor: Bool = true, into out: inout [DirectorCommand]) {
        if !desktopVisible {
            desktopVisible = true
            out.append(.show(.desktop))
        }
        if hidingCursor, settings.general.hideCursor, !cursorHidden {
            cursorHidden = true
            out.append(.setCursorHidden(true))
        }
    }

    /// Hides the overlay and releases the accepted capture, shown or not (a near miss holds one too).
    private mutating func hideDesktop(fade: Double, into out: inout [DirectorCommand]) {
        if desktopVisible {
            desktopVisible = false
            out.append(.hide(.desktop, fade: fade))
        }
        if holdsSnapshot {
            holdsSnapshot = false
            out.append(.releaseSnapshot(after: Self.snapshotRelease))
        }
        restoreCursor(into: &out)
    }

    private mutating func restoreCursor(into out: inout [DirectorCommand]) {
        if cursorHidden {
            cursorHidden = false
            out.append(.setCursorHidden(false))
        }
    }

    private mutating func showLock(into out: inout [DirectorCommand]) {
        if !lockVisible {
            lockVisible = true
            out.append(.show(.lockScreen))
        }
    }

    private mutating func hideLock(fade: Double, into out: inout [DirectorCommand]) {
        if lockVisible {
            lockVisible = false
            out.append(.hide(.lockScreen, fade: fade))
        }
    }

    private mutating func setLockPolling(_ on: Bool, into out: inout [DirectorCommand]) {
        guard on != lockPolling else { return }
        lockPolling = on
        out.append(on ? .startLockPolling : .stopLockPolling)
    }

    private mutating func goIdle(fade: Double, into out: inout [DirectorCommand]) {
        hideLock(fade: fade, into: &out)
        hideDesktop(fade: fade, into: &out)
        setLockPolling(false, into: &out)
        zeroSince = nil
        sequenceStart = nil
        if armGate == .open, let angle = lid.angle, let preArm = lid.preArmAngle, angle < preArm + Self.disarmMargin {
            armGate = .waitForLidBelowStart
        }
        phase = .idle
    }
}
