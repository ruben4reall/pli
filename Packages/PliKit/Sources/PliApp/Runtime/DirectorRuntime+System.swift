import PliCore
import PliSystem

extension DirectorRuntime {
    /// System events (spec 10.3). On wake, the sensor is checked, the capture cache refreshed, and the director told
    /// whether the screen is locked.
    public func handle(_ event: SystemEvent) {
        switch event {
        case .willSleep:
            send(.willSleep)
        case .didWake:
            adapters.sensor.didWake()
            adapters.snapshotter.invalidate()
            refreshEnvironment()
            send(.didWake(locked: adapters.lockState.isLocked()))
            if environment.screenCaptureAllowed { adapters.snapshotter.prewarm() }
        case .screenLocked:
            send(.screenLocked)
        case .screenUnlocked:
            send(.screenUnlocked)
        case .displaysChanged:
            adapters.snapshotter.invalidate()
            refreshEnvironment()
            if environment.screenCaptureAllowed { adapters.snapshotter.prewarm() }
        case .accessibilityChanged, .powerStateChanged, .appActivated:
            refreshEnvironment()
        }
    }

    /// The Demo shortcut or menu item (spec 5.4). A closed MacBook on an external display is paused (spec 5.5).
    public func requestDemo() {
        guard environment.effectTarget != nil else { return }
        send(.demoRequested)
    }

    /// The Animated Lock shortcut or menu item (spec 5.4). When the fold cannot play right now (paused, or busy
    /// with a gesture), the Mac still locks: the shortcut means lock.
    public func requestLock() {
        guard settings.triggers.animatedLockEnabled, adapters.locker.isAvailable else { return }
        if environment.effectTarget != nil, director.phase == .idle {
            send(.lockRequested)
        } else {
            adapters.locker.lockNow()
        }
    }
}
