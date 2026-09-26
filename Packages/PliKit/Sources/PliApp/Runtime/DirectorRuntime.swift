import CoreGraphics
import PliCore
import PliRender
import PliSystem

/// Runs the fold director on the Mac (spec 10.2, 10.3): feeds it sensor samples, frame ticks and system events,
/// carries out its commands on the adapters, owns the frame cadence, and keeps the safeguards of spec 5.6 even
/// when something upstream misbehaves.
@MainActor
public final class DirectorRuntime {
    public struct Adapters {
        public var sensor: any LidSensing
        public var snapshotter: any DesktopCapturing
        public var wallpapers: any WallpaperProviding
        public var surfaces: any SurfacePresenting
        public var cursor: any CursorControlling
        public var locker: any ScreenLocking
        public var lockState: any LockStateReading
        public var clock: any FrameClock
        public var scheduler: any Scheduling
        public var environment: any EnvironmentReading

        public init(sensor: any LidSensing, snapshotter: any DesktopCapturing, wallpapers: any WallpaperProviding,
                    surfaces: any SurfacePresenting, cursor: any CursorControlling, locker: any ScreenLocking,
                    lockState: any LockStateReading, clock: any FrameClock, scheduler: any Scheduling,
                    environment: any EnvironmentReading) {
            self.sensor = sensor
            self.snapshotter = snapshotter
            self.wallpapers = wallpapers
            self.surfaces = surfaces
            self.cursor = cursor
            self.locker = locker
            self.lockState = lockState
            self.clock = clock
            self.scheduler = scheduler
            self.environment = environment
        }
    }

    /// Frame rates (spec 4.2, 5.5).
    public static let fullRate = 120.0
    public static let lowPowerRate = 60.0
    /// While frames are wanted, a display link that stops (display asleep, screen gone) is covered by 10 Hz ticks.
    public static let stallCheckInterval = 0.1
    public static let stallLimit = 0.25
    /// Unlock polling while waiting for an unlock: 4 times per second (spec 5.6).
    public static let lockPollInterval = 0.25
    /// A visible surface with no reason to be visible is faded out within 2 s (spec 5.6):
    /// checked every 0.5 s, reset after 1 s without a reason, 0.3 s fade.
    public static let watchdogInterval = 0.5
    public static let watchdogGrace = 1.0
    public static let watchdogFade = 0.3

    public private(set) var director: FoldDirector
    public private(set) var settings: PliSettings
    public private(set) var environment: RuntimeEnvironment
    let adapters: Adapters
    /// Called after every change the interface may show: a lid sample, a phase, the capabilities, the environment.
    /// Up to twice per frame during a gesture, never at rest.
    public var onStateChange: (@MainActor () -> Void)?

    private var pending: [(event: DirectorEvent, fade: Double?)] = []
    private(set) var isProcessing = false
    private var lastSequence: UInt64?
    private var lastFrameTime = 0.0
    private var runningRate: Double?
    private var stallCheck: (any Cancellable)?
    private var snapshotGeneration = 0
    private var captureRequest = 0
    private var releaseTask: (any Cancellable)?
    private var wallpaperRequest = 0
    private var lockPoll: (any Cancellable)?
    private var watchdog: (any Cancellable)?
    private var unjustifiedSince: Double?
    private var sensorTask: Task<Void, Never>?
    private var started = false

    public init(settings: PliSettings, adapters: Adapters) {
        self.settings = settings
        self.adapters = adapters
        environment = adapters.environment.read()
        director = FoldDirector(settings: settings, capabilities: environment.capabilities(lidSensorAvailable: false))
    }

    /// Everything starts hidden (spec 5.6); then the sensor, the surfaces and the first capabilities. The capture
    /// warms up last, so the window list it reads already holds Pli's own overlays.
    public func start() {
        guard !started else { return }
        started = true
        adapters.surfaces.hideAll()
        adapters.sensor.start()
        let updates = adapters.sensor.updates
        sensorTask = Task { [weak self] in
            for await update in updates {
                self?.sensorUpdated(update)
            }
        }
        refreshCapabilities()
        if environment.screenCaptureAllowed { adapters.snapshotter.prewarm() }
        deliverSample()
    }

    /// Quitting: every surface off, the cursor back, the sensor thread stopped.
    public func stop() {
        guard started else { return }
        started = false
        sensorTask?.cancel()
        sensorTask = nil
        for task in [stallCheck, releaseTask, lockPoll, watchdog] { task?.cancel() }
        stallCheck = nil
        releaseTask = nil
        lockPoll = nil
        watchdog = nil
        adapters.clock.stop()
        runningRate = nil
        adapters.surfaces.hideAll()
        adapters.cursor.setHidden(false)
        adapters.sensor.stop()
    }

    public func apply(settings new: PliSettings) {
        guard new != settings else { return }
        settings = new
        adapters.surfaces.configure(surfaceConfiguration)
        send(.settingsChanged(new))
    }

