import PliCore
import SwiftUI

/// A footnote in the brand's secondary color, which keeps 4.5:1 in both appearances (spec 8.6).
struct Footnote: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(Theme.Colors.secondaryText)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// A row's name, with an optional note under it. A dimmed row's name takes the secondary color: SwiftUI leaves a
/// disabled row's label at full strength, and spec 7.3 wants what Basic mode ignores to look dimmed.
struct RowLabel: View {
    let title: String
    var note: String?
    var dimmed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).foregroundStyle(dimmed ? Theme.Colors.secondaryText : Color.primary)
            if let note { Footnote(note) }
        }
    }
}

/// The value next to a slider: its number and unit, in tabular figures (spec 8.6).
struct ValueLabel: View {
    let text: String
    var width = Theme.Layout.valueLabelWidth

    var body: some View {
        Text(text)
            .monospacedDigit()
            .foregroundStyle(Theme.Colors.secondaryText)
            .frame(minWidth: width, alignment: .trailing)
            .accessibilityHidden(true)
    }
}

/// A slider row: the setting's name, the slider, the value with its unit. A drag is one undo step; arrow-key moves
/// within a second share one. No `step:`: SwiftUI would draw a tick per step (a dotted line for 100 steps); values snap
/// to the grid in `validated`, and the arrow keys move 5% of the range, never less than one step.
struct SettingSlider: View {
    let setting: NumericSetting
    let editor: SettingsEditor
    var disabled = false
    @Environment(\.undoManager) private var undoManager

    var body: some View {
        let value = editor.settings[keyPath: setting.keyPath]
        LabeledContent {
            HStack(spacing: 10) {
                Slider(value: Binding(get: { value }, set: { new in
                    editor.slide(setting.keyPath, to: setting.validated(new), action: setting.title, undoManager: undoManager)
                }), in: setting.range) { editing in
                    if editing {
                        editor.beginContinuous(setting.keyPath)
                    } else {
                        editor.endContinuous(action: setting.title, undoManager: undoManager)
                    }
                }
                .labelsHidden()
                .accessibilityLabel(Text(setting.title))
                .accessibilityValue(Text(setting.spoken(value)))
                ValueLabel(text: setting.text(value))
            }
        } label: {
            RowLabel(title: setting.title, dimmed: disabled)
        }
        .help(setting.help)
        .disabled(disabled)
    }
}

/// Tint (spec 7.4): the glass's color and how strongly it applies, on one row.
struct TintRow: View {
    let editor: SettingsEditor
    var disabled = false
    @Environment(\.undoManager) private var undoManager

    var body: some View {
        let setting = SettingsCatalog.tintAmount
        let amount = editor.settings.glass.tintAmount
        LabeledContent {
            HStack(spacing: 10) {
                ColorPicker(selection: Binding(get: { editor.settings.glass.tintColor.color }, set: { color in
                    editor.set(\.glass.tintColor, to: PliCore.RGBColor(color), action: Strings.tint, undoManager: undoManager, coalescing: true)
                }), supportsOpacity: false) {
                    Text(Strings.tint)
                }
                .labelsHidden()
                Slider(value: Binding(get: { amount }, set: { new in
                    editor.slide(setting.keyPath, to: setting.validated(new), action: setting.title, undoManager: undoManager)
                }), in: setting.range) { editing in
                    if editing {
                        editor.beginContinuous(setting.keyPath)
                    } else {
                        editor.endContinuous(action: setting.title, undoManager: undoManager)
                    }
                }
                .labelsHidden()
                .accessibilityLabel(Text(setting.title))
                .accessibilityValue(Text(setting.spoken(amount)))
                ValueLabel(text: setting.text(amount))
            }
        } label: {
            RowLabel(title: Strings.tint, dimmed: disabled)
        }
        .help(Strings.tintHelp)
        .disabled(disabled)
    }
}

/// A section footer: an optional note on the left, the group's Reset on the right (spec 8.6: Reset per group).
struct ResetFooter: View {
    let title: String
    var note: String?
    let action: () -> Void

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            if let note { Footnote(note) }
            Spacer()
            Button(title, action: action)
        }
    }
}

/// A one-line message with its symbol and a close button.
struct BannerRow: View {
    let banner: Banner
    let onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: banner.isProblem ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                .foregroundStyle(banner.isProblem ? Color.orange : Color.green)
                .accessibilityHidden(true)
            Text(banner.text)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 8)
            Button(action: onDismiss) {
                Image(systemName: "xmark")
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(Text(Strings.dismiss))
        }
    }
}
