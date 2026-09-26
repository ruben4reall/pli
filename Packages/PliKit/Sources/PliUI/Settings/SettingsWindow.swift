import PliCore
import SwiftUI

/// The Settings window, Noir design: one dark window, capsule tabs in the title bar, the lid's angle always in view.
/// Its height follows the tab, like Apple's preference windows. Opening it makes Pli a regular app; closing it lets
/// the preview picture go.
public struct SettingsWindow: View {
    let interface: InterfaceModel
    @Environment(\.undoManager) private var undoManager

    public init(interface: InterfaceModel) {
        self.interface = interface
    }

    public var body: some View {
        VStack(spacing: 0) {
            pane
        }
        .frame(width: Noir.windowWidth)
        .fixedSize(horizontal: false, vertical: true)
        .background(Noir.window)
        .overlay(alignment: .top) { titleBar }
        .ignoresSafeArea(.container, edges: .top)
        .environment(\.colorScheme, .dark)
        .preferredColorScheme(.dark)
        .tint(Noir.glacier)
        .animation(.easeInOut(duration: 0.25), value: interface.pane)
        .onAppear { interface.settingsDidOpen() }
        .onDisappear { interface.settingsDidClose() }
    }

    private var titleBar: some View {
        ZStack {
            NoirTabs(selection: Binding(get: { interface.pane }, set: { interface.pane = $0 }))
            HStack(spacing: 10) {
                Spacer()
                Text(interface.settings.general.enabled ? Strings.on : Strings.off)
                    .font(.system(size: 12))
                    .foregroundStyle(Noir.secondary)
                    .accessibilityHidden(true)
                Toggle(isOn: Binding(get: { interface.settings.general.enabled },
                                     set: { interface.setEnabled($0, undoManager: undoManager) })) {
                    Text(Strings.enablePli)
                }
                .toggleStyle(.switch)
                .tint(Noir.green)
                .labelsHidden()
            }
            .padding(.trailing, 18)
        }
        .frame(height: 46)
    }

    @ViewBuilder
    private var pane: some View {
        switch interface.pane {
        case .look: LookPane(interface: interface)
        case .motion: MotionPane(interface: interface)
        case .triggers: TriggersPane(interface: interface)
        case .general: GeneralPane(interface: interface)
        }
    }
}

/// What the header shows: the lid's angle, and where it comes from.
struct LidReadout {
    var angle: Double
    var status: String
    var live: Bool

    @MainActor
    init(interface: InterfaceModel, at now: Double) {
        let preview = interface.preview
        let live = interface.live
        let marks = interface.protractorMarks
        if preview.isPlaying || !preview.followsLid && !isGhost(preview) {
            // A played fold, or its last frame: the lid moves from the rest to fully frosted with the progress.
            let p = interface.previewProgress(at: now)
            angle = marks.rest + (marks.fullyFrosted - marks.rest) * p
            status = preview.isPlaying ? Strings.playing : Strings.simulated
            self.live = false
        } else if preview.followsLid, live.sensorAvailable, let lid = live.lidAngle {
            angle = lid
            status = Strings.followingYourLid
            self.live = true
        } else {
            angle = preview.ghostAngle
            status = live.sensorAvailable ? Strings.simulated : Strings.noSensorShort
            self.live = false
        }
    }
}

@MainActor
private func isGhost(_ preview: PreviewModel) -> Bool {
    if case .ghost = preview.mode { return true }
    return false
}

/// The big angle numerals and the line under them, with Follow My Lid when the preview is simulated.
struct AngleHeadline: View {
    let interface: InterfaceModel
    let readout: LidReadout
    var compact = false

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 6 : 12) {
            HStack(alignment: .top, spacing: 2) {
                Text(verbatim: "\(Int(readout.angle.rounded()))")
                    .font(.system(size: compact ? 56 : 104, weight: .thin))
                    .tracking(compact ? -2 : -4)
                    .monospacedDigit()
                    .contentTransition(.numericText(value: readout.angle))
                Text(verbatim: "°")
                    .font(.system(size: compact ? 28 : 52, weight: .thin))
                    .foregroundStyle(Noir.secondary)
                    .padding(.top, compact ? 4 : 8)
            }
            .foregroundStyle(Noir.text)
            .accessibilityElement()
            .accessibilityLabel(Text(Strings.lidAngleAccessibility(Int(readout.angle.rounded()))))
            HStack(spacing: 8) {
                Circle()
                    .fill(readout.live ? Noir.glacier : Noir.tertiary)
                    .frame(width: 7, height: 7)
                    .shadow(color: readout.live ? Noir.glacier : .clear, radius: 5)
                    .accessibilityHidden(true)
                Text(readout.status)
                    .font(.system(size: 13))
                    .foregroundStyle(Noir.secondary)
                if !readout.live, interface.live.sensorAvailable {
                    Button(Strings.followMyLid) { interface.preview.setFollowLid(true) }
                        .buttonStyle(NoirLinkStyle())
                }
            }
        }
    }
}

/// The header of Motion, Triggers and General: the angle on the left, the MacBook in profile on the right.
struct CompactHeader: View {
    let interface: InterfaceModel

    var body: some View {
        TimelineView(.animation(minimumInterval: nil, paused: !interface.preview.isPlaying)) { context in
            let readout = LidReadout(interface: interface, at: context.date.timeIntervalSinceReferenceDate)
            HStack(alignment: .bottom) {
                AngleHeadline(interface: interface, readout: readout, compact: true)
                Spacer()
                MacBookSide(angle: readout.angle)
                    .frame(width: 150)
                    .padding(.bottom, -4)
            }
            .padding(.horizontal, Noir.gutter + 8)
            .padding(.top, 58)
            .padding(.bottom, 18)
            .background(StageBackground())
        }
    }
}

/// The soft light behind the header.
struct StageBackground: View {
    var body: some View {
        ZStack(alignment: .bottom) {
            RadialGradient(colors: [Noir.stageTop, Noir.window], center: .top, startRadius: 0, endRadius: 560)
            RadialGradient(colors: [Noir.glacier.opacity(0.10), .clear], center: UnitPoint(x: 0.66, y: 0.62),
                           startRadius: 0, endRadius: 300)
            LinearGradient(colors: [.clear, Color.white.opacity(0.08), .clear], startPoint: .leading, endPoint: .trailing)
                .frame(height: 0.5)
        }
    }
}
