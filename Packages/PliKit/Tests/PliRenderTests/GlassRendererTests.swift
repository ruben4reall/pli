import Foundation
import Metal
import PliCore
import simd
import Testing
@testable import PliRender

@Suite(.enabled(if: MTLCreateSystemDefaultDevice() != nil, "needs a GPU"))
struct GlassRendererTests {
    private func render(_ source: MTLTexture, progress: Double, pixelsPerMM: Double = 2,
                        _ tweak: (inout GlassParameters) -> Void = { _ in }) throws -> [SIMD4<Float>] {
        let renderer = try GlassRenderer()
        let prepared = try renderer.prepareAndWait(source)
        var parameters = GlassParameters.duo
        tweak(&parameters)
        let geometry = GlassGeometry(width: Double(source.width), height: Double(source.height), pixelsPerMM: pixelsPerMM)
        let frame = GlassFrame(progress: progress, parameters: parameters, geometry: geometry)
        return TestTextures.read(try renderer.renderOffscreen(frame, source: prepared))
    }

    @Test func zeroProgressReturnsTheSourceUnchanged() throws {
        let source = TestTextures.make(width: 64, height: 48) { x, y in
            SIMD4(Float((x * 37 + y * 11) % 255) / 255, Float((x * 5 + y * 71) % 255) / 255, Float((x + y) % 255) / 255, 1)
        }
        let input = TestTextures.read(source)
        let output = try render(source, progress: 0) { $0.prism = 1; $0.edgeSheen = 1; $0.grain = 1 }
        for (a, b) in zip(input, output) {
            #expect(abs(a.x - b.x) < 1.0 / 255 && abs(a.y - b.y) < 1.0 / 255 && abs(a.z - b.z) < 1.0 / 255)
        }
    }

    @Test func frostGrowsTowardTheTop() throws {
        let source = TestTextures.checkerboard(width: 256, height: 192, cell: 4)
        let out = try render(source, progress: 0.8) {
            $0.frost = 0.2; $0.grain = 0; $0.darkening = 0; $0.finalBlackout = 0; $0.spatialAnchor = 0; $0.maxTiltDegrees = 60
        }
        let top = (10..<40).flatMap { y in (0..<256).map { out[y * 256 + $0] } }
        let bottom = (170..<190).flatMap { y in (0..<256).map { out[y * 256 + $0] } }
        #expect(TestTextures.variance(top) < TestTextures.variance(bottom) * 0.5)
    }

    @Test func geometryMatchesTheCPUReference() throws {
        let width = 512, height = 384
        let source = TestTextures.make(width: width, height: height) { x, y in
            SIMD4((Float(x) + 0.5) / Float(width), (Float(y) + 0.5) / Float(height), 0, 1)
        }
        var parameters = GlassParameters.duo
        parameters.frost = 0; parameters.grain = 0; parameters.darkening = 0; parameters.finalBlackout = 0; parameters.edgeSoftnessMM = 0
        let ppm = Double(width) / 302
        let out = try render(source, progress: 0.6, pixelsPerMM: ppm) { $0 = parameters }
        let geometry = GlassGeometry(width: Double(width), height: Double(height), pixelsPerMM: ppm)
        let optics = GlassOptics.derive(progress: 0.6, parameters: parameters, geometry: geometry, reduceMotion: false)
        var checked = 0
        for y in stride(from: 20, to: height, by: 45) {
            for x in stride(from: 20, to: width, by: 61) {
                let s = GlassOptics.sample(x: Double(x) + 0.5, y: Double(y) + 0.5, optics: optics, geometry: geometry)
                guard !s.isBlack, s.sourceX > 2, s.sourceX < Double(width) - 2, s.sourceY > 2, s.sourceY < Double(height) - 2 else { continue }
                let pixel = out[y * width + x]
                #expect(abs(Double(pixel.x) * Double(width) - s.sourceX) < 1.5, "x at (\(x), \(y))")
                #expect(abs(Double(pixel.y) * Double(height) - s.sourceY) < 1.5, "y at (\(x), \(y))")
                checked += 1
            }
        }
        #expect(checked > 20)
    }

