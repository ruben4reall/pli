import AppKit
import CoreVideo
import Metal
import PliCore
import Testing
@testable import PliRender

@MainActor @Suite(.enabled(if: MTLCreateSystemDefaultDevice() != nil, "needs a GPU"))
struct GlassSurfaceViewTests {
    private func pixelBuffer(width: Int, height: Int) throws -> CVPixelBuffer {
        let attributes: [CFString: Any] = [kCVPixelBufferIOSurfacePropertiesKey: [CFString: Any]() as CFDictionary,
                                           kCVPixelBufferMetalCompatibilityKey: true]
        var buffer: CVPixelBuffer?
        CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_32BGRA, attributes as CFDictionary, &buffer)
        return try #require(buffer)
    }

    @Test func aPixelBufferBecomesATextureWithoutACopy() throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let importer = try PixelBufferImporter(device: device)
        let buffer = try pixelBuffer(width: 64, height: 40)
        let mapped = try importer.texture(for: buffer)
        #expect(mapped.texture.width == 64 && mapped.texture.height == 40)
        #expect(mapped.texture.pixelFormat == .bgra8Unorm)
        let surface = try #require(CVPixelBufferGetIOSurface(buffer)?.takeUnretainedValue())
        #expect(mapped.texture.iosurface === surface)   // the same memory, not a copy
    }

    @Test func aBufferWithoutAnIOSurfaceIsRefused() throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let importer = try PixelBufferImporter(device: device)
        var plain: CVPixelBuffer?
        CVPixelBufferCreate(kCFAllocatorDefault, 8, 8, kCVPixelFormatType_32BGRA, nil, &plain)
        #expect(throws: RenderError.allocationFailed) { try importer.texture(for: try #require(plain)) }
    }

    @Test func theDrawableFollowsTheBoundsAtTheBackingScale() throws {
        let view = try GlassSurfaceView(renderer: try GlassRenderer(), frame: NSRect(x: 0, y: 0, width: 100, height: 50))
        let scale = NSScreen.main?.backingScaleFactor ?? 2
        #expect(view.drawableSize == CGSize(width: 100 * scale, height: 50 * scale))
        view.setFrameSize(NSSize(width: 30, height: 20))
        #expect(view.drawableSize == CGSize(width: 30 * scale, height: 20 * scale))
    }

    @Test func itDrawsBlackWithoutAPictureAndTheGlassWithOne() throws {
        let view = try GlassSurfaceView(renderer: try GlassRenderer(), frame: NSRect(x: 0, y: 0, width: 64, height: 40))
        #expect(!view.hasSource)
        #expect(view.draw(progress: 0.5, parameters: .duo, pixelsPerMM: 10))
        try view.setSource(try pixelBuffer(width: 128, height: 80), halfResolution: false)
        #expect(view.hasSource)
        #expect(view.draw(progress: 0.5, parameters: .duo, pixelsPerMM: 10, quality: .light, reduceMotion: true))
        view.presentClear()
        view.clearSource()
        #expect(!view.hasSource)
    }
}
