import SwiftUI

/// The wordmark's outlines, copied from `brand/wordmark/pli-wordmark-ink.svg` (the Ice file has the same paths), in
/// that file's units. The brand draws the wordmark and never types it in a font (docs/brand/BRAND.md).
struct WordmarkOutline: Shape {
    static let size = CGSize(width: 183.5, height: 184)
    /// The letters stand on this line; the p's descender reaches the bottom.
    static let baseline = 142.0
    /// The letters, with the pane that dots the i as the last shape.
    static let letters = "M0 42H21V46.79C28.33 42.56 37.53 40.4 48.5 40.4C80.13 40.4 97 58.35 97 92C97 125.65 80.13 143.6 48.5 143.6C37.53 143.6 28.33 141.44 21 137.21V184H0ZM21 64.7V119.3C26.04 123.59 33.34 125.54 43.27 125.54C65.44 125.54 74.53 115.79 74.53 92C74.53 68.21 65.44 58.46 43.27 58.46C33.34 58.46 26.04 60.41 21 64.7ZM115 0H136V142H115ZM161 42H182V142H161ZM162.7 9H180.3C182.07 9 183.5 10.43 183.5 12.2V25.8C183.5 27.02 182.52 28 181.3 28H161.7C160.48 28 159.5 27.02 159.5 25.8V12.2C159.5 10.43 160.93 9 162.7 9Z"
    /// The pane alone, which carries the iridescent rim.
    static let pane = "M162.7 9H180.3C182.07 9 183.5 10.43 183.5 12.2V25.8C183.5 27.02 182.52 28 181.3 28H161.7C160.48 28 159.5 27.02 159.5 25.8V12.2C159.5 10.43 160.93 9 162.7 9Z"
    /// Where the rim's color runs (the pane's width) and fades (its top 5.2 units).
    static let rimLeading = 159.5
    static let rimTop = 9.0
    static let rimBottom = 14.2

    let data: String

    func path(in rect: CGRect) -> Path {
        guard let outline = OutlinePath.parse(data) else { return Path() }
        let scale = min(rect.width / Self.size.width, rect.height / Self.size.height)
        let x = rect.minX + (rect.width - Self.size.width * scale) / 2
        let y = rect.minY + (rect.height - Self.size.height * scale) / 2
        return outline.applying(CGAffineTransform(a: scale, b: 0, c: 0, d: scale, tx: x, ty: y))
    }
}

/// The wordmark (spec 9.2): a lowercase "pli" whose i is dotted by a small pane of glass, its top edge catching the
/// iridescent light. Ink letters in light appearance, Ice in dark appearance. It unfolds from the hinge on its
/// baseline as the frost clears (spec 9.1); under Reduce Motion it fades in instead (docs/brand/BRAND.md, Motion).
struct Wordmark: View {
    var height: CGFloat = 104
    var unfolded = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let size = WordmarkOutline.size
        let folded = !unfolded && !reduceMotion
        ZStack {
            WordmarkOutline(data: WordmarkOutline.letters)
                .fill(Theme.Colors.wordmark)
            WordmarkOutline(data: WordmarkOutline.pane)
                .fill(Theme.iridescent(from: UnitPoint(x: WordmarkOutline.rimLeading / size.width, y: 0.5),
                                       to: UnitPoint(x: 1, y: 0.5)))
                .mask {
                    LinearGradient(stops: [.init(color: .white, location: 0), .init(color: .white, location: 0.58),
                                           .init(color: .white.opacity(0.4), location: 0.7), .init(color: .clear, location: 1)],
                                   startPoint: UnitPoint(x: 0.5, y: WordmarkOutline.rimTop / size.height),
                                   endPoint: UnitPoint(x: 0.5, y: WordmarkOutline.rimBottom / size.height))
                }
        }
        .frame(width: height * size.width / size.height, height: height)
        .rotation3DEffect(.degrees(folded ? 80 : 0), axis: (x: 1, y: 0, z: 0),
                          anchor: UnitPoint(x: 0.5, y: WordmarkOutline.baseline / size.height), perspective: 0.5)
        .blur(radius: folded ? height * 0.12 : 0)
        .opacity(unfolded ? 1 : 0)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(Strings.appName))
    }
}
