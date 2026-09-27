// Exports the glass frames the page shows as pictures, from the real desktop and the site's own code.
// Usage: node tools/export-images.mjs   (writes into site/assets/, prints each file and its size)
import { mkdir, writeFile } from 'node:fs/promises';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { launchChrome } from './cdp.mjs';
import { SITE_DIR, startServer } from './serve.mjs';
import { DISPLAY_RATIO, PRESETS } from '../js/optics.js';

/** Presets are shown at the lid control's starting angle, on both wallpapers; How It Works at three angles of the Duo
 * preset, on the Tahoe wallpaper, whose colors show the glass best. */
export const PRESET_ANGLE = 60;
export const HOW_ANGLES = [75, 50, 25];
const sized = (width) => ({ width, height: Math.round(width / DISPLAY_RATIO) });

export const JOBS = [
  ...PRESETS.map((p) => ({ file: `assets/presets/${p.id}.webp`, call: `__export.frame('${p.id}', ${PRESET_ANGLE}, 1440, 0.82, 'tahoe')`, ...sized(1440), maxKB: 140 })),
  ...PRESETS.map((p) => ({ file: `assets/presets/black/${p.id}.webp`, call: `__export.frame('${p.id}', ${PRESET_ANGLE}, 1440, 0.86, 'black')`, ...sized(1440), maxKB: 140 })),
  ...HOW_ANGLES.map((a) => ({ file: `assets/how/duo-${a}.webp`, call: `__export.frame('duo', ${a}, 720, 0.86)`, ...sized(720), maxKB: 60 })),
];

export async function exportImages() {
  const server = await startServer();
  const chrome = await launchChrome();
  let ok = true;
  try {
    const page = await chrome.newPage({ width: 1440, height: 900 });
    await page.goto(`${server.url}/tools/export.html`);
    await page.waitUntil('window.__exportReady === true');
    for (const job of JOBS) {
      const url = await page.evaluate(job.call);
      if (!url.startsWith('data:image/webp;base64,')) throw new Error(`${job.file}: the browser did not encode WebP`);
      const bytes = Buffer.from(url.slice(url.indexOf(',') + 1), 'base64');
      await mkdir(dirname(join(SITE_DIR, job.file)), { recursive: true });
      await writeFile(join(SITE_DIR, job.file), bytes);
      const kb = bytes.length / 1024;
      if (kb > job.maxKB) ok = false;
      console.log(`${kb <= job.maxKB ? 'ok  ' : 'FAIL'} ${job.file} ${kb.toFixed(1)} KB (max ${job.maxKB} KB)`);
    }
    for (const problem of page.problems) console.log(`page: ${problem}`);
  } finally {
    await chrome.close();
    await server.close();
  }
  return ok;
}

if (process.argv[1] === fileURLToPath(import.meta.url)) process.exit((await exportImages()) ? 0 : 1);
