// The local server applies vercel.json like production, so the CSP is live during every check.
import assert from 'node:assert/strict';
import { after, before, test } from 'node:test';
import { headersFor, loadHeaderRules, sourceToRegExp, startServer } from '../tools/serve.mjs';

let server;
before(async () => { server = await startServer(); });
after(async () => { await server.close(); });

test('vercel source patterns become anchored expressions', () => {
  assert.ok(sourceToRegExp('/(.*)').test('/anything/at/all'));
  assert.ok(sourceToRegExp('/assets/(.*)').test('/assets/desktop.webp'));
  assert.ok(!sourceToRegExp('/assets/(.*)').test('/css/site.css'));
  assert.ok(!sourceToRegExp('/a.b').test('/aXb'));
});

test('every path gets the strict CSP; assets also get their cache rule', async () => {
  const rules = await loadHeaderRules();
  const page = headersFor('/', rules);
  assert.match(page['Content-Security-Policy'], /script-src 'self';/);
  assert.match(page['Content-Security-Policy'], /style-src 'self';/);
  assert.doesNotMatch(page['Content-Security-Policy'], /unsafe-inline|unsafe-eval/);
  assert.match(headersFor('/assets/desktop.webp', rules)['Cache-Control'], /max-age=86400/);
});

test('the server serves the page with its headers, clean URLs and a real 404', async () => {
  const home = await fetch(`${server.url}/`);
  assert.equal(home.status, 200);
  assert.match(home.headers.get('content-type'), /text\/html/);
  assert.match(home.headers.get('content-security-policy'), /default-src 'none'/);
  const clean = await fetch(`${server.url}/404`);
  assert.equal(clean.status, 200);
  const missing = await fetch(`${server.url}/nope`);
  assert.equal(missing.status, 404);
  assert.match(await missing.text(), /Page not found/);
  const text = await fetch(`${server.url}/robots.txt`);
  assert.match(text.headers.get('content-type'), /text\/plain/);
});

test('paths never escape the site folder', async () => {
  const response = await fetch(`${server.url}/%2e%2e/%2e%2e/etc/passwd`);
  assert.equal(response.status, 404);
});
