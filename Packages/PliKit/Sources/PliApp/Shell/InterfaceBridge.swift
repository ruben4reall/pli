import AppKit
import PliCore
import PliSystem
import PliUI

/// What the interface shows of the running app, read from the runtime and the Mac.
enum LiveSnapshotBuilder {
    static func make(environment: RuntimeEnvironment, sensorAvailable: Bool, lidAngle: Double?, rest: Double?,
                     cursorHidingAvailable: Bool, permissionRequested: Bool, refused: Set<HotKeys.Action>) -> LiveSnapshot {
        let display = previewDisplay(in: environment)
        let widthMM = display.map { Double($0.pixelWidth) / $0.pixelsPerMM } ?? PreviewPicture.fallbackWidthMM
        let aspect = display.flatMap { $0.pixelHeight > 0 ? Double($0.pixelWidth) / Double($0.pixelHeight) : nil } ?? 1512.0 / 982.0
        return LiveSnapshot(
            lidAngle: sensorAvailable ? lidAngle : nil,
            restAngle: sensorAvailable ? rest : nil,
            sensorAvailable: sensorAvailable,
            screenCaptureAllowed: environment.screenCaptureAllowed,
            permissionRequested: permissionRequested,
            paused: environment.effectTarget == nil,
            canLockNow: environment.canLockNow,
            lockScreenSurfaceAvailable: environment.lockScreenSurfaceAvailable,
            cursorHidingAvailable: cursorHidingAvailable,
            reduceMotion: environment.reduceMotion,
            refusedShortcuts: Set(refused.map { $0 == .demo ? ShortcutAction.demo : .animatedLock }),
            displayWidthMM: widthMM,
            displayAspectRatio: aspect
        )
    }

    /// The display the previews picture: the effect's, or the main one while Pli is paused.
    static func previewDisplay(in environment: RuntimeEnvironment) -> DisplayDescription? {
        environment.effectTarget ?? environment.displays.first(where: \.isMain) ?? environment.displays.first
    }
}

extension LoginItemState {
    init(_ status: LoginItemStatus) {
        switch status {
        case .enabled: self = .enabled
        case .disabled: self = .disabled
        case .needsApproval: self = .needsApproval
        case .unavailable: self = .unavailable
        }
    }
}

/// PliSystem's shortcut rules for the interface, with the letters of the keyboard layout in use.
@MainActor
final class SystemShortcutInterpreter: ShortcutInterpreting {
    func display(_ combo: KeyCombo) -> String {
        combo.layoutDisplay
    }

    func interpret(keyCode: UInt16, modifiers: NSEvent.ModifierFlags) -> ShortcutKeyResult {
        switch KeyCombo.record(keyCode: keyCode, modifiers: modifiers) {
        case .combo(let combo): .combo(combo)
        case .cancel: .cancel
        case .needsModifier: .needsModifier
        case .appCommand: .appCommand
        }
    }
}
