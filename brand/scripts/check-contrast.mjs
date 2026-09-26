#!/usr/bin/env node
// Checks the Pli brand guide against the tokens: WCAG 2 contrast, and the
// palette the guide prints.
//   node brand/scripts/check-contrast.mjs
//
// 1. Every text pairing listed in docs/brand/BRAND.md: the rows of the table
//    between <!-- contrast:start --> and <!-- contrast:end -->:
//      | Text | Background | Size | Ratio | Used for |
//    Text and Background name a palette token from brand/tokens/tokens.json
//    ("Deep Glacier"), optionally followed by its hex in backticks, which must
//    match the token. Size is "Body" (needs 4.5:1) or "Large" (needs 3:1: at
//    least 24 px regular or 18.66 px bold). Ratio is the value the guide
//    prints; it must agree with the computed ratio to 0.05, so the guide stays
//    true.
// 2. The roles in brand/tokens/tokens.json, for each appearance: text,
//    text-secondary and accent must read as body text (4.5:1) on the
//    background and on the surface; separator must stay visible (1.3:1) on
//    both. A translucent value (#RRGGBBAA) is composited over the backdrop it
//    is checked against.
// 3. The palette tables of the guide, between <!-- palette:core:start --> and
//    <!-- palette:core:end --> (and the same for light):
//      | Token | Hex | Role |
//    Every token of that group in tokens.json has a row, every row names a
//    palette token and prints its exact hex, and the Iridescent row (core)
//    prints the gradient's stops in order. So the guide cannot drift from
//    the tokens.
//
// Exits 1 if anything is under its threshold, if a printed value is wrong, or
// if a table, a cell or a role cannot be read. No dependency.
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

const ROOT = fileURLToPath(new URL('../../', import.meta.url));
const GUIDE = 'docs/brand/BRAND.md';
const MIN = { body: 4.5, large: 3 };
const SEPARATOR_MIN = 1.3;

const errors = [];
const fail = (message) => {
  console.error(message);
  process.exit(1);
};

// ---------- Palette

const tokens = JSON.parse(readFileSync(`${ROOT}brand/tokens/tokens.json`, 'utf8'));
const palette = new Map();
const groupOf = new Map();
for (const group of ['core', 'light']) {
  for (const [name, t] of Object.entries(tokens.color[group])) {
    palette.set(name, t.$value.toUpperCase());
    groupOf.set(name, group);
  }
}
const iridescent = tokens.gradient.iridescent.$value.map((s) => s.color.toUpperCase());
const tokenKey = (name) => name.toLowerCase().replace(/\s+/g, '-');

// ---------- WCAG 2 contrast (colors as [r, g, b, a], channels 0 to 255)

const rgba = (hex) => {
  const h = hex.replace('#', '');
  const [r, g, b] = [0, 2, 4].map((i) => parseInt(h.slice(i, i + 2), 16));
  return [r, g, b, h.length === 8 ? parseInt(h.slice(6, 8), 16) / 255 : 1];
};
const over = ([r, g, b, a], [R, G, B]) => [R + (r - R) * a, G + (g - G) * a, B + (b - B) * a, 1];
const channel = (v) => {
  const c = v / 255;
  return c <= 0.04045 ? c / 12.92 : ((c + 0.055) / 1.055) ** 2.4;
};
const luminance = ([r, g, b]) => 0.2126 * channel(r) + 0.7152 * channel(g) + 0.0722 * channel(b);
const contrast = (fg, bg) => {
  const [hi, lo] = [luminance(over(fg, bg)), luminance(bg)].sort((x, y) => y - x);
  return (hi + 0.05) / (lo + 0.05);
};

const pad = (s, n) => String(s).padEnd(n);
const ratioText = (r) => pad(`${r.toFixed(2)}:1`, 8);

// ---------- The guide's tables

const md = readFileSync(`${ROOT}${GUIDE}`, 'utf8');

