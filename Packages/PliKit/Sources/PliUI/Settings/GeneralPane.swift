import AppKit
import PliCore
import SwiftUI

/// General: startup and updates, the permission, rendering; This Mac (what works here, and the memory Pli uses right
/// now); then About at the foot: the version, the links, the credits and the notice.
struct GeneralPane: View {
    let interface: InterfaceModel
    @Environment(\.undoManager) private var undoManager
    @State private var showsCredits = false

    var body: some View {
        let general = interface.settings.general
        let live = interface.live
        VStack(alignment: .leading, spacing: 0) {
            CompactHeader(interface: interface)
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top, spacing: 20) {
                    VStack(alignment: .leading, spacing: 18) {
                        VStack(alignment: .leading, spacing: 0) {
                            NoirGroupLabel(text: Strings.appName)
                            NoirCard {
                                NoirRow(symbol: "power", tint: Color(white: 0.3), title: Strings.openAtLogin, note: loginNote,
                                        dimmed: interface.loginItem == .unavailable, showsDivider: false) {
                                    if interface.loginItem == .needsApproval {
                                        Button(Strings.openLoginItems) { interface.openLoginItemsSettings() }
                                            .buttonStyle(NoirButtonStyle(small: true))
                                    }
                                    Toggle(isOn: Binding(get: { interface.loginItem == .enabled || interface.loginItem == .needsApproval },
                                                         set: { interface.setOpenAtLogin($0) })) { Text(Strings.openAtLogin) }
                                        .toggleStyle(.switch).tint(Noir.green).labelsHidden()
                                        .disabled(interface.loginItem == .unavailable)
                                }
                                NoirRow(symbol: "menubar.rectangle", tint: Color(white: 0.3), title: Strings.showInMenuBar,
                                        note: general.showInMenuBar ? nil : Strings.menuBarHiddenNote) {
                                    Toggle(isOn: toggle(\.general.showInMenuBar, Strings.showInMenuBar)) { Text(Strings.showInMenuBar) }
                                        .toggleStyle(.switch).tint(Noir.green).labelsHidden()
                                }
                                NoirRow(symbol: "arrow.down.circle.fill", tint: Color(red: 0.04, green: 0.52, blue: 1),
                                        title: Strings.updates, note: AppVersion.current.text) {
                                    if interface.supportsAutomaticUpdateChecks {
                                        Toggle(isOn: Binding(get: { interface.automaticallyChecksForUpdates },
                                                             set: { interface.automaticallyChecksForUpdates = $0 })) {
                                            Text(Strings.checkAutomatically)
                                        }
                                        .toggleStyle(.checkbox)
                                        .font(.system(size: 12))
                                    }
                                    Button(Strings.checkNow) { interface.checkForUpdates() }.buttonStyle(NoirLinkStyle())
                                }
                            }
                        }
                        VStack(alignment: .leading, spacing: 0) {
                            NoirGroupLabel(text: Strings.permissions)
                            NoirCard {
                                NoirRow(symbol: "rectangle.dashed.badge.record",
                                        tint: live.screenCaptureAllowed ? Color(red: 0.19, green: 0.7, blue: 0.36) : Color(red: 0.9, green: 0.55, blue: 0.1),
                                        title: Strings.screenRecording,
                                        note: live.screenCaptureAllowed ? Strings.pictureStaysNote : Strings.basicModeShort,
                                        showsDivider: false) {
                                    HStack(spacing: 6) {
                                        Circle().fill(live.screenCaptureAllowed ? Noir.green : Noir.yellow).frame(width: 7, height: 7)
                                        Text(live.screenCaptureAllowed ? Strings.allowed : Strings.notAllowed)
                                            .font(.system(size: 12)).foregroundStyle(Noir.secondary)
                                    }
                                    if !live.screenCaptureAllowed {
                                        Button(Strings.allow) { interface.openScreenRecordingSettings() }
                                            .buttonStyle(NoirButtonStyle(small: true))
                                    }
                                }
                            }
                        }
                    }
                    VStack(alignment: .leading, spacing: 18) {
                        VStack(alignment: .leading, spacing: 0) {
                            NoirGroupLabel(text: Strings.rendering)
                            NoirCard {
                                NoirRow(symbol: "cube.transparent", tint: Color(red: 0.12, green: 0.65, blue: 0.77),
                                        title: Strings.quality, note: Strings.renderingFootnote, showsDivider: false) {
                                    Picker(selection: binding(\.general.rendering, Strings.rendering)) {
                                        ForEach(RenderingMode.allCases, id: \.self) { mode in
                                            Text(Strings.renderingModeName(mode)).tag(mode)
                                        }
                                    } label: {
                                        Text(Strings.rendering)
                                    }
                                    .labelsHidden().fixedSize()
                                }
                                NoirRow(symbol: "battery.50", tint: Color(red: 0.12, green: 0.65, blue: 0.77),
                                        title: Strings.lighterInLowPower, note: Strings.lighterFootnote) {
                                    Toggle(isOn: toggle(\.general.lighterInLowPower, Strings.lighterInLowPower)) { Text(Strings.lighterInLowPower) }
                                        .toggleStyle(.switch).tint(Noir.green).labelsHidden()
                                }
                                NoirRow(symbol: "circle.dotted.circle", tint: Color(red: 0.12, green: 0.65, blue: 0.77),
                                        title: Strings.followReduceMotion, note: Strings.reduceMotionFootnote) {
                                    Toggle(isOn: toggle(\.general.followReduceMotion, Strings.followReduceMotion)) { Text(Strings.followReduceMotion) }
                                        .toggleStyle(.switch).tint(Noir.green).labelsHidden()
                                }
                                NoirRow(symbol: "cursorarrow", tint: Color(red: 0.12, green: 0.65, blue: 0.77),
                                        title: Strings.hideCursor,
                                        note: live.cursorHidingAvailable ? Strings.usesPrivateAPI : Strings.unavailableOnThisMacOS,
                                        dimmed: !live.cursorHidingAvailable) {
                                    Toggle(isOn: toggle(\.general.hideCursor, Strings.hideCursor, available: live.cursorHidingAvailable)) {
                                        Text(Strings.hideCursor)
                                    }
                                    .toggleStyle(.switch).tint(Noir.green).labelsHidden().disabled(!live.cursorHidingAvailable)
                                }
                            }
                        }
                    }
                }
                ThisMacCard(interface: interface)
                AboutFooter(showsCredits: $showsCredits) { interface.showWelcome() }
            }
            .padding(.horizontal, Noir.gutter + 8)
            .padding(.top, 24)
            .padding(.bottom, 26)
        }
        .onAppear { interface.refreshLoginItem() }
        .sheet(isPresented: $showsCredits) { CreditsSheet() }
    }

    private var loginNote: String? {
        if let problem = interface.loginProblem { return problem }
        switch interface.loginItem {
        case .needsApproval: return Strings.loginNeedsApproval
        case .unavailable: return Strings.loginUnavailable
        case .enabled, .disabled: return nil
        }
    }

    private func toggle(_ keyPath: WritableKeyPath<PliSettings, Bool>, _ action: String, available: Bool = true) -> Binding<Bool> {
        Binding(get: { available && interface.settings[keyPath: keyPath] },
                set: { interface.editor.set(keyPath, to: $0, action: action, undoManager: undoManager) })
    }

    private func binding<Value: Equatable>(_ keyPath: WritableKeyPath<PliSettings, Value>, _ action: String) -> Binding<Value> {
        Binding(get: { interface.settings[keyPath: keyPath] },
                set: { interface.editor.set(keyPath, to: $0, action: action, undoManager: undoManager) })
    }
}

