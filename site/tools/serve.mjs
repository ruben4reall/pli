// Serves site/ on 127.0.0.1 with the headers of vercel.json, so the production CSP applies locally.
// Usage: node tools/serve.mjs [port]   (default 4173; 0 picks a free port)
import { createServer } from 'node:http';
import { readFile, stat } from 'node:fs/promises';
import { extname, join, resolve, sep } from 'node:path';
import { fileURLToPath } from 'node:url';

export const SITE_DIR = resolve(fileURLToPath(new URL('..', import.meta.url)));

const TYPES = {
  '.html': 'text/html; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.mjs': 'text/javascript; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.svg': 'image/svg+xml',
  '.png': 'image/png',
  '.webp': 'image/webp',
  '.jpg': 'image/jpeg',
  '.woff2': 'font/woff2',
  '.txt': 'text/plain; charset=utf-8',
  '.xml': 'application/xml; charset=utf-8',
};

/** Vercel `source` patterns here only use "(.*)": everything else is literal. */
export function sourceToRegExp(source) {
  const parts = source.split('(.*)').map((part) => part.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'));
  return new RegExp(`^${parts.join('(.*)')}$`);
}

export async function loadHeaderRules(siteDir = SITE_DIR) {
  const config = JSON.parse(await readFile(join(siteDir, 'vercel.json'), 'utf8'));
  return (config.headers ?? []).map((rule) => ({ test: sourceToRegExp(rule.source), headers: rule.headers }));
}

/** Every matching rule applies, later rules winning on the same key, as on Vercel. */
export function headersFor(pathname, rules) {
  const out = {};
  for (const rule of rules) {
    if (!rule.test.test(pathname)) continue;
    for (const { key, value } of rule.headers) out[key] = value;
  }
  return out;
}

async function isFile(path) {
  try {
    return (await stat(path)).isFile();
  } catch {
    return false;
  }
}

/** cleanUrls: "/" is index.html and "/404" is 404.html. Paths never leave the site folder. */
export async function findFile(pathname, siteDir = SITE_DIR) {
  const clean = pathname.endsWith('/') ? `${pathname}index.html` : pathname;
  const candidates = extname(clean) ? [clean] : [clean, `${clean}.html`];
  for (const candidate of candidates) {
    const full = resolve(siteDir, `.${candidate}`);
    if (full !== siteDir && !full.startsWith(siteDir + sep)) return null;
    if (await isFile(full)) return full;
  }
  return null;
}

export async function startServer({ port = 0, siteDir = SITE_DIR } = {}) {
  const rules = await loadHeaderRules(siteDir);
  const server = createServer(async (req, res) => {
    let pathname;
    try {
      pathname = decodeURIComponent(new URL(req.url, 'http://localhost').pathname);
    } catch {
      res.writeHead(400).end();
      return;
    }
    const file = await findFile(pathname, siteDir);
    const target = file ?? join(siteDir, '404.html');
    const body = await readFile(target);
    res.writeHead(file ? 200 : 404, {
      'Content-Type': TYPES[extname(target)] ?? 'application/octet-stream',
      'Content-Length': body.length,
      ...headersFor(pathname, rules),
      'Cache-Control': 'no-store', // local runs never cache; vercel.json's caching applies in production only
    });
    res.end(req.method === 'HEAD' ? undefined : body);
  });
  await new Promise((done) => server.listen(port, '127.0.0.1', done));
  const url = `http://127.0.0.1:${server.address().port}`;
  return { url, close: () => new Promise((done) => server.close(done)) };
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const { url } = await startServer({ port: Number(process.argv[2] ?? 4173) });
  console.log(`Pli site on ${url} (Ctrl-C to stop)`);
}
