import Metal

/// A source picture and its progressively blurred mip levels, built once per capture (spec 7.2).
public final class PreparedSource: @unchecked Sendable {
    public let texture: MTLTexture
    public var width: Int { texture.width }
    public var height: Int { texture.height }
    public var mipLevels: Int { texture.mipmapLevelCount }

    init(texture: MTLTexture) {
        self.texture = texture
    }
}

struct BlurPyramid {
    static let maxLevels = 8

    let device: MTLDevice
    let copy: MTLComputePipelineState
    let downsample: MTLComputePipelineState

    init(device: MTLDevice, library: MTLLibrary) throws {
        self.device = device
        guard let copyFunction = library.makeFunction(name: "pli_copy"),
              let downsampleFunction = library.makeFunction(name: "pli_downsample") else {
            throw RenderError.pipelineFailed("missing pyramid kernels")
        }
        do {
            copy = try device.makeComputePipelineState(function: copyFunction)
            downsample = try device.makeComputePipelineState(function: downsampleFunction)
        } catch {
            throw RenderError.pipelineFailed(String(describing: error))
        }
    }

    func encode(source: MTLTexture, halfResolution: Bool, into commandBuffer: MTLCommandBuffer) throws -> PreparedSource {
        let width = halfResolution ? max(source.width / 2, 1) : source.width
        let height = halfResolution ? max(source.height / 2, 1) : source.height
        let levels = min(Self.maxLevels, Int(log2(Double(max(width, height)))) + 1)
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba16Float, width: width, height: height, mipmapped: true)
        descriptor.mipmapLevelCount = levels
        descriptor.usage = [.shaderRead, .shaderWrite]
        descriptor.storageMode = .private
        guard let pyramid = device.makeTexture(descriptor: descriptor),
              let encoder = commandBuffer.makeComputeCommandEncoder() else {
            throw RenderError.allocationFailed
        }
        func level(_ index: Int) throws -> MTLTexture {
            guard let view = pyramid.makeTextureView(pixelFormat: .rgba16Float, textureType: .type2D,
                                                     levels: index..<(index + 1), slices: 0..<1) else {
                throw RenderError.allocationFailed
            }
            return view
        }
        func dispatch(_ pipeline: MTLComputePipelineState, from: MTLTexture, to: MTLTexture) {
            encoder.setComputePipelineState(pipeline)
            encoder.setTexture(from, index: 0)
            encoder.setTexture(to, index: 1)
            let group = MTLSize(width: 16, height: 16, depth: 1)
            let grid = MTLSize(width: (to.width + 15) / 16, height: (to.height + 15) / 16, depth: 1)
            encoder.dispatchThreadgroups(grid, threadsPerThreadgroup: group)
        }
        var previous = try level(0)
        dispatch(copy, from: source, to: previous)
        for index in 1..<levels {
            let current = try level(index)
            dispatch(downsample, from: previous, to: current)
            previous = current
        }
        encoder.endEncoding()
        return PreparedSource(texture: pyramid)
    }
}
