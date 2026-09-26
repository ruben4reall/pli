import Foundation
import Metal
import PliCore

public enum RenderQuality: Sendable, Equatable {
    case full
    case light

    var taps: Int { self == .full ? 8 : 4 }
}

/// Everything needed to draw one frame.
public struct GlassFrame: Sendable, Equatable {
    public var progress: Double
    public var parameters: GlassParameters
    public var geometry: GlassGeometry
    public var quality: RenderQuality
    public var reduceMotion: Bool

    public init(progress: Double, parameters: GlassParameters, geometry: GlassGeometry,
                quality: RenderQuality = .full, reduceMotion: Bool = false) {
        self.progress = progress
        self.parameters = parameters
        self.geometry = geometry
        self.quality = quality
        self.reduceMotion = reduceMotion
    }
}

/// Draws the frosted glass: one pyramid per source picture, one fragment pass per frame (spec 7.2).
/// Pipelines are cached per pixel format behind a lock; everything else is immutable after init.
public final class GlassRenderer: @unchecked Sendable {
    public let device: MTLDevice
    public let commandQueue: MTLCommandQueue
    private let library: MTLLibrary
    private let pyramid: BlurPyramid
    private var pipelines: [MTLPixelFormat: MTLRenderPipelineState] = [:]
    private let lock = NSLock()

    public init(device: MTLDevice? = MTLCreateSystemDefaultDevice()) throws {
        guard let device, let queue = device.makeCommandQueue() else { throw RenderError.noDevice }
        self.device = device
        self.commandQueue = queue
        do {
            library = try device.makeLibrary(source: ShaderSource.glass, options: nil)
        } catch {
            throw RenderError.libraryFailed(String(describing: error))
        }
        pyramid = try BlurPyramid(device: device, library: library)
    }

    public func prepare(_ source: MTLTexture, halfResolution: Bool = false, commandBuffer: MTLCommandBuffer) throws -> PreparedSource {
        try pyramid.encode(source: source, halfResolution: halfResolution, into: commandBuffer)
    }

    public func prepareAndWait(_ source: MTLTexture, halfResolution: Bool = false) throws -> PreparedSource {
        guard let buffer = commandQueue.makeCommandBuffer() else { throw RenderError.allocationFailed }
        let prepared = try prepare(source, halfResolution: halfResolution, commandBuffer: buffer)
        buffer.commit()
        buffer.waitUntilCompleted()
        return prepared
    }

    public func encode(_ frame: GlassFrame, source: PreparedSource, target: MTLTexture, commandBuffer: MTLCommandBuffer) throws {
        let pipeline = try pipeline(for: target.pixelFormat)
        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = target
        pass.colorAttachments[0].loadAction = .dontCare
        pass.colorAttachments[0].storeAction = .store
        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: pass) else { throw RenderError.allocationFailed }
        var uniforms = Self.uniforms(for: frame, source: source)
        encoder.setRenderPipelineState(pipeline)
        encoder.setFragmentTexture(source.texture, index: 0)
        encoder.setFragmentBytes(&uniforms, length: MemoryLayout<GlassUniforms>.stride, index: 0)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        encoder.endEncoding()
    }

    /// Renders into a new CPU-readable texture and waits. For tests and the CLI.
    public func renderOffscreen(_ frame: GlassFrame, source: PreparedSource, pixelFormat: MTLPixelFormat = .rgba16Float) throws -> MTLTexture {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: pixelFormat,
                                                                  width: Int(frame.geometry.width),
                                                                  height: Int(frame.geometry.height),
                                                                  mipmapped: false)
        descriptor.usage = [.renderTarget, .shaderRead]
        descriptor.storageMode = .shared
        guard let target = device.makeTexture(descriptor: descriptor),
              let buffer = commandQueue.makeCommandBuffer() else { throw RenderError.allocationFailed }
        try encode(frame, source: source, target: target, commandBuffer: buffer)
        buffer.commit()
        buffer.waitUntilCompleted()
        return target
    }

    static func uniforms(for frame: GlassFrame, source: PreparedSource) -> GlassUniforms {
        let o = GlassOptics.derive(progress: frame.progress, parameters: frame.parameters,
                                   geometry: frame.geometry, reduceMotion: frame.reduceMotion)
        let g = frame.parameters
        let sourceScale = Double(source.width) / max(frame.geometry.width, 1)
        return GlassUniforms(
            sizeAndProgress: SIMD4(Float(frame.geometry.width), Float(frame.geometry.height),
                                   Float(frame.progress.clamped(to: 0...1)), Float(frame.quality.taps)),
            optics: SIMD4(Float(o.tiltRadians), Float(o.eyeDistancePx), Float(o.eyeX), Float(o.eyeY)),
            blur: SIMD4(Float(o.frost), Float(o.maxBlurPx), Float(g.grain), Float(o.darkeningPerPx)),
            shape: SIMD4(Float(o.spatialAnchor), Float(o.edgeSoftnessPx), Float(o.blackout), Float(source.mipLevels)),
            tint: SIMD4(Float(g.tintColor.red), Float(g.tintColor.green), Float(g.tintColor.blue), Float(g.tintAmount)),
            color: SIMD4(Float(g.saturation), Float(g.edgeSheen), Float(g.prism), Float(sourceScale))
        )
    }

    private func pipeline(for format: MTLPixelFormat) throws -> MTLRenderPipelineState {
        lock.lock()
        defer { lock.unlock() }
        if let cached = pipelines[format] { return cached }
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = library.makeFunction(name: "pli_fullscreen")
        descriptor.fragmentFunction = library.makeFunction(name: "pli_glass")
        descriptor.colorAttachments[0].pixelFormat = format
        do {
            let state = try device.makeRenderPipelineState(descriptor: descriptor)
            pipelines[format] = state
            return state
        } catch {
            throw RenderError.pipelineFailed(String(describing: error))
        }
    }
}
