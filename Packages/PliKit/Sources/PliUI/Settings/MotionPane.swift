import PliCore
import SwiftUI

/// Motion: how the frost follows the lid. One curve, drawn from the real settings, with two handles (where the frost
/// starts, where it is complete), the curve's shape, and the two timings people change. The rest is in Fine-Tune.
struct MotionPane: View {
    let interface: InterfaceModel
    @Environment(\.undoManager) private var undoManager
    @State private var fineTuning = false

    var body: some View {
        let motion = interface.settings.motion
        VStack(alignment: .leading, spacing: 0) {
            CompactHeader(interface: interface)
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline) {
                    Text(Strings.frostByAngle)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Noir.text)
                        .accessibilityAddTraits(.isHeader)
                    Spacer()
                    Text(Strings.frostCurveHint).font(.system(size: 12)).foregroundStyle(Noir.secondary)
                }
                .padding(.bottom, 14)
                FrostCurveEditor(interface: interface)
                HStack(spacing: 12) {
                    Text(Strings.curve).font(.system(size: 12)).foregroundStyle(Noir.secondary)
                    NoirSegmented(options: FoldCurve.allCases.map { ($0, Strings.curveName($0)) },
                                  selection: Binding(get: { motion.curve }, set: {
                                      interface.editor.set(\.motion.curve, to: $0, action: Strings.curve, undoManager: undoManager)
                                  }))
                        .help(Strings.curveHelp)
                    Spacer()
                    Button(Strings.fineTuneTiming) { fineTuning = true }.buttonStyle(NoirLinkStyle())
                }
                .padding(.top, 20)
                HStack(spacing: 28) {
                    NoirSlider(setting: SettingsCatalog.smoothing, editor: interface.editor)
                    NoirSlider(setting: SettingsCatalog.unlockReveal, editor: interface.editor)
                }
                .padding(.top, 22)
            }
            .padding(.horizontal, Noir.gutter + 8)
            .padding(.top, 22)
            .padding(.bottom, 30)
        }
        .sheet(isPresented: $fineTuning) { TimingSheet(interface: interface) }
    }
}

/// Frost by angle: open on the left, closed on the right. The handles set Start Angle and Fully Frosted At; the
/// white line is the lid (real or simulated). With the sensor, each handle can also be set from the lid itself.
struct FrostCurveEditor: View {
    let interface: InterfaceModel
    @Environment(\.undoManager) private var undoManager
    @State private var dragging: WritableKeyPath<PliSettings, Double>?

    private static let maxAngle = 130.0
    private let chartHeight: CGFloat = 150

