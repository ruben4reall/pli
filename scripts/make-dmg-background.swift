// swift scripts/make-dmg-background.swift [output.png]
//
// The installer window's background, drawn from the brand (docs/brand/BRAND.md: direction A "Glass", variant A1
// "Pane"): 660 x 400 points, rendered at 2x. scripts/release.sh copies it into the disk image and places Pli's icon at
// (165, 215) and Applications at (495, 215), in Finder's coordinates (points from the top left), with 112-point icons.
//
// Light on purpose. Finder draws the labels under the icons in black on any window with a background picture, whatever
// the appearance, so a Night background would hide "Pli" and "Applications". White and Paper also follow the brand's
// light-first rule for brand materials (spec 9.2, D10), and Pli's icon, a glass pane on Night, stands out most on a
// light ground. The pane's iridescent rim comes back as the lit middle of a hinge line under the labels.
import AppKit

func color(_ hex: String, alpha: CGFloat = 1) -> NSColor {
    let value = UInt64(hex.dropFirst(), radix: 16) ?? 0
    return NSColor(srgbRed: CGFloat((value >> 16) & 0xFF) / 255, green: CGFloat((value >> 8) & 0xFF) / 255,
                   blue: CGFloat(value & 0xFF) / 255, alpha: alpha)
}

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("make-dmg-background: \(message)\n".utf8))
    exit(1)
}

// Brand tokens (brand/tokens/tokens.json): scripts/tests/test-dmg-background.sh checks they are still the brand's.
let white = color("#FFFFFF"), paper = color("#F5F5F7"), ink = color("#1D1D1F"), graphite = color("#6E6E73")
let hairline = color("#D2D2D7")
let iridescent = [color("#A6F0FF"), color("#C8B8FF"), color("#FFD3B0")]

let output = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "docs/brand/dmg-background.png"
let width: CGFloat = 660, height: CGFloat = 400, scale = 2
guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(width) * scale, pixelsHigh: Int(height) * scale,
                                 bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                 colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) else { fail("no bitmap") }
rep.size = NSSize(width: width, height: height)   // 144 dpi: Finder shows it at 660 x 400 points
guard let wordmark = NSImage(contentsOfFile: "brand/wordmark/pli-wordmark-ink.svg") else {
    fail("brand/wordmark/pli-wordmark-ink.svg is missing (the brand plan draws it); run from the repository root")
}

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
// Drawing coordinates start at the bottom left: Finder's y = 215 is 400 - 215 = 185 here.

// 1. The ground: White at the top, Paper at the bottom.
NSGradient(colors: [paper, white])!.draw(in: NSRect(x: 0, y: 0, width: width, height: height), angle: 90)

// 2. The wordmark, top left, 26 points high.
let markHeight: CGFloat = 26
let markWidth = markHeight * wordmark.size.width / max(wordmark.size.height, 1)
wordmark.draw(in: NSRect(x: 40, y: height - 40 - markHeight, width: markWidth, height: markHeight))

// 3. The arrow from Pli to Applications, at icon height.
let arrow = NSBezierPath()
arrow.lineWidth = 3
arrow.lineCapStyle = .round
arrow.lineJoinStyle = .round
arrow.move(to: NSPoint(x: 262, y: 185))
arrow.line(to: NSPoint(x: 398, y: 185))
arrow.move(to: NSPoint(x: 378, y: 203))
arrow.line(to: NSPoint(x: 398, y: 185))
arrow.line(to: NSPoint(x: 378, y: 167))
graphite.withAlphaComponent(0.7).setStroke()
arrow.stroke()

// 4. The hinge: a hairline under the labels, lit in its middle by the pane's iridescent rim.
let hingeY: CGFloat = 92
NSGradient(colors: [hairline.withAlphaComponent(0), hairline, hairline, hairline.withAlphaComponent(0)],
           atLocations: [0, 0.2, 0.8, 1], colorSpace: .sRGB)!
    .draw(in: NSRect(x: 90, y: hingeY, width: 480, height: 1), angle: 0)
NSGradient(colors: [iridescent[0].withAlphaComponent(0), iridescent[0], iridescent[1], iridescent[2], iridescent[2].withAlphaComponent(0)],
           atLocations: [0, 0.25, 0.5, 0.75, 1], colorSpace: .sRGB)!
    .draw(in: NSRect(x: 230, y: hingeY - 0.5, width: 200, height: 2), angle: 0)

// 5. What to do, then who Pli is not.
func centered(_ text: String, size: CGFloat, weight: NSFont.Weight, color: NSColor, y: CGFloat) {
    let attributes: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: size, weight: weight), .foregroundColor: color]
    let textWidth = (text as NSString).size(withAttributes: attributes).width
    (text as NSString).draw(at: NSPoint(x: (width - textWidth) / 2, y: y), withAttributes: attributes)
}
centered("Drag Pli to Applications.", size: 13, weight: .medium, color: ink, y: 54)
centered("Pli is not affiliated with Apple.", size: 10.5, weight: .regular, color: graphite, y: 22)
NSGraphicsContext.restoreGraphicsState()

guard let png = rep.representation(using: .png, properties: [:]) else { fail("no PNG") }
do {
    try FileManager.default.createDirectory(at: URL(fileURLWithPath: output).deletingLastPathComponent(), withIntermediateDirectories: true)
    try png.write(to: URL(fileURLWithPath: output))
} catch {
    fail("cannot write \(output): \(error)")
}
print("DMG background: \(output)")
