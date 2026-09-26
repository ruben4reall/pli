// Static rules for everything in site/: the owner's copy rules, CSP-safe markup, links, and files that exist.
import assert from 'node:assert/strict';
import { existsSync } from 'node:fs';
import { readFile, readdir } from 'node:fs/promises';
import { dirname, extname, join, relative, resolve } from 'node:path';
import { test } from 'node:test';
import { fileURLToPath } from 'node:url';

const SITE = fileURLToPath(new URL('..', import.meta.url));
const TEXT = new Set(['.html', '.css', '.js', '.mjs', '.svg', '.json', '.txt', '.xml', '.md', '.sh']);
const HOST = 'getpli.vercel.app';
const EM_DASH = String.fromCharCode(0x2014);
const APPLE_LOGO = String.fromCharCode(0xf8ff); // the private-use glyph Apple fonts draw as their logo

async function list(dir) {
  const out = [];
  for (const entry of await readdir(dir, { withFileTypes: true })) {
    if (['.shots', 'node_modules', '.vercel'].includes(entry.name)) continue;
    const path = join(dir, entry.name);
    if (entry.isDirectory()) out.push(...(await list(path)));
    else out.push(path);
  }
  return out;
}

const read = (path) => readFile(join(SITE, path), 'utf8');
const html = await read('index.html');
const visible = html.replace(/<head>[\s\S]*?<\/head>/, '').replace(/<[^>]+>/g, ' ').replace(/\s+/g, ' ');

test('no em dash anywhere in site/, tools and tests included', async () => {
  for (const file of await list(SITE)) {
    if (!TEXT.has(extname(file))) continue;
    assert.ok(!(await readFile(file, 'utf8')).includes(EM_DASH), `em dash in ${relative(SITE, file)}`);
  }
});

test('markup is CSP-safe: no inline script, style or handler', async () => {
  for (const file of (await list(SITE)).filter((f) => f.endsWith('.html'))) {
    const text = await readFile(file, 'utf8');
    const name = relative(SITE, file);
    assert.doesNotMatch(text, /<script(?![^>]*\bsrc=)[^>]*>/i, `inline script in ${name}`);
    assert.doesNotMatch(text, /<style[\s>]/i, `<style> in ${name}`);
    assert.doesNotMatch(text, /\sstyle\s*=/i, `style attribute in ${name}`);
    assert.doesNotMatch(text, /\son[a-z]+\s*=/i, `inline handler in ${name}`);
    assert.doesNotMatch(text, /javascript:/i, `javascript: URL in ${name}`);
  }
});

test('the required words are on the page', () => {
  for (const words of [
    'The iPhone Duo fold, on your MacBook.',
    'Pli is French for fold.',
    'Pli is not affiliated with Apple. iPhone, MacBook and macOS are trademarks of Apple Inc.',
  ]) assert.ok(visible.includes(words), `missing: ${words}`);
  const DOWNLOAD = 'https://github.com/ruben4reall/pli/releases/latest/download/Pli.dmg';
  assert.ok(html.split(DOWNLOAD).length - 1 >= 3, 'the download link appears in the nav, the hero and the download section');
});

test('every picture has alt text and dimensions', () => {
  for (const tag of html.match(/<img\b[^>]*>/g) ?? []) {
    assert.match(tag, /\balt="/, tag);
    assert.match(tag, /\bwidth="\d+"/, tag);
    assert.match(tag, /\bheight="\d+"/, tag);
  }
});

test('links stay on the page or go to the project on GitHub', () => {
  for (const [, href] of html.matchAll(/href="([^"]+)"/g)) {
    const ok = href.startsWith('#') || !/^[a-z]+:/i.test(href) || href.startsWith('https://github.com/ruben4reall/pli')
      || href === `https://${HOST}/`;
    assert.ok(ok, `unexpected link: ${href}`);
  }
});

test('in-page links land on an element', () => {
  for (const [, id] of html.matchAll(/href="#([^"]+)"/g)) assert.match(html, new RegExp(`id="${id}"`), `no element with id="${id}"`);
});

test('one production domain everywhere', async () => {
  const hosts = new Set();
  for (const file of ['index.html', 'robots.txt', 'sitemap.xml']) {
    for (const [, host] of (await read(file)).matchAll(/https:\/\/([a-z0-9.-]+\.vercel\.app)/g)) hosts.add(host);
  }
  hosts.delete('ruben-analytics.vercel.app');
  assert.deepEqual([...hosts], [HOST]);
});

test('no SF Pro file, no Apple logo, Inter as the only webfont', async () => {
  for (const file of await list(SITE)) {
    const name = relative(SITE, file);
    assert.doesNotMatch(name, /sf-?pro|sanfrancisco/i, name);
    if (/\.(woff2?|ttf|otf)$/.test(name)) assert.match(name, /^assets\/fonts\/inter-\d{3}\.woff2$/, name);
    if (TEXT.has(extname(file))) assert.ok(!(await readFile(file, 'utf8')).includes(APPLE_LOGO), `Apple logo character in ${name}`);
  }
  assert.match(await read('css/site.css'), /--font: -apple-system, BlinkMacSystemFont, 'Inter', system-ui, sans-serif;/);
});

test('every file the page and its styles reference exists', async () => {
  const refs = [...html.matchAll(/(?:src|href)="([^"#:]+)"/g)].map(([, ref]) => ref);
  for (const file of ['css/site.css', 'css/mac.css'].filter((f) => existsSync(join(SITE, f)))) {
    for (const [, ref] of (await read(file)).matchAll(/url\(['"]?([^'")]+)['"]?\)/g)) refs.push(join(dirname(file), ref));
  }
  for (const ref of refs) assert.ok(existsSync(resolve(SITE, ref.replace(/^\//, ''))), `missing file: ${ref}`);
});

test('tools, tests and dev files never ship', async () => {
  const ignored = (await read('.vercelignore')).split('\n').map((line) => line.trim()).filter(Boolean);
  for (const path of ['/tools/', '/tests/', '/.shots/', '/package.json', '/README.md']) assert.ok(ignored.includes(path), `.vercelignore lacks ${path}`);
});
