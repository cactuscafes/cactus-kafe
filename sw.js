/* Cactus Adisyon — Service Worker
 * Strateji:
 *  - HTML (adisyon, adisyon-fsm): network-first → cache fallback (her zaman güncel kalır)
 *  - Statik (favicon, manifest): cache-first
 *  - API çağrıları (rapor-api.workers.dev): sadece network — offline'da sessizce başarısız
 */
const VERSION = 'cactus-v1';
const CACHE = 'cactus-cache-' + VERSION;
const STATIC_ASSETS = [
  '/adisyon.html',
  '/adisyon-fsm.html',
  '/favicon.svg',
  '/manifest.json'
];

self.addEventListener('install', (e) => {
  e.waitUntil(
    caches.open(CACHE).then((c) => c.addAll(STATIC_ASSETS).catch(() => {})).then(() => self.skipWaiting())
  );
});

self.addEventListener('activate', (e) => {
  e.waitUntil(
    caches.keys().then((keys) => Promise.all(
      keys.filter((k) => k !== CACHE && k.startsWith('cactus-cache-')).map((k) => caches.delete(k))
    )).then(() => self.clients.claim())
  );
});

self.addEventListener('fetch', (e) => {
  const req = e.request;
  if (req.method !== 'GET') return;
  const url = new URL(req.url);

  // API çağrıları — service worker'a uğramasın (D1 sync gerekli)
  if (url.hostname.includes('workers.dev')) return;
  // Same origin değilse atla
  if (url.origin !== location.origin) return;

  // HTML — network-first (her açılışta güncel sürümü dene, offline'da cache)
  const isHTML = req.mode === 'navigate' || req.destination === 'document' || url.pathname.endsWith('.html') || url.pathname === '/';
  if (isHTML) {
    e.respondWith(
      fetch(req).then((res) => {
        // Başarılı yanıtı cache'le
        if (res && res.ok) {
          const copy = res.clone();
          caches.open(CACHE).then((c) => c.put(req, copy).catch(() => {}));
        }
        return res;
      }).catch(() => caches.match(req).then((r) => r || caches.match('/adisyon.html')))
    );
    return;
  }

  // Diğer statikler — cache-first
  e.respondWith(
    caches.match(req).then((cached) => {
      if (cached) return cached;
      return fetch(req).then((res) => {
        if (res && res.ok) {
          const copy = res.clone();
          caches.open(CACHE).then((c) => c.put(req, copy).catch(() => {}));
        }
        return res;
      }).catch(() => cached);
    })
  );
});

// Yeni sürüm hazır olduğunda hemen aktive et
self.addEventListener('message', (e) => {
  if (e.data === 'SKIP_WAITING') self.skipWaiting();
});
