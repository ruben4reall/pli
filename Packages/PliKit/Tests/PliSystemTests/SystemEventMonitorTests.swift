import AppKit
import Testing
@testable import PliSystem

@MainActor @Suite struct SystemEventMonitorTests {
    final class Recorder { var events: [SystemEvent] = [] }

    @Test func notificationsBecomeEventsInOrder() {
        let workspace = NotificationCenter(), distributed = NotificationCenter(), app = NotificationCenter()
        let recorder = Recorder()
        let monitor = SystemEventMonitor(workspaceCenter: workspace, distributedCenter: distributed, appCenter: app, queue: nil) {
            recorder.events.append($0)
        }
        monitor.start()
        distributed.post(name: SystemEventMonitor.screenLockedName, object: nil)
        workspace.post(name: NSWorkspace.willSleepNotification, object: nil)
        workspace.post(name: NSWorkspace.didWakeNotification, object: nil)
        distributed.post(name: SystemEventMonitor.screenUnlockedName, object: nil)
        app.post(name: NSApplication.didChangeScreenParametersNotification, object: nil)
        app.post(name: Notification.Name.NSProcessInfoPowerStateDidChange, object: nil)
        workspace.post(name: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification, object: nil)
        #expect(recorder.events == [.screenLocked, .willSleep, .didWake, .screenUnlocked, .displaysChanged, .powerStateChanged, .accessibilityChanged])
    }

    @Test func stoppingSilencesTheMonitor() {
        let workspace = NotificationCenter()
        let recorder = Recorder()
        let monitor = SystemEventMonitor(workspaceCenter: workspace, distributedCenter: NotificationCenter(), appCenter: NotificationCenter(), queue: nil) {
            recorder.events.append($0)
        }
        monitor.start()
        monitor.start()   // twice: still one observer per notification
        workspace.post(name: NSWorkspace.willSleepNotification, object: nil)
        monitor.stop()
        workspace.post(name: NSWorkspace.willSleepNotification, object: nil)
        #expect(recorder.events == [.willSleep])
    }
}
