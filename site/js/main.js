// The page's entry point: each part starts on its own, and a failure in one never stops the others.
import { startHero } from './hero.js';
import { startBeacon } from './beacon.js';
import { startLooks, startReveal } from './looks.js';

for (const start of [startHero, startLooks, startReveal]) {
  try {
    start();
  } catch (error) {
    console.error(error);
  }
}

window.addEventListener('load', () => {
  requestAnimationFrame(() => document.documentElement.classList.add('smooth-scroll'));
  try {
    startBeacon();
  } catch (error) {
    console.error(error);
  }
}, { once: true });
