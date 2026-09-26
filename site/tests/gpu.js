// The WebGL2 port against the CPU reference, mirroring PliRender's PyramidTests and GlassRendererTests.
// Run by tools/check-gpu.mjs in headless Chrome; results land in window.__gpu.
import { GlassRenderer } from '../js/renderer.js';
import { DUO_GLASS, deriveOptics, displayGeometry, sampleOptics } from '../js/optics.js';

const results = [];

function check(name, fn) {
  try {
    fn();
    results.push({ name, ok: true });
  } catch (error) {
    results.push({ name, ok: false, error: String(error?.message ?? error) });
  }
}

function expect(condition, message) {
  if (!condition) throw new Error(message);
}

function picture(width, height, pixel) {
  const data = new ImageData(width, height);
  for (let y = 0; y < height; y++) {
    for (let x = 0; x < width; x++) {
      const [r, g, b] = pixel(x, y);
      const i = (y * width + x) * 4;
      data.data[i] = r;
      data.data[i + 1] = g;
      data.data[i + 2] = b;
      data.data[i + 3] = 255;
    }
  }
  return data;
}

const checkerboard = (width, height, cell) => picture(width, height, (x, y) => {
  const v = (Math.floor(x / cell) + Math.floor(y / cell)) % 2 === 0 ? 255 : 0;
  return [v, v, v];
});

/** Renders `source` at `progress` and returns a reader of the output in top-left pixel coordinates (0...255). */
function render(source, progress, glass, pixelsPerMM) {
  const canvas = document.createElement('canvas');
  canvas.width = source.width;
  canvas.height = source.height;
  const renderer = new GlassRenderer(canvas);
  renderer.setSource(source);
  renderer.render({ progress, glass, pixelsPerMM });
  const gl = renderer.gl;
  const out = new Uint8Array(source.width * source.height * 4);
  gl.readPixels(0, 0, source.width, source.height, gl.RGBA, gl.UNSIGNED_BYTE, out);
  renderer.dispose();
  return (x, y) => {
    const i = ((source.height - 1 - y) * source.width + x) * 4;
    return [out[i], out[i + 1], out[i + 2]];
  };
}

function variance(values) {
  const mean = values.reduce((a, b) => a + b, 0) / values.length;
  return values.reduce((a, b) => a + (b - mean) * (b - mean), 0) / values.length;
}

function rows(read, width, from, to) {
  const values = [];
  for (let y = from; y < to; y++) for (let x = 0; x < width; x++) values.push(read(x, y)[0]);
  return values;
}

check('the pyramid levels get smoother and keep the average', () => {
  const canvas = document.createElement('canvas');
  const renderer = new GlassRenderer(canvas);
  renderer.setSource(checkerboard(256, 192, 4));
  expect(renderer.source.mipLevels === 8, `expected 8 levels, got ${renderer.source.mipLevels}`);
  const gl = renderer.gl;
  const readLevel = (level) => {
    const w = 256 >> level;
    const h = 192 >> level;
    const framebuffer = gl.createFramebuffer();
    gl.bindFramebuffer(gl.FRAMEBUFFER, framebuffer);
    gl.framebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.TEXTURE_2D, renderer.source.texture, level);
    const out = new Uint8Array(w * h * 4);
    gl.readPixels(0, 0, w, h, gl.RGBA, gl.UNSIGNED_BYTE, out);
    gl.bindFramebuffer(gl.FRAMEBUFFER, null);
    gl.deleteFramebuffer(framebuffer);
    return Array.from({ length: w * h }, (_, i) => out[i * 4]);
  };
  const base = readLevel(0);
  const blurred = readLevel(3);
  expect(variance(blurred) < variance(base) * 0.5, 'level 3 is not smoother than level 0');
  const mean = blurred.reduce((a, b) => a + b, 0) / blurred.length;
  expect(Math.abs(mean - 127.5) < 13, `level 3 mean drifted to ${mean}`);
  renderer.dispose();
});

check('zero progress returns the source unchanged', () => {
  const source = picture(64, 48, (x, y) => [(x * 37 + y * 11) % 255, (x * 5 + y * 71) % 255, (x + y) % 255]);
  const read = render(source, 0, { ...DUO_GLASS, prism: 1, edgeSheen: 1, grain: 1 });
  for (let y = 0; y < 48; y++) {
    for (let x = 0; x < 64; x++) {
      const i = (y * 64 + x) * 4;
      const [r, g, b] = read(x, y);
      expect(Math.abs(r - source.data[i]) <= 1 && Math.abs(g - source.data[i + 1]) <= 1 && Math.abs(b - source.data[i + 2]) <= 1,
        `pixel (${x}, ${y}) changed`);
    }
  }
});

check('frost grows toward the top', () => {
  const read = render(checkerboard(256, 192, 4), 0.8,
    { ...DUO_GLASS, frost: 0.2, grain: 0, darkening: 0, finalBlackout: 0, spatialAnchor: 0, maxTiltDegrees: 60 }, 2);
  expect(variance(rows(read, 256, 10, 40)) < variance(rows(read, 256, 170, 190)) * 0.5, 'the top is not blurrier than the bottom');
});

