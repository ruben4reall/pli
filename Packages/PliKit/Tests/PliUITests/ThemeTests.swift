import AppKit
import Foundation
import Testing
@testable import PliUI

@MainActor @Suite struct ThemeTests {
    typealias RGB = (red: Double, green: Double, blue: Double)

    nonisolated static let tokensFile = TestPaths.repositoryRoot.appendingPathComponent("brand/tokens/tokens.json")

    static func luminance(_ c: RGB) -> Double {
        func channel(_ v: Double) -> Double { v <= 0.04045 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4) }
        return 0.2126 * channel(c.red) + 0.7152 * channel(c.green) + 0.0722 * channel(c.blue)
    }

    static func contrast(_ a: RGB, _ b: RGB) -> Double {
        let la = luminance(a), lb = luminance(b)
        return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
    }

    static func rgb(_ hex: String) -> RGB {
        let token = Theme.Token(name: "", hex: hex)
        return (token.red, token.green, token.blue)
    }

    /// `color` as drawn over `background` in `appearance`: its alpha composited, like the screen does.
    static func resolved(_ color: NSColor, over background: RGB, in appearance: NSAppearance.Name) -> RGB {
        var result: RGB = (0, 0, 0)
        NSAppearance(named: appearance)!.performAsCurrentDrawingAppearance {
            let c = color.usingColorSpace(.sRGB)!
            let a = Double(c.alphaComponent)
            result = (Double(c.redComponent) * a + background.red * (1 - a),
                      Double(c.greenComponent) * a + background.green * (1 - a),
                      Double(c.blueComponent) * a + background.blue * (1 - a))
        }
        return result
    }

    /// Backgrounds measured on macOS 26: window, grouped-form row and Paper in light appearance; plain and
    /// wallpaper-tinted window and row in dark appearance.
    static let lightBackgrounds = ["#FFFFFF", "#F8F8F8", "#F5F5F7"]
    static let darkBackgrounds = ["#1E1E1E", "#2F2D2C", "#383635"]

    @Test func paletteMatchesSpec() {
        let expected = ["night": "#0A0C10", "slate": "#161A22", "ice": "#EEF2F6", "mist": "#8A94A3", "glacier": "#7CCBFF",
                        "deep-glacier": "#0B6FB0", "iridescent-start": "#A6F0FF", "iridescent-middle": "#C8B8FF",
                        "iridescent-end": "#FFD3B0", "white": "#FFFFFF", "paper": "#F5F5F7", "ink": "#1D1D1F",
                        "graphite": "#6E6E73", "hairline": "#D2D2D7"]
        #expect(Dictionary(uniqueKeysWithValues: Theme.Palette.all.map { ($0.name, $0.hex) }) == expected)
        #expect(abs(Theme.Palette.deepGlacier.red - 11.0 / 255) < 1e-9)
        #expect(abs(Theme.Palette.deepGlacier.blue - 176.0 / 255) < 1e-9)
    }

    @Test func secondaryTextMeetsWCAGAAInBothAppearances() {
        for hex in Self.lightBackgrounds {
            let background = Self.rgb(hex)
            let text = Self.resolved(Theme.Colors.secondaryTextNS, over: background, in: .aqua)
            #expect(Self.contrast(text, background) >= 4.5, "light on \(hex): \(Self.contrast(text, background))")
        }
        for hex in Self.darkBackgrounds {
            let background = Self.rgb(hex)
            let text = Self.resolved(Theme.Colors.secondaryTextNS, over: background, in: .darkAqua)
            #expect(Self.contrast(text, background) >= 4.5, "dark on \(hex): \(Self.contrast(text, background))")
        }
    }

    @Test func secondaryTextMeetsWCAGAAOnTheLiveWindowBackground() {
        for appearance in [NSAppearance.Name.aqua, .darkAqua] {
            let window = Self.resolved(.windowBackgroundColor, over: (0, 0, 0), in: appearance)
            let text = Self.resolved(Theme.Colors.secondaryTextNS, over: window, in: appearance)
            #expect(Self.contrast(text, window) >= 4.5, "\(appearance.rawValue): \(Self.contrast(text, window))")
        }
    }

    /// Marks of the protractor and the curve are graphics: WCAG asks 3:1.
    @Test func accentInkIsVisibleInBothAppearances() {
        for hex in Self.lightBackgrounds {
            let background = Self.rgb(hex)
            #expect(Self.contrast(Self.resolved(Theme.Colors.accentInkNS, over: background, in: .aqua), background) >= 3)
        }
        for hex in Self.darkBackgrounds {
            let background = Self.rgb(hex)
            #expect(Self.contrast(Self.resolved(Theme.Colors.accentInkNS, over: background, in: .darkAqua), background) >= 3)
        }
    }

    /// Theme.swift carries the brand's tokens for the app (docs/brand/BRAND.md): a change in tokens.json that it does not
    /// follow fails here.
    @Test(.enabled(if: FileManager.default.fileExists(atPath: ThemeTests.tokensFile.path), "brand/tokens/tokens.json is not merged yet"))
    func themeMatchesTheBrandTokens() throws {
        let data = try Data(contentsOf: Self.tokensFile)
        let text = try #require(String(data: data, encoding: .utf8))
        let hexes = Set(text.matches(of: /#[0-9A-Fa-f]{6}\b/).map { $0.output.uppercased() })
        for token in Theme.Palette.all {
            #expect(hexes.contains(token.hex.uppercased()), "\(token.name) \(token.hex) is not in brand/tokens/tokens.json")
        }
        let tokens = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let radius = try #require(tokens["radius"] as? [String: Any])
        let radii: [(String, CGFloat)] = [("s", Theme.Radius.small), ("m", Theme.Radius.medium), ("l", Theme.Radius.large),
                                          ("xl", Theme.Radius.extraLarge)]
        for (key, value) in radii {
            #expect((radius[key] as? [String: Any])?["$value"] as? String == "\(Int(value))px", "radius \(key)")
        }
        let ease = try #require((tokens["motion"] as? [String: Any])?["ease"] as? [String: Any])
        #expect((ease["fold"] as? [String: Any])?["$value"] as? [Double] == Theme.Motion.foldEase)
        #expect((ease["reveal"] as? [String: Any])?["$value"] as? [Double] == Theme.Motion.revealEase)
    }
}
