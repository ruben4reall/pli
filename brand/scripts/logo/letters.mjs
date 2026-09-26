// Production outlines of the Pli wordmark, "pli", as cubic Bezier contours.
//
// The letters are the A1 "Pane" exploration letters, rebuilt without
// polylines: each quarter of a superellipse bowl is one cubic, split exactly
// where it meets the stem, so every glyph is a clean, non-overlapping outline
// (one outer contour, plus one counter for the p), like a font glyph after
// "remove overlap".
//
// Units: the x-height is 100, the baseline is y = 0, y grows downward (SVG).
import { f } from '../lib/geom.mjs';

export const M = {
  S: 21,        // stem width
  xh: 100,      // x-height
  asc: 142,     // ascender (top of the l)
  desc: 42,     // descender (bottom of the p)
  over: 1.6,    // overshoot of the bowl above the x-height and below the baseline
  bowlW: 97,    // width of the p, from the stem's left edge to the bowl's right extreme
  gap1: 18,     // bowl to l (round to straight)
  gap2: 25,     // l to i (straight to straight)
  n: 2.35,      // superellipse exponent of the bowl
  nIn: 2.6,     // superellipse exponent of the counter
  inL: 12,      // virtual left extreme of the counter, inside the stem
  // The pane that dots the i: landscape, like the icon's pane, its top
  // corners rounder than its bottom ones, centered on the stem.
  dotW: 24, dotTop: -133, dotBottom: -114, dotRTop: 3.2, dotRBottom: 2.2,
};

// ---------- Contours

// A contour is a start point and a list of segments, ['L', to] or
// ['C', c1, c2, to]; d(dx, dy) writes it as SVG path data, offset by (dx, dy).
export class Contour {
  constructor(start) { this.start = start; this.segs = []; }
  L(to) { this.segs.push(['L', to]); return this; }
  C(c1, c2, to) { this.segs.push(['C', c1, c2, to]); return this; }
  cubic([, c1, c2, to]) { return this.C(c1, c2, to); }
  d(dx = 0, dy = 0) {
    const X = (x) => f(x + dx), Y = (y) => f(y + dy);
    const P = ([x, y]) => `${X(x)} ${Y(y)}`;
    let s = `M${P(this.start)}`;
    let cur = this.start;
    this.segs.forEach((seg, i) => {
      const to = seg[seg.length - 1];
      const closing = i === this.segs.length - 1 && P(to) === P(this.start);
      if (seg[0] === 'L') {
        if (closing) return; // Z draws the closing line
        if (X(to[0]) === X(cur[0])) s += `V${Y(to[1])}`;
        else if (Y(to[1]) === Y(cur[1])) s += `H${X(to[0])}`;
        else s += `L${P(to)}`;
      } else {
        s += `C${P(seg[1])} ${P(seg[2])} ${P(to)}`;
      }
      cur = to;
    });
    return s + 'Z';
  }
}

export const rect = (x, y, w, h) =>
  new Contour([x, y]).L([x + w, y]).L([x + w, y + h]).L([x, y + h]);

// A rectangle with its own top and bottom corner radii (circular quarters as
// cubics), clockwise from the top left.
export function pane(x, y, w, h, rTop, rBottom) {
  const k = 0.5523;
  return new Contour([x + rTop, y])
    .L([x + w - rTop, y])
    .C([x + w - rTop + k * rTop, y], [x + w, y + rTop - k * rTop], [x + w, y + rTop])
    .L([x + w, y + h - rBottom])
    .C([x + w, y + h - rBottom + k * rBottom], [x + w - rBottom + k * rBottom, y + h], [x + w - rBottom, y + h])
    .L([x + rBottom, y + h])
    .C([x + rBottom - k * rBottom, y + h], [x, y + h - rBottom + k * rBottom], [x, y + h - rBottom])
    .L([x, y + rTop])
    .C([x, y + rTop - k * rTop], [x + rTop - k * rTop, y], [x + rTop, y]);
}

// ---------- Cubic helpers

const lerp = (a, b, t) => [a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t];

// De Casteljau split of [P0, P1, P2, P3] at t: [left, right].
export function split([p0, p1, p2, p3], t) {
  const a = lerp(p0, p1, t), b = lerp(p1, p2, t), c = lerp(p2, p3, t);
  const d = lerp(a, b, t), e = lerp(b, c, t);
  const m = lerp(d, e, t);
  return [[p0, a, d, m], [m, e, c, p3]];
}

function xAt([p0, p1, p2, p3], t) {
  const u = 1 - t;
  return u * u * u * p0[0] + 3 * u * u * t * p1[0] + 3 * u * t * t * p2[0] + t * t * t * p3[0];
}

// Splits a cubic whose x is monotonic where it crosses x = X.
function splitAtX(c, X) {
  let lo = 0, hi = 1;
  const increasing = xAt(c, 1) > xAt(c, 0);
  for (let i = 0; i < 64; i++) {
    const mid = (lo + hi) / 2;
    if ((xAt(c, mid) < X) === increasing) lo = mid; else hi = mid;
  }
  return split(c, (lo + hi) / 2);
}

