import Foundation
import PliCore

/// My Presets and `.pli` files (spec 7.5, 10.8). A change that fails says so in the Style pane's banner, and returns the
/// sentence for a sheet to show.
extension InterfaceModel {
    private func fail(_ error: Error) -> String {
        let message = PresetTransfer.message(for: error)
        banner = Banner(text: message, isProblem: true)
        return message
    }

    @discardableResult
    public func saveAsPreset(named name: String) -> String? {
        do {
            let preset = try presets.saveAsPreset(named: name, from: editor.settings)
            editor.setQuietly(\.activePresetID, to: preset.id)
            return nil
        } catch {
            return fail(error)
        }
    }

    @discardableResult
    public func saveChangesToActivePreset() -> String? {
        let preset = presetState.preset
        guard !preset.isBuiltIn else { return nil }
        do {
            try presets.saveChanges(to: preset.id, from: editor.settings)
            return nil
        } catch {
            return fail(error)
        }
    }

    @discardableResult
    public func renamePreset(_ preset: Preset, to name: String) -> String? {
        do {
            try presets.rename(preset.id, to: name)
            return nil
        } catch {
            return fail(error)
        }
    }

    @discardableResult
    public func duplicatePreset(_ preset: Preset) -> String? {
        do {
            try presets.duplicate(preset)
            return nil
        } catch {
            return fail(error)
        }
    }

    /// Deleting the preset in use keeps the look; the label becomes Duo's, modified.
    @discardableResult
    public func deletePreset(_ preset: Preset) -> String? {
        do {
            try presets.delete(preset.id)
            if editor.settings.activePresetID == preset.id {
                editor.setQuietly(\.activePresetID, to: BuiltInPresets.duo.id)
            }
            return nil
        } catch {
            return fail(error)
        }
    }

    // MARK: - .pli files

    /// Import…: each file is added to My Presets; the last one is chosen (undoable).
    public func importPresets(from urls: [URL], undoManager: UndoManager?) {
        var imported: [Preset] = []
        var problem: String?
        for url in urls {
            do {
                imported.append(try presets.add(imported: try PresetTransfer.read(from: url)))
            } catch {
                problem = PresetTransfer.message(for: error)
            }
        }
        if let last = imported.last { choose(last, undoManager: undoManager) }
        if let problem {
            banner = Banner(text: problem, isProblem: true)
        } else if imported.count == 1 {
            banner = Banner(text: Strings.importedPreset(imported[0].name), isProblem: false)
        } else if imported.count > 1 {
            banner = Banner(text: Strings.importedPresets(imported.count), isProblem: false)
        }
    }

    /// A `.pli` file opened from Finder: imported, then shown in Style.
    public func openPresetFiles(_ urls: [URL]) {
        let files = urls.filter { $0.pathExtension.lowercased() == PresetFile.fileExtension }
        guard !files.isEmpty else { return }
        importPresets(from: files, undoManager: nil)
        pane = .look
        windows.open(.settings)
    }

    public func dismissBanner() {
        banner = nil
    }

    /// Export…: the current look, named as the Style pane shows it.
    public func exportDocument() -> PresetDocument {
        let settings = editor.settings
        return PresetDocument(preset: Preset(id: settings.activePresetID, name: Preset.sanitizedName(presetState.title),
                                             glass: settings.glass, motion: settings.motion))
    }

    public func exportDocument(for preset: Preset) -> PresetDocument {
        PresetDocument(preset: Preset(id: preset.id, name: displayName(of: preset), glass: preset.glass, motion: preset.motion))
    }
}
