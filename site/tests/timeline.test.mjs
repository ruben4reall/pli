// The hero's lid: opens once on a timer, holds while the visitor reads, then follows the scroll.
import assert from 'node:assert/strict';
import { test } from 'node:test';
import { INTRO, frozenAngle, introAngle, nextPhase, resumedStart, runway, scrollAngle, startPhase, targetAngle } from '../js/timeline.js';

const end = INTRO.delay + INTRO.duration;

test('the opening waits a beat, then eases from 0° to 110°', () => {
  assert.equal(introAngle(0), 0);
  assert.equal(introAngle(INTRO.delay), 0);
  assert.ok(Math.abs(introAngle(INTRO.delay + INTRO.duration / 2) - 55) < 1e-9);
  assert.equal(introAngle(end), 110);
  assert.equal(introAngle(end + 5), 110);
  let previous = -1;
  for (let t = 0; t <= end; t += 0.05) {
    assert.ok(introAngle(t) >= previous);
    previous = introAngle(t);
  }
});

test('the runway is 40% of the viewport, between 200 and 420 px', () => {
  assert.equal(runway(900), 360);
  assert.equal(runway(300), 200);
  assert.equal(runway(2000), 420);
});

test('a page loaded at the top plays the opening; one loaded scrolled starts linked', () => {
  assert.equal(startPhase(0, 360), 'intro');
  assert.equal(startPhase(359, 360), 'intro');
  assert.equal(startPhase(360, 360), 'linked');
});

test('the opening holds open, and links once the visitor scrolls a runway down', () => {
  const at = (elapsed, scrollY) => ({ elapsed, scrollY, run: 360 });
  assert.equal(nextPhase('intro', at(1, 0)), 'intro');
  assert.equal(nextPhase('intro', at(end, 0)), 'held');
  assert.equal(nextPhase('intro', at(1, 900)), 'intro', 'scrolling during the opening does not cut it short');
  assert.equal(nextPhase('intro', at(0.2, 900)), 'linked', 'landing a runway down before the lid moves skips the opening');
  assert.equal(nextPhase('intro', at(end, 900)), 'linked');
  assert.equal(nextPhase('held', at(9, 200)), 'held', 'a short scroll back up never closes an unlinked lid');
  assert.equal(nextPhase('held', at(9, 360)), 'linked');
  assert.equal(nextPhase('linked', at(9, 0)), 'linked', 'once linked, always linked');
});

test('linked, the top of the page is a closed Mac and one runway down is an open one', () => {
  assert.equal(targetAngle('linked', { elapsed: 9, scrollY: 0, run: 360 }), 0);
  assert.equal(targetAngle('linked', { elapsed: 9, scrollY: 180, run: 360 }), 55);
  assert.equal(targetAngle('linked', { elapsed: 9, scrollY: 5000, run: 360 }), 110);
  assert.equal(targetAngle('held', { elapsed: 9, scrollY: 0, run: 360 }), 110);
  assert.equal(scrollAngle(-40, 360), 0, 'rubber-band overscroll at the top stays closed');
});

test('?lid= freezes the lid only on a usable number', () => {
  assert.equal(frozenAngle('?lid=45'), 45);
  assert.equal(frozenAngle('?lid=500'), 110);
  assert.equal(frozenAngle('?lid=-3'), 0);
  assert.equal(frozenAngle('?lid='), null);
  assert.equal(frozenAngle('?lid=abc'), null);
  assert.equal(frozenAngle(''), null);
});

test('a hidden tab pauses the opening instead of skipping it', () => {
  assert.equal(resumedStart(10, 11, 15), 14);
  assert.equal(resumedStart(null, 11, 15), null, 'before the first frame there is nothing to shift');
  assert.equal(resumedStart(10, 15, 11), 10, 'a clock going backward never rewinds the opening');
});
