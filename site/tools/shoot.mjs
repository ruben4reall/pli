// Screenshots of the page at desktop (1440 x 900) and phone (390 x 844) sizes, into site/.shots/.
// Usage: node tools/shoot.mjs <name> [--path /] [--wait 1500] [--scroll "#id"|<y>] [--eval "<js>"]
//        [--reduced] [--only desktop|phone|narrow] [--no-webgl]
import { mkdir } from 'node:fs/promises';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { parseArgs } from 'node:util';
import { setTimeout as sleep } from 'node:timers/promises';
import { SIZES, launchChrome } from './cdp.mjs';
import { SITE_DIR, startServer } from './serve.mjs';

export const SHOTS_DIR = join(SITE_DIR, '.shots');

// Makes the page believe WebGL2 does not exist, to see the fallback.
export const NO_WEBGL = `(() => {
  const original = HTMLCanvasElement.prototype.getContext;
  HTMLCanvasElement.prototype.getContext = function (type, ...rest) {
    return type === 'webgl2' ? null : original.call(this, type, ...rest);
  };
  delete window.WebGL2RenderingContext;
})();`;

export async function shoot(name, { path = '/', wait = 1500, scroll, evaluate, reduced = false, only, noWebgl = false } = {}) {
  await mkdir(SHOTS_DIR, { recursive: true });
  const server = await startServer();
  const chrome = await launchChrome();
  const written = [];
  try {
    for (const [sizeName, size] of Object.entries(SIZES)) {
      if (only ? sizeName !== only : sizeName === 'narrow') continue;
      const page = await chrome.newPage({ ...size, reducedMotion: reduced, beforeLoad: noWebgl ? [NO_WEBGL] : [] });
      await page.goto(server.url + path);
      if (scroll !== undefined) {
        const target = /^\d+$/.test(String(scroll))
          ? `window.scrollTo({ top: ${scroll}, behavior: 'instant' })`
          : `document.querySelector(${JSON.stringify(scroll)}).scrollIntoView({ block: 'start', behavior: 'instant' })`;
        await page.evaluate(target);
      }
      if (evaluate) await page.evaluate(evaluate);
      await sleep(wait);
      written.push(await page.screenshot(join(SHOTS_DIR, `${name}-${sizeName}.png`)));
      if (page.problems.length) console.warn(`${sizeName}: ${page.problems.join('\n')}`);
      await page.close();
    }
  } finally {
    await chrome.close();
    await server.close();
  }
  return written;
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const { values, positionals } = parseArgs({
    allowPositionals: true,
    options: {
      path: { type: 'string', default: '/' },
      wait: { type: 'string', default: '1500' },
      scroll: { type: 'string' },
      eval: { type: 'string' },
      reduced: { type: 'boolean', default: false },
      only: { type: 'string' },
      'no-webgl': { type: 'boolean', default: false },
    },
  });
  const files = await shoot(positionals[0] ?? 'page', {
    path: values.path,
    wait: Number(values.wait),
    scroll: values.scroll,
    evaluate: values.eval,
    reduced: values.reduced,
    only: values.only,
    noWebgl: values['no-webgl'],
  });
  for (const file of files) console.log(file);
}
