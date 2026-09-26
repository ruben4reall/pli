import AppKit
import SwiftUI

/// The MacBook of the Settings window: a 14-inch MacBook Pro in Space Black, rendered offline every 5° of lid angle
/// with RealityKit from a procedural model kept outside this repository, the display rendered in a marker colour. The
/// three-quarter frames have the display cut out; `macbook.json` gives its four corners, so the live effect is drawn
/// into the display with a projective transform.
@MainActor
final class MacBookSprites {
    static let shared = MacBookSprites()

    /// Lid angles with a frame: 0 to 135 in steps of 5.
    static let step = 5
    static let maxAngle = 135

    let threeQuarterAspect: Double
    let sideAspect: Double
    /// Display corners per angle (top left, top right, bottom right, bottom left), in fractions of the frame.
    private let screens: [Int: [CGPoint]]
    private var cache: [String: NSImage] = [:]

    private init() {
        struct File: Decodable {
            struct ThreeQuarter: Decodable { var aspect: Double; var screen: [String: [[Double]]] }
            struct Side: Decodable { var aspect: Double }
            var threeQuarter: ThreeQuarter
            var side: Side
        }
        let file = Bundle.module.url(forResource: "macbook", withExtension: "json")
            .flatMap { try? Data(contentsOf: $0) }
            .flatMap { try? JSONDecoder().decode(File.self, from: $0) }
        threeQuarterAspect = file?.threeQuarter.aspect ?? 1.49
        sideAspect = file?.side.aspect ?? 1.72
        var screens: [Int: [CGPoint]] = [:]
        for (key, corners) in file?.threeQuarter.screen ?? [:] {
            guard let angle = Int(key), corners.count == 4 else { continue }
            screens[angle] = corners.map { CGPoint(x: $0[0], y: $0[1]) }
        }
        self.screens = screens
    }

    /// The frame angle nearest to `angle`.
    static func frame(for angle: Double) -> Int {
        let clamped = min(max(angle, 0), Double(maxAngle))
        return Int((clamped / Double(step)).rounded()) * step
    }

    func threeQuarter(_ frame: Int) -> NSImage? { image(String(format: "tq-%03d", frame)) }
    func side(_ frame: Int) -> NSImage? { image(String(format: "side-%03d", frame)) }
    func screen(_ frame: Int) -> [CGPoint]? { screens[frame] }

    private func image(_ name: String) -> NSImage? {
        if let cached = cache[name] { return cached }
        guard let url = Bundle.module.url(forResource: name, withExtension: "png"), let image = NSImage(contentsOf: url) else { return nil }
        cache[name] = image
        return image
    }
}

/// A projective transform taking the rectangle `size` onto the quadrilateral `quad` (top left, top right, bottom
/// right, bottom left), for `projectionEffect` (Heckbert's square to quad, then scaled to the rectangle).
func quadTransform(from size: CGSize, to quad: [CGPoint]) -> ProjectionTransform {
    guard quad.count == 4, size.width > 0, size.height > 0 else { return ProjectionTransform() }
    let (x0, y0) = (quad[0].x, quad[0].y), (x1, y1) = (quad[1].x, quad[1].y)
    let (x2, y2) = (quad[2].x, quad[2].y), (x3, y3) = (quad[3].x, quad[3].y)
    let dx1 = x1 - x2, dx2 = x3 - x2, dx3 = x0 - x1 + x2 - x3
    let dy1 = y1 - y2, dy2 = y3 - y2, dy3 = y0 - y1 + y2 - y3
    var g = 0.0, h = 0.0
    let den = dx1 * dy2 - dx2 * dy1
    if den != 0, dx3 != 0 || dy3 != 0 {
        g = (dx3 * dy2 - dx2 * dy3) / den
        h = (dx1 * dy3 - dx3 * dy1) / den
    }
    let a = x1 - x0 + g * x1, b = x3 - x0 + h * x3, c = x0
    let d = y1 - y0 + g * y1, e = y3 - y0 + h * y3, f = y0
    var t = CATransform3DIdentity
    t.m11 = a / size.width; t.m12 = d / size.width; t.m14 = g / size.width
    t.m21 = b / size.height; t.m22 = e / size.height; t.m24 = h / size.height
    t.m41 = c; t.m42 = f; t.m44 = 1
    return ProjectionTransform(t)
}

/// The three-quarter MacBook with the effect on its display. `screenImage` is the glass as drawn by the engine;
/// vertical drags on the MacBook move the simulated lid (`onDrag` gets the new angle).
struct MacBookHero: View {
    let angle: Double
    let screenImage: CGImage?
    var onDrag: ((Double) -> Void)?
    @Environment(\.displayScale) private var displayScale
    @State private var dragStart: Double?

    var body: some View {
        let sprites = MacBookSprites.shared
        let frame = MacBookSprites.frame(for: angle)
        GeometryReader { proxy in
            let size = proxy.size
            ZStack(alignment: .topLeading) {
                if let quad = sprites.screen(frame), let screenImage {
                    let points = quad.map { CGPoint(x: $0.x * size.width, y: $0.y * size.height) }
                    let imageSize = CGSize(width: 302, height: 196)
                    Image(decorative: screenImage, scale: 1)
                        .resizable()
                        .frame(width: imageSize.width, height: imageSize.height)
                        .projectionEffect(quadTransform(from: imageSize, to: points))
                } else if let quad = sprites.screen(frame) {
                    // Before the first picture: a dark display.
                    Path { path in
                        path.addLines(quad.map { CGPoint(x: $0.x * size.width, y: $0.y * size.height) })
                        path.closeSubpath()
                    }
                    .fill(Color.black)
                }
                if let image = sprites.threeQuarter(frame) {
                    Image(nsImage: image)
                        .resizable()
                        .interpolation(.high)
                        .frame(width: size.width, height: size.height)
                }
            }
            .frame(width: size.width, height: size.height, alignment: .topLeading)
            .contentShape(.rect)
            .gesture(DragGesture(minimumDistance: 2).onChanged { value in
                guard let onDrag else { return }
                let start = dragStart ?? angle
                if dragStart == nil { dragStart = angle }
                // Dragging down closes the lid, up opens it: about a degree every 2 points.
                onDrag(min(max(start - value.translation.height / 2, 0), Double(MacBookSprites.maxAngle)))
            }.onEnded { _ in dragStart = nil })
        }
        .aspectRatio(sprites.threeQuarterAspect, contentMode: .fit)
        .accessibilityHidden(true)
    }
}

/// The MacBook in profile, at the lid angle, for the compact header and the menu bar panel.
struct MacBookSide: View {
    let angle: Double

    var body: some View {
        let sprites = MacBookSprites.shared
        Group {
            if let image = sprites.side(MacBookSprites.frame(for: angle)) {
                Image(nsImage: image).resizable().interpolation(.high)
            } else {
                Color.clear
            }
        }
        .aspectRatio(sprites.sideAspect, contentMode: .fit)
        .accessibilityHidden(true)
    }
}
