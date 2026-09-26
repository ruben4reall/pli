// The pictures the site ships, made by tools/export-images.mjs: WebP, the right size, within budget.
import assert from 'node:assert/strict';
import { existsSync } from 'node:fs';
import { readFile } from 'node:fs/promises';
import { test } from 'node:test';
import { JOBS } from '../tools/export-images.mjs';

/** Width and height from a WebP header (lossy VP8, lossless VP8L or extended VP8X). */
function webpSize(bytes) {
  if (bytes.toString('ascii', 0, 4) !== 'RIFF' || bytes.toString('ascii', 8, 12) !== 'WEBP') return null;
  const chunk = bytes.toString('ascii', 12, 16);
  if (chunk === 'VP8X') return { width: 1 + bytes.readUIntLE(24, 3), height: 1 + bytes.readUIntLE(27, 3) };
  if (chunk === 'VP8 ') return { width: bytes.readUInt16LE(26) & 0x3fff, height: bytes.readUInt16LE(28) & 0x3fff };
  if (chunk === 'VP8L') {
    const bits = bytes.readUInt32LE(21);
    return { width: (bits & 0x3fff) + 1, height: ((bits >> 14) & 0x3fff) + 1 };
  }
  return null;
}

test('ten glass frames are exported from the real desktop', () => {
  assert.equal(JOBS.length, 10);
  assert.equal(JOBS[0].file, 'assets/presets/duo.webp');
  assert.ok(existsSync(new URL('../assets/desktop.webp', import.meta.url)), 'assets/desktop.webp comes from brand-sources/real-desktop');
});

for (const job of JOBS) {
  test(`${job.file} is a ${job.width} x ${job.height} WebP under ${job.maxKB} KB`, async () => {
    const url = new URL(`../${job.file}`, import.meta.url);
    assert.ok(existsSync(url), 'run: node tools/export-images.mjs');
    const bytes = await readFile(url);
    assert.deepEqual(webpSize(bytes), { width: job.width, height: job.height });
    assert.ok(bytes.length <= job.maxKB * 1024, `${(bytes.length / 1024).toFixed(1)} KB`);
  });
}
