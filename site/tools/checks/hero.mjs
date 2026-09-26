// The opening sequence: no layout shift, 60 fps, the scroll link, and every way it falls back to a still Mac.
import { NO_WEBGL } from '../shoot.mjs';
import { INTRO_DONE, LID_ANGLE, check, sleep } from './common.mjs';

export const NAME = 'hero';
export const FRAMES = { medianMs: 17.5, p95Ms: 20, slowMs: 34, slowAllowed: 2 };

const INTRO_FRAMES = `(() => {
  const start = performance.getEntriesByName('pli-intro-start')[0].startTime;
  const end = performance.getEntriesByName('pli-intro-end')[0].startTime;
  const frames = window.__pli.frames.filter((t) => t >= start && t <= end);
  const deltas = frames.slice(1).map((t, i) => t - frames[i]).sort((a, b) => a - b);
  return {
    count: deltas.length,
    median: deltas[deltas.length >> 1],
    p95: deltas[Math.floor(deltas.length * 0.95)],
    slow: deltas.filter((d) => d > ${FRAMES.slowMs}).length,
    cls: window.__pli.shifts.reduce((a, b) => a + b, 0),
  };
})()`;

const STILL = `(() => ({
  motion: document.documentElement.dataset.motion,
  lid: document.querySelector('[data-mac]').dataset.lid,
  angle: ${LID_ANGLE},
  running: document.getAnimations().filter((a) => a.playState === 'running' && !(a.timeline instanceof ViewTimeline)).length,
  webgl: document.querySelector('.mac-glass').width !== 300,
  still: getComputedStyle(document.querySelector('.mac-still')).visibility === 'visible',
}))()`;

const isStill = (s) => s.motion === 'still' && s.lid === 'still' && s.angle === 110 && s.still && s.running === 0;
const LIVE = `document.querySelector('[data-mac]').dataset.lid === 'live'`;

// Review Focus 4: with srcset, the <img> reports a density-corrected naturalWidth smaller than the pixels
// WebGL uploads. Here 3840w at 100px makes it report 50 px for a 1920 px file.
const SRCSET_PICTURE = `(() => {
  new MutationObserver((records, observer) => {
    const img = document.querySelector('.mac-still');
    if (!img) return;
    img.srcset = 'assets/desktop.webp 3840w';
    img.sizes = '100px';
    observer.disconnect();
  }).observe(document, { childList: true, subtree: true });
})();`;

export async function run({ chrome, url }) {
  const out = [];

  const page = await chrome.newPage({ width: 1440, height: 900, deviceScaleFactor: 2 });
  await page.goto(`${url}/`);
  await page.waitUntil(INTRO_DONE, 15000);
  const intro = await page.evaluate(INTRO_FRAMES);
  out.push(check('no layout shift during the opening', intro.cls < 0.001, `CLS ${intro.cls.toFixed(4)}`));
  out.push(check('60 fps during the opening at 2x',
    intro.count > 60 && intro.median <= FRAMES.medianMs && intro.p95 <= FRAMES.p95Ms && intro.slow <= FRAMES.slowAllowed,
    `${intro.count} frames, median ${intro.median?.toFixed(1)} ms, p95 ${intro.p95?.toFixed(1)} ms, ${intro.slow} over ${FRAMES.slowMs} ms`));
  out.push(check('no error during the opening', page.problems.length === 0, page.problems.slice(0, 2).join(' | ')));
  await page.close();

  // A short window makes the page scroll far enough for the link at every stage of the build.
  const short = await chrome.newPage({ width: 1440, height: 500 });
  await short.goto(`${url}/`);
  await short.waitUntil(INTRO_DONE, 15000);
  await short.evaluate(`window.scrollTo({ top: document.documentElement.scrollHeight, behavior: 'instant' })`);
  await sleep(500);
  const open = await short.evaluate(LID_ANGLE);
  await short.evaluate(`window.scrollTo({ top: 0, behavior: 'instant' })`);
  await sleep(1200);
  const closed = await short.evaluate(LID_ANGLE);
  out.push(check('scrolling down keeps the lid open', open > 109, `${open}°`));
  out.push(check('scrolling back to the top closes the lid again', closed < 1, `${closed}°`));
  await short.close();

  // A visitor who arrives scrolled (a reload, a link to #footer) gets an open Mac, and no opening off screen.
  const arrived = await chrome.newPage({ width: 1440, height: 500 });
  await arrived.goto(`${url}/#footer`);
  await arrived.waitUntil(LIVE);
  await sleep(600); // an opening would still be under 1° here
  const late = await arrived.evaluate(`({ angle: ${LID_ANGLE}, y: scrollY })`);
  out.push(check('arriving scrolled: open at once, no opening off screen', late.y > 0 && late.angle > 109, JSON.stringify(late)));
  await arrived.close();

  const reduced = await chrome.newPage({ reducedMotion: true });
  await reduced.goto(`${url}/`);
  await sleep(400);
  const r = await reduced.evaluate(STILL);
  out.push(check('reduced motion: open and still, no WebGL', isStill(r) && !r.webgl, JSON.stringify(r)));
  await reduced.close();

  const flat = await chrome.newPage({ beforeLoad: [NO_WEBGL] });
  await flat.goto(`${url}/`);
  await sleep(400);
  const f = await flat.evaluate(STILL);
  out.push(check('no WebGL2: open with the static picture', isStill(f), JSON.stringify(f)));
  await flat.close();

  const switched = await chrome.newPage();
  await switched.goto(`${url}/`);
  await switched.waitUntil(LIVE);
  await sleep(700);
  await switched.send('Emulation.setEmulatedMedia', { features: [{ name: 'prefers-reduced-motion', value: 'reduce' }] });
  await sleep(300);
  const s = await switched.evaluate(STILL);
  out.push(check('Reduce Motion switched on mid-opening: snaps open and stops', isStill(s), JSON.stringify(s)));
  await switched.close();

  const lost = await chrome.newPage();
  await lost.goto(`${url}/`);
  await lost.waitUntil(LIVE);
  await sleep(700);
  await lost.evaluate(`document.querySelector('.mac-glass').getContext('webgl2').getExtension('WEBGL_lose_context').loseContext()`);
  await sleep(1300);
  const l = await lost.evaluate(STILL);
  out.push(check('GPU context lost mid-opening: opens with the static picture', isStill(l), JSON.stringify(l)));
  await lost.close();

  const shrunk = await chrome.newPage({ beforeLoad: [SRCSET_PICTURE] });
  await shrunk.goto(`${url}/`);
  await sleep(1500);
  const p = await shrunk.evaluate(STILL);
  out.push(check('a picture given a srcset: the upload is refused and the Mac opens still', isStill(p), JSON.stringify(p)));
  await shrunk.close();
  return out;
}
