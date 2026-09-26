// The drawn MacBook stays in its place at every lid angle: inside the 16 px gutters on phones, below the
// headline, and (on a 1440 x 900 screen) entirely within the first screen.
import { check, sleep } from './common.mjs';

export const NAME = 'mac';
export const ANGLES = [0, 15, 30, 45, 60, 75, 90, 110];
const GUTTER = 16;

const BOUNDS = `(() => {
  let left = Infinity, right = -Infinity, top = Infinity, bottom = -Infinity;
  for (const el of document.querySelectorAll('.mac-base, .mac-front, .mac-lid, .mac-screen, .mac-shell')) {
    const r = el.getBoundingClientRect();
    left = Math.min(left, r.left); right = Math.max(right, r.right);
    top = Math.min(top, r.top); bottom = Math.max(bottom, r.bottom);
  }
  return { left, right, top, bottom, h1: document.querySelector('h1').getBoundingClientRect().bottom, vw: innerWidth, vh: innerHeight };
})()`;

export async function run({ chrome, url }) {
  const out = [];
  const sizes = {
    desktop: { width: 1440, height: 900 },
    phone: { width: 390, height: 844, deviceScaleFactor: 2, mobile: true },
    narrow: { width: 375, height: 812, deviceScaleFactor: 2, mobile: true },
  };
  for (const [label, size] of Object.entries(sizes)) {
    // Reduced motion keeps the page still, so the angle set here stays put.
    const page = await chrome.newPage({ ...size, reducedMotion: true });
    await page.goto(`${url}/`);
    await sleep(300);
    const escapes = [];
    for (const angle of ANGLES) {
      const b = await page.evaluate(`(document.querySelector('[data-mac]').style.setProperty('--lid-angle', '${angle}'), ${BOUNDS})`);
      const margin = label === 'desktop' ? 0 : GUTTER - 1;
      if (b.left < margin || b.right > b.vw - margin) escapes.push(`${angle}°: x ${Math.round(b.left)}..${Math.round(b.right)}`);
      if (b.top < b.h1) escapes.push(`${angle}°: top ${Math.round(b.top)} above the headline at ${Math.round(b.h1)}`);
      if (label === 'desktop' && b.bottom > b.vh) escapes.push(`${angle}°: bottom ${Math.round(b.bottom)} below the first screen`);
    }
    out.push(check(`${label}: the Mac stays in its place at every angle`, escapes.length === 0, escapes.slice(0, 3).join(' | ')));
    await page.close();
  }
  return out;
}
