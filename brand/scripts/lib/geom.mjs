// Geometry helpers shared by the Pli brand generators (icon, symbol, wordmark).

// Degrees to radians.
export const rad = (d) => (d * Math.PI) / 180;

// A number as SVG writes it: two decimals at most, no negative zero.
export const f = (n) => {
  const v = Math.round(n * 100) / 100;
  return Object.is(v, -0) ? '0' : String(v);
};

// Continuous-corner rounded rectangle (the macOS icon "squircle"), after the
// corner-smoothing construction described by Figma. s is the smoothing, from
// 0 (circular corners) to 1.
function cornerParams(r, s, budget) {
  let p = (1 + s) * r;
  if (p > budget) {
    s = Math.max(0, Math.min(s, budget / r - 1));
    p = Math.min(p, budget);
  }
  const arcMeasure = 90 * (1 - s);
  const L = Math.sin(rad(arcMeasure / 2)) * r * Math.SQRT2;
  const angleAlpha = (90 - arcMeasure) / 2;
  const p3p4 = r * Math.tan(rad(angleAlpha / 2));
  const angleBeta = 45 * s;
  const c = p3p4 * Math.cos(rad(angleBeta));
  const d = c * Math.tan(rad(angleBeta));
  const b = (p - L - c - d) / 3;
  const a = 2 * b;
  return { a, b, c, d, p, L, r };
}

// r is one radius, or four: [top left, top right, bottom right, bottom left].
export function squircle(x, y, w, h, r, s = 0.6) {
  const radii = Array.isArray(r) ? r : [r, r, r, r];
  const [tl, tr, br, bl] = radii.map((ri) => cornerParams(ri, s, Math.min(w, h) / 2));
  const arc = (k, dx, dy) => `a${f(k.r)} ${f(k.r)} 0 0 1 ${f(dx)} ${f(dy)}`;
  return [
    `M${f(x + w - tr.p)} ${f(y)}`,
    `c${f(tr.a)} 0 ${f(tr.a + tr.b)} 0 ${f(tr.a + tr.b + tr.c)} ${f(tr.d)}`,
    arc(tr, tr.L, tr.L),
    `c${f(tr.d)} ${f(tr.c)} ${f(tr.d)} ${f(tr.b + tr.c)} ${f(tr.d)} ${f(tr.a + tr.b + tr.c)}`,
    `L${f(x + w)} ${f(y + h - br.p)}`,
    `c0 ${f(br.a)} 0 ${f(br.a + br.b)} ${f(-br.d)} ${f(br.a + br.b + br.c)}`,
    arc(br, -br.L, br.L),
    `c${f(-br.c)} ${f(br.d)} ${f(-(br.b + br.c))} ${f(br.d)} ${f(-(br.a + br.b + br.c))} ${f(br.d)}`,
    `L${f(x + bl.p)} ${f(y + h)}`,
    `c${f(-bl.a)} 0 ${f(-(bl.a + bl.b))} 0 ${f(-(bl.a + bl.b + bl.c))} ${f(-bl.d)}`,
    arc(bl, -bl.L, -bl.L),
    `c${f(-bl.d)} ${f(-bl.c)} ${f(-bl.d)} ${f(-(bl.b + bl.c))} ${f(-bl.d)} ${f(-(bl.a + bl.b + bl.c))}`,
    `L${f(x)} ${f(y + tl.p)}`,
    `c0 ${f(-tl.a)} 0 ${f(-(tl.a + tl.b))} ${f(tl.d)} ${f(-(tl.a + tl.b + tl.c))}`,
    arc(tl, tl.L, -tl.L),
    `c${f(tl.c)} ${f(-tl.d)} ${f(tl.b + tl.c)} ${f(-tl.d)} ${f(tl.a + tl.b + tl.c)} ${f(-tl.d)}`,
    'Z',
  ].join('');
}

// Polygon with filleted corners (circular arcs tangent to both edges).
// pts: [[x,y],...] in drawing order; r: radius or array of radii.
export function roundedPoly(pts, r) {
  const n = pts.length;
  const radii = Array.isArray(r) ? r : pts.map(() => r);
  let out = '';
  for (let i = 0; i < n; i++) {
    const p0 = pts[(i - 1 + n) % n];
    const p1 = pts[i];
    const p2 = pts[(i + 1) % n];
    const v1 = [p0[0] - p1[0], p0[1] - p1[1]];
    const v2 = [p2[0] - p1[0], p2[1] - p1[1]];
    const l1 = Math.hypot(...v1);
    const l2 = Math.hypot(...v2);
    const u1 = [v1[0] / l1, v1[1] / l1];
    const u2 = [v2[0] / l2, v2[1] / l2];
    const cos = u1[0] * u2[0] + u1[1] * u2[1];
    const ang = Math.acos(Math.max(-1, Math.min(1, cos)));
    const rr = radii[i];
    const t = rr / Math.tan(ang / 2);
    const a = [p1[0] + u1[0] * t, p1[1] + u1[1] * t];
    const b = [p1[0] + u2[0] * t, p1[1] + u2[1] * t];
    const cross = u1[0] * u2[1] - u1[1] * u2[0];
    const sweep = cross < 0 ? 1 : 0;
    out += (i === 0 ? `M${f(a[0])} ${f(a[1])}` : `L${f(a[0])} ${f(a[1])}`);
    out += `A${f(rr)} ${f(rr)} 0 0 ${sweep} ${f(b[0])} ${f(b[1])}`;
  }
  return out + 'Z';
}
