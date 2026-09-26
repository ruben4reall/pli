// Generates assets/keyboard.svg: a blank, legend-free MacBook-style keyboard used as the background image of
// .mac-keyboard (site/css/mac.css). Six rows: a full-height function row (esc, 12 keys, a square key at the
// right end), the number row, tab row, caps row, shift row, and a bottom row with fn, control, option,
// command, a wide spacebar, command, option and inverted-T half-height arrow keys. No legends, no Apple logo:
// every key is a plain rounded rect, near-black with a faint top highlight, sitting on a darker well so the
// gaps between keys read as recesses, never bright lines. Run once and commit the output.
// Usage: node tools/make-keyboard-svg.mjs
import { writeFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';

const KEY = 100; // one key unit, in SVG px
const ROW_H = 90; // row height, in SVG px
const GAP = 10; // gap between keys, both axes: the well shows through here
const MARGIN = 16; // canvas margin around the whole grid
const RADIUS = 9; // key corner radius
const WELL = '#0b0b0c'; // the gaps and the canvas background: darker than any key
const UNITS = 15; // every row sums to this many key units, so columns stay aligned row to row

// Each row is a list of key spans in key units; the string 'split' is the arrow cluster's middle
// column, drawn as two stacked half-height keys (the inverted-T shape) instead of one key.
const ROWS = [
  Array(14).fill(UNITS / 14), // function row: esc, F1-F12, the square key at the right end
  [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 2], // number row: ` 1 2 3 4 5 6 7 8 9 0 - = delete
  [1.5, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1.5], // tab row: tab q w e r t y u i o p [ ] backslash
  [1.75, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 2.25], // caps row: caps a s d f g h j k l ; ' return
  [2.25, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 2.75], // shift row: shift z x c v b n m , . / shift
  [1, 1, 1, 1.25, 5.5, 1.25, 1, 1, 'split', 1], // bottom row: fn control option command [space] command option left [up/down] right
];

for (const [i, row] of ROWS.entries()) {
  const sum = row.reduce((total, span) => total + (span === 'split' ? 1 : span), 0);
  if (Math.abs(sum - UNITS) > 1e-6) throw new Error(`row ${i} sums to ${sum}, expected ${UNITS}`);
}

const WIDTH = UNITS * KEY + MARGIN * 2;
const HEIGHT = ROWS.length * ROW_H + MARGIN * 2;
const round = (n) => Math.round(n * 100) / 100;

function key(x, y, w, h) {
  return `<rect x="${round(x)}" y="${round(y)}" width="${round(w)}" height="${round(h)}" rx="${RADIUS}" fill="url(#key)"/>`;
}

const rects = [];
ROWS.forEach((row, r) => {
  const y = MARGIN + r * ROW_H;
  let col = 0;
  for (const span of row) {
    const x = MARGIN + col * KEY;
    if (span === 'split') {
      const w = KEY - GAP;
      const half = (ROW_H - GAP * 2) / 2;
      rects.push(key(x + GAP / 2, y + GAP / 2, w, half));
      rects.push(key(x + GAP / 2, y + GAP / 2 + half + GAP, w, half));
      col += 1;
    } else {
      const w = span * KEY - GAP;
      const h = ROW_H - GAP;
      rects.push(key(x + GAP / 2, y + GAP / 2, w, h));
      col += span;
    }
  }
});

const svg = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${WIDTH} ${HEIGHT}">
<defs>
<linearGradient id="key" x1="0" y1="0" x2="0" y2="1">
<stop offset="0%" stop-color="#2f2f33"/>
<stop offset="14%" stop-color="#2c2c2f"/>
<stop offset="100%" stop-color="#232326"/>
</linearGradient>
</defs>
<rect width="${WIDTH}" height="${HEIGHT}" fill="${WELL}"/>
${rects.join('\n')}
</svg>
`;

const OUT = new URL('../assets/keyboard.svg', import.meta.url);
if (process.argv[1] === fileURLToPath(import.meta.url)) {
  await writeFile(OUT, svg);
  console.log(`${fileURLToPath(OUT)} (${svg.length} bytes, ${WIDTH}x${HEIGHT})`);
}
