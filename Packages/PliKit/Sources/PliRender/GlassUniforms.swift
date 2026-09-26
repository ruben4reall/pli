import simd

/// Matches `struct GlassUniforms` in `ShaderSource.glass`: six float4, 96 bytes.
struct GlassUniforms {
    var sizeAndProgress: SIMD4<Float>
    var optics: SIMD4<Float>
    var blur: SIMD4<Float>
    var shape: SIMD4<Float>
    var tint: SIMD4<Float>
    var color: SIMD4<Float>
}

public enum RenderError: Error, Equatable {
    case noDevice
    case libraryFailed(String)
    case pipelineFailed(String)
    case allocationFailed
}
