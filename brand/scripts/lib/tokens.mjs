// The brand tokens for the generators, read from brand/tokens/tokens.json (the
// source of truth), so no generator carries a hand-typed palette.
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

export const TOKENS_PATH = fileURLToPath(new URL('../../tokens/tokens.json', import.meta.url));
export const T = JSON.parse(readFileSync(TOKENS_PATH, 'utf8'));

const camel = (s) => s.replace(/-([a-z0-9])/g, (_, c) => c.toUpperCase());

// The palette by camel-cased token name: C.night, C.deepGlacier, C.ink...
export const C = Object.fromEntries(
  ['core', 'light'].flatMap((group) =>
    Object.entries(T.color[group]).map(([name, t]) => [camel(name), t.$value.toUpperCase()])));

// The iridescent gradient stops, left to right: [{ color, position }].
export const IRI = T.gradient.iridescent.$value.map((s) => ({ color: s.color.toUpperCase(), position: s.position }));

// A #RRGGBB color as [r, g, b], channels 0 to 255.
export const rgb = (hex) => [1, 3, 5].map((i) => parseInt(hex.slice(i, i + 2), 16));
