/* Basket Efsanesi — çevrimdışı destek.
   Strateji: sayfa için önce ağ (güncel sürüm gelsin), ağ yoksa önbellek;
   ikon gibi değişmeyen dosyalar için önce önbellek. */
const AD = 'hoop-legend-v4';
const DOSYALAR = ['./', './index.html', './diller.js', './sahne3d.js', './oyuncu.glb', './manifest.webmanifest', './ikon-180.png', './ikon-192.png', './ikon-512.png'];

self.addEventListener('install', e=>{
  e.waitUntil(caches.open(AD).then(c => c.addAll(DOSYALAR)).then(()=> self.skipWaiting()).catch(()=>{}));
});

self.addEventListener('activate', e=>{
  e.waitUntil(
    caches.keys()
      .then(anahtarlar => Promise.all(anahtarlar.filter(a => a !== AD).map(a => caches.delete(a))))
      .then(()=> self.clients.claim())
  );
});

self.addEventListener('fetch', e=>{
  const istek = e.request;
  if(istek.method !== 'GET' || !istek.url.startsWith('http')) return;
  const belge = istek.mode === 'navigate' || istek.destination === 'document';
  if(belge){
    e.respondWith(
      fetch(istek).then(yanit=>{
        const kopya = yanit.clone();
        caches.open(AD).then(c => c.put(istek, kopya)).catch(()=>{});
        return yanit;
      }).catch(()=> caches.match(istek).then(r => r || caches.match('./index.html')))
    );
  }else{
    e.respondWith(
      caches.match(istek).then(r => r || fetch(istek).then(yanit=>{
        const kopya = yanit.clone();
        caches.open(AD).then(c => c.put(istek, kopya)).catch(()=>{});
        return yanit;
      }))
    );
  }
});
