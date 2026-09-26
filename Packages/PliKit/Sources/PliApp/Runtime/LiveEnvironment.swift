import AppKit
import PliSystem

/// The real Mac, read on demand.
@MainActor
public final class LiveEnvironment: EnvironmentReading {
    private let metalAvailable: Bool
    private let lockSpaceAvailable: Bool
    private let canLockNow: Bool

    public init(metalAvailable: Bool, lockSpaceAvailable: Bool, canLockNow: Bool) {
        self.metalAvailable = metalAvailable
        self.lockSpaceAvailable = lockSpaceAvailable
        self.canLockNow = canLockNow
    }

    public func read() -> RuntimeEnvironment {
        RuntimeEnvironment(
            displays: DisplayInfo.current(),
            isLaptop: DisplayInfo.isLaptop,
            // Without Metal a capture could not be drawn: Basic mode, which needs none.
            screenCaptureAllowed: metalAvailable && ScreenRecordingPermission.isGranted,
            reduceMotion: NSWorkspace.shared.accessibilityDisplayShouldReduceMotion,
            lowPowerMode: ProcessInfo.processInfo.isLowPowerModeEnabled,
            darkAppearance: NSApplication.shared.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua,
            lockScreenSurfaceAvailable: metalAvailable && lockSpaceAvailable,
            canLockNow: canLockNow
        )
    }
}
