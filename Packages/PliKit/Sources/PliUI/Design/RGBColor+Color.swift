import AppKit
import PliCore
import SwiftUI

// Qualified: AppKit also brings QuickDraw's legacy RGBColor into scope.
extension PliCore.RGBColor {
    /// The tint as SwiftUI shows it, in sRGB.
    public var color: Color {
        Color(.sRGB, red: red, green: green, blue: blue)
    }

    /// A color picked in the color panel, converted to sRGB and clamped.
    public init(_ color: Color) {
        let srgb = NSColor(color).usingColorSpace(.sRGB) ?? .white
        self.init(red: Double(srgb.redComponent), green: Double(srgb.greenComponent), blue: Double(srgb.blueComponent))
        self = clamped()
    }
}
