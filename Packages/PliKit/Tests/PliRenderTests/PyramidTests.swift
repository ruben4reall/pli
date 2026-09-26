import Metal
import Testing
@testable import PliRender

@Suite(.enabled(if: MTLCreateSystemDefaultDevice() != nil, "needs a GPU"))
struct PyramidTests {
    @Test func uniformLayoutMatchesTheShader() {
        #expect(MemoryLayout<GlassUniforms>.size == 96)
        #expect(MemoryLayout<GlassUniforms>.stride == 96)
    }

    @Test func theShaderCompiles() throws {
        let device = try #require(TestTextures.device)
        let library = try device.makeLibrary(source: ShaderSource.glass, options: nil)
        for name in ["pli_fullscreen", "pli_glass", "pli_copy", "pli_downsample"] {
            #expect(library.functionNames.contains(name))
        }
    }

    @Test func levelsGetSmootherAndKeepTheAverage() throws {
        let device = try #require(TestTextures.device)
        let library = try device.makeLibrary(source: ShaderSource.glass, options: nil)
        let queue = try #require(device.makeCommandQueue())
        let pyramid = try BlurPyramid(device: device, library: library)
        let source = TestTextures.checkerboard(width: 256, height: 192, cell: 4)
        let buffer = try #require(queue.makeCommandBuffer())
        let prepared = try pyramid.encode(source: source, halfResolution: false, into: buffer)
        buffer.commit()
        buffer.waitUntilCompleted()
        #expect(prepared.width == 256 && prepared.height == 192)
        #expect(prepared.mipLevels == 8)
        let base = TestTextures.readLevel(prepared.texture, level: 0, queue: queue)
        let blurred = TestTextures.readLevel(prepared.texture, level: 3, queue: queue)
        #expect(TestTextures.variance(blurred.pixels) < TestTextures.variance(base.pixels) * 0.5)
        let mean = blurred.pixels.map(\.x).reduce(0, +) / Float(blurred.pixels.count)
        #expect(abs(mean - 0.5) < 0.05)
    }

    @Test func halfResolutionHalvesTheBase() throws {
        let device = try #require(TestTextures.device)
        let library = try device.makeLibrary(source: ShaderSource.glass, options: nil)
        let queue = try #require(device.makeCommandQueue())
        let pyramid = try BlurPyramid(device: device, library: library)
        let buffer = try #require(queue.makeCommandBuffer())
        let prepared = try pyramid.encode(source: TestTextures.checkerboard(width: 200, height: 100), halfResolution: true, into: buffer)
        buffer.commit()
        buffer.waitUntilCompleted()
        #expect(prepared.width == 100 && prepared.height == 50)
    }
}
