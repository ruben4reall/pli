// The optics port against the same cases as PliCore's GlassOpticsTests, MotionTests, CurvesTests and presets.
import assert from 'node:assert/strict';
import { test } from 'node:test';
import {
  DUO_GLASS, DUO_MOTION, Easing, PRESETS, RANGES, applyCurve, blackout, clamp, deriveOptics, displayGeometry,
  effectStart, follow, foldProgress, glassUniforms, mipLevelCount, percentOfRange, presetById, sampleOptics,
} from '../js/optics.js';

const geometry = { width: 1000, height: 600, pixelsPerMM: 5 };
const optics = (p, tweak = {}) => deriveOptics(p, { ...DUO_GLASS, ...tweak }, geometry, false);
const near = (a, b, eps = 1e-9) => Math.abs(a - b) < eps;

test('clamp sends non-finite values to the lower bound', () => {
  assert.equal(clamp(5, 0, 1), 1);
  assert.equal(clamp(-2, 0, 1), 0);
  assert.equal(clamp(Number.NaN, 2, 3), 2);
  assert.equal(clamp(Number.POSITIVE_INFINITY, 2, 3), 2);
});

test('curves keep their endpoints, clamp their input and differ in shape', () => {
  for (const curve of ['linear', 'smooth', 'fastStart', 'slowStart']) {
    assert.equal(applyCurve(curve, 0), 0);
    assert.equal(applyCurve(curve, 1), 1);
    assert.equal(applyCurve(curve, -0.5), 0);
    assert.equal(applyCurve(curve, 1.5), 1);
    let previous = -1;
    for (let step = 0; step <= 200; step++) {
      const value = applyCurve(curve, step / 200);
      assert.ok(value >= previous);
      previous = value;
    }
  }
  assert.equal(applyCurve('linear', 0.25), 0.25);
  assert.ok(applyCurve('fastStart', 0.25) > 0.25);
  assert.ok(applyCurve('slowStart', 0.25) < 0.25);
  assert.equal(applyCurve('wobbly', 0.25), 0.25);
  assert.ok(near(Easing.inOutCubic(0.5), 0.5, 1e-12));
  assert.equal(Easing.outCubic(1), 1);
});

test('zero progress is the identity', () => {
  const o = optics(0);
  for (const [x, y] of [[0.5, 0.5], [500.5, 300.5], [999.5, 10.5]]) {
    const s = sampleOptics(x, y, o, geometry);
    assert.ok(near(s.sourceX, x) && near(s.sourceY, y));
    assert.equal(s.blurRadius, 0);
    assert.equal(s.attenuation, 1);
    assert.equal(s.coverage, 1);
    assert.equal(s.isBlack, false);
  }
});

test('derived values are in pixels', () => {
  const o = optics(0.5);
  assert.ok(near(o.tiltRadians, (25 * Math.PI) / 180, 1e-12));
  assert.equal(o.eyeDistancePx, 450 * 5);
  assert.equal(o.eyeX, 500);
  assert.ok(near(o.eyeY, 180));
  assert.equal(o.maxBlurPx, 18 * 5);
  assert.ok(near(o.darkeningPerPx, 0.05 / 5, 1e-12));
  assert.equal(o.edgeSoftnessPx, 15);
});

test('the hinge row stays sharp', () => {
  const s = sampleOptics(500.5, 599.5, optics(0.8), geometry);
  assert.ok(s.blurRadius < 0.1);
  assert.ok(Math.abs(s.sourceY - 599.5) < 1);
});

test('blur and darkness grow toward the top', () => {
  const o = optics(0.6);
  let lastRadius = -1;
  let lastAttenuation = 2;
  for (let y = 590.5; y >= 10.5; y -= 40) {
    const s = sampleOptics(500.5, y, o, geometry);
    assert.ok(s.blurRadius >= lastRadius);
    assert.ok(s.attenuation <= lastAttenuation + 1e-12);
    lastRadius = s.blurRadius;
    lastAttenuation = s.attenuation;
  }
});

test('the top slides into black', () => {
  const s = sampleOptics(500.5, 0.5, optics(1), geometry);
  assert.ok(s.isBlack || s.coverage < 1 || s.attenuation === 0);
});

test('no anchor keeps the picture in place', () => {
  const s = sampleOptics(300.5, 200.5, optics(0.7, { spatialAnchor: 0 }), geometry);
  assert.ok(near(s.sourceX, 300.5) && near(s.sourceY, 200.5));
  assert.ok(s.blurRadius > 0);
});

test('reduce motion forces the anchor to zero', () => {
  assert.equal(deriveOptics(0.5, DUO_GLASS, geometry, true).spatialAnchor, 0);
});

