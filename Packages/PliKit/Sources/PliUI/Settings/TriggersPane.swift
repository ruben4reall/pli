import PliCore
import SwiftUI

/// Triggers: what the lid does, and the two shortcuts. What this Mac or this macOS cannot do is dimmed with the
/// reason, and keeps its stored choice for the day it can.
struct TriggersPane: View {
    let interface: InterfaceModel
    @Environment(\.undoManager) private var undoManager

    var body: some View {
        let live = interface.live
        let triggers = interface.settings.triggers
        VStack(alignment: .leading, spacing: 0) {
            CompactHeader(interface: interface)
            HStack(alignment: .top, spacing: 20) {
                VStack(alignment: .leading, spacing: 0) {
                    NoirGroupLabel(text: Strings.theLid)
                    NoirCard {
                        NoirRow(symbol: "laptopcomputer", tint: Color(red: 0.04, green: 0.52, blue: 1),
                                title: Strings.lidClose,
                                note: live.sensorAvailable ? Strings.lidCloseFootnote : Strings.noSensorTriggerNote,
                                dimmed: !live.sensorAvailable, showsDivider: false) {
                            Toggle(isOn: toggle(\.triggers.lidClose, Strings.lidClose, available: live.sensorAvailable)) { Text(Strings.lidClose) }
                                .toggleStyle(.switch).tint(Noir.green).labelsHidden().disabled(!live.sensorAvailable)
                        }
                        NoirRow(symbol: "lock.fill", tint: Color(red: 0.37, green: 0.36, blue: 0.9),
                                title: Strings.unfoldOnLockScreen,
                                note: live.lockScreenSurfaceAvailable ? Strings.usesPrivateAPI : Strings.unavailableOnThisMacOS,
                                dimmed: !live.lockScreenSurfaceAvailable) {
                            Toggle(isOn: toggle(\.triggers.unfoldOnLockScreen, Strings.unfoldOnLockScreen,
                                                available: live.lockScreenSurfaceAvailable)) { Text(Strings.unfoldOnLockScreen) }
                                .toggleStyle(.switch).tint(Noir.green).labelsHidden().disabled(!live.lockScreenSurfaceAvailable)
                        }
                        NoirRow(symbol: "arrow.up", tint: Color(red: 0.19, green: 0.7, blue: 0.36),
                                title: Strings.onUnlock, note: Strings.onUnlockFootnote) {
                            Picker(selection: binding(\.triggers.onUnlock, Strings.onUnlock)) {
                                ForEach(UnlockRevealMode.allCases, id: \.self) { mode in
                                    Text(Strings.unlockModeName(mode)).tag(mode)
                                }
                            } label: {
                                Text(Strings.onUnlock)
                            }
                            .labelsHidden()
                            .fixedSize()
                        }
                    }
                }
                VStack(alignment: .leading, spacing: 0) {
                    NoirGroupLabel(text: Strings.shortcuts)
                    NoirCard {
                        NoirRow(symbol: "play.fill", tint: Color(red: 1, green: 0.62, blue: 0.04),
                                title: Strings.demo, note: Strings.demoFootnote, showsDivider: false) {
                            Toggle(isOn: toggle(\.triggers.demoEnabled, Strings.demo)) { Text(Strings.demo) }
                                .toggleStyle(.switch).tint(Noir.green).labelsHidden()
                        }
                        ShortcutLine(interface: interface, action: .demo, enabled: triggers.demoEnabled)
                        NoirRow(symbol: "lock.fill", tint: Color(red: 0.56, green: 0.42, blue: 0.94),
                                title: Strings.animatedLock,
                                note: live.canLockNow ? Strings.animatedLockFootnote : Strings.unavailableOnThisMacOS,
                                dimmed: !live.canLockNow) {
                            Toggle(isOn: toggle(\.triggers.animatedLockEnabled, Strings.animatedLock, available: live.canLockNow)) {
                                Text(Strings.animatedLock)
                            }
                            .toggleStyle(.switch).tint(Noir.green).labelsHidden().disabled(!live.canLockNow)
                        }
                        ShortcutLine(interface: interface, action: .animatedLock,
                                     enabled: triggers.animatedLockEnabled && live.canLockNow)
                    }
                }
            }
            .padding(.horizontal, Noir.gutter + 8)
            .padding(.top, 24)
            .padding(.bottom, 32)
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

/// The shortcut of an action, under its row: the recorder, and what went wrong with the last key.
struct ShortcutLine: View {
    let interface: InterfaceModel
    let action: ShortcutAction
    let enabled: Bool

    var body: some View {
        HStack(spacing: 12) {
            Text(Strings.shortcut)
                .font(.system(size: 12))
                .foregroundStyle(enabled ? Noir.secondary : Noir.tertiary)
            Spacer()
            ShortcutRecorderView(interface: interface, action: action)
                .disabled(!enabled)
        }
        .padding(.leading, 54)
        .padding(.trailing, 14)
        .padding(.bottom, 10)
    }
}
