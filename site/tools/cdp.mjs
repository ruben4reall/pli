// A small Chrome DevTools Protocol client for the site's local checks (Node 22, no dependencies).
import { spawn } from 'node:child_process';
import { mkdtemp, rm, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { setTimeout as sleep } from 'node:timers/promises';

export const CHROME = process.env.CHROME_PATH ?? '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';

export const SIZES = {
  desktop: { width: 1440, height: 900, deviceScaleFactor: 1, mobile: false },
  phone: { width: 390, height: 844, deviceScaleFactor: 2, mobile: true },
  narrow: { width: 375, height: 812, deviceScaleFactor: 2, mobile: true },
};

// Injected before any page script: layout shifts, CSP violations, uncaught errors and frame times.
const RECORDER = `(() => {
  const record = (window.__pli = { shifts: [], csp: [], errors: [], frames: [] });
  addEventListener('securitypolicyviolation', (e) => record.csp.push(e.violatedDirective + ' ' + e.blockedURI));
  addEventListener('error', (e) => record.errors.push(String(e.message)));
  addEventListener('unhandledrejection', (e) => record.errors.push(String(e.reason)));
  new PerformanceObserver((list) => {
    for (const entry of list.getEntries()) if (!entry.hadRecentInput) record.shifts.push(entry.value);
  }).observe({ type: 'layout-shift', buffered: true });
  const tick = (t) => { record.frames.push(t); if (record.frames.length < 3600) requestAnimationFrame(tick); };
  requestAnimationFrame(tick);
})();`;

class Connection {
  constructor(ws) {
    this.ws = ws;
    this.nextId = 0;
    this.pending = new Map();
    this.listeners = new Set();
    ws.addEventListener('message', (event) => {
      const message = JSON.parse(event.data);
      if (message.id === undefined) {
        for (const listener of this.listeners) listener(message);
        return;
      }
      const call = this.pending.get(message.id);
      if (!call) return;
      this.pending.delete(message.id);
      if (message.error) call.reject(new Error(`${call.method}: ${message.error.message}`));
      else call.resolve(message.result);
    });
  }

  send(method, params = {}, sessionId = undefined) {
    const id = ++this.nextId;
    this.ws.send(JSON.stringify({ id, method, params, ...(sessionId ? { sessionId } : {}) }));
    return new Promise((resolve, reject) => this.pending.set(id, { resolve, reject, method }));
  }

  on(listener) {
    this.listeners.add(listener);
    return () => this.listeners.delete(listener);
  }
}

export async function launchChrome({ args = [] } = {}) {
  const profile = await mkdtemp(join(tmpdir(), 'pli-chrome-'));
  const proc = spawn(
    CHROME,
    ['--headless=new', '--remote-debugging-port=0', `--user-data-dir=${profile}`, '--no-first-run',
      '--no-default-browser-check', '--hide-scrollbars', '--mute-audio', ...args, 'about:blank'],
    { stdio: ['ignore', 'ignore', 'pipe'] },
  );
  const wsUrl = await new Promise((resolve, reject) => {
    let log = '';
    const timer = setTimeout(() => reject(new Error(`Chrome did not start:\n${log}`)), 20000);
    proc.stderr.on('data', (chunk) => {
      log += chunk;
      const match = log.match(/DevTools listening on (ws:\/\/\S+)/);
      if (match) {
        clearTimeout(timer);
        resolve(match[1]);
      }
    });
    proc.once('exit', (code) => {
      clearTimeout(timer);
      reject(new Error(`Chrome exited with ${code}:\n${log}`));
    });
  });
  const ws = new WebSocket(wsUrl);
  await new Promise((resolve, reject) => {
    ws.addEventListener('open', resolve, { once: true });
    ws.addEventListener('error', reject, { once: true });
  });
  const connection = new Connection(ws);
  return {
    connection,
    newPage: (options) => openPage(connection, options),
    async close() {
      ws.close();
      if (proc.exitCode === null) {
        proc.kill();
        await new Promise((done) => proc.once('exit', done));
      }
      await rm(profile, { recursive: true, force: true });
    },
  };
}

async function openPage(connection, options = {}) {
  const { width, height, deviceScaleFactor, mobile } = { ...SIZES.desktop, ...options };
  const { targetId } = await connection.send('Target.createTarget', { url: 'about:blank' });
  const { sessionId } = await connection.send('Target.attachToTarget', { targetId, flatten: true });
  const send = (method, params) => connection.send(method, params, sessionId);
  const waiters = [];
  const problems = [];
  const responses = new Map();
  const off = connection.on((message) => {
    if (message.sessionId !== sessionId) return;
    const { method, params } = message;
    if (method === 'Runtime.exceptionThrown') problems.push(`exception: ${params.exceptionDetails.exception?.description ?? params.exceptionDetails.text}`);
    if (method === 'Runtime.consoleAPICalled' && (params.type === 'error' || params.type === 'warning')) {
      problems.push(`console.${params.type}: ${params.args.map((a) => a.value ?? a.description).join(' ')}`);
    }
    if (method === 'Log.entryAdded' && (params.entry.level === 'error' || params.entry.level === 'warning')) {
      problems.push(`${params.entry.source}: ${params.entry.text} ${params.entry.url ?? ''}`.trim());
    }
    if (method === 'Network.responseReceived') {
      responses.set(params.requestId, { url: params.response.url, status: params.response.status, type: params.type, bytes: 0 });
    }
    if (method === 'Network.loadingFinished' && responses.has(params.requestId)) {
      responses.get(params.requestId).bytes = params.encodedDataLength;
    }
    for (const waiter of [...waiters]) {
      if (waiter.method !== method) continue;
      waiters.splice(waiters.indexOf(waiter), 1);
      waiter.resolve(params);
    }
  });
  await send('Page.enable');
  await send('Runtime.enable');
  await send('Log.enable');
  await send('Network.enable');
  await send('Emulation.setDeviceMetricsOverride', { width, height, deviceScaleFactor, mobile });
  if (mobile) await send('Emulation.setTouchEmulationEnabled', { enabled: true, maxTouchPoints: 5 });
  await send('Emulation.setEmulatedMedia', {
    features: [{ name: 'prefers-reduced-motion', value: options.reducedMotion ? 'reduce' : 'no-preference' }],
  });
  for (const source of [RECORDER, ...(options.beforeLoad ?? [])]) {
    await send('Page.addScriptToEvaluateOnNewDocument', { source });
  }

  const page = {
    send,
    problems,
    transfers: () => [...responses.values()],
    waitFor(method, timeout = 30000) {
      return new Promise((resolve, reject) => {
        const waiter = { method, resolve };
        waiters.push(waiter);
        setTimeout(() => {
          const index = waiters.indexOf(waiter);
          if (index < 0) return;
          waiters.splice(index, 1);
          reject(new Error(`Timed out waiting for ${method}`));
        }, timeout);
      });
    },
    async goto(url) {
      const loaded = page.waitFor('Page.loadEventFired');
      await send('Page.navigate', { url });
      await loaded;
    },
    async evaluate(expression) {
      const { result, exceptionDetails } = await send('Runtime.evaluate', { expression, awaitPromise: true, returnByValue: true });
      if (exceptionDetails) throw new Error(`evaluate: ${exceptionDetails.exception?.description ?? exceptionDetails.text}`);
      return result.value;
    },
    async waitUntil(expression, timeout = 15000) {
      const end = Date.now() + timeout;
      while (Date.now() < end) {
        if (await page.evaluate(expression)) return;
        await sleep(50);
      }
      throw new Error(`Timed out waiting for: ${expression}`);
    },
    async press(key, code = key, keyCode = 0) {
      await send('Input.dispatchKeyEvent', { type: 'keyDown', key, code, windowsVirtualKeyCode: keyCode });
      await send('Input.dispatchKeyEvent', { type: 'keyUp', key, code, windowsVirtualKeyCode: keyCode });
    },
    async screenshot(path) {
      const { data } = await send('Page.captureScreenshot', { format: 'png' });
      await writeFile(path, Buffer.from(data, 'base64'));
      return path;
    },
    async close() {
      off();
      await connection.send('Target.closeTarget', { targetId });
    },
  };
  return page;
}