// The Markdown table between <!-- name:start --> and <!-- name:end -->: its
// header cells, and its rows as { cells, where }, each checked to have a cell
// under every column the caller needs.
function table(name, columns) {
  const block = md.match(new RegExp(`<!-- ${name}:start -->([\\s\\S]*?)<!-- ${name}:end -->`));
  if (!block) fail(`${GUIDE}: no <!-- ${name}:start --> ... <!-- ${name}:end --> block`);
  const lines = block[1].split('\n').map((l) => l.trim()).filter((l) => l.startsWith('|'));
  const split = (l) => l.replace(/^\|/, '').replace(/\|$/, '').split('|').map((c) => c.trim());
  const [head, rule, ...body] = lines.map(split);
  const index = Object.fromEntries(columns.map((c) => [c, head ? head.findIndex((h) => h.toLowerCase() === c) : -1]));
  const missing = columns.filter((c) => index[c] < 0);
  if (!head || !rule || missing.length || body.length === 0) {
    fail(`${GUIDE}: the ${name} table needs ${columns.map((c) => c[0].toUpperCase() + c.slice(1)).join(', ')} columns and at least one row` +
      (missing.length && head ? ` (missing: ${missing.join(', ')})` : ''));
  }
  const rows = [];
  body.forEach((cells, i) => {
    const where = `${name} table, row ${i + 1}`;
    const empty = columns.filter((c) => !cells[index[c]]);
    if (empty.length) {
      const names = empty.map((c) => c[0].toUpperCase() + c.slice(1)).join(' and ');
      errors.push(`${where}: the ${names} cell${empty.length > 1 ? 's are' : ' is'} empty or missing ` +
        `(the row has ${cells.length} of the table's ${head.length} cells)`);
      return;
    }
    rows.push({ cells, where, get: (c) => cells[index[c]] });
  });
  return rows;
}

// ---------- 1. The text pairings

