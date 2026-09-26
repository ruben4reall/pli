import AppKit
import PliCore
import PliRender
import PliSystem
import PliUI
import ServiceManagement

/// The composition root (spec 10.2): builds the adapters, the runtime, the shortcuts and the interface, keeps the
/// settings, and does what the interface asks (`InterfaceServices`). Every surface starts hidden (spec 5.6).
@MainActor
public final class AppModel: InterfaceServices {
    public let options: LaunchOptions
    /// The menu bar panel, the Settings window and the welcome window read this.
    public let interface: InterfaceModel
    public private(set) var settings: PliSettings
    /// Updates, as the panel and General show them (spec 8.2, 8.3). The app target passes Sparkle in.
    public let updates: UpdatesModel
    private(set) var lastCaptureReport: String?
    private let store: SettingsStore
    private let runtime: DirectorRuntime
    private let simulator: SimulatedLidSensor?
    private let locker: ScreenLocker
    private let cursor: BackgroundCursor
    private let snapshotter: ScreenSnapshotter
    private let wallpapers: WallpaperProvider
    private let loginItem: LoginItem
    private let scheduler: MainScheduler
    private var events: SystemEventMonitor?
    private var hotKeys: HotKeys?
    private var refusedShortcuts: Set<HotKeys.Action> = []
    private var shortcutsSuspended = false
    private var debugItem: DebugStatusItem?
    private var permissionRequested = false
    private var permissionChecksLeft = 0
    private var permissionWatch: (any Cancellable)?
    private var symbolFlush: (any Cancellable)?

    public init(options: LaunchOptions = .current, defaults: UserDefaults = .standard,
                updater: any UpdateChecking = NoUpdates()) {
        self.options = options
        let store = SettingsStore(defaults: defaults)
        let loaded = store.load()
        if loaded.wasUnreadable { Log.runtime.error("stored settings were unreadable; using the defaults") }
        let renderer: GlassRenderer?
        do {
            renderer = try GlassRenderer()
        } catch {
            renderer = nil
            Log.runtime.error("no Metal renderer: \(String(describing: error), privacy: .public)")
        }
        let lockSpace = LockScreenSpace(functions: PrivateAPI.skyLight())
        let locker = ScreenLocker(functions: PrivateAPI.login())
        let cursor = BackgroundCursor(functions: PrivateAPI.cursor())
        let snapshotter = ScreenSnapshotter()
        let wallpapers = WallpaperProvider()
        let scheduler = MainScheduler()
        let simulator = options.simulateLid ? SimulatedLidSensor() : nil
        let adapters = DirectorRuntime.Adapters(
            sensor: simulator ?? LidSensor(),
            snapshotter: snapshotter,
            wallpapers: wallpapers,
            surfaces: OverlayController(renderer: renderer, lockSpace: lockSpace),
            cursor: cursor,
            locker: locker,
            lockState: SessionLockState(),
            clock: DisplayLinkClock(),
            scheduler: scheduler,
            environment: LiveEnvironment(metalAvailable: renderer != nil, lockSpaceAvailable: lockSpace != nil, canLockNow: locker.isAvailable)
        )
        self.store = store
        updates = UpdatesModel(updater: updater)
        settings = loaded.settings
        self.locker = locker
        self.cursor = cursor
        self.snapshotter = snapshotter
        self.wallpapers = wallpapers
        self.scheduler = scheduler
        self.simulator = simulator
        loginItem = LoginItem()
        runtime = DirectorRuntime(settings: loaded.settings, adapters: adapters)
        interface = InterfaceModel(settings: loaded.settings, presetStore: PresetStore(directory: PresetStore.defaultDirectory()),
                                   renderer: renderer, interpreter: SystemShortcutInterpreter())
        interface.connect(self)
        runtime.onStateChange = { [weak self] in self?.publishLive() }
    }

    public func start() {
        runtime.start()
        let events = SystemEventMonitor { [weak self] event in self?.runtime.handle(event) }
        events.start()
        self.events = events
        hotKeys = HotKeys(registrar: CarbonHotKeyRegistrar()) { [weak self] action in
            switch action {
            case .demo: self?.playDemo()
            case .lock: self?.lockWithPli()
            }
        }
        applyHotKeys()
        if options.debugMenu { debugItem = DebugStatusItem(menu: DebugMenu(model: self, simulator: simulator)) }
        publishLive()
        Log.runtime.info("Pli started, simulator \(self.options.simulateLid)")
    }

