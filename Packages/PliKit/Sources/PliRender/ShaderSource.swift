/// Metal source for the glass effect, compiled at runtime so the app, the tests and CI run the same code.
/// The optical model mirrors `GlassOptics.sample` in PliCore (spec 7.1).
enum ShaderSource {
    static let glass = #"""
    #include <metal_stdlib>
    using namespace metal;

    struct GlassUniforms {
        float4 sizeAndProgress; // width, height (target px), progress, taps
        float4 optics;          // tilt (rad), eye distance (px), eye x, eye y
        float4 blur;            // frost, max blur (px), grain, darkening per px
        float4 shape;           // spatial anchor, edge softness (px), blackout, mip levels
        float4 tint;            // r, g, b, amount
        float4 color;           // saturation, edge sheen, prism, source px per target px
    };

    struct VertexOut { float4 position [[position]]; };

    vertex VertexOut pli_fullscreen(uint vid [[vertex_id]]) {
        float2 corner = float2(float((vid << 1) & 2), float(vid & 2));
        VertexOut out;
        out.position = float4(corner * 2.0 - 1.0, 0.0, 1.0);
        return out;
    }

    static float pli_hash(float2 p) {
        float3 p3 = fract(float3(p.xyx) * 0.1031);
        p3 += dot(p3, p3.yzx + 33.33);
        return fract((p3.x + p3.y) * p3.z);
    }

    // The pyramid level for a blur radius: the one whose texels are about half the radius wide.
    static float pli_lod(float radius, float sourceScale, float mipLevels) {
        return clamp(log2(max(radius * sourceScale * 0.5, 1.0)), 0.0, mipLevels - 1.0);
    }

    static float3 pli_blurred(texture2d<float> source, sampler s, float2 point, float radius,
                              float2 size, float2 pixel, float grain, int taps,
                              float sourceScale, float mipLevels) {
        float2 invSize = 1.0 / size;
        if (radius < 0.5) {
            return source.sample(s, point * invSize, level(0.0)).rgb;
        }
        float tapLod = max(pli_lod(radius, sourceScale, mipLevels) - 1.0, 0.0);
        // Vogel disk rotated per pixel: tap i sits at i golden angles past the rotation. The direction turns
        // by one golden angle from tap to tap, so a pixel needs one sine and one cosine.
        float rotation = pli_hash(pixel) * 6.2831853;
        float2 direction = float2(cos(rotation), sin(rotation));
        const float2 golden = float2(cos(2.3999632), sin(2.3999632));
        float invTaps = 1.0 / float(taps);
        float3 sum = float3(0.0);
        for (int i = 0; i < taps; i++) {
            float fi = float(i);
            float r = radius * 0.5 * sqrt((fi + 0.5) * invTaps);
            float2 offset = r * direction;
            float2 jitter = (float2(pli_hash(pixel + fi * 17.0), pli_hash(pixel.yx + fi * 31.0)) - 0.5) * grain * radius;
            sum += source.sample(s, (point + offset + jitter) * invSize, level(tapLod)).rgb;
            direction = float2(direction.x * golden.x - direction.y * golden.y,
                               direction.x * golden.y + direction.y * golden.x);
        }
        return sum / float(taps);
    }