/// This Mac: the model and chip, whether Pli can read the lid (and so what works), and the memory Pli uses right now,
/// refreshed every two seconds while the card is on screen.
struct ThisMacCard: View {
    let interface: InterfaceModel

    var body: some View {
        let compatibility = Compatibility(live: interface.live.snapshot)
        VStack(alignment: .leading, spacing: 0) {
            NoirGroupLabel(text: Strings.thisMac)
            HStack(alignment: .top, spacing: 0) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Circle().fill(compatibility.level == .full ? Noir.green : Noir.yellow).frame(width: 9, height: 9)
                        Text(compatibility.level == .full ? Strings.foldsWithYourLid : Strings.shortcutsOnly)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Noir.text)
                    }
                    Text(compatibility.level == .full ? Strings.foldsWithYourLidNote : Strings.shortcutsOnlyNote)
                        .font(.system(size: 12))
                        .foregroundStyle(Noir.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(verbatim: [ThisMac.family, ThisMac.chip, ThisMac.modelIdentifier].compactMap { $0 }.joined(separator: " · "))
                        .font(.system(size: 11))
                        .foregroundStyle(Noir.tertiary)
                        .textSelection(.enabled)
                    HStack(spacing: 14) {
                        FeatureMark(text: Strings.lidClose, on: compatibility.level == .full)
                        FeatureMark(text: Strings.demo, on: true)
                        FeatureMark(text: Strings.animatedLock, on: compatibility.animatedLock)
                        FeatureMark(text: Strings.lockScreenShort, on: compatibility.lockScreen)
                    }
                    .padding(.top, 4)
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                Rectangle().fill(Color.white.opacity(0.07)).frame(width: 0.5)
                MemoryReadout()
                    .padding(18)
                    .frame(width: 260, alignment: .leading)
            }
            .background(Noir.card, in: .rect(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Noir.cardEdge, lineWidth: 0.5))
        }
    }
}

