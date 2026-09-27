// The Looks section: pick a look and drag the lid, and the glass is drawn live on the real desktop with Pli's
// optical model, on either real wallpaper (macOS 26's Tahoe, or the MacBook Pro's Pro Black). Without WebGL2, with
// reduced motion or a lost context, the pictures exported for each look and wallpaper stay (tools/export-images.mjs),
// and the chips still switch them.
import { GlassRenderer } from './renderer.js';
import { PAGE_LID_REST, foldProgress, presetById } from './optics.js';

export function startLooks(doc = document, win = window) {
  const root = doc.querySelector('[data-looks]');
  if (!root) return null;
  const still = root.querySelector('[data-look-still]');
  const canvas = root.querySelector('canvas');
  const input = root.querySelector('[data-lid-input]');
  const output = root.querySelector('[data-lid-output]');
  const note = root.querySelector('[data-look-note]');
  const chips = [...root.querySelectorAll('[data-look]')];
  const walls = [...root.querySelectorAll('[data-wall]')];
  const DESKTOPS = { tahoe: 'assets/desktop-tahoe.webp', black: 'assets/desktop.webp' };
  const sources = {};

  let look = presetById('duo');
  let wall = 'tahoe';
  let angle = Number(input.value);
  let renderer = null;
  let frame = 0;

  function draw() {
    frame = 0;
    if (!renderer) return;
    renderer.render({ progress: foldProgress(look.motion, angle, PAGE_LID_REST), glass: look.glass });
  }

  function request() {
    if (renderer && !frame) frame = win.requestAnimationFrame(draw);
  }

  function goStill() {
    renderer?.dispose();
    renderer = null;
    root.dataset.live = 'off';
  }

  function choose(id) {
    const next = presetById(id);
    if (!next) return;
    look = next;
    for (const chip of chips) chip.setAttribute('aria-pressed', String(chip.dataset.look === id));
    note.textContent = `${next.name}: ${next.intent.charAt(0).toLowerCase()}${next.intent.slice(1)}`;
    if (renderer) request();
    else showStill();
  }

  function showStill() {
    still.src = `assets/presets/${wall === 'black' ? 'black/' : ''}${look.id}.webp`;
  }

  async function picture(name) {
    if (!sources[name]) {
      const image = new win.Image();
      image.src = DESKTOPS[name];
      await image.decode();
      sources[name] = image;
    }
    return sources[name];
  }

  async function chooseWall(name) {
    if (!DESKTOPS[name]) return;
    wall = name;
    for (const button of walls) button.setAttribute('aria-pressed', String(button.dataset.wall === name));
    if (!renderer) {
      showStill();
      return;
    }
    try {
      const image = await picture(name);
      if (wall !== name || !renderer) return;   // another choice came first
      renderer.setSource(image);
      request();
    } catch {
      goStill();
      showStill();
    }
  }

  for (const chip of chips) chip.addEventListener('click', () => choose(chip.dataset.look));
  for (const button of walls) button.addEventListener('click', () => chooseWall(button.dataset.wall));
  input.addEventListener('input', () => {
    angle = Number(input.value);
    output.textContent = `${angle}°`;
    request();
  });

  async function begin() {
    if (doc.documentElement.dataset.motion !== 'full') return;
    try {
      const source = await picture(wall);
      renderer = new GlassRenderer(canvas);
      renderer.setSource(source);
    } catch {
      goStill();
      return;
    }
    renderer.onLost = goStill;
    const observer = new win.ResizeObserver(() => {
      if (renderer?.resize(canvas.clientWidth, canvas.clientHeight, win.devicePixelRatio)) request();
    });
    observer.observe(canvas);
    renderer.resize(canvas.clientWidth, canvas.clientHeight, win.devicePixelRatio);
    root.dataset.live = 'on';
    request();
  }

  // The renderer starts when the section comes near, so the page's first seconds belong to the hero.
  const near = new win.IntersectionObserver((entries) => {
    if (entries.some((entry) => entry.isIntersecting)) {
      near.disconnect();
      begin();
    }
  }, { rootMargin: '400px 0px' });
  near.observe(root);

  return { choose, chooseWall, get live() { return renderer !== null; } };
}

/** Sections ease in once, as they come into view. */
export function startReveal(doc = document, win = window) {
  const items = doc.querySelectorAll('.reveal');
  if (!('IntersectionObserver' in win)) {
    items.forEach((item) => item.classList.add('in'));
    return;
  }
  const observer = new win.IntersectionObserver((entries) => {
    for (const entry of entries) {
      if (!entry.isIntersecting) continue;
      entry.target.classList.add('in');
      observer.unobserve(entry.target);
    }
  }, { rootMargin: '0px 0px -8% 0px' });
  items.forEach((item) => observer.observe(item));
}