    fragment half4 pli_glass(VertexOut in [[stage_in]],
                             texture2d<float> source [[texture(0)]],
                             constant GlassUniforms& u [[buffer(0)]]) {
        constexpr sampler s(address::clamp_to_zero, filter::linear, mip_filter::linear);
        float2 size = u.sizeAndProgress.xy;
        float progress = u.sizeAndProgress.z;
        int taps = int(u.sizeAndProgress.w);
        float2 P = in.position.xy;

        // Glass hinged on the bottom edge, tilted toward the eye; the picture stays on the flat plane.
        float d = size.y - P.y;
        float tilt = u.optics.x;
        float2 g = float2(P.x, size.y - d * cos(tilt));
        float z = d * sin(tilt);
        float depth = u.optics.y - z;
        if (depth <= 1.0) { return half4(0.0, 0.0, 0.0, 1.0); }
        float2 eye = u.optics.zw;
        float2 q = eye + (g - eye) * (u.optics.y / depth);
        float2 sp = P + u.shape.x * (q - P);
        float radius = min(u.blur.x * z, u.blur.y);

        float2 outside = max(max(-sp, sp - size), float2(0.0));
        float coverage = clamp(1.0 - length(outside) / max(u.shape.y + radius, 1.0), 0.0, 1.0);
        if (coverage <= 0.0) { return half4(0.0, 0.0, 0.0, 1.0); }
        float attenuation = max(1.0 - u.blur.w * radius, 0.0) * u.shape.z;

        float3 color = pli_blurred(source, s, sp, radius, size, P, u.blur.z, taps, u.color.w, u.shape.w);
        float prism = u.color.z;
        if (prism > 0.0 && radius >= 0.5) {
            // Red and blue as if sampled at slightly different radii (spec 7.1): the blur above, moved by
            // `shift` along the displacement with the blurred slope there. The slope comes from two samples of
            // the smooth pyramid near the rim of the blur disk (two more grainy blurs used to cost sixteen
            // taps), so the grain stays the same in every channel.
            float2 direction = sp - P;
            float len = length(direction);
            float2 along = len > 0.0 ? direction / len : float2(0.0);
            float shift = prism * radius * 0.25;
            float reach = radius * 0.45;
            float slopeLod = max(pli_lod(radius, u.color.w, u.shape.w) - 0.5, 0.0);
            float2 invSize = 1.0 / size;
            float3 ahead = source.sample(s, (sp + along * reach) * invSize, level(slopeLod)).rgb;
            float3 behind = source.sample(s, (sp - along * reach) * invSize, level(slopeLod)).rgb;
            float3 moved = (ahead - behind) * (shift / (2.0 * reach));
            color.r = clamp(color.r + moved.r, 0.0, 1.0);
            color.b = clamp(color.b - moved.b, 0.0, 1.0);
        }

        float luma = dot(color, float3(0.2126, 0.7152, 0.0722));
        color = mix(float3(luma), color, u.color.x);
        color = mix(color, color * u.tint.rgb, u.tint.a);
        color *= attenuation * coverage;

        // Edge sheen: a light band along the far edge of the glass, growing with the fold.
        float band = exp(-P.y / max(size.y * 0.06, 1.0));
        color += u.color.y * progress * band * 0.35 * coverage * u.shape.z;

        return half4(half3(clamp(color, 0.0, 1.0)), 1.0);
    }

    kernel void pli_copy(texture2d<float, access::sample> src [[texture(0)]],
                         texture2d<float, access::write> dst [[texture(1)]],
                         uint2 gid [[thread_position_in_grid]]) {
        if (gid.x >= dst.get_width() || gid.y >= dst.get_height()) { return; }
        constexpr sampler s(address::clamp_to_edge, filter::linear);
        float2 uv = (float2(gid) + 0.5) / float2(dst.get_width(), dst.get_height());
        dst.write(src.sample(s, uv, level(0.0)), gid);
    }

    // Dual-filter downsample: a smooth half-size copy, so each mip level is a wider blur.
    kernel void pli_downsample(texture2d<float, access::sample> src [[texture(0)]],
                               texture2d<float, access::write> dst [[texture(1)]],
                               uint2 gid [[thread_position_in_grid]]) {
        if (gid.x >= dst.get_width() || gid.y >= dst.get_height()) { return; }
        constexpr sampler s(address::clamp_to_edge, filter::linear);
        float2 size = float2(dst.get_width(), dst.get_height());
        float2 uv = (float2(gid) + 0.5) / size;
        float2 h = 0.5 / size;
        float4 sum = src.sample(s, uv, level(0.0)) * 4.0;
        sum += src.sample(s, uv - h, level(0.0));
        sum += src.sample(s, uv + h, level(0.0));
        sum += src.sample(s, uv + float2(h.x, -h.y), level(0.0));
        sum += src.sample(s, uv - float2(h.x, -h.y), level(0.0));
        dst.write(sum / 8.0, gid);
    }
    """#
}
