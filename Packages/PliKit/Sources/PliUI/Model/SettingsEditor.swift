import Foundation
import Observation
import PliCore

/// What a preset sets (spec 7.5): the Glass, Perspective and Motion groups, and which preset they come from.
public struct Look: Equatable, Sendable {
    public var glass: GlassParameters
    public var motion: MotionParameters
    public var presetID: String

    public init(glass: GlassParameters, motion: MotionParameters, presetID: String) {
        self.glass = glass
        self.motion = motion
        self.presetID = presetID
    }

    public init(preset: Preset) {
        self.init(glass: preset.glass, motion: preset.motion, presetID: preset.id)
    }
}

extension PliSettings {
    /// The preset part of the settings, as one value, so choosing a preset is one undoable change.
    public var look: Look {
        get { Look(glass: glass, motion: motion, presetID: activePresetID) }
        set {
            glass = newValue.glass
            motion = newValue.motion
            activePresetID = newValue.presetID
        }
    }
}

extension GlassParameters {
    /// This value with the Glass group of spec 7.4 (Frost to Prism) taken from `other`.
    public func withGlassGroup(of other: GlassParameters) -> GlassParameters {
        var copy = self
        copy.frost = other.frost
        copy.grain = other.grain
        copy.darkening = other.darkening
        copy.tintColor = other.tintColor
        copy.tintAmount = other.tintAmount
        copy.saturation = other.saturation
        copy.edgeSheen = other.edgeSheen
        copy.prism = other.prism
        return copy
    }

    /// This value with the Perspective group of spec 7.4 (Eye Distance to Edge Softness) taken from `other`.
    public func withPerspectiveGroup(of other: GlassParameters) -> GlassParameters {
        var copy = self
        copy.eyeDistanceMM = other.eyeDistanceMM
        copy.eyeHeight = other.eyeHeight
        copy.spatialAnchor = other.spatialAnchor
        copy.maxTiltDegrees = other.maxTiltDegrees
        copy.finalBlackout = other.finalBlackout
        copy.edgeSoftnessMM = other.edgeSoftnessMM
        return copy
    }
}

/// The settings being edited, with undo (spec 8.6: ⌘Z and ⇧⌘Z). Every change reaches `commit` at once; `persist`
/// is false only during a drag, whose end saves once and registers one undo step. Undo restores the one setting a
/// step changed, never the whole value, so a change made elsewhere (the panel, onboarding) is never rolled back.
@MainActor @Observable
public final class SettingsEditor {
    /// Changes of one setting closer together than this make one undo step: a color dragged in the color panel,
    /// a slider moved with the arrow keys.
    public static let coalescingWindow = 1.0

    public private(set) var settings: PliSettings
    @ObservationIgnored private let commit: @MainActor (PliSettings, Bool) -> Void
    @ObservationIgnored private let clock: @MainActor () -> Double
    @ObservationIgnored private var lastCoalesced: (key: AnyKeyPath, time: Double)?
    @ObservationIgnored private var continuous: (@MainActor (SettingsEditor, String, UndoManager?) -> Void)?

    public init(settings: PliSettings,
                clock: @escaping @MainActor () -> Double = { ProcessInfo.processInfo.systemUptime },
                commit: @escaping @MainActor (PliSettings, Bool) -> Void) {
        self.settings = settings
        self.clock = clock
        self.commit = commit
    }

    public var isChangingContinuously: Bool { continuous != nil }

    /// One discrete change: applied, saved, and undoable as one step named `action`. With `coalescing`, changes of
    /// the same setting within `coalescingWindow` share the first one's undo step.
    public func set<Value: Equatable>(_ keyPath: WritableKeyPath<PliSettings, Value>, to value: Value, action: String,
                                      undoManager: UndoManager?, coalescing: Bool = false) {
        let old = settings[keyPath: keyPath]
        guard old != value else { return }
        write(keyPath, value, persist: true)
        let now = clock()
        if coalescing, let last = lastCoalesced, last.key == keyPath, now - last.time < Self.coalescingWindow {
            lastCoalesced = (keyPath, now)
            return
        }
        lastCoalesced = coalescing ? (keyPath, now) : nil
        registerUndo(keyPath, restoring: old, action: action, undoManager: undoManager)
    }

    /// A change nobody undoes: onboarding done, the menu bar symbol dragged away, the preset id after a save.
    public func setQuietly<Value: Equatable>(_ keyPath: WritableKeyPath<PliSettings, Value>, to value: Value) {
        guard settings[keyPath: keyPath] != value else { return }
        write(keyPath, value, persist: true)
    }

    /// A slider move: live and unsaved inside a drag, a coalesced discrete change outside one (the arrow keys).
    public func slide<Value: Equatable>(_ keyPath: WritableKeyPath<PliSettings, Value>, to value: Value, action: String,
                                        undoManager: UndoManager?) {
        if continuous != nil {
            guard settings[keyPath: keyPath] != value else { return }
            write(keyPath, value, persist: false)
        } else {
            set(keyPath, to: value, action: action, undoManager: undoManager, coalescing: true)
        }
    }

    /// A drag starts: its changes are applied live, and saved and registered as one undo step when it ends.
    public func beginContinuous<Value: Equatable>(_ keyPath: WritableKeyPath<PliSettings, Value>) {
        guard continuous == nil else { return }
        let original = settings[keyPath: keyPath]
        continuous = { editor, action, undoManager in
            guard editor.settings[keyPath: keyPath] != original else { return }
            editor.commit(editor.settings, true)
            editor.lastCoalesced = nil
            editor.registerUndo(keyPath, restoring: original, action: action, undoManager: undoManager)
        }
    }

    public func endContinuous(action: String, undoManager: UndoManager?) {
        guard let finish = continuous else { return }
        continuous = nil
        finish(self, action, undoManager)
    }

    // MARK: - Private

    private func write<Value>(_ keyPath: WritableKeyPath<PliSettings, Value>, _ value: Value, persist: Bool) {
        var next = settings
        next[keyPath: keyPath] = value
        next.glass = next.glass.clamped()
        next.motion = next.motion.clamped()
        settings = next
        commit(next, persist)
    }

    /// One undo group per change, so a window's event grouping and a test's manual grouping both see one step.
    private func registerUndo<Value: Equatable>(_ keyPath: WritableKeyPath<PliSettings, Value>, restoring old: Value,
                                                action: String, undoManager: UndoManager?) {
        guard let undoManager else { return }
        undoManager.beginUndoGrouping()
        undoManager.registerUndo(withTarget: self) { editor in
            editor.restore(keyPath, to: old, action: action, undoManager: undoManager)
        }
        undoManager.setActionName(action)
        undoManager.endUndoGrouping()
    }

    /// Undo and redo: puts `value` back and registers the opposite step.
    private func restore<Value: Equatable>(_ keyPath: WritableKeyPath<PliSettings, Value>, to value: Value,
                                           action: String, undoManager: UndoManager) {
        let current = settings[keyPath: keyPath]
        lastCoalesced = nil
        write(keyPath, value, persist: true)
        undoManager.registerUndo(withTarget: self) { editor in
            editor.restore(keyPath, to: current, action: action, undoManager: undoManager)
        }
        undoManager.setActionName(action)
    }
}
