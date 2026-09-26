// The opening sequence: the page's MacBook opens on load and its display unfolds out of frost, rendered live
// from Pli's optical model. Reduced motion, no WebGL2, a failed picture or a lost GPU context: open and still.
import { GlassRenderer } from './renderer.js';
import { DUO_GLASS, DUO_MOTION, PAGE_LID_REST, follow, foldProgress } from './optics.js';
import { SCROLL_SMOOTHING, frozenAngle, nextPhase, resumedStart, runway, startPhase, targetAngle } from './timeline.js';

export function startHero(doc = document, win = window) {
  const mac = doc.querySelector('[data-mac]');
  if (!mac) return null;
  const root = doc.documentElement;
  const still = mac.querySelector('.mac-still');
  const canvas = mac.querySelector('.mac-glass');
  const reduce = win.matchMedia('(prefers-reduced-motion: reduce)');
  const frozen = frozenAngle(win.location.search);

  let renderer = null;
  let observer = null;
  let frame = 0;
  let phase = null;
  let angle = 0;
  let start = null;
  let last = null;
  let hiddenAt = null;
  let drawn = { progress: Number.NaN, width: 0, height: 0 };

  function wake() {
    if (!frame && renderer) frame = win.requestAnimationFrame(tick);
  }

  function goStill() {
    if (frame) win.cancelAnimationFrame(frame);
    frame = 0;
    win.removeEventListener('scroll', wake);
    win.removeEventListener('resize', wake);
    observer?.disconnect();
    renderer?.dispose();
    renderer = null;
    root.dataset.motion = 'still';
    mac.dataset.lid = 'still';
    mac.style.removeProperty('--lid-angle'); // the CSS rule for a still Mac opens it (with a transition when motion is allowed)
  }

  function draw() {
    mac.style.setProperty('--lid-angle', angle.toFixed(2));
    const progress = foldProgress(DUO_MOTION, angle, PAGE_LID_REST);
    const { width, height } = canvas;
    if (progress === drawn.progress && width === drawn.width && height === drawn.height) return;
    if (renderer.render({ progress, glass: DUO_GLASS })) drawn = { progress, width, height };
  }

  function tick(now) {
    frame = 0;
    const t = now / 1000;
    const input = { elapsed: 0, scrollY: win.scrollY, run: runway(win.innerHeight) };
    if (start === null) {
      start = t;
      phase = frozen !== null ? 'frozen' : startPhase(input.scrollY, input.run);
      if (phase === 'linked') angle = targetAngle(phase, input); // arrived already scrolled: no glide
      if (phase === 'intro') win.performance.mark('pli-intro-start');
    }
    input.elapsed = t - start;
    const dt = last === null ? 0 : t - last;
    last = t;
    if (phase !== 'frozen') {
      const previous = phase;
      phase = nextPhase(phase, input);
      if (previous === 'intro' && phase !== 'intro') win.performance.mark('pli-intro-end');
    }
    const target = phase === 'frozen' ? frozen : targetAngle(phase, input);
    angle = phase === 'intro' || phase === 'frozen' ? target : follow(angle, target, dt, SCROLL_SMOOTHING);
    draw();
    if (phase === 'intro' || angle !== target) wake();
    else last = null; // idle: the next scroll starts from a fresh clock
  }

  async function begin() {
    if (root.dataset.motion !== 'full' || reduce.matches) {
      goStill();
      return;
    }
    try {
      renderer = new GlassRenderer(canvas);
      await still.decode();
      renderer.setSource(still);
    } catch {
      goStill();
      return;
    }
    renderer.onLost = goStill;
    reduce.addEventListener('change', (event) => {
      if (event.matches) goStill();
    });
    doc.addEventListener('visibilitychange', () => {
      // A hidden tab pauses the opening instead of skipping it.
      if (doc.hidden) hiddenAt = win.performance.now() / 1000;
      else if (hiddenAt !== null) {
        start = resumedStart(start, hiddenAt, win.performance.now() / 1000);
        hiddenAt = null;
        last = null;
        wake();
      }
    });
    observer = new win.ResizeObserver(() => {
      if (renderer?.resize(canvas.clientWidth, canvas.clientHeight, win.devicePixelRatio)) {
        drawn = { progress: Number.NaN, width: 0, height: 0 };
        wake();
      }
    });
    observer.observe(canvas);
    renderer.resize(canvas.clientWidth, canvas.clientHeight, win.devicePixelRatio);
    mac.dataset.lid = 'live';
    win.addEventListener('scroll', wake, { passive: true });
    win.addEventListener('resize', wake);
    wake();
  }

  begin();
  return { goStill, get phase() { return phase; }, get angle() { return angle; } };
}
