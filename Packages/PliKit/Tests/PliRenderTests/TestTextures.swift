import Metal
import simd
@testable import PliRender

enum TestTextures {
    static let device = MTLCreateSystemDefaultDevice()

    /// A CPU-readable rgba32Float texture filled by `pixel(x, y)`.
    static func make(width: Int, height: Int, pixel: (Int, Int) -> SIMD4<Float>) -> MTLTexture {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba32Float, width: width, height: height, mipmapped: false)
        descriptor.usage = [.shaderRead]
        descriptor.storageMode = .shared
        let texture = device!.makeTexture(descriptor: descriptor)!
        var data = [SIMD4<Float>](repeating: .zero, count: width * height)
        for y in 0..<height { for x in 0..<width { data[y * width + x] = pixel(x, y) } }
        texture.replace(region: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0,
                        withBytes: data, bytesPerRow: width * MemoryLayout<SIMD4<Float>>.stride)
        return texture
    }

    /// Reads a shared rgba16Float or rgba32Float texture (level 0) as floats.
    static func read(_ texture: MTLTexture) -> [SIMD4<Float>] {
        let count = texture.width * texture.height
        switch texture.pixelFormat {
        case .rgba32Float:
            var data = [SIMD4<Float>](repeating: .zero, count: count)
            texture.getBytes(&data, bytesPerRow: texture.width * 16, from: MTLRegionMake2D(0, 0, texture.width, texture.height), mipmapLevel: 0)
            return data
        default:
            var data = [SIMD4<Float16>](repeating: .zero, count: count)
            texture.getBytes(&data, bytesPerRow: texture.width * 8, from: MTLRegionMake2D(0, 0, texture.width, texture.height), mipmapLevel: 0)
            return data.map { SIMD4<Float>(Float($0.x), Float($0.y), Float($0.z), Float($0.w)) }
        }
    }

    /// Copies one mip level of a private texture into a shared rgba16Float texture and reads it.
    static func readLevel(_ texture: MTLTexture, level: Int, queue: MTLCommandQueue) -> (width: Int, height: Int, pixels: [SIMD4<Float>]) {
        let width = max(texture.width >> level, 1)
        let height = max(texture.height >> level, 1)
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba16Float, width: width, height: height, mipmapped: false)
        descriptor.storageMode = .shared
        let target = device!.makeTexture(descriptor: descriptor)!
        let buffer = queue.makeCommandBuffer()!
        let blit = buffer.makeBlitCommandEncoder()!
        blit.copy(from: texture, sourceSlice: 0, sourceLevel: level, sourceOrigin: MTLOrigin(),
                  sourceSize: MTLSize(width: width, height: height, depth: 1),
                  to: target, destinationSlice: 0, destinationLevel: 0, destinationOrigin: MTLOrigin())
        blit.endEncoding()
        buffer.commit()
        buffer.waitUntilCompleted()
        return (width, height, read(target))
    }

    static func checkerboard(width: Int, height: Int, cell: Int = 8) -> MTLTexture {
        make(width: width, height: height) { x, y in
            ((x / cell) + (y / cell)) % 2 == 0 ? SIMD4(1, 1, 1, 1) : SIMD4(0, 0, 0, 1)
        }
    }

    static func variance(_ pixels: [SIMD4<Float>]) -> Float {
        let values = pixels.map(\.x)
        let mean = values.reduce(0, +) / Float(values.count)
        return values.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Float(values.count)
    }
}
