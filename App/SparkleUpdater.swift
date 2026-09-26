import AppKit
import PliApp
import Sparkle

/// Pli's only network code (spec 10.9, 13.3): Sparkle reads the update feed on the website and installs EdDSA-signed
/// disk images from GitHub Releases. Automatic checks are Sparkle's own question on the second launch (spec 8.4).
/// Debug builds never start it, so a development copy is never replaced by a release.
@MainActor
final class SparkleUpdater: NSObject, UpdateChecking {
    private let reminders: UpdateReminders
    private let controller: SPUStandardUpdaterController
    private var observations: [NSKeyValueObservation] = []
    var onChange: (@MainActor () -> Void)?

    override init() {
        let reminders = UpdateReminders()
        self.reminders = reminders
        // Sparkle takes its delegates only here; the updater starts below, once everything is wired.
        controller = SPUStandardUpdaterController(startingUpdater: false, updaterDelegate: nil, userDriverDelegate: reminders)
        super.init()
        reminders.changed = { [weak self] in self?.onChange?() }
        let updater = controller.updater
        observations = [
            updater.observe(\.canCheckForUpdates) { [weak self] _, _ in
                Task { @MainActor [weak self] in self?.onChange?() }
            },
            updater.observe(\.automaticallyChecksForUpdates) { [weak self] _, _ in
                Task { @MainActor [weak self] in self?.onChange?() }
            },
        ]
        #if !DEBUG
        controller.startUpdater()
        #endif
    }

    var canCheckForUpdates: Bool { controller.updater.canCheckForUpdates }

    var automaticallyChecksForUpdates: Bool {
        get { controller.updater.automaticallyChecksForUpdates }
        set { controller.updater.automaticallyChecksForUpdates = newValue }
    }

    var pendingUpdateVersion: String? { reminders.pendingVersion }

    func checkForUpdates() {
        controller.checkForUpdates(nil)
    }
}

/// Sparkle's gentle reminders, for an app without a Dock icon: a version found by a scheduled check is named in
/// Pli's menu, instead of an alert that would take focus from the app in use.
@MainActor
private final class UpdateReminders: NSObject, @preconcurrency SPUStandardUserDriverDelegate {
    private(set) var pendingVersion: String?
    var changed: (@MainActor () -> Void)?

    var supportsGentleScheduledUpdateReminders: Bool { true }

    func standardUserDriverWillHandleShowingUpdate(_ handleShowingUpdate: Bool, forUpdate update: SUAppcastItem, state: SPUUserUpdateState) {
        guard !state.userInitiated else { return }
        pendingVersion = update.displayVersionString
        changed?()
    }

    func standardUserDriverDidReceiveUserAttention(forUpdate update: SUAppcastItem) {
        clear()
    }

    func standardUserDriverWillFinishUpdateSession() {
        clear()
    }

    private func clear() {
        guard pendingVersion != nil else { return }
        pendingVersion = nil
        changed?()
    }
}

/// The package's delegate, with Sparkle as its updater (only this target links Sparkle).
final class PliShellDelegate: PliAppDelegate {
    override func makeUpdater() -> any UpdateChecking {
        SparkleUpdater()
    }
}
