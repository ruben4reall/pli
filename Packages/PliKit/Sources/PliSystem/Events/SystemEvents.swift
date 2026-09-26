import AppKit

/// What happens to the Mac that Pli reacts to (spec 10.3).
public enum SystemEvent: Sendable, Equatable {
    case willSleep
    case didWake
    case screenLocked
    case screenUnlocked
    /// Displays were added, removed, or changed resolution or arrangement.
    case displaysChanged
    /// Reduce Motion or another accessibility display option changed.
    case accessibilityChanged
    /// Low Power Mode turned on or off.
    case powerStateChanged
    case appActivated
}

/// Turns system notifications into `SystemEvent`s, on the main actor, in the order macOS posts them.
@MainActor
public final class SystemEventMonitor {
    public static let screenLockedName = Notification.Name("com.apple.screenIsLocked")
    public static let screenUnlockedName = Notification.Name("com.apple.screenIsUnlocked")

    private let workspaceCenter: NotificationCenter
    private let distributedCenter: NotificationCenter
    private let appCenter: NotificationCenter
    private let queue: OperationQueue?
    private let onEvent: @MainActor (SystemEvent) -> Void
    private var observers: [(center: NotificationCenter, token: any NSObjectProtocol)] = []

    /// `queue` is where observers run; the default, the main queue, is right for macOS, which posts the power state
    /// change on any thread. Tests pass nil to have notifications delivered at once on the posting thread.
    public init(workspaceCenter: NotificationCenter = NSWorkspace.shared.notificationCenter,
                distributedCenter: NotificationCenter = DistributedNotificationCenter.default(),
                appCenter: NotificationCenter = .default,
                queue: OperationQueue? = .main,
                onEvent: @escaping @MainActor (SystemEvent) -> Void) {
        self.workspaceCenter = workspaceCenter
        self.distributedCenter = distributedCenter
        self.appCenter = appCenter
        self.queue = queue
        self.onEvent = onEvent
    }

    public func start() {
        guard observers.isEmpty else { return }
        observe(workspaceCenter, NSWorkspace.willSleepNotification, .willSleep)
        observe(workspaceCenter, NSWorkspace.didWakeNotification, .didWake)
        observe(workspaceCenter, NSWorkspace.accessibilityDisplayOptionsDidChangeNotification, .accessibilityChanged)
        observe(distributedCenter, Self.screenLockedName, .screenLocked)
        observe(distributedCenter, Self.screenUnlockedName, .screenUnlocked)
        observe(appCenter, NSApplication.didChangeScreenParametersNotification, .displaysChanged)
        observe(appCenter, NSApplication.didBecomeActiveNotification, .appActivated)
        observe(appCenter, Notification.Name.NSProcessInfoPowerStateDidChange, .powerStateChanged)
    }

    public func stop() {
        for observer in observers { observer.center.removeObserver(observer.token) }
        observers.removeAll()
    }

    private func observe(_ center: NotificationCenter, _ name: Notification.Name, _ event: SystemEvent) {
        let onEvent = self.onEvent
        let token = center.addObserver(forName: name, object: nil, queue: queue) { _ in
            MainActor.assumeIsolated { onEvent(event) }
        }
        observers.append((center, token))
    }
}
