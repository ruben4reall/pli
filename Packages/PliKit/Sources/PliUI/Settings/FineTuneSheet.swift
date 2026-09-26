import PliCore
import SwiftUI
import UniformTypeIdentifiers

/// Fine-Tune: every Glass and Perspective setting (spec 7.4), the look's own actions (save, reset, import, export),
/// in a dark sheet over Look. What Basic mode does not use is dimmed, and the footers say why (spec 7.3).
struct FineTuneSheet: View {
    let interface: InterfaceModel
    @Environment(\.undoManager) private var undoManager
    @Environment(\.dismiss) private var dismiss
    @State private var naming = false
    @State private var importing = false
    @State private var exporting: PresetDocument?

    var body: some View {
        let state = interface.presetState
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(Strings.fineTune).font(.system(size: 17, weight: .semibold))
                    Text(state.title).font(.system(size: 12)).foregroundStyle(Noir.secondary)
                }
                Spacer()
                Button(Strings.done) { dismiss() }
                    .buttonStyle(NoirButtonStyle(primary: true, small: true))
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 8)
            Form {
                GlassSettingsSections(interface: interface)
                Section {
                    HStack(spacing: 8) {
                        Button(Strings.saveAsPreset) { naming = true }
                        if !state.preset.isBuiltIn, state.isModified {
                            Button(Strings.saveChanges) { interface.saveChangesToActivePreset() }
                        }
                        Button(Strings.reset) { interface.resetToPreset(undoManager: undoManager) }
                            .disabled(!state.isModified)
                        Spacer()
                        Button(Strings.importPreset) { importing = true }
                        Button(Strings.exportPreset) { exporting = interface.exportDocument() }
                    }
                } header: {
                    Text(Strings.presets)
                } footer: {
                    Footnote(Strings.shareLookNote)
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
        }
        .frame(width: 600, height: 640)
        .background(Noir.window)
        .environment(\.colorScheme, .dark)
        .tint(Noir.glacier)
        .sheet(isPresented: $naming) {
            PresetNameSheet(title: Strings.newPreset, name: state.name) { interface.saveAsPreset(named: $0) }
        }
        .fileExporter(isPresented: Binding(get: { exporting != nil }, set: { if !$0 { exporting = nil } }), document: exporting,
                      contentType: .pliPreset, defaultFilename: exporting.map { PresetTransfer.fileName(for: $0.preset.name) }) { _ in
            exporting = nil
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.pliPreset], allowsMultipleSelection: true) { result in
            if case .success(let urls) = result { interface.importPresets(from: urls, undoManager: undoManager) }
        }
    }
}

/// The Glass and Perspective groups (spec 7.4), each with its Reset.
struct GlassSettingsSections: View {
    let interface: InterfaceModel
    @Environment(\.undoManager) private var undoManager

    var body: some View {
        let reason = interface.basicModeReason
        Section {
            ForEach(SettingsCatalog.glass) { setting in
                SettingSlider(setting: setting, editor: interface.editor, disabled: setting.needsCapture && reason != nil)
            }
            TintRow(editor: interface.editor, disabled: reason != nil)
        } header: {
            Text(Strings.glass)
        } footer: {
            ResetFooter(title: Strings.resetGlass, note: reason?.note) { interface.resetGlass(undoManager: undoManager) }
        }
        Section {
            ForEach(SettingsCatalog.perspective) { setting in
                SettingSlider(setting: setting, editor: interface.editor, disabled: setting.needsCapture && reason != nil)
            }
        } header: {
            Text(Strings.perspective)
        } footer: {
            ResetFooter(title: Strings.resetPerspective, note: reason?.note) { interface.resetPerspective(undoManager: undoManager) }
        }
    }
}

/// Save as Preset and Rename: one field, Cancel and Save.
struct PresetNameSheet: View {
    let title: String
    @State var name: String
    let onSave: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title).font(.headline)
            TextField(Strings.presetName, text: $name)
                .textFieldStyle(.roundedBorder)
                .frame(width: 300)
                .onSubmit(save)
            HStack {
                Spacer()
                Button(Strings.cancel, role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button(Strings.save, action: save)
                    .keyboardShortcut(.defaultAction)
                    .disabled(isBlank)
            }
        }
        .padding(20)
        .environment(\.colorScheme, .dark)
    }

    private var isBlank: Bool { name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    private func save() {
        guard !isBlank else { return }
        onSave(name)
        dismiss()
    }
}
