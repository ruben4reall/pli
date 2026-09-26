// swift scripts/tests/check-dmg-background.swift <png>: the installer background's size and layout.
import AppKit

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("check-dmg-background: \(message)\n".utf8))
    exit(1)
}

guard CommandLine.arguments.count == 2, let data = FileManager.default.contents(atPath: CommandLine.arguments[1]),
      let rep = NSBitmapImageRep(data: data) else { fail("usage: check-dmg-background.swift <png>") }
guard rep.pixelsWide == 1320, rep.pixelsHigh == 800 else { fail("\(rep.pixelsWide) x \(rep.pixelsHigh) pixels, expected 1320 x 800") }
guard Int(rep.size.width.rounded()) == 660, Int(rep.size.height.rounded()) == 400 else {
    fail("\(rep.size.width) x \(rep.size.height) points, expected 660 x 400 (144 dpi)")
}

/// Luminance (0 to 1) at a point in Finder's coordinates: points from the top left.
func luminance(_ x: Double, _ y: Double) -> Double {
    guard let color = rep.colorAt(x: Int(x * 2), y: Int(y * 2))?.usingColorSpace(.sRGB) else { fail("no pixel at \(x), \(y)") }
    return 0.2126 * color.redComponent + 0.7152 * color.greenComponent + 0.0722 * color.blueComponent
}

func darkest(x: ClosedRange<Double>, y: ClosedRange<Double>) -> Double {
    var result = 1.0
    for px in stride(from: x.lowerBound, through: x.upperBound, by: 0.5) {
        for py in stride(from: y.lowerBound, through: y.upperBound, by: 0.5) { result = min(result, luminance(px, py)) }
    }
    return result
}

// Finder draws each 112-point icon centered at y = 215 and its label under it, in black: the ground must be light
// there, for the black labels and for Pli's dark icon.
for x in [165.0, 495.0] {
    for y in [180.0, 215.0, 250.0, 283.0, 292.0] where luminance(x, y) < 0.9 {
        fail("the ground at (\(x), \(y)) is too dark for Finder's black labels and Pli's icon")
    }
}
let ground = luminance(240, 215)
guard darkest(x: 280...380, y: 214...216) < ground - 0.2 else { fail("no arrow between the icons") }
guard darkest(x: 40...92, y: 40...66) < 0.5 else { fail("no wordmark in the top left corner") }
guard darkest(x: 250...410, y: 334...345) < 0.5 else { fail("no instruction under the hinge") }
guard darkest(x: 270...390, y: 368...377) < 0.75 else { fail("no non-affiliation notice at the bottom") }
var hinge = 0.0
for px in stride(from: 250.0, through: 410.0, by: 1) { hinge = max(hinge, abs(luminance(px, 307.5) - ground)) }
guard hinge > 0.04 else { fail("no hinge line under the labels") }
print("OK: 1320 x 800 px at 144 dpi, light under the icons and labels, arrow, wordmark, hinge and text in place")
