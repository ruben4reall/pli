import Testing
@testable import PliCore

/// Drives a FoldDirector like the runtime does: frames, sensor samples, captures that land after a delay.
struct DirectorHarness {
    var director: FoldDirector
    var now: Double = 0
    var log: [(time: Double, command: DirectorCommand)] = []
    /// Delay before a requested capture lands; nil means captures never land.
    var captureDelay: Double? = 0.03
    var captureFails = false
    /// Like the app (Plan 2): while no frames run, a sample reaches the director only when the angle changes.
    /// Off: a sample every step, frames or not.
    var idleSamplesOnChangeOnly = false
    private(set) var samplesSent = 0
    private var pendingCaptureAt: Double?

    // The runtime's desktop picture, kept the way Plan 2 keeps it: one slot. A capture the director accepts
    // fills it, replacing (and so freeing) any picture still there; a release empties it. A capture the
    // director answers with an immediate release was refused and never fills it.
    private(set) var acceptedCaptures = 0
    private(set) var releasedSnapshots = 0
    private(set) var replacedSnapshots = 0
    private(set) var releasesWithoutSnapshot = 0
    private var snapshotHeld = false
    /// The surfaces on screen, from the show and hide commands: a render must only ever target one of them.
    private(set) var shown: Set<Surface> = []

    init(settings: PliSettings = .default, capabilities: Capabilities = Capabilities(), rest: Double = 110) {
        director = FoldDirector(settings: settings, capabilities: capabilities)
        send(.angle(rest))
    }

    @discardableResult
    mutating func send(_ event: DirectorEvent) -> [DirectorCommand] {
        let out = director.handle(event, at: now)
        let refused = event == .captureReady && out.contains(.releaseSnapshot(after: 0))
        if event == .captureReady, !refused {
            acceptedCaptures += 1
            if snapshotHeld { replacedSnapshots += 1 }
            snapshotHeld = true
        }
        for command in out {
            log.append((now, command))
            switch command {
            case .show(let surface): shown.insert(surface)
            case .hide(let surface, _): shown.remove(surface)
            case .render(let surface, _): #expect(shown.contains(surface), "render(\(surface)) while it is hidden, at \(now) s")
            default: break
            }
            if command == .captureDesktop, let delay = captureDelay { pendingCaptureAt = now + delay }
            if case .releaseSnapshot(let delay) = command, !(refused && delay == 0) {
                if snapshotHeld {
                    snapshotHeld = false
                    releasedSnapshots += 1
                } else {
                    releasesWithoutSnapshot += 1
                }
            }
        }
        return out
    }

    /// Advances time frame by frame. `lid(t)` gives the lid angle at time t (rounded like the sensor);
    /// nil means the sensor sends nothing.
    mutating func run(for seconds: Double, step: Double = 1.0 / 120, lid: ((Double) -> Double)? = nil) {
        let end = now + seconds
        while now < end - 1e-9 {
            now += step
            if let lid {
                let angle = lid(now).rounded()
                let skip = idleSamplesOnChangeOnly && !director.wantsFrames && angle == director.lid.rawAngle
                if !skip {
                    samplesSent += 1
                    send(.angle(angle))
                }
            }
            if let at = pendingCaptureAt, now >= at {
                pendingCaptureAt = nil
                send(captureFails ? .captureFailed : .captureReady)
            }
            if director.wantsFrames { send(.tick) }
        }
    }

    /// Moves the lid linearly from its current raw angle to `target` over `seconds`, then keeps it there for `hold`.
    mutating func moveLid(to target: Double, over seconds: Double, hold: Double = 0) {
        let from = director.lid.rawAngle ?? target
        let start = now
        run(for: seconds) { t in from + (target - from) * min((t - start) / seconds, 1) }
        if hold > 0 { run(for: hold) { _ in target } }
    }

    func commands(since time: Double = -1) -> [DirectorCommand] {
        log.filter { $0.time > time }.map(\.command)
    }

    func count(_ command: DirectorCommand) -> Int { log.filter { $0.command == command }.count }

    func renders(_ surface: Surface, since time: Double = -1) -> [Double] {
        log.compactMap { entry in
            guard entry.time > time, case .render(surface, let p) = entry.command else { return nil }
            return p
        }
    }

    /// True once a safeguard faded a surface out (stale samples, a lost capture, a cap).
    var fadedOut: Bool {
        log.contains { if case .hide(_, fade: FoldDirector.failFade) = $0.command { return true } else { return false } }
    }

    /// The delay of every `.releaseSnapshot` sent so far.
    var releases: [Double] {
        log.compactMap { if case .releaseSnapshot(let delay) = $0.command { return delay } else { return nil } }
    }

    var everShown: Set<Surface> {
        Set(log.compactMap { if case .show(let s) = $0.command { return s } else { return nil } })
    }

    /// Closes the lid fully and lets the Mac sleep for `seconds` of host time.
    mutating func closeAndSleep(for seconds: Double = 0) {
        moveLid(to: 0, over: 0.8, hold: 0.2)
        sleep(for: seconds)
    }

    /// The Mac goes to sleep: `.willSleep`, then `seconds` of host time pass without frames or samples.
    mutating func sleep(for seconds: Double) {
        send(.willSleep)
        now += seconds
    }

    /// Sets the lid angle without moving time (e.g. the lid was opened during sleep).
    mutating func setLid(_ angle: Double) { send(.angle(angle)) }

    var lastCursorCommand: Bool? {
        log.last { if case .setCursorHidden = $0.command { return true } else { return false } }
            .flatMap { if case .setCursorHidden(let hidden) = $0.command { return hidden } else { return nil } }
    }

    /// End-of-scenario invariant: every capture the director accepted was released, or replaced by a later
    /// one, and no release came without a picture to free.
    func expectCapturesReleased(sourceLocation: SourceLocation = #_sourceLocation) {
        #expect(acceptedCaptures == releasedSnapshots + replacedSnapshots,
                "accepted \(acceptedCaptures), released \(releasedSnapshots), replaced \(replacedSnapshots)",
                sourceLocation: sourceLocation)
        #expect(releasesWithoutSnapshot == 0, "\(releasesWithoutSnapshot) releases without a picture",
                sourceLocation: sourceLocation)
    }
}
