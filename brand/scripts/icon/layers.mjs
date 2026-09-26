// Writes the SVG layers of the Pli app icon (brand/Pli.icon/Assets/).
//   node brand/scripts/icon/layers.mjs [assets-dir]
//   node brand/scripts/icon/layers.mjs --square-background <file.svg>
// The second form writes the icon's background (fill and glow) as a square
// SVG, which brand/scripts/export-icon.sh uses for opaque-1024.png. The
// export script renders the previews.
//
// Variant A1 "Pane": one pane of glass tilted toward the viewer on a hinge
// line, frost rising to the top, an iridescent rim on the top edge, on Night.
// The geometry starts from the A1 exploration icon (drawn in the 824 body of
// the 1024 grid), scaled to the Icon Composer canvas, where the full
// 1024 x 1024 square is the icon body. Icon Composer renders SVG without
// filters, so every soft effect here is a gradient, a clip path or a mask.
// Colors come from brand/tokens/tokens.json.
//
// The geometry G is exported for the favicon symbol (brand/scripts/logo/build.mjs);
// importing this module computes the layers without writing them.
import { writeFileSync, mkdirSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { resolve } from 'node:path';
import { f, roundedPoly } from '../lib/geom.mjs';
import { C, IRI } from '../lib/tokens.mjs';

const OUT = process.argv[2] || fileURLToPath(new URL('../../Pli.icon/Assets', import.meta.url));

// Board body (100..924) to canvas (0..1024).
const S = 1024 / 824;
const X = (x) => (x - 100) * S;

// ---------- Geometry (canvas units)
// The hinge is centered on y = 812: its core then falls inside a single
// pixel row when the icon body is 13 or 26 px (a 16 pt Finder icon at 1x and
// 2x) and 16 or 32 px (the small previews), so it renders as one bright row
// under the pane instead of two dim ones.
const HINGE_Y = 812;
const SLOPE = 44 / 438; // side lean of the board pane, per unit of height
export const G = {
  // The pane: wider at the top, so it leans toward the viewer.
  yTop: X(290), yBot: HINGE_Y,
  topL: X(226), topR: X(798),
  rTop: 60, rBot: 10,
  // The rim: iridescent light entering the top edge of the glass.
  rimH: 60,
  // The hinge: a bright core with a Glacier halo, fading at its very ends.
  hingeL: X(150), hingeR: X(874), hingeY: HINGE_Y, hingeCore: 18, hingeHalo: 12, hingeFade: 0.05,
};
G.botL = G.topL + SLOPE * (G.yBot - G.yTop);
G.botR = G.topR - SLOPE * (G.yBot - G.yTop);

const pane = roundedPoly(
  [[G.topL, G.yTop], [G.topR, G.yTop], [G.botR, G.yBot], [G.botL, G.yBot]],
  [G.rTop, G.rTop, G.rBot, G.rBot]);

// ---------- SVG helpers
const svg = (body, defs) =>
  `<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">\n` +
  `<defs>\n${defs.join('\n')}\n</defs>\n${body.join('\n')}\n</svg>\n`;
const stop = (o, color, a = 1) => `<stop offset="${f(o)}" stop-color="${color}" stop-opacity="${f(a)}"/>`;
const grad = (id, [x1, y1, x2, y2], stops) =>
  `<linearGradient id="${id}" x1="${f(x1)}" y1="${f(y1)}" x2="${f(x2)}" y2="${f(y2)}" gradientUnits="userSpaceOnUse">` +
  `${stops.join('')}</linearGradient>`;
const vertical = (id, y1, y2, stops) => grad(id, [0, y1, 0, y2], stops);
const horizontal = (id, x1, x2, stops) => grad(id, [x1, 0, x2, 0], stops);
const maskOf = (id, fill) =>
  `<mask id="${id}" maskUnits="userSpaceOnUse" x="0" y="0" width="1024" height="1024">` +
  `<rect width="1024" height="1024" fill="${fill}"/></mask>`;

// ---------- Layers
const layers = {};

// Pane (glass layer). Frost rises from clear, Glacier-tinted glass at the
// hinge to milky Ice at the top. The iridescent rim is drawn inside the same
// layer, so the Liquid Glass bevel lights it like the rest of the edge.
layers['pane.svg'] = svg([
  `<path d="${pane}" fill="url(#frost)"/>`,
  `<g clip-path="url(#pane)" mask="url(#rim-fade)">`,
  `<rect x="0" y="${f(G.yTop - 2)}" width="1024" height="${f(G.rimH + 2)}" fill="url(#iridescent)"/>`,
  `</g>`,
], [
  vertical('frost', G.yTop, G.yBot, [
    stop(0, C.ice, 0.94), stop(0.32, C.ice, 0.5), stop(0.7, C.glacier, 0.14), stop(1, C.glacier, 0.1)]),
  horizontal('iridescent', G.topL, G.topR, IRI.map((s) => stop(s.position, s.color))),
  vertical('rim-alpha', G.yTop, G.yTop + G.rimH, [stop(0, '#FFFFFF'), stop(0.35, '#FFFFFF', 0.8), stop(1, '#FFFFFF', 0)]),
  `<clipPath id="pane"><path d="${pane}"/></clipPath>`,
  maskOf('rim-fade', 'url(#rim-alpha)'),
]);

// Hinge (flat layer, in front of the pane). A white core with a soft Glacier
// halo: thin at 1024, and still one bright row, wider than the pane, at 16 px.
{
  const { hingeL: x0, hingeR: x1, hingeY: y, hingeCore: t, hingeHalo: h, hingeFade: e } = G;
  const H = t / 2 + h;
  const inner = (t / 2) / (2 * H);
  layers['hinge.svg'] = svg([
    `<g mask="url(#hinge-ends)">`,
    `<rect x="${f(x0)}" y="${f(y - H)}" width="${f(x1 - x0)}" height="${f(2 * H)}" fill="url(#hinge-halo)"/>`,
    `<rect x="${f(x0)}" y="${f(y - t / 2)}" width="${f(x1 - x0)}" height="${f(t)}" rx="${f(t / 2)}" fill="${C.white}"/>`,
    `</g>`,
  ], [
    vertical('hinge-halo', y - H, y + H, [
      stop(0, C.glacier, 0), stop(0.5 - inner, C.glacier, 0.3), stop(0.5 + inner, C.glacier, 0.3), stop(1, C.glacier, 0)]),
    horizontal('hinge-alpha', x0, x1, [stop(0, '#FFFFFF', 0), stop(e, '#FFFFFF'), stop(1 - e, '#FFFFFF'), stop(1, '#FFFFFF', 0)]),
    maskOf('hinge-ends', 'url(#hinge-alpha)'),
  ]);
}

// Glow (flat layer, behind the pane): Deep Glacier light rising behind the
// top edge. Hidden in the tinted and clear appearances (see icon.json).
const glowGradient = (id) =>
  `<radialGradient id="${id}" cx="512" cy="${f(G.yTop)}" r="${f(420 * S)}" gradientUnits="userSpaceOnUse" ` +
  `gradientTransform="translate(0 ${f(G.yTop)}) scale(1 0.55) translate(0 ${f(-G.yTop)})">` +
  `${stop(0, C.deepGlacier, 0.34)}${stop(1, C.deepGlacier, 0)}</radialGradient>`;
layers['glow.svg'] = svg([`<rect width="1024" height="1024" fill="url(#glow)"/>`], [glowGradient('glow')]);

// The icon's background as a square SVG, for the unmasked preview: Night to
// Slate, top to bottom, as in icon.json, with the glow.
const squareBackground = svg([
  `<rect width="1024" height="1024" fill="url(#fill)"/>`,
  `<rect width="1024" height="1024" fill="url(#glow)"/>`,
], [
  vertical('fill', 0, 1024, [stop(0, C.night), stop(1, C.slate)]),
  glowGradient('glow'),
]);

if (process.argv[1] && fileURLToPath(import.meta.url) === resolve(process.argv[1]) && process.argv[2] === '--square-background') {
  if (!process.argv[3]) throw new Error('--square-background needs an output file');
  writeFileSync(process.argv[3], squareBackground);
} else if (process.argv[1] && fileURLToPath(import.meta.url) === resolve(process.argv[1])) {
  mkdirSync(OUT, { recursive: true });
  for (const [name, content] of Object.entries(layers)) writeFileSync(`${OUT}/${name}`, content);
  console.log(`wrote ${Object.keys(layers).join(', ')} to ${OUT}`);
}