check('geometry matches the CPU reference', () => {
  const width = 256;
  const height = 192;
  const source = picture(width, height, (x, y) => [x, y, 0]);
  const glass = { ...DUO_GLASS, frost: 0, grain: 0, darkening: 0, finalBlackout: 0, edgeSoftnessMM: 0 };
  const read = render(source, 0.6, glass);
  const geometry = displayGeometry(width, height);
  const optics = deriveOptics(0.6, glass, geometry, false);
  let checked = 0;
  for (let y = 10; y < height; y += 23) {
    for (let x = 10; x < width; x += 31) {
      const s = sampleOptics(x + 0.5, y + 0.5, optics, geometry);
      if (s.isBlack || s.sourceX < 2 || s.sourceX > width - 2 || s.sourceY < 2 || s.sourceY > height - 2) continue;
      const [r, g] = read(x, y);
      expect(Math.abs(r + 0.5 - s.sourceX) < 1.5, `x at (${x}, ${y}): GPU ${r + 0.5}, CPU ${s.sourceX.toFixed(2)}`);
      expect(Math.abs(g + 0.5 - s.sourceY) < 1.5, `y at (${x}, ${y}): GPU ${g + 0.5}, CPU ${s.sourceY.toFixed(2)}`);
      checked += 1;
    }
  }
  expect(checked > 20, `only ${checked} points checked`);
});

check('uniform gray matches the CPU attenuation', () => {
  const width = 400;
  const height = 300;
  const glass = { ...DUO_GLASS, frost: 0.1, darkening: 0.1, grain: 0, spatialAnchor: 0 };
  const read = render(picture(width, height, () => [128, 128, 128]), 0.85, glass, 2);
  const geometry = displayGeometry(width, height, 2);
  const optics = deriveOptics(0.85, glass, geometry, false);
  for (let y = 60; y < 260; y += 50) {
    for (let x = 100; x < 300; x += 50) {
      const s = sampleOptics(x + 0.5, y + 0.5, optics, geometry);
      const expected = (128 / 255) * s.attenuation * s.coverage;
      const actual = read(x, y)[0] / 255;
      expect(Math.abs(actual - expected) < 0.02, `at (${x}, ${y}): GPU ${actual.toFixed(3)}, CPU ${expected.toFixed(3)}`);
    }
  }
});

check('the end is black', () => {
  const read = render(picture(120, 80, () => [255, 255, 255]), 1, DUO_GLASS);
  for (let y = 0; y < 80; y++) for (let x = 0; x < 120; x++) expect(read(x, y).every((v) => v <= 2), `pixel (${x}, ${y}) is not black`);
});

/** The page feeds the renderer an <img>: its pixels must arrive whole (no srcset, see setSource). */
async function imageSourceRenders() {
  try {
    const image = new Image();
    image.src = '../assets/brand/icon-256.png';
    await image.decode();
    const read = render(image, 0, DUO_GLASS);
    let sum = 0;
    for (let y = 0; y < image.height; y += 97) for (let x = 0; x < image.width; x += 89) sum += read(x, y)[0] + read(x, y)[1] + read(x, y)[2];
    expect(sum > 0, 'the picture rendered black');
    results.push({ name: 'an <img> source renders', ok: true });
  } catch (error) {
    results.push({ name: 'an <img> source renders', ok: false, error: String(error?.message ?? error) });
  }
}
await imageSourceRenders();

/**
 * Synced frame time at the hero's largest size (1840 x 1195): render, then read one pixel, which waits for the GPU.
 * Frames are paced by requestAnimationFrame like the page, so the GPU clocks as it would for real.
 * Not timer queries: under ANGLE on Metal they read high even for a clear. Not back-to-back draws either:
 * Apple GPUs discard overdrawn opaque frames within one pass, so those read near zero.
 */
async function benchmark() {
  const canvas = document.createElement('canvas');
  canvas.width = 1840;
  canvas.height = 1195;
  const renderer = new GlassRenderer(canvas);
  const gl = renderer.gl;
  renderer.setSource(checkerboard(1920, 1247, 16));
  const pixel = new Uint8Array(4);
  const times = [];
  for (let i = 0; i < 70; i++) {
    const start = performance.now();
    renderer.render({ progress: 0.2 + 0.7 * (i / 69), glass: DUO_GLASS });
    gl.readPixels(0, 0, 1, 1, gl.RGBA, gl.UNSIGNED_BYTE, pixel);
    if (i >= 10) times.push(performance.now() - start); // the first frames include shader warm-up
    await new Promise(requestAnimationFrame);
  }
  renderer.dispose();
  times.sort((a, b) => a - b);
  return { medianMs: times[times.length >> 1], p95Ms: times[Math.floor(times.length * 0.95)] };
}

const probe = document.createElement('canvas').getContext('webgl2');
const info = probe?.getExtension('WEBGL_debug_renderer_info');
window.__gpu = {
  renderer: info ? probe.getParameter(info.UNMASKED_RENDERER_WEBGL) : 'unknown',
  results,
  benchmark: new URLSearchParams(location.search).has('bench') ? await benchmark() : null,
  done: true,
};