    public var sensorAvailable: Bool { adapters.sensor.isAvailable }
    public var lidAngle: Double? { adapters.sensor.latest?.angle }

    // MARK: - Sensor and frames

    func sensorUpdated(_ update: LidSensorUpdate) {
        switch update {
        case .availabilityChanged:
            refreshCapabilities()
        case .angleChanged:
            if runningRate == nil { deliverSample() }
        }
    }

    /// Hands the director the latest sample, once: a sample it already has is never sent again, so a silent
    /// sensor ages and the director's stale-sample fade works (spec 11).
    private func deliverSample() {
        guard let sample = adapters.sensor.latest, sample.sequence != lastSequence else { return }
        lastSequence = sample.sequence
        send(.angle(sample.angle))
    }

    func frame() {
        lastFrameTime = adapters.scheduler.now
        deliverSample()
        send(.tick)
    }

    // MARK: - Events and commands

    /// Events are queued, so a command whose result arrives at once (a failed capture) never re-enters the director.
    func send(_ event: DirectorEvent, fade: Double? = nil) {
        pending.append((event, fade))
        guard !isProcessing else { return }
        isProcessing = true
        while !pending.isEmpty {
            let next = pending.removeFirst()
            execute(director.handle(next.event, at: adapters.scheduler.now), fade: next.fade)
        }
        isProcessing = false
        updateCadence()
        updateWatchdog()
        onStateChange?()
    }

    private func execute(_ commands: [DirectorCommand], fade override: Double?) {
        for command in commands {
            switch command {
            case .captureDesktop: startCapture()
            case .loadWallpaper: loadWallpaper()
            case .show(let surface): adapters.surfaces.show(surface)
            case .render(let surface, let progress): adapters.surfaces.render(surface, progress: progress)
            case .hide(let surface, let fade): adapters.surfaces.hide(surface, fade: override ?? fade)
            case .releaseSnapshot(let delay): scheduleRelease(after: delay)
            case .setCursorHidden(let hidden): adapters.cursor.setHidden(hidden)
            case .lockNow: adapters.locker.lockNow()
            case .startLockPolling: startLockPolling()
            case .stopLockPolling: stopLockPolling()
            }
        }
    }

    private func startCapture() {
        guard let target = environment.effectTarget else {
            send(.captureFailed)
            return
        }
        captureRequest += 1
        let request = captureRequest
        let requestedAt = adapters.scheduler.now
        adapters.snapshotter.capture(display: target.id) { [weak self] result in
            self?.captureFinished(result, request: request, requestedAt: requestedAt)
        }
    }

    /// The director gives up on a capture after `FoldDirector.captureLostAfter` and may show a newer picture since:
    /// a capture that lands later, or after a newer request, is dropped here, never installed over the one on screen.
    func captureFinished(_ result: Result<DesktopSnapshot, CaptureError>, request: Int, requestedAt: Double) {
        guard request == captureRequest, adapters.scheduler.now - requestedAt < FoldDirector.captureLostAfter else {
            Log.runtime.info("late capture dropped")
            return
        }
        switch result {
        case .success(let snapshot):
            snapshotGeneration += 1
            adapters.surfaces.setDesktopSnapshot(snapshot)
            send(.captureReady)
        case .failure(let error):
            Log.runtime.error("capture failed: \(String(describing: error), privacy: .public)")
            if error == .permissionMissing { refreshEnvironment() }
            send(.captureFailed)
        }
    }

    /// Releases the picture after `delay`, unless a newer capture replaced it meanwhile.
    private func scheduleRelease(after delay: Double) {
        releaseTask?.cancel()
        releaseTask = nil
        let generation = snapshotGeneration
        let release: @MainActor () -> Void = { [weak self] in
            guard let self, self.snapshotGeneration == generation else { return }
            self.adapters.surfaces.releaseDesktopSnapshot()
        }
        if delay <= 0 { release() } else { releaseTask = adapters.scheduler.after(delay, release) }
    }

    /// The appearance is read fresh: it may have changed since the last event that refreshed the environment.
    private func loadWallpaper() {
        guard let target = environment.effectTarget else { return }
        wallpaperRequest += 1
        let request = wallpaperRequest
        let dark = adapters.environment.read().darkAppearance
        adapters.wallpapers.load(for: target, darkAppearance: dark) { [weak self] wallpaper in
            guard let self, request == self.wallpaperRequest else { return }
            self.adapters.surfaces.setLockWallpaper(wallpaper)
        }
    }

    private func startLockPolling() {
        lockPoll?.cancel()
        lockPoll = adapters.scheduler.every(Self.lockPollInterval) { [weak self] in
            guard let self else { return }
            self.send(.lockStatePolled(locked: self.adapters.lockState.isLocked()))
        }
    }