test('blackout ramps over the last part of the travel', () => {
  assert.equal(blackout(0.5, 0.12), 1);
  assert.equal(blackout(1, 0.12), 0);
  const mid = blackout(0.94, 0.12);
  assert.ok(mid > 0 && mid < 1);
  assert.equal(blackout(1, 0), 1);
});

test('blur is capped at 18 mm', () => {
  const s = sampleOptics(500.5, 50.5, optics(1, { frost: 0.25, maxTiltDegrees: 75 }), geometry);
  assert.ok(s.blurRadius <= 18 * 5 + 1e-9);
});

test('uniforms follow the renderer layout', () => {
  const u = glassUniforms({ progress: 0.5, glass: DUO_GLASS, geometry }, { width: 2000, mipLevels: 8 });
  assert.deepEqual(u.sizeAndProgress, [1000, 600, 0.5, 8]);
  assert.equal(u.optics[1], 2250);
  assert.deepEqual(u.blur.slice(0, 3), [0.09, 90, 0.3]);
  assert.equal(u.shape[3], 8);
  assert.equal(u.color[3], 2);
  assert.equal(mipLevelCount(256, 192), 8);
  assert.equal(mipLevelCount(64, 48), 7);
  assert.equal(displayGeometry(604, 392).pixelsPerMM, 2);
});

test('the fold mapping matches the app', () => {
  assert.equal(effectStart(DUO_MOTION, 110), 90);
  assert.equal(effectStart(DUO_MOTION, 80), 74);
  assert.equal(effectStart(DUO_MOTION, 33), 30);
  assert.equal(effectStart(DUO_MOTION, 25), 25);
  assert.equal(foldProgress(DUO_MOTION, 110, 110), 0);
  assert.equal(foldProgress(DUO_MOTION, 90, 110), 0);
  assert.ok(near(foldProgress(DUO_MOTION, 55, 110), 0.5, 1e-12));
  assert.equal(foldProgress(DUO_MOTION, 20, 110), 1);
  assert.equal(foldProgress(DUO_MOTION, 3, 110), 1);
  assert.equal(foldProgress(DUO_MOTION, 95, 130), 0);
});

test('the follower eases, converges, and bounds big gaps', () => {
  assert.equal(follow(null, 100, 1 / 120, 0.045), 100);
  let value = follow(100, 99, 1 / 120, 0.045);
  assert.ok(value < 100 && value > 99);
  for (let i = 0; i < 120; i++) value = follow(value, 99, 1 / 120, 0.045);
  assert.equal(value, 99);
  assert.equal(follow(100, 50, 1 / 120, 0), 50);
  assert.ok(follow(100, 0, 30, 0.045) > 0);
});

test('the seven presets match spec table 7.5', () => {
  assert.deepEqual(PRESETS.map((p) => p.id), ['duo', 'subtle', 'deepFrost', 'night', 'crystal', 'prism', 'cinema']);
  assert.deepEqual(PRESETS.map((p) => p.name), ['Duo', 'Subtle', 'Deep Frost', 'Night', 'Crystal', 'Prism', 'Cinema']);
  const subtle = presetById('subtle');
  assert.equal(subtle.glass.frost, 0.05);
  assert.equal(subtle.glass.spatialAnchor, 0.7);
  assert.equal(subtle.glass.maxTiltDegrees, 35);
  assert.equal(subtle.motion.startAngle, 85);
  assert.equal(subtle.motion.deadZoneDegrees, 8);
  assert.equal(subtle.motion.curve, 'smooth');
  const night = presetById('night');
  assert.ok(near(night.glass.tintColor.red, 10 / 255) && night.glass.tintAmount === 0.35 && night.motion.curve === 'fastStart');
  const cinema = presetById('cinema');
  assert.ok(cinema.glass.maxTiltDegrees === 65 && cinema.motion.startAngle === 100 && cinema.motion.fullFoldAngle === 28);
  assert.equal(presetById('crystal').glass.edgeSheen, 0.6);
  assert.equal(presetById('prism').glass.prism, 0.55);
  assert.equal(presetById('deepFrost').glass.grain, 0.7);
  assert.equal(presetById('deepFrost').motion.fullFoldAngle, 25);
  assert.equal(presetById('nope'), null);
  for (const p of PRESETS) {
    for (const [key, [lo, hi]] of Object.entries(RANGES)) {
      const value = p.glass[key] ?? p.motion[key];
      assert.ok(value >= lo && value <= hi, `${p.id}.${key} = ${value} is outside ${lo}...${hi}`);
    }
  }
  assert.equal(percentOfRange('frost', 0.16), 64);
  assert.equal(percentOfRange('darkening', 0.025), 13);
});
