import CoreGraphics
import Foundation
import Metal
import PliCore
import PliRender

/// Still pictures of the effect for the preset gallery (spec 8.3: thumbnails rendered live by the real engine). One
/// blur pyramid per picture, built at half resolution and shared by every thumbnail; the pixels stay in memory.
@MainActor
public final class PreviewRenderer {
    public let renderer: GlassRenderer?
    private let importer: PixelBufferImporter?
    private var prepared: (picture: ObjectIdentifier, source: PreparedSource)?

    public init(renderer: GlassRenderer?) {
        self.renderer = renderer
        importer = renderer.flatMap { try? PixelBufferImporter(device: $0.device) }
    }

    /// The effect on `picture` at `progress`, `pixelWidth` x `pixelHeight` pixels; nil without Metal.
    public func still(of picture: PreviewPicture, progress: Double, parameters: GlassParameters,
                      pixelWidth: Int, pixelHeight: Int) -> CGImage? {
        guard let renderer, pixelWidth > 0, pixelHeight > 0, let source = source(for: picture) else { return nil }
        let geometry = GlassGeometry(width: Double(pixelWidth), height: Double(pixelHeight),
                                     pixelsPerMM: Double(pixelWidth) / picture.displayWidthMM)
        let frame = GlassFrame(progress: progress, parameters: parameters, geometry: geometry)
        guard let texture = try? renderer.renderOffscreen(frame, source: source, pixelFormat: .bgra8Unorm) else { return nil }
        return Self.image(from: texture)
    }

    /// Lets the pyramid go (Settings closed).
    public func release() {
        prepared = nil
    }

    private func source(for picture: PreviewPicture) -> PreparedSource? {
        let id = ObjectIdentifier(picture)
        if let prepared, prepared.picture == id { return prepared.source }
        guard let renderer, let importer,
              let mapped = try? importer.texture(for: picture.pixelBuffer),
              let source = try? renderer.prepareAndWait(mapped.texture, halfResolution: true) else { return nil }
        prepared = (id, source)
        return source
    }

    /// A BGRA texture read back into an in-memory image, in Display P3 like the pictures it was made from.
    static func image(from texture: MTLTexture) -> CGImage? {
        let width = texture.width, height = texture.height, bytesPerRow = width * 4
        var bytes = [UInt8](repeating: 0, count: bytesPerRow * height)
        texture.getBytes(&bytes, bytesPerRow: bytesPerRow, from: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0)
        guard let provider = CGDataProvider(data: Data(bytes) as CFData),
              let space = CGColorSpace(name: CGColorSpace.displayP3) else { return nil }
        let info = CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)
        return CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: bytesPerRow,
                       space: space, bitmapInfo: info, provider: provider, decode: nil, shouldInterpolate: true,
                       intent: .defaultIntent)
    }
}
