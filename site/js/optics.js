// Pli's optical model and lid mapping, ported from PliCore (GlassOptics, FoldMapper, AngleFollower, FoldCurve,
// Easing, BuiltInPresets) so the page renders the same glass as the app. Pure functions: tested in Node.

export const MAX_BLUR_MM = 18;
/** A 14-inch MacBook Pro display is 302 mm wide; the page's display uses the same density. */
export const DISPLAY_WIDTH_MM = 302;
/** The 14-inch display's ratio, 3024 x 1964: the demo desktop and every frame on the page use it. */
export const DISPLAY_RATIO = 3024 / 1964;
/** The page's MacBook rests with its lid at 110°: the rest position of every lid mapping on the page. */
export const PAGE_LID_REST = 110;

/** Like PliCore's `clamped(to:)`: NaN and infinities fall to the lower bound. */
export function clamp(x, lo, hi) {
  if (!Number.isFinite(x)) return lo;
  return Math.min(Math.max(x, lo), hi);
}

const CURVES = {
  linear: (t) => t,
  smooth: (t) => t * t * (3 - 2 * t),
  fastStart: (t) => 1 - (1 - t) * (1 - t),
  slowStart: (t) => t * t,
};

export function applyCurve(curve, x) {
  return (CURVES[curve] ?? CURVES.linear)(clamp(x, 0, 1));
}

export const Easing = {
  inOutCubic(x) {
    const t = clamp(x, 0, 1);
    return t < 0.5 ? 4 * t * t * t : 1 - Math.pow(-2 * t + 2, 3) / 2;
  },
  outCubic(x) {
    const t = clamp(x, 0, 1);
    return 1 - Math.pow(1 - t, 3);
  },
};

const WHITE = Object.freeze({ red: 1, green: 1, blue: 1 });
/** Brand token Night, #0A0C10. */
const NIGHT = Object.freeze({ red: 10 / 255, green: 12 / 255, blue: 16 / 255 });

/** Spec table 7.4, the Duo preset. */
export const DUO_GLASS = Object.freeze({
  frost: 0.09, grain: 0.3, darkening: 0.05, tintColor: WHITE, tintAmount: 0,
  saturation: 1, edgeSheen: 0, prism: 0, eyeDistanceMM: 450, eyeHeight: 0.3,
  spatialAnchor: 1, maxTiltDegrees: 50, finalBlackout: 0.12, edgeSoftnessMM: 3,
});
export const DUO_MOTION = Object.freeze({ startAngle: 90, deadZoneDegrees: 6, fullFoldAngle: 20, curve: 'linear' });

/** Spec table 7.4 ranges, used to show Frost and Darkening as a percentage of their range, as the app does. */
export const RANGES = Object.freeze({
  frost: [0, 0.25], grain: [0, 1], darkening: [0, 0.2], tintAmount: [0, 1], saturation: [0, 2],
  edgeSheen: [0, 1], prism: [0, 1], eyeDistanceMM: [250, 900], eyeHeight: [0, 1], spatialAnchor: [0, 1],
  maxTiltDegrees: [20, 75], finalBlackout: [0, 0.3], edgeSoftnessMM: [0, 12],
  startAngle: [40, 130], deadZoneDegrees: [0, 20], fullFoldAngle: [5, 60],
});

function preset(id, name, intent, glass = {}, motion = {}) {
  return Object.freeze({
    id, name, intent,
    glass: Object.freeze({ ...DUO_GLASS, ...glass }),
    motion: Object.freeze({ ...DUO_MOTION, ...motion }),
  });
}

/** Spec table 7.5, in the app's order. Values not listed are Duo's. */
export const PRESETS = Object.freeze([
  preset('duo', 'Duo', 'Faithful to the iPhone Duo.'),
  preset('subtle', 'Subtle', 'Present without taking over.',
    { frost: 0.05, grain: 0.15, darkening: 0.025, spatialAnchor: 0.7, maxTiltDegrees: 35, finalBlackout: 0.1 },
    { startAngle: 85, deadZoneDegrees: 8, curve: 'smooth' }),
  preset('deepFrost', 'Deep Frost', 'Thick sandblasted glass.',
    { frost: 0.16, grain: 0.7, darkening: 0.06, saturation: 0.85, maxTiltDegrees: 55 },
    { fullFoldAngle: 25 }),
  preset('night', 'Night', 'Dark and smoky.',
    { frost: 0.1, darkening: 0.12, tintColor: NIGHT, tintAmount: 0.35, saturation: 0.8, finalBlackout: 0.2 },
    { fullFoldAngle: 30, curve: 'fastStart' }),
  preset('crystal', 'Crystal', 'Nearly clear glass with a sheen.',
    { frost: 0.02, grain: 0.05, darkening: 0.02, edgeSheen: 0.6, prism: 0.1, eyeDistanceMM: 400, maxTiltDegrees: 55, finalBlackout: 0.08 },
    { curve: 'smooth' }),
  preset('prism', 'Prism', 'Iridescent edges.',
    { frost: 0.08, grain: 0.25, darkening: 0.04, prism: 0.55, edgeSheen: 0.2 }),
  preset('cinema', 'Cinema', 'Starts early, leans further, frosts harder.',
    { frost: 0.13, grain: 0.35, darkening: 0.07, eyeDistanceMM: 380, maxTiltDegrees: 65 },
    { startAngle: 100, deadZoneDegrees: 3, fullFoldAngle: 28, curve: 'fastStart' }),
]);

export function presetById(id) {
  return PRESETS.find((p) => p.id === id) ?? null;
}