// ---------- Superellipse quarters as cubics

// Handle factor that makes a one-cubic quarter pass through the
// superellipse's 45 degree point (x = a * 2^(-1/n) at t = 0.5).
const kappa = (n) => (Math.pow(2, -1 / n) - 0.5) / 0.375;

// One quarter from extreme `from` to the adjacent extreme `to`
// (R, B, L, T: right, bottom, left, top; y down).
function quarter({ cx, cy, ax, ay, n }, from, to) {
  const k = kappa(n);
  const P = { R: [cx + ax, cy], B: [cx, cy + ay], L: [cx - ax, cy], T: [cx, cy - ay] };
  const handle = (e, toward) => {
    const p = P[e], q = P[toward];
    return e === 'R' || e === 'L' ? [p[0], p[1] + k * (q[1] - p[1])] : [p[0] + k * (q[0] - p[0]), p[1]];
  };
  return [P[from], handle(from, to), handle(to, from), P[to]];
}

// ---------- The letters

// Returns the glyph contours in letter units, plus the same glyphs cut along
// the crease (a horizontal line at y = creaseY, which must be the bowl's
// vertical middle, -xh / 2, where the quarters meet): `upper` is everything
// above it, `lower` everything below. `upperReach` extends the upper pieces
// below the crease, so an effect drawn around them has no edge at the cut
// (the lower pieces are drawn over them).
export function glyphs(m = M, { upperReach = 0 } = {}) {
  const { S, xh, asc, desc, over, bowlW } = m;
  const top = -xh - over, bot = over;
  const Y = -xh / 2;
  const outer = { cx: bowlW / 2, cy: Y, ax: bowlW / 2, ay: (bot - top) / 2, n: m.n };
  const Tside = S * 1.07, Ttop = S * 0.86; // curves a touch heavier than stems, horizontals lighter
  const inR = bowlW - Tside;
  const inner = { cx: (inR + m.inL) / 2, cy: Y, ax: (inR - m.inL) / 2, ay: (bot - top) / 2 - Ttop, n: m.nIn };

  const [, oTL] = splitAtX(quarter(outer, 'L', 'T'), S); // from the stem up to the top
  const [oBL] = splitAtX(quarter(outer, 'B', 'L'), S);   // from the bottom back to the stem
  const [iTL] = splitAtX(quarter(inner, 'T', 'L'), S);   // counter: top, to the stem
  const [, iBL] = splitAtX(quarter(inner, 'L', 'B'), S); // counter: stem, to the bottom
  const oTR = quarter(outer, 'T', 'R'), oRB = quarter(outer, 'R', 'B');
  const iBR = quarter(inner, 'B', 'R'), iRT = quarter(inner, 'R', 'T');

  // p: the stem and the bowl in one clockwise contour, the counter counterclockwise.
  const p = new Contour([0, -xh]).L([S, -xh]).L(oTL[0])
    .cubic(oTL).cubic(oTR).cubic(oRB).cubic(oBL)
    .L([S, desc]).L([0, desc]);
  const counter = new Contour(iTL[3]).L(iBL[0]).cubic(iBL).cubic(iBR).cubic(iRT).cubic(iTL);

  const lx = bowlW + m.gap1;
  const ix = lx + S + m.gap2;
  const l = rect(lx, -asc, S, asc);
  const i = rect(ix, -xh, S, xh);
  const dot = pane(ix + S / 2 - m.dotW / 2, m.dotTop, m.dotW, m.dotBottom - m.dotTop, m.dotRTop, m.dotRBottom);

  // The same letters cut along the crease. The bowl's quarters meet at y = Y,
  // so the cut runs exactly through quarter ends: no curve is split.
  const r = upperReach;
  const pUpper = new Contour([0, -xh]).L([S, -xh]).L(oTL[0]).cubic(oTL).cubic(oTR)
    .L([oTR[3][0], Y + r]).L([iRT[0][0], Y + r]).L(iRT[0]).cubic(iRT).cubic(iTL)
    .L([S, Y + r]).L([0, Y + r]);
  const pLower = new Contour([0, Y]).L([S, Y]).L(iBL[0]).cubic(iBL).cubic(iBR)
    .L(oRB[0]).cubic(oRB).cubic(oBL).L([S, desc]).L([0, desc]);
  const upper = [pUpper, rect(lx, -asc, S, asc + Y + r), rect(ix, -xh, S, xh + Y + r), dot];
  const lower = [pLower, rect(lx, Y, S, -Y), rect(ix, Y, S, -Y)];

  const bounds = { x0: 0, x1: Math.max(ix + S, ix + S / 2 + m.dotW / 2), y0: -asc, y1: desc };
  return { p, counter, l, i, dot, upper, lower, creaseY: Y, lx, ix, bounds, m };
}
