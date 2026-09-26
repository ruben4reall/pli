import CoreGraphics
import Foundation
import ImageIO
import Metal
import MetalKit
import PliCore
import PliRender
import UniformTypeIdentifiers

// Developer tool: renders the Pli effect to PNG frames for tuning, the website and brand images.
// pli-render (<input image> | --test-pattern WIDTHxHEIGHT) <output directory> [--preset ID] [--steps 0,0.5,1] [--width-mm 302]

struct Options {
    var input: URL?
    var testPattern: (width: Int, height: Int)?
    var output: URL
    var preset = BuiltInPresets.duo
    var steps: [Double] = [0, 0.25, 0.5, 0.75, 1]
    var widthMM = 302.0
}

enum ToolError: Error, CustomStringConvertible {
    case usage(String)
    case image(String)

    var description: String {
        switch self {
        case .usage(let message), .image(let message): return message
        }
    }
}

func parse(_ arguments: [String]) throws -> Options {
    let usage = "usage: pli-render (<image> | --test-pattern WxH) <output dir> [--preset ID] [--steps 0,0.5,1] [--width-mm 302]"
    var positional: [String] = []
    var pattern: (width: Int, height: Int)?
    var presetID = "duo"
    var steps: [Double]?
    var widthMM = 302.0
    var index = 0
    while index < arguments.count {
        let argument = arguments[index]
        func value() throws -> String {
            index += 1
            guard index < arguments.count else { throw ToolError.usage(usage) }
            return arguments[index]
        }
        switch argument {
        case "--test-pattern":
            let parts = try value().split(separator: "x").compactMap { Int($0) }
            guard parts.count == 2, parts[0] > 0, parts[1] > 0 else { throw ToolError.usage(usage) }
            pattern = (parts[0], parts[1])
        case "--preset": presetID = try value()
        case "--steps":
            let list = try value()
            let values = list.split(separator: ",", omittingEmptySubsequences: false)
                .map { Double($0.trimmingCharacters(in: .whitespaces)) }
            guard values.allSatisfy({ $0?.isFinite == true }) else {
                throw ToolError.usage("--steps needs numbers separated by commas, not \"\(list)\"\n\(usage)")
            }
            steps = values.compactMap { $0 }
        case "--width-mm":
            let text = try value()
            guard let width = Double(text), width.isFinite, width > 0 else {
                throw ToolError.usage("--width-mm needs a width above 0, not \"\(text)\"\n\(usage)")
            }
            widthMM = width
        default: positional.append(argument)
        }
        index += 1
    }
    guard let preset = BuiltInPresets.preset(id: presetID) else { throw ToolError.usage("unknown preset \(presetID)") }
    if let pattern {
        guard positional.count == 1 else { throw ToolError.usage(usage) }
        var options = Options(testPattern: pattern, output: URL(fileURLWithPath: positional[0]))
        options.preset = preset
        options.steps = steps ?? options.steps
        options.widthMM = widthMM
        return options
    }
    guard positional.count == 2 else { throw ToolError.usage(usage) }
    var options = Options(input: URL(fileURLWithPath: positional[0]), output: URL(fileURLWithPath: positional[1]))
    options.preset = preset
    options.steps = steps ?? options.steps
    options.widthMM = widthMM
    return options
}

/// A synthetic desktop: a soft gradient, three light windows with title bars and text lines.
func testPatternImage(width: Int, height: Int) throws -> CGImage {
    guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
        throw ToolError.image("cannot create a bitmap")
    }
    let colors = [CGColor(red: 0.28, green: 0.45, blue: 0.86, alpha: 1), CGColor(red: 0.93, green: 0.55, blue: 0.62, alpha: 1)] as CFArray
    let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!, colors: colors, locations: [0, 1])!
    context.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: width, y: height), options: [])
    let w = Double(width), h = Double(height)
    let windows = [CGRect(x: w * 0.08, y: h * 0.35, width: w * 0.42, height: h * 0.5),
                   CGRect(x: w * 0.55, y: h * 0.45, width: w * 0.36, height: h * 0.42),
                   CGRect(x: w * 0.30, y: h * 0.08, width: w * 0.40, height: h * 0.30)]
    for rect in windows {
        context.setFillColor(CGColor(gray: 1, alpha: 0.96))
        context.addPath(CGPath(roundedRect: rect, cornerWidth: h * 0.015, cornerHeight: h * 0.015, transform: nil))
        context.fillPath()
        context.setFillColor(CGColor(gray: 0.12, alpha: 1))
        var y = rect.maxY - rect.height * 0.18
        while y > rect.minY + rect.height * 0.08 {
            context.fill(CGRect(x: rect.minX + rect.width * 0.06, y: y, width: rect.width * 0.7, height: max(h * 0.006, 1)))
            y -= rect.height * 0.08
        }
    }
    guard let image = context.makeImage() else { throw ToolError.image("cannot render the test pattern") }
    return image
}

func loadImage(_ url: URL) throws -> CGImage {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
        throw ToolError.image("cannot read \(url.path)")
    }
    return image
}

func writePNG(_ texture: MTLTexture, to url: URL) throws {
    let width = texture.width, height = texture.height
    var halfs = [Float16](repeating: 0, count: width * height * 4)
    texture.getBytes(&halfs, bytesPerRow: width * 8, from: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0)
    var bytes = [UInt8](repeating: 255, count: width * height * 4)
    for i in 0..<(width * height * 4) {
        bytes[i] = UInt8(max(0, min(255, (Float(halfs[i]) * 255).rounded())))
    }
    guard let provider = CGDataProvider(data: Data(bytes) as CFData),
          let image = CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * 4,
                              space: CGColorSpace(name: CGColorSpace.sRGB)!,
                              bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue),
                              provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent),
          let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        throw ToolError.image("cannot encode \(url.path)")
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else { throw ToolError.image("cannot write \(url.path)") }
}

do {
    let options = try parse(Array(CommandLine.arguments.dropFirst()))
    let renderer = try GlassRenderer()
    let image = try options.testPattern.map { try testPatternImage(width: $0.width, height: $0.height) } ?? loadImage(options.input!)
    let source = try MTKTextureLoader(device: renderer.device).newTexture(cgImage: image, options: [.SRGB: false, .textureUsage: MTLTextureUsage.shaderRead.rawValue])
    let prepared = try renderer.prepareAndWait(source)
    let geometry = GlassGeometry(width: Double(source.width), height: Double(source.height), pixelsPerMM: Double(source.width) / options.widthMM)
    try FileManager.default.createDirectory(at: options.output, withIntermediateDirectories: true)
    for step in options.steps {
        let frame = GlassFrame(progress: step, parameters: options.preset.glass, geometry: geometry)
        let texture = try renderer.renderOffscreen(frame, source: prepared)
        let file = options.output.appendingPathComponent("\(options.preset.id)-\(String(format: "%.2f", step)).png")
        try writePNG(texture, to: file)
        print(file.path)
    }
} catch {
    FileHandle.standardError.write(Data("pli-render: \(error)\n".utf8))
    exit(1)
}
