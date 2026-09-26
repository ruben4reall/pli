// Ruben's own page counter (ruben-analytics): one anonymous page view, no cookie, no identifier, sent as a
// beacon after load so it never slows the page. Nothing is sent from a local copy.
const ENDPOINT = 'https://ruben-analytics.vercel.app/api/hit';

export function startBeacon(doc = document, win = window) {
  const host = win.location.hostname;
  if (host === 'localhost' || host === '127.0.0.1' || host === '' || host.endsWith('.local')) return;
  const body = JSON.stringify({ site: 'pli', path: win.location.pathname, ref: doc.referrer });
  try {
    if (!win.navigator.sendBeacon(ENDPOINT, body)) throw new Error('beacon');
  } catch {
    win.fetch(ENDPOINT, { method: 'POST', body, keepalive: true }).catch(() => {});
  }
}
