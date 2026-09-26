// Runs tests/gpu.html in headless Chrome: the WebGL2 port against the CPU reference, plus a synced-frame benchmark.
// Usage: node tools/check-gpu.mjs [--bench]   (exit code 1 on any failure)
import { launchChrome } from './cdp.mjs';
import { startServer } from './serve.mjs';

/** Synced frame budget at 1840 x 1195, the hero at 1440 px and 2x (2.0 to 3.6 ms on an M3 Pro). */
export const FRAME_BUDGET_MS = 6;

const bench = process.argv.includes('--bench');
const server = await startServer();
const chrome = await launchChrome();
let failed = 0;
try {
  const page = await chrome.newPage();
  await page.goto(`${server.url}/tests/gpu.html${bench ? '?bench' : ''}`);
  try {
    await page.waitUntil('window.__gpu && window.__gpu.done', 30000);
  } catch {
    console.log(`FAIL tests/gpu.html never finished: ${page.problems.join(' | ') || 'no message'}`);
    failed += 1;
  }
  if (!failed) {
    const gpu = await page.evaluate('window.__gpu');
    console.log(`renderer: ${gpu.renderer}`);
    for (const result of gpu.results) {
      console.log(`${result.ok ? 'ok  ' : 'FAIL'} ${result.name}${result.ok ? '' : `: ${result.error}`}`);
      if (!result.ok) failed += 1;
    }
    if (gpu.benchmark) {
      const { medianMs, p95Ms } = gpu.benchmark;
      const ok = medianMs < FRAME_BUDGET_MS;
      console.log(`${ok ? 'ok  ' : 'FAIL'} synced frame at 1840 x 1195: median ${medianMs.toFixed(2)} ms, p95 ${p95Ms.toFixed(2)} ms (budget ${FRAME_BUDGET_MS} ms)`);
      if (!ok) failed += 1;
    }
    for (const problem of page.problems) console.log(`page: ${problem}`);
    if (/swiftshader|software|llvmpipe/i.test(gpu.renderer)) {
      console.log('FAIL the renderer is software: WebGL2 must run on the GPU for these checks');
      failed += 1;
    }
  }
} finally {
  await chrome.close();
  await server.close();
}
process.exit(failed ? 1 : 0);
