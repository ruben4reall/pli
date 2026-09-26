import Foundation
import Observation
import PliCore
import PliRender

/// The tabs of the Settings window, Noir design: Look (the preview and the glass), Motion, Triggers, General (with
/// what used to be About at its foot).
public enum SettingsPane: String, CaseIterable, Identifiable, Sendable {
    case look
    case motion
    case triggers
    case general

    public var id: SettingsPane { self }

    public var title: String {
        switch self {
        case .look: Strings.look
        case .motion: Strings.motion
        case .triggers: Strings.triggers
        case .general: Strings.general
        }
    }
}

/// A one-line message at the top of the Look pane: an import that worked or failed.
public struct Banner: Equatable, Sendable {
    public var text: String
    public var isProblem: Bool
}

/// Why the capture-only settings are dimmed (spec 7.3), or nil with full rendering.
public enum BasicModeReason: Equatable, Sendable {
    case permissionMissing
    case alwaysBasic

    public var note: String { self == .permissionMissing ? Strings.requiresScreenRecording : Strings.notUsedInBasicMode }
}

/// Holds the services weakly, so the editor's and the recorder's closures can reach them before `connect`.
@MainActor
final class ServiceRelay {
    weak var services: (any InterfaceServices)?
}

/// The interface's root model: the settings being edited, the presets, the live state, the previews, the windows.
/// Views read it; every action that leaves the interface goes through `InterfaceServices`. Preset and window actions
/// live in the two extension files next to this one.
@MainActor @Observable
public final class InterfaceModel {
    public let editor: SettingsEditor
    public let presets: PresetLibrary
    public let live: LiveState
    public let preview: PreviewModel
    public let recorder: ShortcutRecorderModel
    public let onboarding: OnboardingModel
    public let windows: WindowRouter
    public let renderer: PreviewRenderer
    public var pane: SettingsPane = .look
    public internal(set) var banner: Banner?
    public internal(set) var loginItem: LoginItemState = .disabled
    public internal(set) var loginProblem: String?
    @ObservationIgnored let relay: ServiceRelay
    @ObservationIgnored let clock: @MainActor () -> Double
    /// Numbers each preview picture request, so an answer that arrives after Settings closed is dropped.
    @ObservationIgnored var pictureRequest = 0

    public init(settings: PliSettings, presetStore: PresetStore, renderer: GlassRenderer?, interpreter: any ShortcutInterpreting,
                live: LiveSnapshot = LiveSnapshot(),
                clock: @escaping @MainActor () -> Double = { Date().timeIntervalSinceReferenceDate }) {
        let relay = ServiceRelay()
        let editor = SettingsEditor(settings: settings) { settings, persist in
            relay.services?.apply(settings, persist: persist)
        }
        self.relay = relay
        self.clock = clock
        self.editor = editor
        presets = PresetLibrary(store: presetStore)
        self.live = LiveState(live)
        preview = PreviewModel(ghostAngle: PreviewModel.defaultGhostAngle(motion: settings.motion,
                                                                         rest: live.restAngle ?? FrostCurve.nominalRest))
        recorder = ShortcutRecorderModel(editor: editor, interpreter: interpreter) { suspended in
            relay.services?.suspendShortcuts(suspended)
        }
        onboarding = OnboardingModel()
        windows = WindowRouter()
        self.renderer = PreviewRenderer(renderer: renderer)
    }

    public func connect(_ services: any InterfaceServices) {
        relay.services = services
        loginItem = services.openAtLogin
    }

    public var services: (any InterfaceServices)? { relay.services }

    // MARK: - Reading

    public var settings: PliSettings { editor.settings }
    public var presetState: PresetState { presets.state(for: editor.settings) }
    public var status: PanelStatus { PanelStatus.make(settings: editor.settings, live: live.snapshot) }
    public var showsOnboardingAtLaunch: Bool { !editor.settings.general.hasCompletedOnboarding }

    public var basicModeReason: BasicModeReason? {
        if editor.settings.general.rendering == .alwaysBasic { return .alwaysBasic }
        return live.screenCaptureAllowed ? nil : .permissionMissing
    }

    public var protractorMarks: ProtractorMarks {
        ProtractorMarks(motion: editor.settings.motion, rest: live.restAngle ?? FrostCurve.nominalRest)
    }

    public var previewReduceMotion: Bool { live.reduceMotion && editor.settings.general.followReduceMotion }

    public func previewProgress(at now: Double) -> Double {
        preview.progress(at: now, motion: editor.settings.motion, rest: live.restAngle, lidAngle: live.lidAngle)
    }

    public func displayName(of preset: Preset) -> String { Strings.presetName(preset) }

    /// A shortcut recorder's line: the last refused key, or macOS refusing the saved shortcut.
    public func shortcutProblem(for action: ShortcutAction) -> String? {
        if let problem = recorder.problem, problem.action == action { return problem.text }
        return live.refusedShortcuts.contains(action) ? Strings.shortcutTaken : nil
    }

    // MARK: - Settings (undoable)

    public func setEnabled(_ enabled: Bool, undoManager: UndoManager?) {
        editor.set(\.general.enabled, to: enabled, action: Strings.enablePli, undoManager: undoManager)
    }

    public func choose(_ preset: Preset, undoManager: UndoManager?) {
        editor.set(\.look, to: Look(preset: preset), action: Strings.choosePreset, undoManager: undoManager)
    }

    /// Reset: the active preset's saved values, every group.
    public func resetToPreset(undoManager: UndoManager?) {
        editor.set(\.look, to: Look(preset: presetState.preset), action: Strings.reset, undoManager: undoManager)
    }

    public func resetGlass(undoManager: UndoManager?) {
        let glass = editor.settings.glass.withGlassGroup(of: presetState.preset.glass)
        editor.set(\.glass, to: glass, action: Strings.resetGlass, undoManager: undoManager)
    }

    public func resetPerspective(undoManager: UndoManager?) {
        let glass = editor.settings.glass.withPerspectiveGroup(of: presetState.preset.glass)
        editor.set(\.glass, to: glass, action: Strings.resetPerspective, undoManager: undoManager)
    }

    public func resetMotion(undoManager: UndoManager?) {
        editor.set(\.motion, to: presetState.preset.motion, action: Strings.resetMotion, undoManager: undoManager)
    }

    // MARK: - From the app

    /// A live snapshot from the runtime. Returns when the menu bar symbol wants its deferred redraw.
    @discardableResult
    public func receive(_ snapshot: LiveSnapshot, at now: Double) -> Double? {
        let wasAllowed = live.screenCaptureAllowed
        let flushAt = live.apply(snapshot, at: now)
        if snapshot.screenCaptureAllowed != wasAllowed {
            onboarding.permissionChanged(allowed: snapshot.screenCaptureAllowed)
            if windows.isOpen(.settings) { requestPreviewPicture() }
        }
        return flushAt
    }
}