function color(cell, where) {
  const hex = cell.match(/`(#[0-9A-Fa-f]{6})`/)?.[1]?.toUpperCase();
  const name = cell.replace(/`[^`]*`/g, '').trim();
  const value = palette.get(tokenKey(name));
  if (!value) { errors.push(`${where}: "${name}" is not a palette token`); return null; }
  if (hex && hex !== value) errors.push(`${where}: ${name} is ${value} in tokens.json, not ${hex}`);
  return { name, value };
}

const pairings = table('contrast', ['text', 'background', 'size', 'ratio']).map((row) => {
  const { where } = row;
  const text = color(row.get('text'), `${where} (text)`);
  const bg = color(row.get('background'), `${where} (background)`);
  const size = row.get('size').toLowerCase();
  if (!(size in MIN)) errors.push(`${where}: size "${row.get('size')}" is neither Body nor Large`);
  if (!text || !bg || !(size in MIN)) return null;
  const ratio = contrast(rgba(text.value), rgba(bg.value));
  const printed = parseFloat(row.get('ratio').replace(/:1.*/, ''));
  const pass = ratio >= MIN[size];
  if (!pass) errors.push(`${where}: ${text.name} on ${bg.name} is ${ratio.toFixed(2)}:1, under ${MIN[size]}:1 for ${size} text`);
  if (!(Math.abs(printed - ratio) <= 0.05)) errors.push(`${where}: the guide prints ${row.get('ratio')} for ${text.name} on ${bg.name}; the ratio is ${ratio.toFixed(1)}:1`);
  return { text: text.name, bg: bg.name, size, ratio, pass };
}).filter(Boolean);

// ---------- 2. The roles in tokens.json

const ROLE_MIN = { text: MIN.body, 'text-secondary': MIN.body, accent: MIN.body, separator: SEPARATOR_MIN };
const BACKDROPS = ['background', 'surface'];

function roleColor(appearance, name) {
  const t = tokens.role?.[appearance]?.[name];
  if (!t) { errors.push(`role ${appearance}.${name} is missing from tokens.json`); return null; }
  const alias = t.$value.match(/^\{color\.(core|light)\.(.+)\}$/);
  const hex = alias ? palette.get(alias[2]) : t.$value;
  if (!hex || !/^#[0-9A-Fa-f]{6}([0-9A-Fa-f]{2})?$/.test(hex)) {
    errors.push(`role ${appearance}.${name}: ${t.$value} is neither a palette alias nor a hex color`);
    return null;
  }
  return rgba(hex);
}

const roles = [];
for (const appearance of ['light', 'dark']) {
  const backdrops = Object.fromEntries(BACKDROPS.map((b) => [b, roleColor(appearance, b)]));
  for (const [b, c] of Object.entries(backdrops)) {
    if (c && c[3] !== 1) errors.push(`role ${appearance}.${b} must be opaque`);
  }
  for (const [name, min] of Object.entries(ROLE_MIN)) {
    const fg = roleColor(appearance, name);
    for (const b of BACKDROPS) {
      if (!fg || !backdrops[b] || backdrops[b][3] !== 1) continue;
      const ratio = contrast(fg, backdrops[b]);
      const pass = ratio >= min;
      if (!pass) errors.push(`role ${appearance}.${name} on ${b} is ${ratio.toFixed(2)}:1, under ${min}:1`);
      roles.push({ appearance, name, b, ratio, min, pass });
    }
  }
}

// ---------- 3. The palette tables

const swatches = [];
for (const group of ['core', 'light']) {
  const seen = new Set();
  for (const row of table(`palette:${group}`, ['token', 'hex'])) {
    const name = row.get('token').replace(/[*`]/g, '').trim();
    const key = tokenKey(name);
    const printed = (row.get('hex').match(/#[0-9A-Fa-f]{6}\b/g) || []).map((h) => h.toUpperCase());
    if (seen.has(key)) errors.push(`${row.where}: ${name} is listed twice`);
    seen.add(key);
    let expected;
    if (key === 'iridescent' && group === 'core') expected = iridescent;
    else if (palette.has(key)) expected = [palette.get(key)];
    else { errors.push(`${row.where}: "${name}" is not a palette token`); continue; }
    const pass = printed.length === expected.length && printed.every((h, i) => h === expected[i]);
    if (!pass) errors.push(`${row.where}: the guide prints ${printed.join(' → ') || 'no hex'} for ${name}; tokens.json has ${expected.join(' → ')}`);
    swatches.push({ group, name, value: expected.join(' → '), pass });
  }
  const required = [...groupOf].filter(([, g]) => g === group).map(([k]) => k).concat(group === 'core' ? ['iridescent'] : []);
  for (const key of required) {
    if (!seen.has(key)) errors.push(`palette:${group} table: no row for ${key}, which tokens.json defines`);
  }
}

// ---------- Report

console.log(`WCAG contrast, ${pairings.length} text pairings from ${GUIDE}\n`);
for (const r of pairings) {
  console.log(`${r.pass ? 'pass' : 'FAIL'}  ${pad(r.text, 13)} on ${pad(r.bg, 13)} ${ratioText(r.ratio)} ${r.size} (needs ${MIN[r.size]}:1)`);
}
console.log(`\nRoles from brand/tokens/tokens.json, on each appearance's background and surface\n`);
for (const r of roles) {
  console.log(`${r.pass ? 'pass' : 'FAIL'}  ${pad(r.appearance, 5)} ${pad(r.name, 14)} on ${pad(r.b, 10)} ${ratioText(r.ratio)} (needs ${r.min}:1)`);
}
console.log(`\nPalette tables from ${GUIDE}, against brand/tokens/tokens.json\n`);
for (const s of swatches) {
  console.log(`${s.pass ? 'pass' : 'FAIL'}  ${pad(s.group, 5)} ${pad(s.name, 13)} ${s.value}`);
}
if (errors.length) {
  console.error(`\n${errors.length} problem${errors.length > 1 ? 's' : ''}:`);
  for (const e of errors) console.error(`  ${e}`);
  process.exit(1);
}
console.log('\nAll pairings, roles and palette tables pass.');