    private func stopLockPolling() {
        lockPoll?.cancel()
        lockPoll = nil
    }

    // MARK: - Cadence

    private var frameRate: Double {
        environment.lowPowerMode && settings.general.lighterInLowPower ? Self.lowPowerRate : Self.fullRate
    }

    /// Frames and fast sensor reads only while the director wants them; at rest only the sensor thread runs (spec 10.3).
    private func updateCadence() {
        if director.wantsFrames {
            if runningRate != frameRate { startFrames() }
        } else if runningRate != nil {
            stopFrames()
        }
    }

    private func startFrames() {
        let rate = frameRate
        runningRate = rate
        lastFrameTime = adapters.scheduler.now
        adapters.clock.start(display: environment.effectTarget?.id, maximumRate: rate) { [weak self] in self?.frame() }
        adapters.sensor.setMode(.active(hz: rate))
        stallCheck?.cancel()
        stallCheck = adapters.scheduler.every(Self.stallCheckInterval) { [weak self] in self?.checkForStall() }
    }

    private func stopFrames() {
        runningRate = nil
        adapters.clock.stop()
        adapters.sensor.setMode(.rest)
        stallCheck?.cancel()
        stallCheck = nil
    }

    private func checkForStall() {
        guard runningRate != nil, adapters.scheduler.now - lastFrameTime > Self.stallLimit else { return }
        frame()
    }

    // MARK: - Environment

    var surfaceConfiguration: SurfaceConfiguration {
        let lighter = environment.lowPowerMode && settings.general.lighterInLowPower
        return SurfaceConfiguration(
            display: environment.effectTarget,
            glass: settings.glass,
            basic: !environment.screenCaptureAllowed || settings.general.rendering == .alwaysBasic,
            quality: lighter ? .light : .full,
            halfResolution: lighter,
            reduceMotion: environment.reduceMotion && settings.general.followReduceMotion
        )
    }

    /// Reads the Mac again. A display change during a gesture tears the surfaces down and rebuilds them (spec 11).
    func refreshEnvironment() {
        let previous = environment
        environment = adapters.environment.read()
        if previous.effectTarget != environment.effectTarget, director.phase != .idle, director.phase != .inactive {
            forceRest()
        }
        refreshCapabilities()
        updateCadence()
        onStateChange?()
    }

    func refreshCapabilities() {
        adapters.surfaces.configure(surfaceConfiguration)
        let capabilities = environment.capabilities(lidSensorAvailable: adapters.sensor.isAvailable)
        if capabilities != director.capabilities { send(.capabilitiesChanged(capabilities)) }
    }

    // MARK: - Watchdog (spec 5.6)

    private func updateWatchdog() {
        let visible = !adapters.surfaces.visibleSurfaces.isEmpty
        if visible, watchdog == nil {
            unjustifiedSince = nil
            watchdog = adapters.scheduler.every(Self.watchdogInterval) { [weak self] in self?.checkSurfaces() }
        } else if !visible, let running = watchdog {
            running.cancel()
            watchdog = nil
            unjustifiedSince = nil
        }
    }

    private func checkSurfaces() {
        guard !adapters.surfaces.visibleSurfaces.isEmpty else {
            updateWatchdog()
            return
        }
        guard !surfacesAreJustified else {
            unjustifiedSince = nil
            return
        }
        let now = adapters.scheduler.now
        guard let since = unjustifiedSince else {
            unjustifiedSince = now
            return
        }
        if now - since >= Self.watchdogGrace {
            Log.runtime.error("watchdog: a surface stayed visible without a reason")
            forceRest()
        }
    }

    /// A surface may be visible while the lid is lowered past the start threshold, while a timed animation runs,
    /// while a fold waits for the wake, or while the screen is locked (spec 5.6).
    var surfacesAreJustified: Bool {
        switch director.phase {
        case .demo, .revealing, .lockFolding:
            return true
        case .arming(_, let afterWake):
            return afterWake || director.lid.isLowered
        case .folding:
            return director.lid.isLowered
        case .folded:
            // After a sleep during a timed sequence the fold holds with the lid open until `didWake`.
            return director.lid.isLowered || director.isWaitingForWake
        case .lockUnfolding, .awaitingUnlock:
            return adapters.lockState.isLocked()
        case .idle, .inactive:
            return false
        }
    }

    /// Puts everything to rest through the director itself, so its state and the screen agree again. Surfaces the
    /// director no longer knows about are hidden directly.
    func forceRest() {
        var off = settings
        off.general.enabled = false
        send(.settingsChanged(off), fade: Self.watchdogFade)
        send(.settingsChanged(settings), fade: Self.watchdogFade)
        adapters.cursor.setHidden(false)
        guard !isProcessing else { return }
        if !adapters.surfaces.visibleSurfaces.isEmpty { adapters.surfaces.hideAll() }
        updateWatchdog()
    }
}
