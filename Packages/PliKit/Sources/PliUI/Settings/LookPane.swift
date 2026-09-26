import PliCore
import SwiftUI
import UniformTypeIdentifiers

/// Look: the angle, the MacBook with the real effect on its display, Play Fold and Unfold, then the looks and the
/// three settings that matter most. Everything else is in Fine-Tune.
struct LookPane: View {
    let interface: InterfaceModel
    @Environment(\.undoManager) private var undoManager
    @State private var fineTuning = false
    @State private var naming = false
    @State private var renaming: Preset?
    @State private var deleting: Preset?
    @State private var exporting: PresetDocument?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            LookStage(interface: interface)
            VStack(alignment: .leading, spacing: 0) {
                if interface.basicModeReason == .permissionMissing {
                    NoirNotice(symbol: "exclamationmark.triangle.fill", tint: Noir.yellow, text: Strings.basicModeBanner,
                               action: Strings.openSystemSettings) { interface.openScreenRecordingSettings() }
                        .padding(.bottom, 16)
                }
                if let banner = interface.banner {
                    NoirNotice(symbol: banner.isProblem ? "exclamationmark.circle.fill" : "checkmark.circle.fill",
                               tint: banner.isProblem ? Noir.red : Noir.green, text: banner.text,
                               action: Strings.dismiss) { interface.dismissBanner() }
                        .padding(.bottom, 16)
                }
                HStack(alignment: .firstTextBaseline) {
                    Text(Strings.look)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Noir.text)
                        .accessibilityAddTraits(.isHeader)
                    Spacer()
                    Text(interface.presetState.title)
                        .font(.system(size: 12))
                        .foregroundStyle(Noir.secondary)
                    Text(verbatim: "·").foregroundStyle(Noir.tertiary).accessibilityHidden(true)
                    Button(Strings.fineTune) { fineTuning = true }
                        .buttonStyle(NoirLinkStyle())
                }
                .padding(.bottom, 14)
                LooksStrip(interface: interface, naming: $naming, renaming: $renaming, deleting: $deleting, exporting: $exporting)
                HStack(spacing: 28) {
                    NoirSlider(setting: SettingsCatalog.frost, editor: interface.editor,
                               disabled: interface.basicModeReason != nil)
                    NoirSlider(setting: SettingsCatalog.darkening, editor: interface.editor)
                    NoirSlider(setting: SettingsCatalog.maxTilt, editor: interface.editor,
                               disabled: interface.basicModeReason != nil)
                }
                .padding(.top, 24)
            }
            .padding(.horizontal, Noir.gutter + 8)
            .padding(.top, 22)
            .padding(.bottom, 30)
        }
        .sheet(isPresented: $fineTuning) { FineTuneSheet(interface: interface) }
        .sheet(isPresented: $naming) {
            PresetNameSheet(title: Strings.newPreset, name: interface.presetState.name) { interface.saveAsPreset(named: $0) }
        }
        .sheet(item: $renaming) { preset in
            PresetNameSheet(title: Strings.renamePreset, name: preset.name) { interface.renamePreset(preset, to: $0) }
        }
        .confirmationDialog(deleting.map { Strings.deletePresetTitle($0.name) } ?? Strings.delete,
                            isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }),
                            presenting: deleting) { preset in
            Button(Strings.deleteConfirm, role: .destructive) { interface.deletePreset(preset) }
            Button(Strings.cancel, role: .cancel) {}
        } message: { _ in
            Text(Strings.deletePresetMessage)
        }
        .fileExporter(isPresented: Binding(get: { exporting != nil }, set: { if !$0 { exporting = nil } }), document: exporting,
                      contentType: .pliPreset, defaultFilename: exporting.map { PresetTransfer.fileName(for: $0.preset.name) }) { _ in
            exporting = nil
        }
    }
}

/// The top of Look: the angle and the simulated lid on the left, the MacBook on the right.
struct LookStage: View {
    let interface: InterfaceModel