    public func stop() {
        permissionWatch?.cancel()
        symbolFlush?.cancel()
        hotKeys?.unregisterAll()
        events?.stop()
        runtime.stop()
        store.save(settings)
    }

    /// `.pli` files opened from Finder (spec 10.8).
    public func openFiles(_ urls: [URL]) {
        interface.openPresetFiles(urls)
    }

    /// Pli opened again from Finder or Spotlight while running (spec 8.1).
    public func reopen() {
        interface.reopen()
    }

    // MARK: - InterfaceServices

    public func apply(_ settings: PliSettings, persist: Bool) {
        self.settings = settings
        runtime.apply(settings: settings)
        applyHotKeys()
        if persist, !store.save(settings) { Log.runtime.error("settings could not be saved") }
    }

    public func refresh() {
        runtime.handle(.appActivated)
    }

    public func playDemo() {
        runtime.requestDemo()
    }

    public func lockWithPli() {
        runtime.requestLock()
    }

    /// First time: the system prompt. Afterwards macOS no longer prompts, so System Settings opens instead.
    public func requestScreenRecording() {
        if permissionRequested {
            NSWorkspace.shared.open(ScreenRecordingPermission.settingsURL)
        } else {
            permissionRequested = true
            ScreenRecordingPermission.request()
        }
        watchPermission()
        publishLive()
    }

    public func openScreenRecordingSettings() {
        NSWorkspace.shared.open(ScreenRecordingPermission.settingsURL)
    }