    var body: some View {
        let motion = interface.settings.motion
        let marks = interface.protractorMarks
        let points = Array(FrostCurve.points(motion: motion, rest: marks.rest).reversed())   // open first, left to right
        let readout = LidReadout(interface: interface, at: Date().timeIntervalSinceReferenceDate)
        VStack(alignment: .leading, spacing: 10) {
            GeometryReader { proxy in
                let w = proxy.size.width, h = chartHeight
                let x = { (a: Double) in CGFloat((Self.maxAngle - min(max(a, 0), Self.maxAngle)) / Self.maxAngle) * w }
                let y = { (p: Double) in h - 10 - CGFloat(p) * (h - 26) }
                ZStack(alignment: .topLeading) {
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: y(0)))
                        path.addLine(to: CGPoint(x: w, y: y(0)))
                    }
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: y(1)))
                        path.addLine(to: CGPoint(x: w, y: y(1)))
                    }
                    .stroke(Color.white.opacity(0.06), style: StrokeStyle(lineWidth: 1, dash: [4, 6]))
                    // The area under the curve, then the curve.
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: y(0)))
                        for point in points { path.addLine(to: CGPoint(x: x(point.angle), y: y(point.progress))) }
                        path.addLine(to: CGPoint(x: w, y: y(0)))
                        path.closeSubpath()
                    }
                    .fill(LinearGradient(colors: [Noir.glacier.opacity(0.28), Noir.glacier.opacity(0)], startPoint: .top, endPoint: .bottom))
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: y(points.first?.progress ?? 0)))
                        for point in points { path.addLine(to: CGPoint(x: x(point.angle), y: y(point.progress))) }
                    }
                    .stroke(Noir.glacier, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                    // The lid.
                    Rectangle().fill(Noir.text).frame(width: 1.5, height: h).offset(x: x(readout.angle) - 0.75)
                    Text(Strings.yourLid)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Noir.text)
                        .fixedSize()
                        .offset(x: x(readout.angle) + 6, y: -2)
                    handle(\.motion.startAngle, setting: SettingsCatalog.startAngle, at: CGPoint(x: x(marks.start), y: y(0)),
                           label: Strings.startsAt(Int(marks.start.rounded())), labelAbove: true, width: w)
                    handle(\.motion.fullFoldAngle, setting: SettingsCatalog.fullyFrostedAt, at: CGPoint(x: x(marks.fullyFrosted), y: y(1)),
                           label: Strings.frostedAt(Int(marks.fullyFrosted.rounded())), labelAbove: false, width: w)
                }
                .coordinateSpace(.named("frostChart"))
            }
            .frame(height: chartHeight)
            .padding(.horizontal, 18)
            .padding(.top, 20)
            .padding(.bottom, 4)
            HStack {
                ForEach([110, 90, 60, 30, 0], id: \.self) { a in
                    Text(verbatim: Strings.degrees("\(a)"))
                    if a != 0 { Spacer() }
                }
            }
            .font(.system(size: 11))
            .monospacedDigit()
            .foregroundStyle(Noir.tertiary)
            .padding(.horizontal, 18)
            .padding(.bottom, 12)
            .accessibilityHidden(true)
        }
        .background(Noir.card, in: .rect(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Noir.cardEdge, lineWidth: 0.5))
        .overlay(alignment: .topTrailing) {
            if interface.live.sensorAvailable, interface.live.lidAngle != nil {
                HStack(spacing: 14) {
                    Button(Strings.startAtMyLid) { if let lid = interface.live.lidAngle { set(\.motion.startAngle, SettingsCatalog.startAngle, lid) } }
                    Button(Strings.frostedAtMyLid) { if let lid = interface.live.lidAngle { set(\.motion.fullFoldAngle, SettingsCatalog.fullyFrostedAt, lid) } }
                }
                .buttonStyle(NoirLinkStyle())
                .padding(.trailing, 16)
                .padding(.top, 10)
            }
        }
    }

    private func set(_ keyPath: WritableKeyPath<PliSettings, Double>, _ setting: NumericSetting, _ angle: Double) {
        interface.editor.set(keyPath, to: setting.validated(angle.rounded()), action: setting.title, undoManager: undoManager)
    }

    private func handle(_ keyPath: WritableKeyPath<PliSettings, Double>, setting: NumericSetting, at point: CGPoint,
                        label: String, labelAbove: Bool, width: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(Color.white)
                .frame(width: 16, height: 16)
                .shadow(color: .black.opacity(0.5), radius: 3, y: 1)
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(Noir.secondary)
                .fixedSize()
                .offset(y: labelAbove ? -20 : 20)
        }
        .frame(width: 28, height: 28)
        .contentShape(.circle)
        .position(point)
        .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .named("frostChart")).onChanged { value in
            if dragging == nil {
                dragging = keyPath
                interface.editor.beginContinuous(keyPath)
            }
            let angle = Self.maxAngle - Double(min(max(value.location.x, 0), width) / max(width, 1)) * Self.maxAngle
            interface.editor.slide(keyPath, to: setting.validated(angle.rounded()), action: setting.title, undoManager: undoManager)
        }.onEnded { _ in
            dragging = nil
            interface.editor.endContinuous(action: setting.title, undoManager: undoManager)
        })
        .accessibilityElement()
        .accessibilityLabel(Text(setting.title))
        .accessibilityValue(Text(setting.spoken(interface.settings[keyPath: keyPath])))
        .accessibilityAdjustableAction { direction in
            let value = interface.settings[keyPath: keyPath] + (direction == .increment ? 1 : -1)
            interface.editor.set(keyPath, to: setting.validated(value), action: setting.title, undoManager: undoManager, coalescing: true)
        }
    }
}

/// Fine-Tune for Motion: every Lid and Timing setting, and Reset.
struct TimingSheet: View {
    let interface: InterfaceModel
    @Environment(\.undoManager) private var undoManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(Strings.fineTuneTiming).font(.system(size: 17, weight: .semibold))
                Spacer()
                Button(Strings.done) { dismiss() }
                    .buttonStyle(NoirButtonStyle(primary: true, small: true))
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 8)
            Form {
                Section(Strings.lidSection) {
                    ForEach(SettingsCatalog.lid) { setting in
                        SettingSlider(setting: setting, editor: interface.editor)
                    }
                }
                Section {
                    ForEach(SettingsCatalog.timing) { setting in
                        SettingSlider(setting: setting, editor: interface.editor)
                    }
                } header: {
                    Text(Strings.timingSection)
                } footer: {
                    ResetFooter(title: Strings.resetMotion) { interface.resetMotion(undoManager: undoManager) }
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
        }
        .frame(width: 600, height: 640)
        .background(Noir.window)
        .environment(\.colorScheme, .dark)
        .tint(Noir.glacier)
    }
}
