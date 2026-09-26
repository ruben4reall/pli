// GLSL ES 3.00 port of PliRender's Metal shader (ShaderSource.glass). Same optical model, same uniform layout.
// Two differences, both forced by WebGL2: fragment coordinates start at the bottom left (flipped to Metal's top
// left below), and there is no clamp-to-zero sampler (taps outside the picture are masked to black by hand).

export const FULLSCREEN_VERTEX = `#version 300 es
void main() {
  vec2 corner = vec2(float((gl_VertexID << 1) & 2), float(gl_VertexID & 2));
  gl_Position = vec4(corner * 2.0 - 1.0, 0.0, 1.0);
}`;

export const GLASS_FRAGMENT = `#version 300 es
precision highp float;
precision highp int;

uniform sampler2D uSource;
uniform vec4 uSizeAndProgress; // width, height (target px), progress, taps
uniform vec4 uOptics;          // tilt (rad), eye distance (px), eye x, eye y
uniform vec4 uBlur;            // frost, max blur (px), grain, darkening per px
uniform vec4 uShape;           // spatial anchor, edge softness (px), blackout, mip levels
uniform vec4 uTint;            // r, g, b, amount
uniform vec4 uColor;           // saturation, edge sheen, prism, source px per target px

out vec4 fragColor;

float pliHash(vec2 p) {
  vec3 p3 = fract(vec3(p.xyx) * 0.1031);
  p3 += dot(p3, p3.yzx + 33.33);
  return fract((p3.x + p3.y) * p3.z);
}

// Metal's clamp_to_zero sampler: anything outside the picture reads as black.
vec3 pliTap(vec2 uv, float lod) {
  vec2 inside = step(vec2(0.0), uv) * step(uv, vec2(1.0));
  return textureLod(uSource, uv, lod).rgb * (inside.x * inside.y);
}

float pliLod(float radius, float sourceScale, float mipLevels) {
  return clamp(log2(max(radius * sourceScale * 0.5, 1.0)), 0.0, mipLevels - 1.0);
}

vec3 pliBlurred(vec2 point, float radius, vec2 size, vec2 pixel, float grain, int taps,
                float sourceScale, float mipLevels) {
  vec2 invSize = 1.0 / size;
  if (radius < 0.5) {
    return pliTap(point * invSize, 0.0);
  }
  float tapLod = max(pliLod(radius, sourceScale, mipLevels) - 1.0, 0.0);
  // The Vogel direction turns by the golden angle with a rotation instead of a sine and cosine per tap.
  float rotation = pliHash(pixel) * 6.2831853;
  vec2 dir = vec2(cos(rotation), sin(rotation));
  const vec2 golden = vec2(-0.73736888, 0.67549029);   // cos and sin of 2.3999632
  vec3 sum = vec3(0.0);
  for (int i = 0; i < 8; i++) {
    if (i >= taps) break;
    float fi = float(i);
    float r = radius * 0.5 * sqrt((fi + 0.5) / float(taps));
    vec2 offset = r * dir;
    vec2 jitter = (vec2(pliHash(pixel + fi * 17.0), pliHash(pixel.yx + fi * 31.0)) - 0.5) * grain * radius;
    sum += pliTap((point + offset + jitter) * invSize, tapLod);
    dir = vec2(dir.x * golden.x - dir.y * golden.y, dir.x * golden.y + dir.y * golden.x);
  }
  return sum / float(taps);
}

void main() {
  vec2 size = uSizeAndProgress.xy;
  float progress = uSizeAndProgress.z;
  int taps = int(uSizeAndProgress.w);
  vec2 P = vec2(gl_FragCoord.x, size.y - gl_FragCoord.y); // Metal's top-left origin

  // Glass hinged on the bottom edge, tilted toward the eye; the picture stays on the flat plane.
  float d = size.y - P.y;
  float tilt = uOptics.x;
  vec2 g = vec2(P.x, size.y - d * cos(tilt));
  float z = d * sin(tilt);
  float depth = uOptics.y - z;
  if (depth <= 1.0) { fragColor = vec4(0.0, 0.0, 0.0, 1.0); return; }
  vec2 eye = uOptics.zw;
  vec2 q = eye + (g - eye) * (uOptics.y / depth);
  vec2 sp = P + uShape.x * (q - P);
  float radius = min(uBlur.x * z, uBlur.y);

  vec2 outside = max(max(-sp, sp - size), vec2(0.0));
  float coverage = clamp(1.0 - length(outside) / max(uShape.y + radius, 1.0), 0.0, 1.0);
  if (coverage <= 0.0) { fragColor = vec4(0.0, 0.0, 0.0, 1.0); return; }
  float attenuation = max(1.0 - uBlur.w * radius, 0.0) * uShape.z;

  // Prism (the engine's I-3 fix): one grainy blur, then red and blue moved along the displacement with the blurred
  // slope, from two samples near the rim of the blur disk. 10 samples instead of 24.
  vec3 color = pliBlurred(sp, radius, size, P, uBlur.z, taps, uColor.w, uShape.w);
  float prism = uColor.z;
  if (prism > 0.0 && radius >= 0.5) {
    vec2 direction = sp - P;
    float len = length(direction);
    vec2 along = len > 0.0 ? direction / len : vec2(0.0);
    float shift = prism * radius * 0.25;
    float reach = radius * 0.45;
    float slopeLod = max(pliLod(radius, uColor.w, uShape.w) - 0.5, 0.0);
    vec2 invSize = 1.0 / size;
    vec3 ahead = pliTap((sp + along * reach) * invSize, slopeLod);
    vec3 behind = pliTap((sp - along * reach) * invSize, slopeLod);
    vec3 moved = (ahead - behind) * (shift / (2.0 * reach));
    color.r = clamp(color.r + moved.r, 0.0, 1.0);
    color.b = clamp(color.b - moved.b, 0.0, 1.0);
  }

  float luma = dot(color, vec3(0.2126, 0.7152, 0.0722));
  color = mix(vec3(luma), color, uColor.x);
  color = mix(color, color * uTint.rgb, uTint.a);
  color *= attenuation * coverage;

  // Edge sheen: a light band along the far edge of the glass, growing with the fold.
  float band = exp(-P.y / max(size.y * 0.06, 1.0));
  color += uColor.y * progress * band * 0.35 * coverage * uShape.z;

  fragColor = vec4(clamp(color, 0.0, 1.0), 1.0);
}`;

// Dual-filter downsample (pli_downsample): each mip level is a smooth half-size copy of the one above.
export const DOWNSAMPLE_FRAGMENT = `#version 300 es
precision highp float;

uniform sampler2D uSource;
uniform vec2 uTargetSize;

out vec4 fragColor;

void main() {
  vec2 uv = gl_FragCoord.xy / uTargetSize;
  vec2 h = 0.5 / uTargetSize;
  vec4 sum = textureLod(uSource, uv, 0.0) * 4.0;
  sum += textureLod(uSource, uv - h, 0.0);
  sum += textureLod(uSource, uv + h, 0.0);
  sum += textureLod(uSource, uv + vec2(h.x, -h.y), 0.0);
  sum += textureLod(uSource, uv - vec2(h.x, -h.y), 0.0);
  fragColor = sum / 8.0;
}`;
