import SwiftUI

/// Pli's own look, "Noir" (validated by Ruben on 26.09.2026): one dark window, white type, soft cards, one accent
/// (Glacier). Every window and the panel are dark whatever the system appearance, like Apple's pro apps.
public enum Noir {
    public static let window = Color(red: 0x11 / 255, green: 0x12 / 255, blue: 0x16 / 255)
    public static let stageTop = Color(red: 0x18 / 255, green: 0x1B / 255, blue: 0x22 / 255)
    public static let card = Color.white.opacity(0.045)
    public static let cardEdge = Color.white.opacity(0.07)
    public static let control = Color.white.opacity(0.08)
    public static let controlOn = Color.white.opacity(0.14)
    public static let text = Color(red: 0xF5 / 255, green: 0xF5 / 255, blue: 0xF7 / 255)
    /// 7.1:1 on the window.
    public static let secondary = Color(red: 0xF5 / 255, green: 0xF5 / 255, blue: 0xF7 / 255).opacity(0.62)
    /// 4.6:1 on the window: captions and notes, never alone for meaning.
    public static let tertiary = Color(red: 0xF5 / 255, green: 0xF5 / 255, blue: 0xF7 / 255).opacity(0.46)
    public static let track = Color.white.opacity(0.12)
    public static let glacier = Theme.Palette.glacier.color
    public static let green = Color(red: 0x30 / 255, green: 0xD1 / 255, blue: 0x58 / 255)
    public static let yellow = Color(red: 0xFF / 255, green: 0xD6 / 255, blue: 0x0A / 255)
    public static let red = Color(red: 0xFF / 255, green: 0x69 / 255, blue: 0x61 / 255)

    public static let gutter: CGFloat = 36
    public static let windowWidth: CGFloat = 900
}

/// A soft card: the Noir grouping for rows and controls.
struct NoirCard<Content: View>: View {
    var padding: CGFloat = 0
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) { content }
            .padding(padding)
            .background(Noir.card, in: .rect(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Noir.cardEdge, lineWidth: 0.5))
    }
}

/// An uppercase label above a card.
struct NoirGroupLabel: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .semibold))
            .tracking(0.6)
            .foregroundStyle(Noir.tertiary)
            .padding(.leading, 4)
            .padding(.bottom, 6)
            .accessibilityAddTraits(.isHeader)
    }
}

/// One row of a card: a colored symbol, a title with an optional note, and a trailing control.
struct NoirRow<Trailing: View>: View {
    let symbol: String
    let tint: Color
    let title: String
    var note: String?
    var dimmed = false
    var showsDivider = true
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(tint, in: .rect(cornerRadius: 8))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13))
                    .foregroundStyle(dimmed ? Noir.tertiary : Noir.text)
                if let note {
                    Text(note)
                        .font(.system(size: 11))
                        .foregroundStyle(Noir.tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 8)
            trailing
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .frame(minHeight: 48)
        .overlay(alignment: .top) {
            if showsDivider { Rectangle().fill(Color.white.opacity(0.07)).frame(height: 0.5).padding(.leading, 54) }
        }
        .accessibilityElement(children: .contain)
    }
}

/// A pill button: white for the main action, glass for the others.
struct NoirButtonStyle: ButtonStyle {
    var primary = false
    var small = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: small ? 12 : 13, weight: .medium))
            .foregroundStyle(primary ? Color.black : Noir.text)
            .padding(.horizontal, small ? 12 : 16)
            .padding(.vertical, small ? 6 : 8)
            .background(primary ? Noir.text : Noir.control, in: .capsule)
            .overlay(Capsule().strokeBorder(primary ? .clear : Color.white.opacity(0.1), lineWidth: 0.5))
            .opacity(configuration.isPressed ? 0.75 : 1)
            .contentShape(.capsule)
    }
}

/// A link-like text button in Glacier.
struct NoirLinkStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12))
            .foregroundStyle(Noir.glacier.opacity(configuration.isPressed ? 0.6 : 1))
            .contentShape(.rect)
    }
}

/// The capsule tabs at the top of the Settings window.
struct NoirTabs: View {
    @Binding var selection: SettingsPane

    var body: some View {
        HStack(spacing: 2) {
            ForEach(SettingsPane.allCases) { pane in
                Button { selection = pane } label: {
                    Text(pane.title)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(selection == pane ? Noir.text : Noir.secondary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 5)
                        .background(selection == pane ? Noir.controlOn : .clear, in: .capsule)
                        .contentShape(.capsule)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selection == pane ? [.isSelected, .isButton] : .isButton)
            }
        }
        .padding(3)
        .background(Color.white.opacity(0.06), in: .capsule)
        .overlay(Capsule().strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Strings.settingsWindowTitle)
    }
}

/// A segmented choice in the Noir style.
struct NoirSegmented<Value: Hashable>: View {
    let options: [(Value, String)]
    @Binding var selection: Value

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options, id: \.0) { value, title in
                Button { selection = value } label: {
                    Text(title)
                        .font(.system(size: 12))
                        .foregroundStyle(selection == value ? Noir.text : Noir.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(selection == value ? Noir.controlOn : .clear, in: .rect(cornerRadius: 7))
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selection == value ? [.isSelected, .isButton] : .isButton)
            }
        }
        .padding(2)
        .background(Color.white.opacity(0.06), in: .rect(cornerRadius: 9))
        .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5))
    }
}