/// A feature and whether it works on this Mac.
struct FeatureMark: View {
    let text: String
    let on: Bool

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: on ? "checkmark.circle.fill" : "minus.circle")
                .foregroundStyle(on ? Noir.green : Noir.tertiary)
                .accessibilityHidden(true)
            Text(text)
                .foregroundStyle(on ? Noir.secondary : Noir.tertiary)
        }
        .font(.system(size: 11))
        .accessibilityElement(children: .combine)
        .accessibilityValue(Text(on ? Strings.works : Strings.unavailable))
    }
}

/// The memory Pli uses right now, and what that is next to the Mac's memory.
struct MemoryReadout: View {
    @State private var bytes: UInt64?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(Strings.memoryNow)
                .font(.system(size: 12))
                .foregroundStyle(Noir.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(verbatim: bytes.map { "\(ThisMac.megabytes($0))" } ?? "…")
                    .font(.system(size: 34, weight: .semibold))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Text(Strings.megabytesUnit)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Noir.secondary)
            }
            .foregroundStyle(Noir.text)
            if let bytes {
                Text(Strings.memoryShare(ThisMac.shareOfMemory(bytes), ThisMac.memoryGB))
                    .font(.system(size: 11))
                    .foregroundStyle(Noir.tertiary)
            }
            Text(Strings.memoryFoldNote)
                .font(.system(size: 11))
                .foregroundStyle(Noir.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
        .task {
            while !Task.isCancelled {
                withAnimation(.snappy) { bytes = ThisMac.memoryFootprint() }
                try? await Task.sleep(for: .seconds(2))
            }
        }
    }
}

/// About, at the foot of General: the icon, the version and the notice, then the links on one line.
struct AboutFooter: View {
    @Binding var showsCredits: Bool
    let showWelcome: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable()
                .frame(width: 40, height: 40)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(verbatim: "\(Strings.appName) \(AppVersion.current.short)")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Noir.text)
                    Text(Strings.signature)
                        .font(.system(size: 12))
                        .foregroundStyle(Noir.secondary)
                }
                HStack(spacing: 16) {
                    Link(destination: Links.website) { Text(Strings.website) }
                    Link(destination: Links.repository) { Text(Strings.github) }
                    Link(destination: Links.newIssue) { Text(Strings.reportIssue) }
                    Button(Strings.credits) { showsCredits = true }.buttonStyle(NoirLinkStyle())
                    Button(Strings.showWelcomeAgain, action: showWelcome).buttonStyle(NoirLinkStyle())
                }
                .font(.system(size: 12))
                .tint(Noir.glacier)
                Text(Strings.notAffiliated)
                    .font(.system(size: 11))
                    .foregroundStyle(Noir.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.top, 2)
    }
}

/// The credits (Appendix C) and the license, in a small sheet.
struct CreditsSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(Strings.credits).font(.system(size: 17, weight: .semibold))
            ForEach(Links.credits) { credit in
                Link(destination: credit.url) {
                    Text(credit.text).multilineTextAlignment(.leading)
                }
                .font(.system(size: 12))
            }
            Text(Strings.license).font(.system(size: 11)).foregroundStyle(Noir.tertiary)
            HStack {
                Spacer()
                Button(Strings.done) { dismiss() }.buttonStyle(NoirButtonStyle(primary: true, small: true)).keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 460)
        .background(Noir.window)
        .environment(\.colorScheme, .dark)
        .tint(Noir.glacier)
    }
}

/// The version, from the app's Info.plist.
struct AppVersion: Equatable {
    var short: String
    var build: String
    var text: String { Strings.version(short, build) }

    static func from(_ info: [String: Any]?) -> AppVersion {
        AppVersion(short: info?["CFBundleShortVersionString"] as? String ?? "0.0",
                   build: info?["CFBundleVersion"] as? String ?? "0")
    }

    static var current: AppVersion { from(Bundle.main.infoDictionary) }
}
