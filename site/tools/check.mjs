// The quality gates, run locally in headless Chrome with no external service. Each module in tools/checks/
// (common.mjs aside) is one suite. Usage: node tools/check.mjs [suite ...]   (exit code 1 on any failure)
import { readdir } from 'node:fs/promises';
import { launchChrome } from './cdp.mjs';
import { startServer } from './serve.mjs';

const dir = new URL('./checks/', import.meta.url);
const wanted = process.argv.slice(2);
const suites = [];
for (const file of (await readdir(dir)).filter((f) => f.endsWith('.mjs') && f !== 'common.mjs').sort()) {
  const suite = await import(new URL(file, dir));
  if (!wanted.length || wanted.includes(suite.NAME)) suites.push(suite);
}
const server = await startServer();
const chrome = await launchChrome();
const results = [];
try {
  for (const suite of suites) {
    try {
      for (const result of await suite.run({ chrome, url: server.url })) results.push({ suite: suite.NAME, ...result });
    } catch (error) {
      results.push({ suite: suite.NAME, name: 'the suite ran to the end', ok: false, detail: error.message });
    }
  }
} finally {
  await chrome.close();
  await server.close();
}
let failed = 0;
for (const r of results) {
  console.log(`${r.ok ? 'ok  ' : 'FAIL'} ${r.suite}: ${r.name}${r.detail ? ` (${r.detail})` : ''}`);
  if (!r.ok) failed += 1;
}
console.log(`${results.length - failed} of ${results.length} checks passed`);
process.exit(failed || !results.length ? 1 : 0);
