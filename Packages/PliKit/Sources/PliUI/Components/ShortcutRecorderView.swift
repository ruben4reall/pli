import AppKit
import SwiftUI

/// Hears this app's own key presses while a shortcut is recorded. A local monitor: no permission is needed.
@MainActor
final class KeyMonitor {
    private var token: Any?

    /// `handler` returns true to swallow the key.
    func start(_ handler: @escaping @MainActor (UInt16, NSEvent.ModifierFlags) -> Bool) {
        guard token == nil else { return }
        token = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let code = event.keyCode, flags = event.modifierFlags
            let consumed = MainActor.assumeIsolated { handler(code, flags) }
            return consumed ? nil : event
        }
    }

    func stop() {
        if let token { NSEvent.removeMonitor(token) }
        token = nil
    }
}

/// A shortcut recorder (spec 8.3): click it and type the shortcut; Esc keeps the current one; the cross clears it,
/// and is hidden while the recorder is disabled.
struct ShortcutRecorderView: View {
    let interface: InterfaceModel
    let action: ShortcutAction
    @State private var monitor = KeyMonitor()
    @Environment(\.undoManager) private var undoManager
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        let recorder = interface.recorder
        let recording = recorder.recording == action
        let shown = recorder.display(for: action)
        VStack(alignment: .trailing, spacing: 4) {
            HStack(spacing: 6) {
                Button {
                    recording ? stop() : start()
                } label: {
                    Text(recording ? Strings.typeShortcut : (shown ?? Strings.recordShortcut))
                        .monospacedDigit()
                        .frame(minWidth: 110)
                }
                .buttonStyle(.bordered)
                .help(recording ? Strings.shortcutRecordingHelp : Strings.recordShortcut)
                .accessibilityLabel(Text(recording ? Strings.typeShortcut : Strings.shortcutValue(shown ?? Strings.recordShortcut)))
                if shown != nil, !recording, isEnabled {
                    Button {
                        recorder.clear(action, undoManager: undoManager)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Theme.Colors.secondaryText)
                    }
                    .buttonStyle(.borderless)
                    .help(Strings.clearShortcut)
                    .accessibilityLabel(Text(Strings.clearShortcut))
                }
            }
            if let problem = interface.shortcutProblem(for: action) {
                Label {
                    Text(problem).font(.footnote).foregroundStyle(Theme.Colors.secondaryText)
                } icon: {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                }
            }
        }
        .onChange(of: recorder.recording) { _, now in
            if now != action { monitor.stop() }
        }
        .onDisappear { stop() }
    }

    private func start() {
        interface.recorder.begin(action)
        monitor.start { code, flags in
            if interface.recorder.key(keyCode: code, modifiers: flags, undoManager: undoManager) {
                // Removed on the next turn, not from inside its own callback.
                Task { @MainActor in monitor.stop() }
            }
            return true
        }
    }

    private func stop() {
        monitor.stop()
        if interface.recorder.recording == action { interface.recorder.cancel() }
    }
}
