import Foundation
import Observation

/// The three steps of the first launch (spec 8.5): Welcome, Screen Recording, Try It.
@MainActor @Observable
public final class OnboardingModel {
    public enum Step: Int, CaseIterable, Sendable {
        case welcome
        case permission
        case tryIt
    }

    public private(set) var step: Step = .welcome
    /// Allow was pressed and macOS has not said yes yet.
    public private(set) var waitingForPermission = false
    /// "Open Pli at login", checked by default (spec 8.1).
    public var openAtLogin = true

    public init() {}

    /// Get Started: the permission step, unless the permission is already there.
    public func getStarted(screenCaptureAllowed: Bool) {
        step = screenCaptureAllowed ? .tryIt : .permission
    }

    public func allowRequested() {
        waitingForPermission = true
    }

    /// The grant is detected by itself (spec 8.5): the permission step moves on.
    public func permissionChanged(allowed: Bool) {
        guard allowed, step == .permission else { return }
        waitingForPermission = false
        step = .tryIt
    }

    /// Later: Try It, in Basic mode until the permission comes.
    public func later() {
        waitingForPermission = false
        step = .tryIt
    }

    /// Show Welcome Again (spec 8.3, General).
    public func restart() {
        step = .welcome
        waitingForPermission = false
        openAtLogin = true
    }
}
