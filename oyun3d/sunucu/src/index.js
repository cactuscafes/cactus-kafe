/**
 * Cactus 3B — anonim telemetri toplayıcısı (Cloudflare Worker + D1).
 *
 * NEDEN AYRI WORKER: kafe API'siyle (kök dizindeki src/index.js) aynı yerde
 * durmamalı. Oyun telemetrisi herkese açık bir uç; adisyon/bordro verisi olan
 * bir worker'a açık uç eklemek, olmayan bir sorunu davet etmektir.
 *
 * Uçlar:
 *   POST /olay    — oyundan gelen olay partisi (kimlik doğrulaması YOK, açık uç)
 *   GET  /ozet    — toplu istatistik (X-Cactus-Key ile korumalı)
 *   GET  /saglik  — ayakta mı?
 *
 * GİZLİLİK — sunucu tarafındaki üç kural:
 *   1. IP, User-Agent, CF-Connecting-IP HİÇBİR YERE yazılmıyor. Cloudflare'in
 *      kendi istek günlükleri kapalı tutulmalı (README'ye bak).
 *   2. Şemada olmayan alan veritabanına giremiyor: gövde ne gönderirse
 *      göndersin, aşağıdaki ALANLAR listesi dışındaki her şey düşüyor.
 *   3. Olay adı beyaz listede değilse parti reddediliyor — "yeni olay ekledim"
 *      diye gizlilik metnini geçersiz kılmak, şema değişikliği gerektiriyor.
 */

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, X-Cactus-Key',
  'Access-Control-Max-Age': '86400',
};

function json(veri, durum = 200) {
  return new Response(JSON.stringify(veri), {
    status: durum,
    headers: { 'Content-Type': 'application/json', 'Cache-Control': 'no-store', ...CORS },
  });
}

// Oyunun gönderdiği olaylar. Beyaz liste: istemci yeni bir olay adı uydurursa
// parti reddedilir (400), çünkü gizlilik metni bu dört olayı anlatıyor.
const OLAYLAR = new Set(['bolum_basladi', 'olum', 'bolum_bitti', 'bolum_birakildi']);

// Şemadaki sayısal alanlar ve makul sınırları. Sınır, kötü niyetten çok
// bozuk veriye karşı: NaN/Infinity D1'e girerse sorgular sessizce çöker.
const ALANLAR = {
  sure: [0, 86400],
  x: [-10000, 10000],
  y: [-10000, 10000],
  z: [-10000, 10000],
  toplanan: [0, 10000],
  olum: [0, 100000],
  yenilen: [0, 100000],
};

const AZAMI_GOVDE = 16 * 1024;   // istemci en çok 60 olay yolluyor; 16 KB bol
const AZAMI_OLAY = 60;           // Telemetri.AZAMI_KUYRUK ile aynı
const METIN_SINIRI = 64;         // oturum / bolum / surum

function metin(deger, sinir = METIN_SINIRI) {
  if (typeof deger !== 'string') return null;
  const s = deger.trim();
  if (s.length === 0 || s.length > sinir) return null;
  return s;
}

function sayi(deger, alan) {
  if (typeof deger !== 'number' || !Number.isFinite(deger)) return null;
  const [alt, ust] = ALANLAR[alan];
  if (deger < alt || deger > ust) return null;
  return deger;
}

/** Gövdeyi satırlara çevirir. Hata varsa {hata} döner — parti tümden reddedilir. */
function satirlastir(govde, simdi) {
  if (govde === null || typeof govde !== 'object' || Array.isArray(govde)) {
    return { hata: 'govde nesne degil' };
  }
  const oturum = metin(govde.oturum);
  if (oturum === null) return { hata: 'oturum yok' };
  if (!Array.isArray(govde.olaylar)) return { hata: 'olaylar dizi degil' };
  if (govde.olaylar.length === 0) return { hata: 'olay yok' };
  if (govde.olaylar.length > AZAMI_OLAY) return { hata: 'cok fazla olay' };

  const satirlar = [];
  for (const olay of govde.olaylar) {
    if (olay === null || typeof olay !== 'object') return { hata: 'olay nesne degil' };
    const ad = metin(olay.ad);
    if (ad === null || !OLAYLAR.has(ad)) return { hata: 'bilinmeyen olay' };
    const surum = metin(olay.surum);
    if (surum === null) return { hata: 'surum yok' };
    // İstemci saati yanlış olabilir (kullanıcı takvimi 2008'e almış olabilir);
    // referans olarak saklıyoruz ama sıralama server_ts ile yapılıyor.
    const t = Number.isFinite(olay.t) ? Math.trunc(olay.t) : Math.trunc(simdi / 1000);
    satirlar.push({
      oturum, ad, bolum: metin(olay.bolum), t, server_ts: simdi, surum,
      demo: olay.demo === true ? 1 : 0,
      sure: sayi(olay.sure, 'sure'),
      x: sayi(olay.x, 'x'), y: sayi(olay.y, 'y'), z: sayi(olay.z, 'z'),
      toplanan: sayi(olay.toplanan, 'toplanan'),
      olum: sayi(olay.olum, 'olum'),
      yenilen: sayi(olay.yenilen, 'yenilen'),
    });
  }
  return { satirlar };
}