    var body: some View {
        let preview = interface.preview
        TimelineView(.animation(minimumInterval: nil, paused: !preview.isPlaying)) { context in
            let now = context.date.timeIntervalSinceReferenceDate
            let readout = LidReadout(interface: interface, at: now)
            let progress = interface.previewProgress(at: now)
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 0) {
                    AngleHeadline(interface: interface, readout: readout)
                    LidSlider(interface: interface, angle: readout.angle)
                        .frame(width: 250)
                        .padding(.top, 26)
                    HStack(spacing: 10) {
                        Button { interface.playPreview(.fold) } label: {
                            Label(Strings.playFold, systemImage: "play.fill").labelStyle(.titleAndIcon)
                        }
                        .buttonStyle(NoirButtonStyle(primary: true))
                        Button(Strings.playUnfold) { interface.playPreview(.unfold) }
                            .buttonStyle(NoirButtonStyle())
                        Button { interface.playDemo() } label: { Label(Strings.demo, systemImage: "rectangle.inset.filled").labelStyle(.titleAndIcon) }
                            .buttonStyle(NoirButtonStyle())
                            .disabled(!interface.status.canPlayDemo)
                            .help(Strings.demoHelp)
                    }
                    .padding(.top, 30)
                }
                .frame(width: 350, alignment: .leading)
                Spacer(minLength: 0)
                ScreenEffect(interface: interface, progress: progress) { image in
                    MacBookHero(angle: readout.angle, screenImage: image) { interface.preview.setGhost(angle: $0.rounded()) }
                }
                .frame(width: 440)
                .offset(x: 12)
            }
            .padding(.leading, Noir.gutter + 8)
            .padding(.trailing, Noir.gutter - 8)
            .padding(.top, 60)
            .padding(.bottom, 26)
            .background(StageBackground())
        }
    }
}

/// Renders the effect the display shows, with the real engine on the preview picture, and hands it to `content`.
struct ScreenEffect<Content: View>: View {
    let interface: InterfaceModel
    let progress: Double
    @ViewBuilder var content: (CGImage?) -> Content
    @State private var image: CGImage?

    struct Key: Equatable {
        var picture: ObjectIdentifier?
        var progress: Double
        var parameters: GlassParameters
        var reduceMotion: Bool
    }

    var body: some View {
        content(image)
            .task(id: Key(picture: interface.preview.picture.map(ObjectIdentifier.init), progress: (progress * 400).rounded() / 400,
                          parameters: interface.settings.glass, reduceMotion: interface.previewReduceMotion)) {
                guard let picture = interface.preview.picture else {
                    image = nil
                    return
                }
                image = interface.renderer.still(of: picture, progress: progress, parameters: interface.settings.glass,
                                                 pixelWidth: 1008, pixelHeight: Int(1008 / picture.aspectRatio))
            }
    }
}

/// The simulated lid: open on the left, closed on the right, with the marks where the frost starts and where the fold
/// is complete. Drag it or use the arrow keys; it follows the real lid when Follow My Lid is on.
struct LidSlider: View {
    let interface: InterfaceModel
    let angle: Double
    @FocusState private var focused: Bool

    private static let maxAngle = 130.0

    var body: some View {
        let marks = interface.protractorMarks
        VStack(alignment: .leading, spacing: 8) {
            GeometryReader { proxy in
                let width = proxy.size.width
                let x = { (a: Double) in CGFloat((Self.maxAngle - min(max(a, 0), Self.maxAngle)) / Self.maxAngle) * width }
                ZStack(alignment: .leading) {
                    Capsule().fill(Noir.track).frame(height: 4)
                    Capsule()
                        .fill(LinearGradient(colors: [Noir.glacier.opacity(0.2), Noir.glacier], startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(0, x(angle) - x(marks.start)), height: 4)
                        .offset(x: x(marks.start))
                    ForEach([marks.start, marks.fullyFrosted], id: \.self) { mark in
                        RoundedRectangle(cornerRadius: 1).fill(Noir.tertiary).frame(width: 2, height: 12).offset(x: x(mark) - 1)
                    }
                    Circle()
                        .fill(Color.white)
                        .frame(width: 16, height: 16)
                        .shadow(color: .black.opacity(0.5), radius: 3, y: 1)
                        .overlay(Circle().stroke(Noir.glacier, lineWidth: focused ? 2 : 0))
                        .offset(x: x(angle) - 8)
                }
                .frame(height: 16)
                .contentShape(.rect)
                .gesture(DragGesture(minimumDistance: 0).onChanged { value in
                    let a = Self.maxAngle - Double(value.location.x / max(width, 1)) * Self.maxAngle
                    interface.preview.setGhost(angle: a.rounded())
                })
            }
            .frame(height: 16)
            HStack {
                Text(verbatim: Strings.degrees("\(Int(marks.start.rounded()))"))
                Spacer()
                Text(verbatim: Strings.degrees("\(Int(marks.fullyFrosted.rounded()))"))
            }
            .font(.system(size: 11))
            .monospacedDigit()
            .foregroundStyle(Noir.tertiary)
            .accessibilityHidden(true)
        }
        .focusable()
        .focused($focused)
        .focusEffectDisabled()
        .onKeyPress(keys: [.leftArrow, .rightArrow]) { press in
            let step = press.modifiers.contains(.shift) ? 5.0 : 1.0
            interface.preview.nudgeGhost(by: press.key == .rightArrow ? -step : step)
            return .handled
        }
        .accessibilityElement()
        .accessibilityLabel(Text(Strings.simulatedLidAngle))
        .accessibilityValue(Text(ValueFormat.spoken(angle, unit: .degrees, range: ProtractorGeometry.angleRange)))
        .accessibilityAdjustableAction { direction in
            interface.preview.nudgeGhost(by: direction == .increment ? 1 : -1)
        }
    }
}

/// The looks: every preset drawn by the engine on the preview picture, and a tile to save the current look.
struct LooksStrip: View {
    let interface: InterfaceModel
    @Binding var naming: Bool
    @Binding var renaming: Preset?
    @Binding var deleting: Preset?
    @Binding var exporting: PresetDocument?
    @Environment(\.undoManager) private var undoManager

