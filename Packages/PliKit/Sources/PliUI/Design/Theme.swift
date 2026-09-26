import AppKit
import SwiftUI

/// Pli's brand tokens (spec 9.2), the values of `brand/tokens/tokens.json`. The app follows the system appearance:
/// views use system colors, materials and controls, and these tokens only where the brand shows or where contrast
/// needs them (footnotes, the protractor, the wordmark, the About pane).
public enum Theme {
    /// A palette color: its token name and its sRGB value.
    public struct Token: Sendable, Equatable {
        public let name: String
        public let hex: String

        public init(name: String, hex: String) {
            self.name = name
            self.hex = hex
        }

        public var red: Double { component(0) }
        public var green: Double { component(1) }
        public var blue: Double { component(2) }

        public func nsColor(alpha: Double = 1) -> NSColor {
            NSColor(srgbRed: red, green: green, blue: blue, alpha: alpha)
        }

        public var color: Color { Color(nsColor: nsColor()) }

        private func component(_ index: Int) -> Double {
            let digits = Array(hex.dropFirst())
            guard digits.count == 6 else { return 0 }
            return Double(UInt8(String(digits[(index * 2)..<(index * 2 + 2)]), radix: 16) ?? 0) / 255
        }
    }

    public enum Palette {
        public static let night = Token(name: "night", hex: "#0A0C10")
        public static let slate = Token(name: "slate", hex: "#161A22")
        public static let ice = Token(name: "ice", hex: "#EEF2F6")
        public static let mist = Token(name: "mist", hex: "#8A94A3")
        public static let glacier = Token(name: "glacier", hex: "#7CCBFF")
        public static let deepGlacier = Token(name: "deep-glacier", hex: "#0B6FB0")
        public static let iridescentStart = Token(name: "iridescent-start", hex: "#A6F0FF")
        public static let iridescentMiddle = Token(name: "iridescent-middle", hex: "#C8B8FF")
        public static let iridescentEnd = Token(name: "iridescent-end", hex: "#FFD3B0")
        public static let white = Token(name: "white", hex: "#FFFFFF")
        public static let paper = Token(name: "paper", hex: "#F5F5F7")
        public static let ink = Token(name: "ink", hex: "#1D1D1F")
        public static let graphite = Token(name: "graphite", hex: "#6E6E73")
        public static let hairline = Token(name: "hairline", hex: "#D2D2D7")

        public static let all: [Token] = [
            night, slate, ice, mist, glacier, deepGlacier, iridescentStart, iridescentMiddle, iridescentEnd,
            white, paper, ink, graphite, hairline,
        ]
    }

    /// Colors that follow the appearance.
    public enum Colors {
        /// Footnotes, value labels and captions: Graphite in light appearance; Ice at 62% in dark appearance, where
        /// Mist (made for Night) falls under 4.5:1 on macOS's wallpaper-tinted dark windows.
        public static var secondaryTextNS: NSColor { dynamic(light: Palette.graphite, dark: Palette.ice, darkAlpha: 0.62) }
        public static var secondaryText: Color { Color(nsColor: secondaryTextNS) }
        /// Lines and marks in the custom drawings: Deep Glacier in light appearance, Glacier in dark appearance.
        public static var accentInkNS: NSColor { dynamic(light: Palette.deepGlacier, dark: Palette.glacier) }
        public static var accentInk: Color { Color(nsColor: accentInkNS) }
        /// The MacBook drawn in the protractor: Ink in light appearance, Ice in dark appearance.
        public static var hardware: Color { Color(nsColor: dynamic(light: Palette.ink, dark: Palette.ice)) }
        /// The wordmark's letters, as the brand's Ink and Ice files draw them.
        public static var wordmark: Color { Color(nsColor: dynamic(light: Palette.ink, dark: Palette.ice)) }
        /// The black of the fold, behind a preview that has no picture yet.
        public static var night: Color { Palette.night.color }

        static func dynamic(light: Token, lightAlpha: Double = 1, dark: Token, darkAlpha: Double = 1) -> NSColor {
            NSColor(name: nil) { appearance in
                appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                    ? dark.nsColor(alpha: darkAlpha)
                    : light.nsColor(alpha: lightAlpha)
            }
        }
    }

    /// Key moments only (spec 9.2): the rim of the wordmark's pane. The stops run left to right, from `start` to `end`.
    public static func iridescent(from start: UnitPoint = .leading, to end: UnitPoint = .trailing) -> LinearGradient {
        LinearGradient(colors: [Palette.iridescentStart.color, Palette.iridescentMiddle.color, Palette.iridescentEnd.color],
                       startPoint: start, endPoint: end)
    }

    public enum Radius {
        public static let small: CGFloat = 8
        public static let medium: CGFloat = 12
        public static let large: CGFloat = 20
        public static let extraLarge: CGFloat = 28
    }

    /// The fold is the brand's motion (spec 9.1): the fold ease and the reveal ease of the brand tokens.
    public enum Motion {
        /// `cubic-bezier(0.65, 0, 0.35, 1)`: the fold eases in and out.
        public static let foldEase = [0.65, 0, 0.35, 1]
        /// `cubic-bezier(0.33, 1, 0.68, 1)`: the reveal, the unfold, eases out.
        public static let revealEase = [0.33, 1, 0.68, 1]

        public static func fold(_ duration: Double) -> Animation { curve(foldEase, duration) }
        public static func reveal(_ duration: Double) -> Animation { curve(revealEase, duration) }
        /// With Reduce Motion: a plain fade in place of any movement.
        public static let reduced = Animation.linear(duration: 0.15)
        public static func unlessReduced(_ animation: Animation, _ reduceMotion: Bool) -> Animation {
            reduceMotion ? reduced : animation
        }

        private static func curve(_ ease: [Double], _ duration: Double) -> Animation {
            .timingCurve(ease[0], ease[1], ease[2], ease[3], duration: duration)
        }
    }

    public enum Layout {
        /// Spec 8.3: 880 x 600 points minimum, resizable.
        public static let settingsMinimum = CGSize(width: 880, height: 600)
        public static let settingsDefault = CGSize(width: 980, height: 700)
        public static let sidebarMinimum: CGFloat = 190
        public static let sidebarIdeal: CGFloat = 210
        public static let sidebarMaximum: CGFloat = 260
        public static let panelWidth: CGFloat = 320
        public static let onboardingSize = CGSize(width: 600, height: 560)
        public static let valueLabelWidth: CGFloat = 64
        public static let presetTileWidth: CGFloat = 132
    }
}
