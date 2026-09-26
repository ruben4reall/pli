import AppKit
import PliCore
import SwiftUI

/// The panel under the menu bar symbol, Noir design: the MacBook in profile at the lid's angle with the numerals and
/// the status line, the switch, Play Fold and Fold and Lock as two tiles, the looks as chips, then the menu part.
public struct MenuBarPanel: View {
    let interface: InterfaceModel
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismiss) private var dismiss

    public init(interface: InterfaceModel) {
        self.interface = interface
    }

    public var body: some View {
        let status = interface.status
        let live = interface.live
        let angle = live.lidAngle ?? interface.protractorMarks.rest
        let followsLid = interface.settings.general.enabled && !live.paused && live.sensorAvailable && live.lidAngle != nil
            && !status.needsPermission
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 14) {
                MacBookSide(angle: angle)
                    .frame(width: 96)
                VStack(alignment: .leading, spacing: 4) {
                    Text(verbatim: live.sensorAvailable && live.lidAngle != nil ? Strings.degrees("\(Int(angle.rounded()))") : "…")
                        .font(.system(size: 36, weight: .thin))
                        .monospacedDigit()
                        .foregroundStyle(Noir.text)
                        .accessibilityHidden(true)
                    Text(followsLid ? Strings.followingYourLid : status.text)
                        .font(.system(size: 11))
                        .monospacedDigit()
                        .foregroundStyle(Noir.secondary)
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
                Toggle(isOn: Binding(get: { interface.settings.general.enabled }, set: { interface.setEnabled($0, undoManager: nil) })) {
                    Text(Strings.enablePli)
                }
                .toggleStyle(.switch)
                .tint(Noir.green)
                .labelsHidden()
                .frame(maxHeight: .infinity, alignment: .top)
            }
            .fixedSize(horizontal: false, vertical: true)
            if status.needsPermission {
                HStack(spacing: 8) {
                    Button(Strings.allowScreenRecording) { interface.requestScreenRecording() }
                        .buttonStyle(NoirButtonStyle(small: true))
                    if status.offerRelaunch {
                        Button(Strings.relaunchPli) { interface.relaunch() }
                            .buttonStyle(NoirButtonStyle(small: true))
                    }
                }
            }
            HStack(spacing: 8) {
                PanelTile(symbol: "play.fill", title: Strings.playFold, detail: interface.recorder.display(for: .demo)) {
                    interface.playDemo()
                }
                .disabled(!status.canPlayDemo)
                .help(Strings.demoHelp)
                PanelTile(symbol: "lock.fill", title: Strings.foldAndLock, detail: interface.recorder.display(for: .animatedLock)) {
                    interface.lockWithPli()
                }
                .disabled(!status.canLock)
                .help(Strings.lockHelp)
            }
            FlowChips(presets: interface.presets.all, selected: interface.presetState.preset.id,
                      title: { title(of: $0) }) { preset in
                interface.choose(preset, undoManager: nil)
            }
            Rectangle().fill(Color.white.opacity(0.1)).frame(height: 0.5).padding(.horizontal, -4)
            VStack(spacing: 0) {
                PanelMenuItem(title: Strings.settingsMenuItem, shortcut: "⌘,") { openSettings() }
                    .keyboardShortcut(",", modifiers: .command)
                PanelMenuItem(title: Strings.checkForUpdates) {
                    dismiss()
                    interface.checkForUpdates()
                }
                PanelMenuItem(title: Strings.quitPli, shortcut: "⌘Q") { interface.quit() }
                    .keyboardShortcut("q", modifiers: .command)
            }
            .padding(.horizontal, -6)
        }
        .padding(16)
        .frame(width: Theme.Layout.panelWidth)
        .background(Color.black.opacity(0.3))
        .environment(\.colorScheme, .dark)
        .preferredColorScheme(.dark)
        .tint(Noir.glacier)
        .onAppear { interface.panelDidOpen() }
    }

    private func title(of preset: Preset) -> String {
        let state = interface.presetState
        return preset.id == state.preset.id ? state.title : interface.displayName(of: preset)
    }

    private func openSettings() {
        dismiss()
        openWindow(id: PliWindow.settings.id)
        NSApplication.shared.activate()
    }
}

/// A Control Center style tile of the panel: a round symbol, a title and the shortcut.
struct PanelTile: View {
    let symbol: String
    let title: String
    let detail: String?
    let action: () -> Void
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: symbol)
                    .font(.system(size: 11, weight: .semibold))
                    .frame(width: 26, height: 26)
                    .background(Color.white.opacity(0.14), in: .circle)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title).font(.system(size: 12, weight: .medium)).lineLimit(1)
                    Text(verbatim: detail ?? " ").font(.system(size: 11)).foregroundStyle(Noir.tertiary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .foregroundStyle(Noir.text)
            .padding(.horizontal, 11)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity)
            .background(Color.white.opacity(0.07), in: .rect(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5))
            .opacity(isEnabled ? 1 : 0.45)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}

/// The looks as chips that wrap onto lines; the active one is white.
struct FlowChips: View {
    let presets: [Preset]
    let selected: String
    let title: (Preset) -> String
    let choose: (Preset) -> Void

    var body: some View {
        ChipLayout(spacing: 6) {
            ForEach(presets) { preset in
                let on = preset.id == selected
                Button { choose(preset) } label: {
                    Text(title(preset))
                        .font(.system(size: 12, weight: on ? .medium : .regular))
                        .foregroundStyle(on ? Color.black : Noir.secondary)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 5)
                        .background(on ? Noir.text : Color.white.opacity(0.08), in: .capsule)
                        .contentShape(.capsule)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(on ? [.isSelected, .isButton] : .isButton)
            }
        }
    }
}

/// Lays its subviews out left to right, wrapping onto new lines.
struct ChipLayout: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 300
        var x: CGFloat = 0, y: CGFloat = 0, line: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > 0, x + size.width > width { x = 0; y += line + spacing; line = 0 }
            x += size.width + spacing
            line = max(line, size.height)
        }
        return CGSize(width: width, height: y + line)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, line: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX { x = bounds.minX; y += line + spacing; line = 0 }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            line = max(line, size.height)
        }
    }
}

/// A row of the panel's menu part: full width, its shortcut on the right, highlighted under the pointer like a menu.
struct PanelMenuItem: View {
    let title: String
    var shortcut: String?
    let action: () -> Void
    @State private var hovering = false
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            HStack {
                Text(title).font(.system(size: 13)).foregroundStyle(Noir.text)
                Spacer()
                if let shortcut {
                    Text(verbatim: shortcut).foregroundStyle(Noir.tertiary)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .contentShape(Rectangle())
            .background {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(hovering && isEnabled ? Color.white.opacity(0.1) : Color.clear)
            }
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}

/// The menu bar symbol (spec 8.2): it redraws only when its 5° pose changes.
public struct MenuBarLabel: View {
    let live: LiveState

    public init(live: LiveState) {
        self.live = live
    }

    public var body: some View {
        let pose = live.symbolPose
        Image(nsImage: MenuBarSymbol.image(for: pose))
            .accessibilityLabel(Text(MenuBarSymbol.accessibilityLabel(for: pose)))
    }
}
