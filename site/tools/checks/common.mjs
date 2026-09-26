// Helpers shared by the quality gates.
export { setTimeout as sleep } from 'node:timers/promises';

export function check(name, ok, detail = '') {
  return { name, ok: Boolean(ok), detail };
}

export const kb = (bytes) => (bytes / 1024).toFixed(1);

/** The lid angle the page shows right now, read from the CSS custom property hero.js drives. */
export const LID_ANGLE = `parseFloat(getComputedStyle(document.querySelector('[data-mac]')).getPropertyValue('--lid-angle'))`;

/** The opening has finished: hero.js sets the pli-intro-end User Timing mark. */
export const INTRO_DONE = `performance.getEntriesByName('pli-intro-end').length > 0`;