    var body: some View {
        let state = interface.presetState
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 8) {
                ForEach(interface.presets.all) { preset in
                    let selected = preset.id == state.preset.id
                    Button { interface.choose(preset, undoManager: undoManager) } label: {
                        VStack(spacing: 8) {
                            PresetThumbnail(renderer: interface.renderer, picture: interface.preview.picture,
                                            parameters: preset.glass, width: 84, cornerRadius: 11)
                                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5))
                                .padding(3)
                                .overlay(RoundedRectangle(cornerRadius: 15).strokeBorder(selected ? Noir.glacier : .clear, lineWidth: 2))
                            Text(interface.displayName(of: preset))
                                .font(.system(size: 12, weight: selected ? .medium : .regular))
                                .foregroundStyle(selected ? Noir.text : Noir.secondary)
                                .lineLimit(1)
                                .frame(width: 90)
                        }
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selected ? .isSelected : [])
                    .contextMenu { menu(for: preset, state: state) }
                }
                Button { naming = true } label: {
                    VStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(Color.white.opacity(0.18), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                            .frame(width: 84, height: 55)
                            .overlay(Image(systemName: "plus").font(.system(size: 16, weight: .medium)).foregroundStyle(Noir.secondary))
                            .padding(3)
                        Text(Strings.saveLook)
                            .font(.system(size: 12))
                            .foregroundStyle(Noir.secondary)
                            .frame(width: 90)
                    }
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .help(Strings.saveAsPreset)
            }
            .padding(.horizontal, 1)
        }
        .scrollClipDisabled()
    }

    @ViewBuilder
    private func menu(for preset: Preset, state: PresetState) -> some View {
        if !preset.isBuiltIn {
            if preset.id == state.preset.id, state.isModified {
                Button(Strings.saveChanges) { interface.saveChangesToActivePreset() }
            }
            Button(Strings.rename) { renaming = preset }
        }
        Button(Strings.duplicate) { interface.duplicatePreset(preset) }
        Button(Strings.exportPreset) { exporting = interface.exportDocument(for: preset) }
        if !preset.isBuiltIn {
            Divider()
            Button(Strings.delete, role: .destructive) { deleting = preset }
        }
    }
}

/// A setting as Noir shows it up front: its name and value above a slider.
struct NoirSlider: View {
    let setting: NumericSetting
    let editor: SettingsEditor
    var disabled = false
    @Environment(\.undoManager) private var undoManager

    var body: some View {
        let value = editor.settings[keyPath: setting.keyPath]
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(setting.title).foregroundStyle(disabled ? Noir.tertiary : Noir.secondary)
                Spacer()
                Text(setting.text(value)).foregroundStyle(disabled ? Noir.tertiary : Noir.text).monospacedDigit()
            }
            .font(.system(size: 12))
            .accessibilityHidden(true)
            Slider(value: Binding(get: { value }, set: { new in
                editor.slide(setting.keyPath, to: setting.validated(new), action: setting.title, undoManager: undoManager)
            }), in: setting.range) { editing in
                if editing {
                    editor.beginContinuous(setting.keyPath)
                } else {
                    editor.endContinuous(action: setting.title, undoManager: undoManager)
                }
            }
            .tint(Noir.text)
            .labelsHidden()
            .accessibilityLabel(Text(setting.title))
            .accessibilityValue(Text(setting.spoken(value)))
        }
        .help(setting.help)
        .disabled(disabled)
        .frame(maxWidth: .infinity)
    }
}

/// A one-line notice above the looks: the permission, an import.
struct NoirNotice: View {
    let symbol: String
    let tint: Color
    let text: String
    let action: String
    let perform: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbol).foregroundStyle(tint).accessibilityHidden(true)
            Text(text)
                .font(.system(size: 12))
                .foregroundStyle(Noir.text)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 8)
            Button(action, action: perform).buttonStyle(NoirButtonStyle(small: true))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Noir.card, in: .rect(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Noir.cardEdge, lineWidth: 0.5))
    }
}