    @Test func uniformGrayMatchesTheCPUAttenuation() throws {
        let width = 400, height = 300
        let source = TestTextures.make(width: width, height: height) { _, _ in SIMD4(0.5, 0.5, 0.5, 1) }
        var parameters = GlassParameters.duo
        parameters.frost = 0.1; parameters.darkening = 0.1; parameters.grain = 0; parameters.spatialAnchor = 0
        let out = try render(source, progress: 0.85) { $0 = parameters }
        let geometry = GlassGeometry(width: Double(width), height: Double(height), pixelsPerMM: 2)
        let optics = GlassOptics.derive(progress: 0.85, parameters: parameters, geometry: geometry, reduceMotion: false)
        for y in stride(from: 60, to: 260, by: 50) {
            for x in stride(from: 100, to: 300, by: 50) {
                let s = GlassOptics.sample(x: Double(x) + 0.5, y: Double(y) + 0.5, optics: optics, geometry: geometry)
                let expected = 0.5 * s.attenuation * s.coverage
                #expect(abs(Double(out[y * width + x].x) - expected) < 0.02, "at (\(x), \(y))")
            }
        }
    }

    @Test func prismColorsEdgesAndLeavesFlatAreasGray() throws {
        let flat = TestTextures.make(width: 256, height: 192) { _, _ in SIMD4(0.5, 0.5, 0.5, 1) }
        let flatOut = try render(flat, progress: 0.7) { $0.prism = 1 }
        // Away from the black frame (itself an edge, so it gets fringes too), a flat picture stays gray.
        let inside = (32..<192).flatMap { y in (32..<224).map { flatOut[y * 256 + $0] } }
        #expect(inside.allSatisfy { abs($0.x - $0.y) < 1.0 / 255 && abs($0.z - $0.y) < 1.0 / 255 })
        let edge = TestTextures.make(width: 256, height: 192) { _, y in y < 96 ? SIMD4(0, 0, 0, 1) : SIMD4(1, 1, 1, 1) }
        let plain = try render(edge, progress: 0.7) { $0.prism = 0 }
        let split = try render(edge, progress: 0.7) { $0.prism = 1 }
        #expect(plain.allSatisfy { abs($0.x - $0.z) < 1.0 / 255 })
        #expect((split.map { abs($0.x - $0.z) }.max() ?? 0) > 0.05)
    }

    @Test func theEndIsBlack() throws {
        let source = TestTextures.make(width: 120, height: 80) { _, _ in SIMD4(1, 1, 1, 1) }
        let out = try render(source, progress: 1)
        #expect(out.allSatisfy { $0.x < 0.01 && $0.y < 0.01 && $0.z < 0.01 })
    }

    /// Spec 4.3 and 7.6 on the reference machine (M3 Pro, 14-inch panel): the pyramid in 6 ms, and every
    /// built-in preset at both qualities in 2 ms per frame, averaged over a whole fold. Run it alone:
    /// `PLI_PERF=1 swift test --filter staysWithinBudgetAtNativeResolution`.
    @Test(.enabled(if: ProcessInfo.processInfo.environment["PLI_PERF"] == "1", "set PLI_PERF=1"))
    func staysWithinBudgetAtNativeResolution() throws {
        let renderer = try GlassRenderer()
        let source = TestTextures.checkerboard(width: 3024, height: 1964, cell: 16)
        let prepareBuffer = try #require(renderer.commandQueue.makeCommandBuffer())
        let prepared = try renderer.prepare(source, commandBuffer: prepareBuffer)
        prepareBuffer.commit()
        prepareBuffer.waitUntilCompleted()
        let prepareMS = (prepareBuffer.gpuEndTime - prepareBuffer.gpuStartTime) * 1000
        print("pyramid \(prepareMS) ms")
        #expect(prepareMS < 6)
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: 3024, height: 1964, mipmapped: false)
        descriptor.usage = [.renderTarget]
        descriptor.storageMode = .private
        let target = try #require(renderer.device.makeTexture(descriptor: descriptor))
        let geometry = GlassGeometry(width: 3024, height: 1964, pixelsPerMM: 3024.0 / 302)
        for quality in [RenderQuality.full, .light] {
            for preset in BuiltInPresets.all {
                var total = 0.0
                for step in 0..<60 {
                    let frame = GlassFrame(progress: Double(step) / 59, parameters: preset.glass, geometry: geometry, quality: quality)
                    let buffer = try #require(renderer.commandQueue.makeCommandBuffer())
                    try renderer.encode(frame, source: prepared, target: target, commandBuffer: buffer)
                    buffer.commit()
                    buffer.waitUntilCompleted()
                    total += (buffer.gpuEndTime - buffer.gpuStartTime) * 1000
                }
                let frameMS = total / 60
                print("\(preset.id), \(quality) quality: frame \(frameMS) ms")
                #expect(frameMS < 2, "\(preset.id) at \(quality) quality: \(frameMS) ms per frame")
            }
        }
    }
}
