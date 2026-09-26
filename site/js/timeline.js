// Where the page's lid is, over time and scroll. Pure functions: tested in Node, driven by hero.js.
import { Easing, PAGE_LID_REST, clamp } from './optics.js';

/** The opening: a short beat, then the lid rises from 0° to 110° with the app's fold easing. Seconds. */
export const INTRO = Object.freeze({ delay: 0.35, duration: 2.2 });
/** Time constant of the scroll-driven lid, as in the app's AngleFollower (45 ms there; scroll steps are coarser). */
export const SCROLL_SMOOTHING = 0.09;

/** Scroll distance over which a linked lid travels from closed to open: 40% of the viewport, 200 to 420 px. */
export function runway(viewportHeight) {
  return clamp(viewportHeight * 0.4, 200, 420);
}

export function introAngle(elapsed) {
  return PAGE_LID_REST * Easing.inOutCubic((elapsed - INTRO.delay) / INTRO.duration);
}

export function scrollAngle(scrollY, run) {
  return PAGE_LID_REST * clamp(scrollY / run, 0, 1);
}

/**
 * Phases: 'intro' opens the lid once, on a timer; 'held' keeps it open while the visitor reads on;
 * 'linked' ties it to the scroll, so coming back to the top closes the Mac again with the effect.
 * The page links itself once the visitor has scrolled one runway down; a page that loads already
 * scrolled (a reload, a link to #download) starts linked, with no opening to miss.
 */
export function startPhase(scrollY, run) {
  return scrollY >= run ? 'linked' : 'intro';
}

export function nextPhase(phase, { elapsed, scrollY, run }) {
  let next = phase;
  // Landed a runway down before the lid starts to move (a late jump to #download, a restored scroll): skip it.
  if (next === 'intro' && elapsed < INTRO.delay && scrollY >= run) next = 'linked';
  if (next === 'intro' && elapsed >= INTRO.delay + INTRO.duration) next = 'held';
  if (next === 'held' && scrollY >= run) next = 'linked';
  return next;
}

export function targetAngle(phase, { elapsed, scrollY, run }) {
  if (phase === 'intro') return introAngle(elapsed);
  if (phase === 'linked') return scrollAngle(scrollY, run);
  return PAGE_LID_REST;
}

/** The opening's start after the tab was hidden from `hiddenAt` to `now`: it resumes where it paused. */
export function resumedStart(start, hiddenAt, now) {
  return start === null ? null : start + Math.max(0, now - hiddenAt);
}

/** `?lid=45` freezes the lid at 45° (reviews, screenshots, the social image). Anything else: null. */
export function frozenAngle(search) {
  const value = new URLSearchParams(search).get('lid');
  if (value === null || value.trim() === '') return null;
  const angle = Number(value);
  return Number.isFinite(angle) ? clamp(angle, 0, PAGE_LID_REST) : null;
}