// Uzunluk sızdırmayan karşılaştırma. Anahtar kısa olduğu için pratikte önemsiz,
// ama doğru olanı yazmak bedava.
function anahtarEsit(a, b) {
  if (typeof a !== 'string' || typeof b !== 'string' || a.length !== b.length) return false;
  let fark = 0;
  for (let i = 0; i < a.length; i++) fark |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return fark === 0;
}

async function olayAl(request, env) {
  const uzunluk = Number(request.headers.get('Content-Length') || 0);
  if (uzunluk > AZAMI_GOVDE) return json({ hata: 'govde buyuk' }, 413);

  const ham = await request.text();
  if (ham.length > AZAMI_GOVDE) return json({ hata: 'govde buyuk' }, 413);

  let govde;
  try {
    govde = JSON.parse(ham);
  } catch (e) {
    return json({ hata: 'bozuk json' }, 400);
  }

  const { hata, satirlar } = satirlastir(govde, Date.now());
  if (hata) return json({ hata }, 400);

  const ifade = env.DB.prepare(
    `INSERT INTO olaylar (oturum, ad, bolum, t, server_ts, surum, demo,
                          sure, x, y, z, toplanan, olum, yenilen)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`
  );
  await env.DB.batch(satirlar.map((s) => ifade.bind(
    s.oturum, s.ad, s.bolum, s.t, s.server_ts, s.surum, s.demo,
    s.sure, s.x, s.y, s.z, s.toplanan, s.olum, s.yenilen
  )));

  // Oyun yanıtı okumuyor; kısa tutuyoruz.
  return json({ ok: true, yazilan: satirlar.length });
}

async function ozet(request, env, url) {
  // Anahtar tanımlı değilse uç KAPALI. "Secret koymayı unuttum" durumunda
  // özetin herkese açık olması, yanlış tarafa düşen bir varsayılandır.
  if (!env.OZET_ANAHTARI) return json({ hata: 'ozet kapali' }, 503);
  if (!anahtarEsit(request.headers.get('X-Cactus-Key') || '', env.OZET_ANAHTARI)) {
    return json({ hata: 'yetkisiz' }, 401);
  }

  const gun = Math.min(Math.max(Number(url.searchParams.get('gun') || 30), 1), 365);
  const sinir = Date.now() - gun * 86400000;

  // Huni: kaç oturum bölüme başladı, kaçı bitirdi, kaçı yarıda bıraktı.
  const huni = await env.DB.prepare(
    `SELECT bolum, ad, COUNT(DISTINCT oturum) AS oturum, COUNT(*) AS adet
     FROM olaylar WHERE server_ts >= ? GROUP BY bolum, ad`
  ).bind(sinir).all();

  // Ölüm noktaları: 2 birimlik ızgaraya yuvarlanmış yığınlar. Asıl soru bu —
  // "oyuncular nerede takılıyor?" tek bir sorgunun cevabı.
  const olumler = await env.DB.prepare(
    `SELECT bolum,
            ROUND(x / 2) * 2 AS gx, ROUND(y / 2) * 2 AS gy, ROUND(z / 2) * 2 AS gz,
            COUNT(*) AS adet
     FROM olaylar
     WHERE ad = 'olum' AND server_ts >= ? AND x IS NOT NULL
     GROUP BY bolum, gx, gy, gz ORDER BY adet DESC LIMIT 50`
  ).bind(sinir).all();

  // Bitirme süresi dağılımı: medyan yerine ortalama + en iyi/en kötü yeterli.
  const sureler = await env.DB.prepare(
    `SELECT bolum, COUNT(*) AS adet, AVG(sure) AS ortalama,
            MIN(sure) AS en_iyi, MAX(sure) AS en_kotu, AVG(olum) AS olum_ort
     FROM olaylar WHERE ad = 'bolum_bitti' AND server_ts >= ? GROUP BY bolum`
  ).bind(sinir).all();

  return json({
    gun,
    huni: huni.results,
    olum_noktalari: olumler.results,
    bitirme: sureler.results,
  });
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);

    if (request.method === 'OPTIONS') {
      return new Response(null, { status: 204, headers: CORS });
    }
    if (url.pathname === '/saglik') {
      return json({ ok: true });
    }
    if (url.pathname === '/olay' && request.method === 'POST') {
      try {
        return await olayAl(request, env);
      } catch (e) {
        // Telemetri oyunu bekletmemeli; ayrıntılı hata da sızdırmamalı.
        console.error('olay yazilamadi', e && e.message);
        return json({ hata: 'yazilamadi' }, 500);
      }
    }
    if (url.pathname === '/ozet' && request.method === 'GET') {
      try {
        return await ozet(request, env, url);
      } catch (e) {
        console.error('ozet alinamadi', e && e.message);
        return json({ hata: 'ozet alinamadi' }, 500);
      }
    }
    return json({ hata: 'bulunamadi' }, 404);
  },
};

// Test için dışa açık. `export default` dışındaki adlar Worker çalışma zamanını
// etkilemiyor; `testler/telemetri_testi.sh` oyunun ürettiği gerçek gövdeyi bu
// işlevden geçirerek istemci ile sunucunun aynı biçimi konuştuğunu doğruluyor.
export { satirlastir, OLAYLAR, AZAMI_OLAY, AZAMI_GOVDE };