    /// If a grant only takes effect after a relaunch (spec R5), the panel and the welcome window offer one.
    public func relaunch() {
        hotKeys?.unregisterAll()
        store.save(settings)
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL, configuration: configuration) { _, _ in
            Task { @MainActor in NSApplication.shared.terminate(nil) }
        }
    }

    public var openAtLogin: LoginItemState {
        LoginItemState(loginItem.status)
    }

    public func setOpenAtLogin(_ enabled: Bool) throws {
        try loginItem.setEnabled(enabled)
    }

    public func openLoginItemsSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }

    /// Sparkle, through the updates model (Plan 6); Debug builds and tests have `NoUpdates`.
    public var supportsAutomaticUpdateChecks: Bool { updates.canCheckForUpdates }

    public var automaticallyChecksForUpdates: Bool {
        get { updates.automaticallyChecksForUpdates }
        set { updates.setAutomaticChecks(newValue) }
    }

    public func checkForUpdates() {
        if updates.canCheckForUpdates {
            updates.checkForUpdates()
        } else {
            NSWorkspace.shared.open(Links.latestRelease)
        }
    }

    public func suspendShortcuts(_ suspended: Bool) {
        shortcutsSuspended = suspended
        applyHotKeys()
    }

    /// The capture of the effect's display when allowed and wanted, the wallpaper otherwise (spec 8.3). Always Basic
    /// means "never capture", so it gets the wallpaper too. The picture stays in memory (spec 10.9).
    public func requestPreviewPicture(_ completion: @escaping @MainActor (PreviewPicture?) -> Void) {
        let environment = runtime.environment
        guard let display = LiveSnapshotBuilder.previewDisplay(in: environment) else {
            completion(nil)
            return
        }
        let widthMM = Double(display.pixelWidth) / display.pixelsPerMM
        let wallpaper: @MainActor () -> Void = { [weak self] in
            self?.wallpapers.load(for: display, darkAppearance: environment.darkAppearance) { source in
                completion(PreviewPicture(pixelBuffer: source.pixelBuffer, kind: .wallpaper, displayWidthMM: widthMM))
            }
        }
        guard environment.screenCaptureAllowed, settings.general.rendering == .automatic else {
            wallpaper()
            return
        }
        snapshotter.capture(display: display.id) { result in
            switch result {
            case .success(let snapshot):
                completion(PreviewPicture(pixelBuffer: snapshot.pixelBuffer, kind: .screen, displayWidthMM: widthMM))
            case .failure:
                wallpaper()
            }
        }
    }

    /// Spec 8.1: a regular app (Dock, ⌘Tab, menus) while a window is open, the menu bar only otherwise.
    public func setRegularApp(_ regular: Bool) {
        NSApplication.shared.setActivationPolicy(regular ? .regular : .accessory)
        if regular { NSApplication.shared.activate() }
    }

    public func open(_ url: URL) {
        NSWorkspace.shared.open(url)
    }

    public func quit() {
        NSApplication.shared.terminate(nil)
    }

    // MARK: - Live state

    /// Every runtime change reaches the interface; the menu bar symbol's own limit (30 per second) may defer a redraw.
    private func publishLive() {
        let snapshot = LiveSnapshotBuilder.make(environment: runtime.environment, sensorAvailable: runtime.sensorAvailable,
                                                lidAngle: runtime.lidAngle, rest: runtime.director.lid.rest,
                                                cursorHidingAvailable: cursor.isAvailable,
                                                permissionRequested: permissionRequested, refused: refusedShortcuts)
        if let flushAt = interface.receive(snapshot, at: scheduler.now) { scheduleSymbolFlush(at: flushAt) }
    }

    private func scheduleSymbolFlush(at time: Double) {
        symbolFlush?.cancel()
        symbolFlush = scheduler.after(max(time - scheduler.now, 0)) { [weak self] in
            guard let self else { return }
            self.symbolFlush = nil
            if let next = self.interface.live.flushSymbol(at: self.scheduler.now) { self.scheduleSymbolFlush(at: next) }
        }
    }

    // MARK: - Shortcuts and permission

    /// The enabled shortcuts, unless Pli is off or a shortcut is being recorded. The ones macOS refused are shown
    /// under their recorder.
    private func applyHotKeys() {
        guard let hotKeys else { return }
        let refused: Set<HotKeys.Action>
        if settings.general.enabled, !shortcutsSuspended {
            refused = hotKeys.apply(settings.triggers)
            if !refused.isEmpty { Log.runtime.error("\(refused.count) shortcut(s) held by another app") }
        } else {
            hotKeys.unregisterAll()
            refused = []
        }
        guard refused != refusedShortcuts else { return }
        refusedShortcuts = refused
        publishLive()
    }

    /// After a request, looks for the grant once a second for a minute, so the next gesture can use it.
    private func watchPermission() {
        permissionWatch?.cancel()
        permissionChecksLeft = 60
        permissionWatch = scheduler.every(1) { [weak self] in
            guard let self else { return }
            self.permissionChecksLeft -= 1
            guard ScreenRecordingPermission.isGranted || self.permissionChecksLeft <= 0 else { return }
            self.permissionWatch?.cancel()
            self.permissionWatch = nil
            self.runtime.handle(.appActivated)
        }
    }

    // MARK: - Debug

    /// Plays a whole night without closing the lid: the simulated lid closes, the Mac "sleeps" (the display stays
    /// on), locks for real if asked, then "wakes" and the simulated lid opens.
    func simulateSleepAndWake(locked: Bool) {
        guard let simulator else { return }
        simulator.play(.closeQuickly)
        scheduler.after(LidScript.closeQuickly.duration + 0.3) { [weak self] in
            guard let self else { return }
            self.runtime.handle(.willSleep)
            if locked { self.locker.lockNow() }
            self.scheduler.after(locked ? 2 : 1) { [weak self] in
                self?.runtime.handle(.didWake)
                simulator.play(.openFromClosed)
            }
        }
    }

    /// One capture of the effect's display, timed; the result shows in the Debug menu and the log.
    func testCapture() {
        guard let target = runtime.environment.effectTarget else { return }
        let started = scheduler.now
        snapshotter.capture(display: target.id) { [weak self] result in
            guard let self else { return }
            let milliseconds = Int((self.scheduler.now - started) * 1000)
            switch result {
            case .success(let snapshot):
                self.lastCaptureReport = "Last capture: \(milliseconds) ms, \(snapshot.width) x \(snapshot.height)"
            case .failure(let error):
                self.lastCaptureReport = "Last capture failed: \(error)"
            }
        }
    }
}
