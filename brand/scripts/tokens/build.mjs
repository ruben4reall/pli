// Writes brand/tokens/tokens.css from brand/tokens/tokens.json, the single
// source of truth. The app's tokens live in
// Packages/PliKit/Sources/PliUI/Design/Theme.swift, which ThemeTests checks
// against tokens.json.
//   node brand/scripts/tokens/build.mjs
import { readFileSync, writeFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

const DIR = fileURLToPath(new URL('../../tokens/', import.meta.url));
const T = JSON.parse(readFileSync(`${DIR}tokens.json`, 'utf8'));

// ---------- Helpers

const entries = (group) => Object.entries(group).filter(([k]) => !k.startsWith('$'));
const resolve = (v) => {
  const m = typeof v === 'string' && v.match(/^\{(.+)\}$/);
  if (!m) return v;
  const token = m[1].split('.').reduce((o, k) => o[k], T);
  return resolve(token.$value);
};
const rgb = (hex) => [1, 3, 5].map((i) => parseInt(hex.slice(i, i + 2), 16));
const fontStack = T.font.family.sans.$value.map((f) => (/[\s]/.test(f) || f === 'Inter' ? `"${f}"` : f)).join(', ');
const iri = T.gradient.iridescent.$value;
const lower = (s) => s[0].toLowerCase() + s.slice(1);
const header = (c) => [
  `${c} Pli brand tokens, direction A "Glass".`,
  `${c} Generated from brand/tokens/tokens.json by brand/scripts/tokens/build.mjs:`,
  `${c} edit the JSON and run the script, never this file.`,
];

// ---------- CSS

const css = [...header('/*').map((l, i, a) => (i === 0 ? l : ' *' + l.slice(2))), ' */', '', ':root {'];
const colorGroups = [['core', 'Core palette'], ['light', 'Light palette']];
for (const [g, title] of colorGroups) {
  css.push(`  /* ${title} */`);
  for (const [name, t] of entries(T.color[g])) css.push(`  --pli-${name}: ${t.$value}; /* ${t.$description} */`);
  css.push('');
}
css.push(`  /* Iridescent gradient: ${lower(T.gradient.iridescent.$description)} */`);
iri.forEach((s, i) => css.push(`  --pli-iridescent-${i + 1}: ${s.color};`));
css.push(`  --pli-iridescent: linear-gradient(90deg, ${iri.map((s, i) => `var(--pli-iridescent-${i + 1}) ${Math.round(s.position * 100)}%`).join(', ')});`);
css.push('');
css.push('  /* Type: SF Pro through the system stack, never shipped; Inter as the fallback.');
css.push('     --pli-<style> is a font shorthand (weight size/line family); set letter-spacing');
css.push('     with --pli-<style>-tracking. */');
css.push(`  --pli-font-sans: ${fontStack};`);
for (const [name, t] of entries(T.font.weight)) css.push(`  --pli-weight-${name}: ${t.$value};`);
for (const [name, t] of entries(T.type)) {
  const v = t.$value;
  css.push(`  --pli-${name}-size: ${v.fontSize};`);
  css.push(`  --pli-${name}-line: ${v.lineHeight};`);
  css.push(`  --pli-${name}-weight: ${v.fontWeight};`);
  css.push(`  --pli-${name}-tracking: ${v.letterSpacing};`);
  css.push(`  --pli-${name}: ${v.fontWeight} ${v.fontSize}/${v.lineHeight} var(--pli-font-sans);`);
}
css.push('');
css.push('  /* Radii */');
for (const [name, t] of entries(T.radius)) css.push(`  --pli-radius-${name}: ${t.$value}; /* ${t.$description} */`);
css.push('');
css.push('  /* Spacing: 4-point scale, the key is the multiple of 4 */');
for (const [name, t] of entries(T.space)) css.push(`  --pli-space-${name}: ${t.$value};`);
css.push('');
css.push('  /* Motion: the fold is the signature */');
for (const [name, t] of entries(T.motion.ease)) css.push(`  --pli-ease-${name}: cubic-bezier(${t.$value.join(', ')}); /* ${t.$description} */`);
for (const [name, t] of entries(T.motion.duration)) css.push(`  --pli-duration-${name}: ${t.$value}; /* ${t.$description} */`);
css.push('');
// A role is an alias of a palette token, or a literal hex (#RRGGBBAA for a
// translucent value), written as is.
const roleValue = (t) => {
  const m = t.$value.match(/^\{color\.(core|light)\.(.+)\}$/);
  if (m) return `var(--pli-${m[2]});`;
  if (/^#[0-9A-Fa-f]{6}([0-9A-Fa-f]{2})?$/.test(t.$value)) return `${t.$value.toUpperCase()};${t.$description ? ` /* ${t.$description} */` : ''}`;
  throw new Error(`role value ${t.$value}: neither a palette alias nor a hex color`);
};
css.push('  /* Roles, light appearance (the default) */');
for (const [name, t] of entries(T.role.light)) css.push(`  --pli-${name}: ${roleValue(t)}`);
css.push('}');
css.push('');
css.push('/* Roles, dark appearance: opt in with data-pli-theme="dark" on any element. */');
css.push('[data-pli-theme="dark"] {');
for (const [name, t] of entries(T.role.dark)) css.push(`  --pli-${name}: ${roleValue(t)}`);
css.push('}');
css.push('');
writeFileSync(`${DIR}tokens.css`, css.join('\n'));

console.log(`wrote tokens.css to ${DIR}`);
