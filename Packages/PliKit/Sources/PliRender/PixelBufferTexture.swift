import CoreVideo
import Metal

/// A Metal texture sharing an IOSurface-backed pixel buffer's memory: the capture reaches the GPU without a copy
/// (spec 7.2). Keep this object alive until the GPU is done reading the texture.
public final class PixelBufferTexture: @unchecked Sendable {
    public let texture: MTLTexture
    private let mapping: CVMetalTexture
    private let pixelBuffer: CVPixelBuffer

    init(texture: MTLTexture, mapping: CVMetalTexture, pixelBuffer: CVPixelBuffer) {
        self.texture = texture
        self.mapping = mapping
        self.pixelBuffer = pixelBuffer
    }
}

/// Maps BGRA pixel buffers to textures through a CoreVideo texture cache. Used on the main actor only.
public final class PixelBufferImporter: @unchecked Sendable {
    private let cache: CVMetalTextureCache

    public init(device: MTLDevice) throws {
        var cache: CVMetalTextureCache?
        guard CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, device, nil, &cache) == kCVReturnSuccess, let cache else {
            throw RenderError.allocationFailed
        }
        self.cache = cache
    }

    public func texture(for pixelBuffer: CVPixelBuffer) throws -> PixelBufferTexture {
        guard CVPixelBufferGetPixelFormatType(pixelBuffer) == kCVPixelFormatType_32BGRA,
              CVPixelBufferGetIOSurface(pixelBuffer) != nil else { throw RenderError.allocationFailed }
        let width = CVPixelBufferGetWidth(pixelBuffer), height = CVPixelBufferGetHeight(pixelBuffer)
        var mapping: CVMetalTexture?
        let status = CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault, cache, pixelBuffer, nil, .bgra8Unorm,
                                                               width, height, 0, &mapping)
        guard status == kCVReturnSuccess, let mapping, let texture = CVMetalTextureGetTexture(mapping) else {
            throw RenderError.allocationFailed
        }
        return PixelBufferTexture(texture: texture, mapping: mapping, pixelBuffer: pixelBuffer)
    }
}
