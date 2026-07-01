/* Cactus Adisyon — Service Worker
 * Strateji:
 *  - HTML: network-first → istenen URL'in cache'i (asla başka HTML'e fallback YOK)
 *  - Statik (favicon, manifest): cache-first
 *  - API çağrıları (rapor-api.workers.dev): sadece network
 *
 * KRİTİK: FSM ve Podyum HTML'leri ASLA birbirine fallback olamaz —
 * Her request kendi URL'ine ait cache döner; yoksa hata döner.
 */
const VERSION = 'cactus-v19'; // v19: footer markası eski yazıya döndü + dijital sadakat kartına logo
const CACHE = 'cactus-cache-' + VERSION;
const STATIC_ASSETS = [
  '/favicon.svg',
  '/manifest.json',
  '/manifest-fsm.json'
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

  // HTML — network-first; offline fallback SADECE istenen URL'in cache'i (asla başka HTML değil)
  const isHTML = req.mode === 'navigate' || req.destination === 'document' || url.pathname.endsWith('.html') || url.pathname === '/';
  if (isHTML) {
    // HTML'i HER ZAMAN ağdan taze çek (cache:'no-store') → CF'nin 10dk tarayıcı cache'ini
    // baypas eder, deploy sonrası eski kod takılı kalmaz. Offline'da son cache'e düşer.
    e.respondWith(
      fetch(req, { cache: 'no-store' }).then((res) => {
        if (res && res.ok) {
          const copy = res.clone();
          caches.open(CACHE).then((c) => c.put(req, copy).catch(() => {}));
        }
        return res;
      }).catch(() => caches.match(req)) // SADECE istenen URL — başka HTML'e fallback YASAK
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
