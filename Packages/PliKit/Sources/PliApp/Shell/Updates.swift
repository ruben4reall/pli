import Observation

/// Software updates as the interface sees them (spec 8.2, 8.3, 13.3). The app target implements it with Sparkle
/// (`App/SparkleUpdater.swift`); the package never links Sparkle and never opens a connection.
@MainActor
public protocol UpdateChecking: AnyObject {
    /// False while a check or an installation runs, and in builds without an updater.
    var canCheckForUpdates: Bool { get }
    /// General's "Check Automatically" (spec 8.3). Sparkle itself asks on the second launch (spec 8.4).
    var automaticallyChecksForUpdates: Bool { get set }
    /// A version a scheduled check found and nobody has looked at yet. Pli has no Dock icon, so its menu names it.
    var pendingUpdateVersion: String? { get }
    /// Called after any of the values above changes.
    var onChange: (@MainActor () -> Void)? { get set }
    /// Shows Sparkle's window: the check, or the waiting update.
    func checkForUpdates()
}

/// Debug builds, tests and the package's own delegate: no updater, nothing to check.
@MainActor
public final class NoUpdates: UpdateChecking {
    public init() {}

    public var canCheckForUpdates: Bool { false }

    public var automaticallyChecksForUpdates: Bool {
        get { false }
        set {}
    }

    public var pendingUpdateVersion: String? { nil }

    public var onChange: (@MainActor () -> Void)?

    public func checkForUpdates() {}
}

/// What the panel's "Check for Updates…" and General's Updates rows bind to.
@MainActor
@Observable
public final class UpdatesModel {
    public private(set) var canCheckForUpdates: Bool
    public private(set) var automaticallyChecksForUpdates: Bool
    public private(set) var pendingUpdateVersion: String?
    private let updater: any UpdateChecking

    public init(updater: any UpdateChecking) {
        self.updater = updater
        canCheckForUpdates = updater.canCheckForUpdates
        automaticallyChecksForUpdates = updater.automaticallyChecksForUpdates
        pendingUpdateVersion = updater.pendingUpdateVersion
        updater.onChange = { [weak self] in self?.refresh() }
    }

    /// The panel's item names a waiting update, so a scheduled find is never missed.
    public var menuTitle: String {
        if let version = pendingUpdateVersion {
            return String(localized: "Update to Pli \(version)…")
        }
        return String(localized: "Check for Updates…")
    }

    /// "Check for Updates…" (panel) and "Check Now" (General).
    public func checkForUpdates() {
        guard canCheckForUpdates else { return }
        updater.checkForUpdates()
    }

    /// General's "Check Automatically".
    public func setAutomaticChecks(_ on: Bool) {
        updater.automaticallyChecksForUpdates = on
        automaticallyChecksForUpdates = updater.automaticallyChecksForUpdates
    }

    private func refresh() {
        canCheckForUpdates = updater.canCheckForUpdates
        automaticallyChecksForUpdates = updater.automaticallyChecksForUpdates
        pendingUpdateVersion = updater.pendingUpdateVersion
    }
}
