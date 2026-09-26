// The site's tokens are the spec's, and the brand's file wins wherever it defines a name.
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { existsSync } from 'node:fs';
import { test } from 'node:test';
import { SITE_TOKENS, declaredTokens, renderTokens, tokenDrift } from '../tools/sync-brand.mjs';

test('site defaults match spec section 9.2', () => {
  assert.deepEqual(
    Object.fromEntries(Object.entries(SITE_TOKENS).filter(([name]) => !name.startsWith('--pli-ease'))),
    {
      '--pli-night': '#0A0C10', '--pli-slate': '#161A22', '--pli-ice': '#EEF2F6', '--pli-mist': '#8A94A3',
      '--pli-glacier': '#7CCBFF', '--pli-deep-glacier': '#0B6FB0', '--pli-iridescent-1': '#A6F0FF',
      '--pli-iridescent-2': '#C8B8FF', '--pli-iridescent-3': '#FFD3B0', '--pli-white': '#FFFFFF',
      '--pli-paper': '#F5F5F7', '--pli-ink': '#1D1D1F', '--pli-graphite': '#6E6E73', '--pli-hairline': '#D2D2D7',
    },
  );
});

test('without a brand file, tokens.css holds the defaults', () => {
  const css = renderTokens(null);
  assert.deepEqual(declaredTokens(css), SITE_TOKENS);
  assert.match(css, /was not found/);
});

test('the brand file comes after the defaults, so it wins', () => {
  const css = renderTokens(':root { --pli-paper: #F4F4F6; --pli-radius-m: 12px; }');
  assert.ok(css.lastIndexOf('#F4F4F6') > css.indexOf('#F5F5F7'));
  assert.deepEqual(tokenDrift(':root { --pli-paper: #f5f5f7; }').different, []);
  assert.deepEqual(tokenDrift(':root { --pli-paper: #F4F4F6; }').different, ['--pli-paper: site #F5F5F7, brand #F4F4F6']);
  assert.ok(tokenDrift(':root {}').missing.includes('--pli-ink'));
});

test('the committed tokens.css holds the defaults, then the repository brand tokens when present', async () => {
  const committed = await readFile(new URL('../css/tokens.css', import.meta.url), 'utf8');
  const empty = renderTokens(null);
  const defaults = empty.slice(0, empty.indexOf('/* brand/tokens/tokens.css was not found'));
  assert.ok(committed.startsWith(defaults), 'run: node tools/sync-brand.mjs');
  const brandPath = new URL('../../brand/tokens/tokens.css', import.meta.url);
  if (existsSync(brandPath)) assert.equal(committed, renderTokens(await readFile(brandPath, 'utf8')), 'brand/ changed: run node tools/sync-brand.mjs');
});