/** The percentage of its range a value covers, rounded like the app's labels. */
export function percentOfRange(key, value) {
  const [lo, hi] = RANGES[key];
  return Math.round(((value - lo) / (hi - lo)) * 100);
}

/** Geometry of a display drawn `width` x `height` pixels wide, at the 14-inch density unless told otherwise. */
export function displayGeometry(width, height, pixelsPerMM = width / DISPLAY_WIDTH_MM) {
  return { width, height, pixelsPerMM };
}

/** `1 − smoothstep(1 − b, 1, p)`; an amount of 0 means no blackout. */
export function blackout(progress, amount) {
  if (!(amount > 1e-4)) return 1;
  const t = clamp((progress - (1 - amount)) / amount, 0, 1);
  return 1 - t * t * (3 - 2 * t);
}

/** Port of `GlassOptics.derive`: the optical model's inputs for one frame, in pixels. */
export function deriveOptics(progress, g, geometry, reduceMotion = false) {
  const p = clamp(progress, 0, 1);
  const rho = geometry.pixelsPerMM;
  return {
    tiltRadians: (p * g.maxTiltDegrees * Math.PI) / 180,
    eyeDistancePx: g.eyeDistanceMM * rho,
    eyeX: geometry.width / 2,
    eyeY: g.eyeHeight * geometry.height,
    frost: g.frost,
    maxBlurPx: MAX_BLUR_MM * rho,
    darkeningPerPx: g.darkening / rho,
    spatialAnchor: reduceMotion ? 0 : g.spatialAnchor,
    edgeSoftnessPx: g.edgeSoftnessMM * rho,
    blackout: blackout(p, g.finalBlackout),
  };
}

/** Port of `GlassOptics.sample` (spec 7.1): where the output pixel at (x, y) looks, how blurred and how dark. */
export function sampleOptics(x, y, o, geometry) {
  const { width, height } = geometry;
  const d = height - y;
  const gy = height - d * Math.cos(o.tiltRadians);
  const z = d * Math.sin(o.tiltRadians);
  const depth = o.eyeDistancePx - z;
  if (!(depth > 1)) return { sourceX: x, sourceY: y, blurRadius: 0, attenuation: 0, coverage: 0, isBlack: true };
  const scale = o.eyeDistancePx / depth;
  const qx = o.eyeX + (x - o.eyeX) * scale;
  const qy = o.eyeY + (gy - o.eyeY) * scale;
  const sx = x + o.spatialAnchor * (qx - x);
  const sy = y + o.spatialAnchor * (qy - y);
  const radius = Math.min(o.frost * z, o.maxBlurPx);
  const outsideX = Math.max(-sx, sx - width, 0);
  const outsideY = Math.max(-sy, sy - height, 0);
  const outside = Math.sqrt(outsideX * outsideX + outsideY * outsideY);
  const coverage = clamp(1 - outside / Math.max(o.edgeSoftnessPx + radius, 1), 0, 1);
  const attenuation = Math.max(1 - o.darkeningPerPx * radius, 0) * o.blackout;
  return { sourceX: sx, sourceY: sy, blurRadius: radius, attenuation, coverage, isBlack: coverage <= 0 };
}

/** Mip levels of the blur pyramid, as in PliRender (8 at most). */
export function mipLevelCount(width, height) {
  return Math.min(8, Math.floor(Math.log2(Math.max(width, height, 1))) + 1);
}

/** Port of `GlassRenderer.uniforms`: six vec4, in the shader's order. */
export function glassUniforms({ progress, glass: g, geometry, taps = 8, reduceMotion = false }, source) {
  const o = deriveOptics(progress, g, geometry, reduceMotion);
  const sourceScale = source.width / Math.max(geometry.width, 1);
  return {
    sizeAndProgress: [geometry.width, geometry.height, clamp(progress, 0, 1), taps],
    optics: [o.tiltRadians, o.eyeDistancePx, o.eyeX, o.eyeY],
    blur: [o.frost, o.maxBlurPx, g.grain, o.darkeningPerPx],
    shape: [o.spatialAnchor, o.edgeSoftnessPx, o.blackout, source.mipLevels],
    tint: [g.tintColor.red, g.tintColor.green, g.tintColor.blue, g.tintAmount],
    color: [g.saturation, g.edgeSheen, g.prism, sourceScale],
  };
}

/** Port of `FoldMapper.effectStart`: `S = max(min(R − D, A), min(R, F + 10))`. */
export function effectStart(motion, rest) {
  return Math.max(Math.min(rest - motion.deadZoneDegrees, motion.startAngle), Math.min(rest, motion.fullFoldAngle + 10));
}

/** Port of `FoldMapper.progress`: fold progress for a lid `angle` against its `rest` position (spec 6.3). */
export function foldProgress(motion, angle, rest) {
  const start = effectStart(motion, rest);
  if (start - motion.fullFoldAngle < 1) return angle <= motion.fullFoldAngle ? 1 : 0;
  return applyCurve(motion.curve, (start - angle) / (start - motion.fullFoldAngle));
}

/** One step of the app's AngleFollower: `dt` is capped at 0.1 s and the value snaps within 0.02°. */
export function follow(current, target, dt, timeConstant) {
  if (current === null || current === undefined) return target;
  const step = clamp(dt, 0, 0.1);
  let next = timeConstant <= 0 ? target : current + (target - current) * (1 - Math.exp(-step / timeConstant));
  if (Math.abs(target - next) < 0.02) next = target;
  return next;
}
