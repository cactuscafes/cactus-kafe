/**
 * Cactus Kafe — Event-Sourced Adisyon Sync
 *
 * Square/Toast/OtterPOS yaklaşımı: her aksiyon (ürün ekle, sil, ödeme)
 * bir EVENT olarak append-only log'a yazılır. Çakışma yok, kayıp yok.
 *
 * Endpoints:
 *   POST /api/event          - Yeni event ekle (idempotent UUID ile)
 *   POST /api/events         - Birden çok event'i batch olarak ekle
 *   GET  /api/events?sube=X&since=N  - seq > N olan eventleri sırayla
 *
 * Bu Worker statik dosyaları da servis ediyor (ASSETS binding).
 * /api/* dışındaki tüm istekler statik dosyaya gider.
 */

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, X-Cactus-Key',
  'Access-Control-Max-Age': '86400',
};

function json(data, status = 200, extraHeaders) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { 'Content-Type': 'application/json', ...CORS, ...(extraHeaders || {}) },
  });
}
const NO_STORE = { 'Cache-Control': 'no-store, no-cache, must-revalidate' };

// Yönetim doğrulama — bordro gibi gizli uçlar için.
// rapor-api'nin auth'lı (/kart/listele) ucuna token ile proxy istek atıp
// 200 dönerse yetkili sayarız. Herhangi bir hata/red → fail-closed (yetkisiz).
const RAPOR_API_BASE = 'https://cactus-rapor-api.batuhanbulut.workers.dev';
async function verifyYonetim(env, token) {
  if (!token || String(token).length < 8) return false;
  try {
    // Aynı hesabın workers.dev adresine worker içinden doğrudan fetch Cloudflare
    // tarafından engelleniyor (istek hiç ulaşmıyor) → Service Binding (env.RAPOR)
    // üzerinden gidiyoruz. Binding yoksa (lokal dev) normal fetch'e düşer.
    const istek = new Request(RAPOR_API_BASE + '/kart/listele', {
      headers: { 'X-Cactus-Key': String(token) },
    });
    const r = env.RAPOR ? await env.RAPOR.fetch(istek) : await fetch(istek);
    return r.status === 200;
  } catch (e) {
    return false;
  }
}

// Yönetim jetonu — /kart/musteri-sil gibi auth'lu rapor-api uçları için.
// Jetonlar süreli (exp) olduğundan secret'a JETON koymak birkaç gün sonra bozulur;
// bu yüzden secret olarak PAROLA (KART_YONETIM_SIFRE) tutulur ve jeton gerektiğinde
// /auth/login'den alınıp isolate ömrü boyunca önbelleklenir.
// KART_YONETIM_KEY verilmişse (uzun ömürlü bir anahtar varsa) o doğrudan kullanılır.
let _yonetimJeton = { token: '', exp: 0 };
async function yonetimJetonu(env) {
  if (env.KART_YONETIM_KEY) return String(env.KART_YONETIM_KEY);
  const sifre = env.KART_YONETIM_SIFRE;
  if (!sifre) return '';
  const now = Date.now();
  if (_yonetimJeton.token && _yonetimJeton.exp > now + 60000) return _yonetimJeton.token;
  try {
    const istek = new Request(RAPOR_API_BASE + '/auth/login', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ sifre: String(sifre) }),
    });
    const r = env.RAPOR ? await env.RAPOR.fetch(istek) : await fetch(istek);
    const d = await r.json();
    if (d && d.ok && d.token) {
      _yonetimJeton = { token: d.token, exp: Number(d.exp) || (now + 3600000) };
      return d.token;
    }
  } catch (e) {}
  return '';
}

// ─── Vardiya ayar deposu (personel+PIN, checklist maddeleri, WhatsApp config) ───
async function ensureVardiyaTable(env) {
  await env.ADISYON_DB.prepare(
    `CREATE TABLE IF NOT EXISTS vardiya_ayar (sube TEXT PRIMARY KEY, data TEXT NOT NULL, updated_at INTEGER)`
  ).run();
}
async function getVardiyaCfg(env, sube) {
  try {
    const row = await env.ADISYON_DB.prepare(`SELECT data FROM vardiya_ayar WHERE sube = ?`).bind(sube).first();
    if (row && row.data) {
      const d = JSON.parse(row.data);
      return {
        personel: Array.isArray(d.personel) ? d.personel : [],
        acilis: Array.isArray(d.acilis) ? d.acilis : [],
        kapanis: Array.isArray(d.kapanis) ? d.kapanis : [],
        // Malzeme listesi — işaretli = eksik/azaldı (günlük değil; alınana dek kalır)
        malzeme: Array.isArray(d.malzeme) ? d.malzeme : [],
        // Bildirim numarası (boş → genel numara: env.WA_PHONE ya da D1 '_wa_')
        wa_phone: d.wa_phone || '',
        // Geç kalma uyarı saati "HH:MM" İstanbul (boş = kapalı)
        gec_saat: d.gec_saat || '',
      };
    }
  } catch (e) {}
  return { personel: [], acilis: [], kapanis: [], malzeme: [], wa_phone: '', gec_saat: '' };
}
// WhatsApp gönderimi — raporlarla AYNI kanal: Green API (rapor-api'deki whatsappGonder ile birebir).
// Kimlik bilgileri: önce worker secret'ları (GREEN_INSTANCE/GREEN_TOKEN/WA_PHONE),
// yoksa D1'deki genel ayar satırı (sube='_wa_'). Böylece secret kurmadan da çalışır.
async function getWaGlobal(env) {
  try {
    const row = await env.ADISYON_DB.prepare(`SELECT data FROM vardiya_ayar WHERE sube = '_wa_'`).first();
    if (row && row.data) {
      const d = JSON.parse(row.data);
      return { green_instance: d.green_instance || '', green_token: d.green_token || '', wa_phone: d.wa_phone || '' };
    }
  } catch (e) {}
  return { green_instance: '', green_token: '', wa_phone: '' };
}
async function resolveWa(env, cfg) {
  const g = await getWaGlobal(env);
  return {
    instance: env.GREEN_INSTANCE || g.green_instance || '',
    token: env.GREEN_TOKEN || g.green_token || '',
    // Alıcı: şubeye özel numara > worker secret WA_PHONE > D1 genel numara
    phone: ((cfg && cfg.wa_phone) || env.WA_PHONE || g.wa_phone || ''),
    defaultPhone: (env.WA_PHONE || g.wa_phone || ''),
  };
}
async function vardiyaWhatsapp(instance, token, phone, mesaj) {
  const tel = (phone || '').replace(/\D/g, '');
  if (!instance || !token || !tel) return null;
  const chatId = tel + '@c.us';
  try {
    const res = await fetch('https://api.green-api.com/waInstance' + instance + '/sendMessage/' + token, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ chatId, message: mesaj }),
    });
    return { ok: res.ok };
  } catch (e) {
    return { ok: false, error: e.message };
  }
}

// ─── Vardiya bildirim otomasyonu: gece özeti + geç kalma uyarısı + checklist tamam mesajı ───
const TR_MS = 3 * 3600 * 1000; // Türkiye UTC+3 (sabit, yaz saati yok)
function gunBasiMs(ms) {
  // İş günü sınırı 05:00 İstanbul → bu iş gününün başlangıcı (UTC ms)
  const d = new Date(ms + TR_MS);
  let bas = Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate(), 5, 0, 0) - TR_MS;
  if (ms < bas) bas -= 86400000;
  return bas;
}
function isTarih(gbMs) {
  // İş günü etiketi YYYY-MM-DD (İstanbul takvimi)
  const d = new Date(gbMs + TR_MS);
  return d.getUTCFullYear() + '-' + String(d.getUTCMonth() + 1).padStart(2, '0') + '-' + String(d.getUTCDate()).padStart(2, '0');
}
function saatStr(ts) {
  try { return new Date(ts).toLocaleTimeString('tr-TR', { hour: '2-digit', minute: '2-digit', timeZone: 'Europe/Istanbul' }); } catch (e) { return ''; }
}
function subeAdi(sube) { return sube === 'fsm' ? 'FSM' : 'Podyumpark'; }

// Bildirim defteri (hangi gün ne gönderildi) — vardiya_ayar '_durum_' satırı
async function getVardiyaDurum(env) {
  try {
    const row = await env.ADISYON_DB.prepare(`SELECT data FROM vardiya_ayar WHERE sube = '_durum_'`).first();
    if (row && row.data) return JSON.parse(row.data) || {};
  } catch (e) {}
  return {};
}
async function setVardiyaDurum(env, obj) {
  await env.ADISYON_DB.prepare(
    `INSERT INTO vardiya_ayar (sube, data, updated_at) VALUES ('_durum_', ?, ?)
     ON CONFLICT(sube) DO UPDATE SET data = excluded.data, updated_at = excluded.updated_at`
  ).bind(JSON.stringify(obj), Date.now()).run();
}

// ─── Stok takibi: ürün bazında adet; MASA_PAY event'inde otomatik düşer ───
let _stokSemaHazir = false;
// iOS Ad Hoc dağıtımı için toplanan cihaz kimlikleri (bkz. /api/ios/*).
async function ensureIosTable(env) {
  await env.ADISYON_DB.prepare(
    `CREATE TABLE IF NOT EXISTS ios_cihazlar (
       udid TEXT PRIMARY KEY, urun TEXT DEFAULT '', surum TEXT DEFAULT '',
       seri TEXT DEFAULT '', ts INTEGER)`
  ).run();
}

async function ensureStokTable(env) {
  await env.ADISYON_DB.prepare(
    `CREATE TABLE IF NOT EXISTS stok (
       sube TEXT NOT NULL, urun_id TEXT NOT NULL, ad TEXT NOT NULL,
       adet REAL NOT NULL DEFAULT 0, esik REAL NOT NULL DEFAULT 0,
       updated_at INTEGER, PRIMARY KEY (sube, urun_id))`
  ).run();
  if (!_stokSemaHazir) {
    // Hammadde alanları: birim (shot/bardak...), paket tanımı (1 kg = 100 shot), tür (urun|hammadde)
    for (const kolon of ["birim TEXT DEFAULT ''", "paket_ad TEXT DEFAULT ''", "paket_birim REAL DEFAULT 0", "tur TEXT DEFAULT 'urun'"]) {
      try { await env.ADISYON_DB.prepare('ALTER TABLE stok ADD COLUMN ' + kolon).run(); } catch (e) {}
    }
    // Reçete: ürün → hammadde + miktar (Latte → 1 shot; Double Türk → 2 shot)
    await env.ADISYON_DB.prepare(
      `CREATE TABLE IF NOT EXISTS recete (
         sube TEXT NOT NULL, urun_id TEXT NOT NULL, urun_ad TEXT DEFAULT '',
         hammadde_id TEXT NOT NULL, miktar REAL NOT NULL,
         PRIMARY KEY (sube, urun_id, hammadde_id))`
    ).run();
    _stokSemaHazir = true;
  }
}
// Ödeme event'lerindeki ürünleri stoktan düş; eşik altına inenler için WhatsApp uyar.
// SADECE kabul edilmiş (yeni) event'lerle çağrılmalı — retry'da çift düşmesin.
async function stokDusHook(env, evts) {
  const dusum = {}; // sube -> { urun_id -> adet }
  for (const evt of (evts || [])) {
    if (!evt || evt.type !== 'MASA_PAY') continue;
    const sube = (evt.sube === 'fsm' || evt.sube === 'podyum') ? evt.sube : null;
    if (!sube) continue;
    let p = evt.payload; if (typeof p === 'string') { try { p = JSON.parse(p); } catch (e) { p = null; } }
    if (!p || !Array.isArray(p.urunler)) continue;
    for (const u of p.urunler) {
      const id = String((u && u.id) || ''); const adet = Number(u && u.adet) || 0;
      if (!id || adet <= 0) continue;
      (dusum[sube] = dusum[sube] || {})[id] = (dusum[sube][id] || 0) + adet;
    }
  }
  const subeler = Object.keys(dusum);
  if (!subeler.length) return;
  await ensureStokTable(env);
  for (const sube of subeler) {
    // Reçeteli ürünler: satılan adet × bileşen miktarı kadar hammaddeden düş
    const ids = Object.keys(dusum[sube]);
    const azalt = {}; ids.forEach(function (id) { azalt[id] = dusum[sube][id]; });
    try {
      const ph = ids.map(function () { return '?'; }).join(',');
      const rc = await env.ADISYON_DB.prepare(
        `SELECT urun_id, hammadde_id, miktar FROM recete WHERE sube = ? AND urun_id IN (` + ph + `)`
      ).bind(sube, ...ids).all();
      for (const r of (rc.results || [])) {
        const m = Number(r.miktar) * dusum[sube][r.urun_id];
        if (m > 0) azalt[r.hammadde_id] = (azalt[r.hammadde_id] || 0) + m;
      }
    } catch (e) {}
    const uyarilar = [];
    for (const id of Object.keys(azalt)) {
      const row = await env.ADISYON_DB.prepare(`SELECT ad, adet, esik FROM stok WHERE sube = ? AND urun_id = ?`).bind(sube, id).first();
      if (!row) continue; // bu ürün takip edilmiyor
      const yeni = Number(row.adet) - azalt[id];
      await env.ADISYON_DB.prepare(`UPDATE stok SET adet = ?, updated_at = ? WHERE sube = ? AND urun_id = ?`).bind(yeni, Date.now(), sube, id).run();
      // Eşiğin ÜSTÜnden altına inişte uyar (tekrar tekrar değil)
      if (yeni <= Number(row.esik) && Number(row.adet) > Number(row.esik)) {
        uyarilar.push({ ad: row.ad, kalan: yeni });
      }
    }
    if (uyarilar.length) {
      const cfg = await getVardiyaCfg(env, sube);
      const wa = await resolveWa(env, cfg);
      if (wa.instance && wa.token && wa.phone) {
        const msg = '📦 Stok uyarısı — ' + subeAdi(sube) + '\n'
          + uyarilar.map(function (u) { return '• ' + u.ad + ': ' + (u.kalan <= 0 ? 'TÜKENDİ' : (u.kalan + ' kaldı')); }).join('\n');
        await vardiyaWhatsapp(wa.instance, wa.token, wa.phone, msg);
      }
    }
  }
}

// Eksik malzemeler — son 30 günün son işaret durumu (alınınca işaret kaldırılır)
const MALZEME_PENCERE = 30 * 86400000;
async function eksikMalzemeler(env, sube, cfg, bitTs) {
  const items = (cfg && cfg.malzeme) || [];
  if (!items.length) return [];
  const rows = await env.ADISYON_DB.prepare(
    `SELECT payload, ts FROM adisyon_events WHERE sube = ? AND type = 'checklist' AND ts >= ? AND ts < ? ORDER BY ts ASC`
  ).bind(sube, bitTs - MALZEME_PENCERE, bitTs).all();
  const son = {};
  for (const r of (rows.results || [])) {
    let p; try { p = JSON.parse(r.payload); } catch (e) { continue; }
    if (p && p.tur === 'malzeme') son[p.madde] = !!p.done;
  }
  return items.filter(function (m) { return son[m]; });
}

// Günlük özet metni: kişi bazında giriş/çıkış seansları + checklist durumu
async function vardiyaOzetOlustur(env, sube, basTs, bitTs, cfg) {
  const rows = await env.ADISYON_DB.prepare(
    `SELECT type, payload, ts FROM adisyon_events
      WHERE sube = ? AND type IN ('vardiya','checklist') AND ts >= ? AND ts < ?
      ORDER BY ts ASC`
  ).bind(sube, basTs, bitTs).all();
  const evs = [];
  for (const r of (rows.results || [])) {
    let p; try { p = JSON.parse(r.payload); } catch (e) { continue; }
    if (p) evs.push({ type: r.type, p: p, ts: r.ts });
  }
  if (!evs.length) return null;
  const d = new Date(basTs + TR_MS);
  const tarihStr = String(d.getUTCDate()).padStart(2, '0') + '.' + String(d.getUTCMonth() + 1).padStart(2, '0');
  const satirlar = ['📋 Vardiya özeti — ' + subeAdi(sube) + ' (' + tarihStr + ')'];
  const kisiler = {}; const sira = [];
  for (const e of evs) {
    if (e.type !== 'vardiya' || !e.p.ad) continue;
    if (!kisiler[e.p.ad]) { kisiler[e.p.ad] = []; sira.push(e.p.ad); }
    kisiler[e.p.ad].push(e);
  }
  for (const ad of sira) {
    const seg = []; let acik = null;
    for (const e of kisiler[ad]) {
      if (e.p.aksiyon === 'giris') { if (acik === null) acik = e.ts; }
      else if (e.p.aksiyon === 'cikis' && acik !== null) { seg.push(saatStr(acik) + '–' + saatStr(e.ts)); acik = null; }
    }
    if (acik !== null) seg.push(saatStr(acik) + '–? (çıkış işaretlenmemiş ⚠️)');
    if (seg.length) satirlar.push('👤 ' + ad + ': ' + seg.join(', '));
  }
  if (sira.length === 0) satirlar.push('👤 Giriş/çıkış kaydı yok.');
  for (const tur of ['acilis', 'kapanis']) {
    const items = (cfg && cfg[tur]) || [];
    if (!items.length) continue;
    const son = {};
    for (const e of evs) { if (e.type === 'checklist' && e.p.tur === tur) son[e.p.madde] = !!e.p.done; }
    const biten = items.filter(function (m) { return son[m]; }).length;
    satirlar.push((tur === 'acilis' ? '🌅 Açılış: ' : '🌙 Kapanış: ') + biten + '/' + items.length + (biten === items.length ? ' ✅' : ' ⚠️'));
  }
  // Eksik malzeme — günlük değil: son işaret durumu (alınınca kaldırılır)
  const eksik = await eksikMalzemeler(env, sube, cfg, bitTs);
  if (eksik.length) satirlar.push('🧂 Eksik malzeme: ' + eksik.join(', '));
  return satirlar.join('\n');
}

// Cron (10 dk'da bir): 05:00–05:30 arası dünün özeti; gec_saat geçtiyse giriş kontrolü
async function vardiyaZamanliKontrol(env) {
  await ensureVardiyaTable(env);
  const now = Date.now();
  const gb = gunBasiMs(now);
  const tarih = isTarih(gb);
  const ist = new Date(now + TR_MS);
  const dakika = ist.getUTCHours() * 60 + ist.getUTCMinutes();
  const durum = await getVardiyaDurum(env);
  let degisti = false;
  for (const sube of ['fsm', 'podyum']) {
    const cfg = await getVardiyaCfg(env, sube);
    const wa = await resolveWa(env, cfg);
    const hazir = !!(wa.instance && wa.token && wa.phone);
    // 1) Gece özeti — yeni iş günü başlar başlamaz (05:00–05:30) biten günü özetle
    if (dakika >= 300 && dakika < 330 && durum['ozet_' + sube] !== tarih) {
      if (hazir) {
        const msg = await vardiyaOzetOlustur(env, sube, gb - 86400000, gb, cfg);
        if (msg) await vardiyaWhatsapp(wa.instance, wa.token, wa.phone, msg);
      }
      durum['ozet_' + sube] = tarih; degisti = true;
    }
    // 3) Eksik malzeme sabah hatırlatması — 09:00–09:30 İst; eksik sürdükçe her gün
    if (dakika >= 540 && dakika < 570 && durum['malzeme_gun_' + sube] !== tarih) {
      if (hazir) {
        const eksik = await eksikMalzemeler(env, sube, cfg, now);
        if (eksik.length) {
          await vardiyaWhatsapp(wa.instance, wa.token, wa.phone,
            '🧂 Eksik malzeme hatırlatması — ' + subeAdi(sube) + '\n• ' + eksik.join('\n• ') + '\nMalzeme alındığında personel listedeki işareti kaldırınca bu hatırlatma durur.');
        }
      }
      durum['malzeme_gun_' + sube] = tarih; degisti = true;
    }
    // 2) Geç kalma — gec_saat (İstanbul) geçti, bugün hiç vardiya kaydı yoksa uyar (günde bir kez)
    if (cfg.gec_saat && durum['gec_' + sube] !== tarih) {
      const m = /^(\d{1,2}):(\d{2})$/.exec(cfg.gec_saat);
      if (m) {
        const esik = Number(m[1]) * 60 + Number(m[2]);
        // 05:00 öncesi eşikler iş günü sınırıyla çakışır → yok say
        if (esik >= 300 && dakika >= esik) {
          const giren = await env.ADISYON_DB.prepare(
            `SELECT 1 AS v FROM adisyon_events WHERE sube = ? AND type = 'vardiya' AND ts >= ? LIMIT 1`
          ).bind(sube, gb).first();
          if (!giren && hazir) {
            await vardiyaWhatsapp(wa.instance, wa.token, wa.phone,
              '⚠️ ' + subeAdi(sube) + ' — saat ' + cfg.gec_saat + ' geçti, bugün henüz vardiya girişi yapılmadı.');
          }
          durum['gec_' + sube] = tarih; degisti = true;
        }
      }
    }
  }
  if (degisti) await setVardiyaDurum(env, durum);
}

// Event kancası: gelen batch'te done=true checklist varsa liste tamamlandı mı bak (günde 1 bildirim)
function vardiyaChecklistKancasi(env, ctx, events) {
  const gorulen = {};
  for (const evt of (events || [])) {
    if (!evt || evt.type !== 'checklist') continue;
    let p = evt.payload; if (typeof p === 'string') { try { p = JSON.parse(p); } catch (e) { p = null; } }
    if (!p || !p.done) continue;
    const tur = (p.tur === 'kapanis' || p.tur === 'acilis') ? p.tur : '';
    const sube = (evt.sube === 'fsm' || evt.sube === 'podyum') ? evt.sube : '';
    if (tur && sube) gorulen[sube + ':' + tur] = true;
  }
  const anahtarlar = Object.keys(gorulen);
  if (anahtarlar.length) ctx.waitUntil(vardiyaChecklistKontrol(env, anahtarlar).catch(function () {}));
}
async function vardiyaChecklistKontrol(env, anahtarlar) {
  await ensureVardiyaTable(env);
  const now = Date.now();
  const gb = gunBasiMs(now);
  const tarih = isTarih(gb);
  let durum = null, degisti = false;
  for (const k of anahtarlar) {
    const parca = k.split(':'); const sube = parca[0], tur = parca[1];
    const cfg = await getVardiyaCfg(env, sube);
    const items = cfg[tur] || [];
    if (!items.length) continue;
    if (durum === null) durum = await getVardiyaDurum(env);
    const dk = 'cl_' + tur + '_' + sube;
    if (durum[dk] === tarih) continue; // bugün zaten bildirildi
    const rows = await env.ADISYON_DB.prepare(
      `SELECT payload, ts FROM adisyon_events WHERE sube = ? AND type = 'checklist' AND ts >= ? ORDER BY ts ASC`
    ).bind(sube, gb).all();
    const son = {}; let sonTs = 0; let sonAd = '';
    for (const r of (rows.results || [])) {
      let p; try { p = JSON.parse(r.payload); } catch (e) { continue; }
      if (!p || p.tur !== tur) continue;
      son[p.madde] = !!p.done;
      if (p.done && r.ts > sonTs) { sonTs = r.ts; sonAd = p.ad || ''; }
    }
    if (items.filter(function (m) { return son[m]; }).length !== items.length) continue; // henüz tamam değil
    const wa = await resolveWa(env, cfg);
    if (wa.instance && wa.token && wa.phone) {
      const saat = saatStr(sonTs || now);
      const msg = (tur === 'kapanis' ? '🌙 Kapanış tamamlandı ✅' : '🌅 Açılış hazırlıkları tamam ✅')
        + '\n' + subeAdi(sube) + ' — ' + items.length + '/' + items.length + ' madde'
        + (sonAd ? (' (son: ' + sonAd + ')') : '') + ' — ' + saat;
      await vardiyaWhatsapp(wa.instance, wa.token, wa.phone, msg);
    }
    durum[dk] = tarih; degisti = true;
  }
  if (degisti && durum) await setVardiyaDurum(env, durum);
}

async function postEvent(env, evt) {
  // Şema: id (UUID), sube, type, masa, payload (JSON string), ts (client), cihaz_id
  if (!evt || !evt.id || !evt.sube || !evt.type || typeof evt.ts !== 'number' || !evt.cihaz_id) {
    return { ok: false, error: 'missing fields' };
  }
  const payload = typeof evt.payload === 'string' ? evt.payload : JSON.stringify(evt.payload || {});
  const serverTs = Date.now();
  try {
    // INSERT OR IGNORE → UUID çakışırsa atla (idempotent retry koruması)
    const result = await env.ADISYON_DB.prepare(
      `INSERT OR IGNORE INTO adisyon_events
         (id, sube, type, masa, payload, ts, server_ts, cihaz_id)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?)`
    ).bind(
      evt.id,
      String(evt.sube),
      String(evt.type),
      evt.masa == null ? null : Number(evt.masa),
      payload,
      Number(evt.ts),
      serverTs,
      String(evt.cihaz_id)
    ).run();
    return { ok: true, accepted: result.meta.changes === 1, server_ts: serverTs };
  } catch (e) {
    return { ok: false, error: String(e && e.message || e) };
  }
}

export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);

    // CORS preflight
    if (request.method === 'OPTIONS') {
      return new Response(null, { status: 204, headers: CORS });
    }

    // ─── /api/event — tek event ekle ───
    if (url.pathname === '/api/event' && request.method === 'POST') {
      try {
        const body = await request.json();
        const evt = body.event || body;
        const res = await postEvent(env, evt);
        if (res.ok) vardiyaChecklistKancasi(env, ctx, [evt]);
        if (res.ok && res.accepted) ctx.waitUntil(stokDusHook(env, [evt]).catch(function () {}));
        return json(res, res.ok ? 200 : 400);
      } catch (e) {
        return json({ ok: false, error: String(e.message || e) }, 400);
      }
    }

    // ─── /api/events — batch event ekle ya da listele ───
    if (url.pathname === '/api/events') {
      // POST: batch insert (offline kuyruğu boşaltırken kullanılır)
      if (request.method === 'POST') {
        try {
          const body = await request.json();
          const events = Array.isArray(body.events) ? body.events : [];
          if (!events.length) return json({ ok: true, accepted: 0 });
          let accepted = 0;
          let lastErr = null;
          const kabulEdilen = []; // stok düşümü İDEMPOTENT DEĞİL → sadece yeni kaydedilenler
          for (const evt of events) {
            const res = await postEvent(env, evt);
            if (res.ok && res.accepted) { accepted++; kabulEdilen.push(evt); }
            else if (!res.ok) lastErr = res.error;
          }
          vardiyaChecklistKancasi(env, ctx, events);
          if (kabulEdilen.length) ctx.waitUntil(stokDusHook(env, kabulEdilen).catch(function () {}));
          return json({ ok: true, accepted, total: events.length, error: lastErr });
        } catch (e) {
          return json({ ok: false, error: String(e.message || e) }, 400);
        }
      }
      // GET: since=N → seq > N olan eventleri sırayla döner
      if (request.method === 'GET') {
        try {
          const sube = url.searchParams.get('sube') || '';
          const since = Number(url.searchParams.get('since') || 0);
          const limit = Math.min(Number(url.searchParams.get('limit') || 1000), 5000);
          if (!sube) return json({ ok: false, error: 'sube required' }, 400);
          const result = await env.ADISYON_DB.prepare(
            `SELECT seq, id, type, masa, payload, ts, server_ts, cihaz_id
               FROM adisyon_events
              WHERE sube = ? AND seq > ?
              ORDER BY seq ASC
              LIMIT ?`
          ).bind(sube, since, limit).all();
          const events = (result.results || []).map(r => ({
            seq: r.seq,
            id: r.id,
            type: r.type,
            masa: r.masa,
            payload: (() => { try { return JSON.parse(r.payload); } catch(e) { return {}; } })(),
            ts: r.ts,
            server_ts: r.server_ts,
            cihaz_id: r.cihaz_id,
          }));
          return json({ ok: true, events, count: events.length, last_seq: events.length ? events[events.length - 1].seq : since });
        } catch (e) {
          return json({ ok: false, error: String(e.message || e) }, 500);
        }
      }
    }

    // ─── /api/ping — sağlık testi ───
    if (url.pathname === '/api/ping') {
      // rapor_binding: verifyYonetim'in kullandığı service binding bağlı mı (teşhis için)
      return json({ ok: true, ts: Date.now(), rapor_binding: !!env.RAPOR });
    }

    // ─── /api/reset — temizleme (gün sonu / debug) ───
    // Sadece eski eventleri (örn. 30 gün öncesi) sil
    if (url.pathname === '/api/reset' && request.method === 'POST') {
      try {
        const body = await request.json();
        const sube = body.sube;
        const olderThanDays = Number(body.days || 30);
        if (!sube) return json({ ok: false, error: 'sube required' }, 400);
        const sinir = Date.now() - olderThanDays * 24 * 3600 * 1000;
        const result = await env.ADISYON_DB.prepare(
          `DELETE FROM adisyon_events WHERE sube = ? AND server_ts < ?`
        ).bind(sube, sinir).run();
        return json({ ok: true, deleted: result.meta.changes });
      } catch (e) {
        return json({ ok: false, error: String(e.message || e) }, 500);
      }
    }

    // ─── /api/bordro — maaş/bordro senkron (şube başına, auth'lı) ───
    // GET  /api/bordro?sube=fsm|podyum   → { ok, data, updated_at }
    // POST /api/bordro  { sube, data }   → { ok, updated_at }
    // Kimlik: X-Cactus-Key header (yönetim token'ı). Yetkisiz → 401.
    if (url.pathname === '/api/bordro') {
      const token = request.headers.get('X-Cactus-Key') || '';
      const yetkili = await verifyYonetim(env, token);
      if (!yetkili) return json({ ok: false, error: 'unauthorized' }, 401, NO_STORE);
      try {
        await env.ADISYON_DB.prepare(
          `CREATE TABLE IF NOT EXISTS bordro_store (
             sube TEXT PRIMARY KEY,
             data TEXT NOT NULL,
             updated_at INTEGER NOT NULL
           )`
        ).run();
      } catch (e) {
        return json({ ok: false, error: 'db init: ' + String(e && e.message || e) }, 500);
      }

      if (request.method === 'GET') {
        const sube = url.searchParams.get('sube') || '';
        if (sube !== 'fsm' && sube !== 'podyum') return json({ ok: false, error: 'sube required' }, 400);
        try {
          const row = await env.ADISYON_DB.prepare(
            `SELECT data, updated_at FROM bordro_store WHERE sube = ?`
          ).bind(sube).first();
          let data = null;
          if (row && row.data) { try { data = JSON.parse(row.data); } catch (e) { data = null; } }
          return json({ ok: true, data, updated_at: row ? row.updated_at : 0 }, 200, NO_STORE);
        } catch (e) {
          return json({ ok: false, error: String(e && e.message || e) }, 500);
        }
      }

      if (request.method === 'POST') {
        try {
          const body = await request.json();
          const sube = body.sube;
          if (sube !== 'fsm' && sube !== 'podyum') return json({ ok: false, error: 'sube required' }, 400);
          const data = (body.data && typeof body.data === 'object') ? body.data : { personel: [], kayitlar: [] };
          const now = Date.now();
          await env.ADISYON_DB.prepare(
            `INSERT INTO bordro_store (sube, data, updated_at) VALUES (?, ?, ?)
             ON CONFLICT(sube) DO UPDATE SET data = excluded.data, updated_at = excluded.updated_at`
          ).bind(sube, JSON.stringify(data), now).run();
          return json({ ok: true, updated_at: now });
        } catch (e) {
          return json({ ok: false, error: String(e && e.message || e) }, 400);
        }
      }

      return json({ ok: false, error: 'method not allowed' }, 405);
    }

    // ─── /api/vardiya — personel/PIN + checklist + WhatsApp config ───
    // GET  ?sube=X            → PUBLIC: { personel:[ad], acilis, kapanis } (PIN'siz)
    // GET  ?sube=X&full=1     → AUTH (X-Cactus-Key): tam config (PIN + bildirim numarası dahil)
    // POST { sube, personel:[{ad,pin}], acilis, kapanis, wa_phone } → AUTH: kaydet
    if (url.pathname === '/api/vardiya') {
      try {
        await ensureVardiyaTable(env);
        if (request.method === 'GET') {
          const sube = url.searchParams.get('sube') || '';
          if (sube !== 'fsm' && sube !== 'podyum') return json({ ok: false, error: 'sube required' }, 400, NO_STORE);
          const cfg = await getVardiyaCfg(env, sube);
          if (url.searchParams.get('full') === '1') {
            const token = request.headers.get('X-Cactus-Key') || '';
            if (!(await verifyYonetim(env, token))) return json({ ok: false, error: 'unauthorized' }, 401, NO_STORE);
            // wa_ready: Green API kimliği + alıcı numara çözülebiliyor mu (secret veya D1) — kurulum ipucu için
            const wa = await resolveWa(env, cfg);
            const waReady = !!(wa.instance && wa.token && wa.phone);
            const waDefMask = wa.defaultPhone ? (String(wa.defaultPhone).replace(/\D/g, '').slice(0, 6) + '••••') : '';
            // green_set: kimlik zaten kayıtlı mı (token asla dönmez); env_wa: secret'lardan mı geliyor
            const greenSet = !!(wa.instance && wa.token);
            const envWa = !!(env.GREEN_INSTANCE && env.GREEN_TOKEN);
            return json({ ok: true, personel: cfg.personel, acilis: cfg.acilis, kapanis: cfg.kapanis, malzeme: cfg.malzeme, wa_phone: cfg.wa_phone, gec_saat: cfg.gec_saat, wa_default: waDefMask, wa_ready: waReady, green_set: greenSet, env_wa: envWa }, 200, NO_STORE);
          }
          // Herkese açık: sadece isimler + maddeler (PIN ve numara asla dönmez).
          // pinli: şifresi OLAN isimler — adisyon şifre kutusunu sadece bunlara gösterir.
          return json({
            ok: true,
            personel: (cfg.personel || []).map(function (p) { return p && p.ad; }).filter(Boolean),
            pinli: (cfg.personel || []).filter(function (p) { return p && p.ad && p.pin; }).map(function (p) { return p.ad; }),
            acilis: cfg.acilis,
            kapanis: cfg.kapanis,
            malzeme: cfg.malzeme,
          }, 200, NO_STORE);
        }
        if (request.method === 'POST') {
          const token = request.headers.get('X-Cactus-Key') || '';
          if (!(await verifyYonetim(env, token))) return json({ ok: false, error: 'unauthorized' }, 401, NO_STORE);
          const body = await request.json();
          const sube = body.sube;
          if (sube !== 'fsm' && sube !== 'podyum') return json({ ok: false, error: 'sube required' }, 400, NO_STORE);
          const gecSaat = String(body.gec_saat || '').trim();
          const cfg = {
            personel: Array.isArray(body.personel) ? body.personel.map(function (p) { return { ad: String((p && p.ad) || '').trim(), pin: String((p && p.pin) || '').trim() }; }).filter(function (p) { return p.ad; }) : [],
            acilis: Array.isArray(body.acilis) ? body.acilis.map(String) : [],
            kapanis: Array.isArray(body.kapanis) ? body.kapanis.map(String) : [],
            malzeme: Array.isArray(body.malzeme) ? body.malzeme.map(String) : [],
            wa_phone: String(body.wa_phone || '').replace(/\D/g, ''),
            gec_saat: /^\d{1,2}:\d{2}$/.test(gecSaat) ? gecSaat : '',
          };
          await env.ADISYON_DB.prepare(
            `INSERT INTO vardiya_ayar (sube, data, updated_at) VALUES (?, ?, ?)
             ON CONFLICT(sube) DO UPDATE SET data = excluded.data, updated_at = excluded.updated_at`
          ).bind(sube, JSON.stringify(cfg), Date.now()).run();
          // Green API kimliği (genel, iki şube için ortak) — verildiyse '_wa_' satırına yaz.
          // Boş string GÖNDERİLİRSE korunur (yanlışlıkla silmeyi önlemek için sadece dolu değerler güncellenir).
          if (typeof body.green_instance === 'string' || typeof body.green_token === 'string' || typeof body.wa_default === 'string') {
            const g = await getWaGlobal(env);
            const gi = String(body.green_instance || '').trim();
            const gt = String(body.green_token || '').trim();
            const gp = String(body.wa_default || '').replace(/\D/g, '');
            const merged = {
              green_instance: gi || g.green_instance,
              green_token: gt || g.green_token,
              wa_phone: gp || g.wa_phone,
            };
            await env.ADISYON_DB.prepare(
              `INSERT INTO vardiya_ayar (sube, data, updated_at) VALUES ('_wa_', ?, ?)
               ON CONFLICT(sube) DO UPDATE SET data = excluded.data, updated_at = excluded.updated_at`
            ).bind(JSON.stringify(merged), Date.now()).run();
          }
          return json({ ok: true }, 200, NO_STORE);
        }
        return json({ ok: false, error: 'method not allowed' }, 405, NO_STORE);
      } catch (e) {
        return json({ ok: false, error: String(e && e.message || e) }, 500, NO_STORE);
      }
    }

    // ─── /api/stok — ürün stok takibi ───
    // GET  ?sube=X            → PUBLIC: takip edilen ürünler {id, ad, adet, esik}
    // POST (X-Cactus-Key)     → { sube, islem:'kaydet'|'ekle'|'sil', urun_id, ad?, adet?, esik?, delta? }
    if (url.pathname === '/api/stok') {
      try {
        await ensureStokTable(env);
        if (request.method === 'GET') {
          const sube = url.searchParams.get('sube') || '';
          if (sube !== 'fsm' && sube !== 'podyum') return json({ ok: false, error: 'sube required' }, 400, NO_STORE);
          const rows = await env.ADISYON_DB.prepare(`SELECT urun_id, ad, adet, esik, birim, paket_ad, paket_birim, tur, updated_at FROM stok WHERE sube = ? ORDER BY ad`).bind(sube).all();
          const hepsi = (rows.results || []).map(function (r) {
            return { id: r.urun_id, ad: r.ad, adet: Number(r.adet), esik: Number(r.esik), birim: r.birim || '', paket_ad: r.paket_ad || '', paket_birim: Number(r.paket_birim) || 0, tur: r.tur === 'hammadde' ? 'hammadde' : 'urun', ts: r.updated_at };
          });
          const hammaddeler = hepsi.filter(function (x) { return x.tur === 'hammadde'; });
          const dogrudan = hepsi.filter(function (x) { return x.tur !== 'hammadde'; });
          // Reçeteler + "kaç adet daha yapılabilir" hesabı (min bileşen kapasitesi)
          const rc = await env.ADISYON_DB.prepare(`SELECT urun_id, urun_ad, hammadde_id, miktar FROM recete WHERE sube = ?`).bind(sube).all();
          const receteler = (rc.results || []).map(function (r) { return { urun_id: r.urun_id, urun_ad: r.urun_ad || r.urun_id, hammadde_id: r.hammadde_id, miktar: Number(r.miktar) }; });
          const H = {}; hammaddeler.forEach(function (h) { H[h.id] = h; });
          const grup = {};
          receteler.forEach(function (r) { (grup[r.urun_id] = grup[r.urun_id] || { ad: r.urun_ad, bilesen: [] }).bilesen.push(r); });
          const hesaplanan = [];
          Object.keys(grup).forEach(function (pid) {
            let min = Infinity, az = false;
            grup[pid].bilesen.forEach(function (b) {
              const h = H[b.hammadde_id]; if (!h || !(Number(b.miktar) > 0)) return;
              const yap = Math.floor(h.adet / b.miktar);
              if (yap < min) min = yap;
              if (h.adet <= h.esik) az = true;
            });
            if (min === Infinity) return;
            // esik: hammadde eşiğe indiyse rozet turuncuya dönsün diye adet'e eşitlenir
            hesaplanan.push({ id: pid, ad: grup[pid].ad, adet: min, esik: az ? min : 0, hesap: true });
          });
          return json({ ok: true, urunler: dogrudan.concat(hesaplanan), hammaddeler: hammaddeler, receteler: receteler }, 200, NO_STORE);
        }
        if (request.method === 'POST') {
          const token = request.headers.get('X-Cactus-Key') || '';
          if (!(await verifyYonetim(env, token))) return json({ ok: false, error: 'unauthorized' }, 401, NO_STORE);
          const body = await request.json();
          const sube = body.sube;
          if (sube !== 'fsm' && sube !== 'podyum') return json({ ok: false, error: 'sube required' }, 400, NO_STORE);
          const id = String(body.urun_id || '').trim();
          if (!id) return json({ ok: false, error: 'urun_id gerekli' }, 400, NO_STORE);
          if (body.islem === 'sil') {
            await env.ADISYON_DB.prepare(`DELETE FROM stok WHERE sube = ? AND urun_id = ?`).bind(sube, id).run();
            // Hammadde silinirse onu kullanan reçeteler de temizlensin
            await env.ADISYON_DB.prepare(`DELETE FROM recete WHERE sube = ? AND hammadde_id = ?`).bind(sube, id).run();
            return json({ ok: true }, 200, NO_STORE);
          }
          if (body.islem === 'recete') {
            const hid = String(body.hammadde_id || '').trim();
            const miktar = Number(body.miktar) || 0;
            if (!hid || miktar <= 0) return json({ ok: false, error: 'hammadde ve miktar gerekli' }, 400, NO_STORE);
            await env.ADISYON_DB.prepare(
              `INSERT INTO recete (sube, urun_id, urun_ad, hammadde_id, miktar) VALUES (?, ?, ?, ?, ?)
               ON CONFLICT(sube, urun_id, hammadde_id) DO UPDATE SET urun_ad = excluded.urun_ad, miktar = excluded.miktar`
            ).bind(sube, id, String(body.urun_ad || id), hid, miktar).run();
            return json({ ok: true }, 200, NO_STORE);
          }
          if (body.islem === 'recete-sil') {
            const hid = String(body.hammadde_id || '').trim();
            if (hid) await env.ADISYON_DB.prepare(`DELETE FROM recete WHERE sube = ? AND urun_id = ? AND hammadde_id = ?`).bind(sube, id, hid).run();
            else await env.ADISYON_DB.prepare(`DELETE FROM recete WHERE sube = ? AND urun_id = ?`).bind(sube, id).run();
            return json({ ok: true }, 200, NO_STORE);
          }
          if (body.islem === 'ekle') {
            const delta = Number(body.delta) || 0;
            const r = await env.ADISYON_DB.prepare(
              `UPDATE stok SET adet = adet + ?, updated_at = ? WHERE sube = ? AND urun_id = ?`
            ).bind(delta, Date.now(), sube, id).run();
            if (!r.meta.changes) return json({ ok: false, error: 'ürün stok listesinde yok' }, 400, NO_STORE);
            return json({ ok: true }, 200, NO_STORE);
          }
          // varsayılan: kaydet (upsert — mutlak adet + eşik + ad; hammaddede birim/paket bilgisi)
          const tur = body.tur === 'hammadde' ? 'hammadde' : 'urun';
          await env.ADISYON_DB.prepare(
            `INSERT INTO stok (sube, urun_id, ad, adet, esik, birim, paket_ad, paket_birim, tur, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
             ON CONFLICT(sube, urun_id) DO UPDATE SET ad = excluded.ad, adet = excluded.adet, esik = excluded.esik,
               birim = excluded.birim, paket_ad = excluded.paket_ad, paket_birim = excluded.paket_birim, tur = excluded.tur, updated_at = excluded.updated_at`
          ).bind(sube, id, String(body.ad || id), Number(body.adet) || 0, Number(body.esik) || 0,
                 String(body.birim || ''), String(body.paket_ad || ''), Number(body.paket_birim) || 0, tur, Date.now()).run();
          return json({ ok: true }, 200, NO_STORE);
        }
        return json({ ok: false, error: 'method not allowed' }, 405, NO_STORE);
      } catch (e) {
        return json({ ok: false, error: String(e && e.message || e) }, 500, NO_STORE);
      }
    }

    // ─── /api/vardiya-gecmis — giriş/çıkış geçmişi (yönetim; admin geçmiş bölümü) ───
    // GET ?sube=X&gun=N (X-Cactus-Key) → son N iş gününün vardiya event'leri
    if (url.pathname === '/api/vardiya-gecmis' && request.method === 'GET') {
      try {
        const token = request.headers.get('X-Cactus-Key') || '';
        if (!(await verifyYonetim(env, token))) return json({ ok: false, error: 'unauthorized' }, 401, NO_STORE);
        const sube = url.searchParams.get('sube') || '';
        if (sube !== 'fsm' && sube !== 'podyum') return json({ ok: false, error: 'sube required' }, 400, NO_STORE);
        const gun = Math.min(Math.max(Number(url.searchParams.get('gun') || 14), 1), 60);
        const bas = gunBasiMs(Date.now()) - (gun - 1) * 86400000;
        const rows = await env.ADISYON_DB.prepare(
          `SELECT payload, ts FROM adisyon_events WHERE sube = ? AND type = 'vardiya' AND ts >= ? ORDER BY ts ASC`
        ).bind(sube, bas).all();
        const evs = [];
        for (const r of (rows.results || [])) {
          let p; try { p = JSON.parse(r.payload); } catch (e) { continue; }
          if (p && p.ad) evs.push({ ad: p.ad, aksiyon: p.aksiyon === 'cikis' ? 'cikis' : 'giris', ts: r.ts });
        }
        return json({ ok: true, events: evs }, 200, NO_STORE);
      } catch (e) {
        return json({ ok: false, error: String(e && e.message || e) }, 500, NO_STORE);
      }
    }

    // ─── /api/malzeme-bildir — personel eksikleri işaretleyip Gönder'e basınca tek WhatsApp ───
    // POST { sube, ad?, eksikler:[...], cihaz_id? } — liste config'teki malzemelerle süzülür.
    if (url.pathname === '/api/malzeme-bildir' && request.method === 'POST') {
      try {
        await ensureVardiyaTable(env);
        const body = await request.json();
        const sube = body.sube;
        if (sube !== 'fsm' && sube !== 'podyum') return json({ ok: false, error: 'sube required' }, 400, NO_STORE);
        const cfg = await getVardiyaCfg(env, sube);
        const gecerli = {};
        (cfg.malzeme || []).forEach(function (m) { gecerli[m] = true; });
        const liste = Array.isArray(body.eksikler)
          ? body.eksikler.map(String).filter(function (m, i, a) { return gecerli[m] && a.indexOf(m) === i; })
          : [];
        if (!liste.length) return json({ ok: false, error: 'Eksik madde seçilmedi' }, 200, NO_STORE);
        // Spam koruması: şube başına en fazla 2 dakikada bir bildirim
        const durum = await getVardiyaDurum(env);
        const now = Date.now();
        if (now - Number(durum['malzeme_ts_' + sube] || 0) < 120000) {
          return json({ ok: false, error: 'Az önce bildirildi — 2 dk sonra tekrar deneyin' }, 200, NO_STORE);
        }
        const wa = await resolveWa(env, cfg);
        if (!(wa.instance && wa.token && wa.phone)) return json({ ok: false, error: 'WhatsApp yapılandırılmamış' }, 200, NO_STORE);
        const ad = String(body.ad || '').trim();
        const msg = '🧂 Eksik malzeme — ' + subeAdi(sube) + '\n• ' + liste.join('\n• ') + '\n' + (ad ? (ad + ' — ') : '') + saatStr(now);
        const sonuc = await vardiyaWhatsapp(wa.instance, wa.token, wa.phone, msg);
        if (!(sonuc && sonuc.ok)) return json({ ok: false, error: 'Mesaj gönderilemedi' }, 200, NO_STORE);
        durum['malzeme_ts_' + sube] = now;
        ctx.waitUntil(setVardiyaDurum(env, durum));
        return json({ ok: true, adet: liste.length }, 200, NO_STORE);
      } catch (e) {
        return json({ ok: false, error: String(e && e.message || e) }, 400, NO_STORE);
      }
    }

    // ─── /api/kart-sil-teshis — silme yolu neden çalışmıyor, onu söyler ───
    // Sır SIZDIRMAZ: yalnızca "var mı yok mu" ve HTTP kodu döner, değer asla dönmez.
    // Secret kurulduğu hâlde silme reddedilirse hatanın nerede olduğunu tek çağrıda gösterir.
    if (url.pathname === '/api/kart-sil-teshis' && request.method === 'GET') {
      const sifreVar = !!env.KART_YONETIM_SIFRE;
      const anahtarVar = !!env.KART_YONETIM_KEY;
      let girisHttp = null;
      let jetonAlindi = false;
      if (sifreVar) {
        try {
          const istek = new Request(RAPOR_API_BASE + '/auth/login', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ sifre: String(env.KART_YONETIM_SIFRE) }),
          });
          const r = env.RAPOR ? await env.RAPOR.fetch(istek) : await fetch(istek);
          girisHttp = r.status;
          const d = await r.json().catch(function () { return null; });
          jetonAlindi = !!(d && d.ok && d.token);
        } catch (e) {
          girisHttp = 'istek hatası: ' + String(e && e.message || e);
        }
      }
      return json({
        ok: true,
        sifre_secreti_var: sifreVar,
        anahtar_secreti_var: anahtarVar,
        rapor_binding_var: !!env.RAPOR,
        auth_login_http: girisHttp,
        jeton_alinabildi: jetonAlindi,
      }, 200, NO_STORE);
    }

    // ─── /api/kart-sil — sadakat kartını kullanıcının KENDİSİ siler ───
    // POST { telefon } → rapor-api'nin /kart/musteri-sil ucuna yönetim anahtarıyla iletir.
    // App Store Guideline 5.1.1(v): hesap oluşturabilen uygulama, hesabın uygulama
    // İÇİNDEN silinmesini de sunmak zorunda (destek hattına yönlendirmek yetmiyor).
    // Kimlik modeli /kart/bak ile aynı: numarayı bilen o karta erişir — kart zaten
    // şifresiz/üyeliksiz ve numarayla sorgulanabiliyor.
    if (url.pathname === '/api/kart-sil' && request.method === 'POST') {
      try {
        const body = await request.json();
        const tel = String(body.telefon || '').replace(/\D/g, '');
        if (tel.length < 10) return json({ ok: false, error: 'Geçerli telefon numarası gerekli' }, 400, NO_STORE);
        const anahtar = await yonetimJetonu(env);
        const basliklar = { 'Content-Type': 'application/json' };
        if (anahtar) basliklar['X-Cactus-Key'] = anahtar;
        // Worker içinden aynı hesabın workers.dev adresine düz fetch engelli →
        // service binding (env.RAPOR) üzerinden; binding yoksa (lokal dev) fetch'e düşer.
        const istek = new Request(RAPOR_API_BASE + '/kart/musteri-sil', {
          method: 'POST',
          headers: basliklar,
          body: JSON.stringify({ telefon: tel }),
        });
        const r = env.RAPOR ? await env.RAPOR.fetch(istek) : await fetch(istek);
        let d = null;
        try { d = await r.json(); } catch (e) {}
        if (r.status === 401 || r.status === 403) {
          // KART_YONETIM_SIFRE secret'ı kurulmamış/geçersiz. Sessizce "silindi" DEMEyiz.
          return json({ ok: false, error: 'Silme servisi yapılandırılmamış' }, 500, NO_STORE);
        }
        if (!r.ok || !(d && d.ok)) {
          return json({ ok: false, error: (d && d.error) || 'Kart silinemedi' }, 502, NO_STORE);
        }
        return json({ ok: true }, 200, NO_STORE);
      } catch (e) {
        return json({ ok: false, error: String(e && e.message || e) }, 400, NO_STORE);
      }
    }

    // ─── /api/vardiya-giris — giriş/çıkış (şifre isteğe bağlı: kişide şifre varsa doğrulanır) ───
    // POST { sube, ad, pin?, aksiyon('giris'|'cikis'), cihaz_id }
    //   → kişinin şifresi varsa eşleşme zorunlu; yoksa şifresiz kabul.
    //     Vardiya event'i kaydeder; girişte WhatsApp bildirimi gönderir.
    if (url.pathname === '/api/vardiya-giris' && request.method === 'POST') {
      try {
        await ensureVardiyaTable(env);
        const body = await request.json();
        const sube = body.sube;
        const ad = String(body.ad || '').trim();
        const pin = String(body.pin || '').trim();
        const aksiyon = body.aksiyon === 'cikis' ? 'cikis' : 'giris';
        if (sube !== 'fsm' && sube !== 'podyum') return json({ ok: false, error: 'sube required' }, 400, NO_STORE);
        if (!ad) return json({ ok: false, error: 'Ad gerekli' }, 200, NO_STORE);
        const cfg = await getVardiyaCfg(env, sube);
        const kisi = (cfg.personel || []).find(function (p) { return p && p.ad === ad; });
        if (!kisi) return json({ ok: false, error: 'Personel bulunamadı' }, 200, NO_STORE);
        if (kisi.pin && kisi.pin !== pin) return json({ ok: false, error: 'Şifre hatalı' }, 200, NO_STORE);
        const now = Date.now();
        const evtId = (crypto && crypto.randomUUID) ? crypto.randomUUID() : ('v' + now + '-' + Math.round(now % 1e6));
        await env.ADISYON_DB.prepare(
          `INSERT OR IGNORE INTO adisyon_events (id, sube, type, masa, payload, ts, server_ts, cihaz_id)
           VALUES (?, ?, 'vardiya', NULL, ?, ?, ?, ?)`
        ).bind(evtId, sube, JSON.stringify({ ad: ad, aksiyon: aksiyon }), now, now, String(body.cihaz_id || 'server')).run();
        // WhatsApp bildirimi — raporlarla AYNI kanal (Green API). Kimlik: secret ya da D1 (_wa_).
        // Girişte 🟢, çıkışta 🔴. Fire-and-forget (ctx.waitUntil).
        const wa = await resolveWa(env, cfg);
        if (wa.instance && wa.token && wa.phone) {
          var subeAd = sube === 'fsm' ? 'FSM' : 'Podyumpark';
          var saat = '';
          try { saat = new Date(now).toLocaleTimeString('tr-TR', { hour: '2-digit', minute: '2-digit', timeZone: 'Europe/Istanbul' }); } catch (e) { saat = ''; }
          var msg = (aksiyon === 'giris' ? '🟢 ' : '🔴 ') + ad + (aksiyon === 'giris' ? ' vardiyaya giriş yaptı' : ' vardiyadan çıkış yaptı') + '\n' + subeAd + (saat ? (' — ' + saat) : '');
          ctx.waitUntil(vardiyaWhatsapp(wa.instance, wa.token, wa.phone, msg).catch(function () {}));
        }
        return json({ ok: true, ts: now, aksiyon: aksiyon }, 200, NO_STORE);
      } catch (e) {
        return json({ ok: false, error: String(e && e.message || e) }, 400, NO_STORE);
      }
    }

    // ─── /api/ios/profil — Ad Hoc kurulum için cihaz kimliği (UDID) toplama ───
    // Apple "Profile Service" profili: iPhone bunu kurunca cihaz bilgilerini
    // imzalı olarak /api/ios/kayit'e POST eder. Ad Hoc dağıtımda her cihazın
    // UDID'si Apple geliştirici portalına kaydedilmek ZORUNDA — bu uç onu toplar.
    // Profil imzasız olduğu için iPhone "Doğrulanmadı" der; normal, kurulabilir.
    if (url.pathname === '/api/ios/profil') {
      const geriUrl = new URL(request.url).origin + '/api/ios/kayit';
      const profil = `<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>PayloadContent</key>
  <dict>
    <key>URL</key><string>${geriUrl}</string>
    <key>DeviceAttributes</key>
    <array><string>UDID</string><string>PRODUCT</string><string>VERSION</string><string>SERIAL</string></array>
  </dict>
  <key>PayloadOrganization</key><string>Cactus Cafes</string>
  <key>PayloadDisplayName</key><string>Cactus Adisyon — Cihaz Kaydı</string>
  <key>PayloadVersion</key><integer>1</integer>
  <key>PayloadUUID</key><string>7f1c0a52-3d4e-4b71-9c1a-cactusadisyon01</string>
  <key>PayloadIdentifier</key><string>com.cactuscafes.adisyon.kayit</string>
  <key>PayloadDescription</key><string>Cactus Adisyon uygulamasının bu cihaza kurulabilmesi için cihaz kimliğini iletir. Kurulum bittikten sonra bu profili silebilirsiniz.</string>
  <key>PayloadType</key><string>Profile Service</string>
</dict>
</plist>`;
      return new Response(profil, {
        headers: {
          'Content-Type': 'application/x-apple-aspen-config',
          'Content-Disposition': 'attachment; filename="cactus-adisyon-kayit.mobileconfig"',
          ...NO_STORE,
        },
      });
    }

    // ─── /api/ios/kayit — profilin gönderdiği cihaz bilgisi (Apple imzalı plist) ───
    // Gövde PKCS#7 imzalı; içindeki düz plist metnini ayıklayıp UDID'yi okuyoruz.
    // (Worker'da imza doğrulaması yapılmıyor: gizli adres + yalnız UDID toplandığı
    //  için risk yok, sahte kayıt en fazla listeye çöp satır ekler.)
    if (url.pathname === '/api/ios/kayit' && request.method === 'POST') {
      try {
        await ensureIosTable(env);
        const ham = await request.text();
        const bas = ham.indexOf('<?xml');
        const son = ham.indexOf('</plist>');
        const govde = (bas >= 0 && son > bas) ? ham.slice(bas, son) : '';
        const alan = (ad) => {
          const m = govde.match(new RegExp('<key>' + ad + '</key>\\s*<string>([^<]*)</string>'));
          return m ? m[1].trim() : '';
        };
        const udid = alan('UDID');
        if (!udid) return new Response('UDID okunamadı', { status: 400, headers: NO_STORE });
        await env.ADISYON_DB.prepare(
          `INSERT INTO ios_cihazlar (udid, urun, surum, seri, ts) VALUES (?, ?, ?, ?, ?)
           ON CONFLICT(udid) DO UPDATE SET urun=excluded.urun, surum=excluded.surum, ts=excluded.ts`
        ).bind(udid, alan('PRODUCT'), alan('VERSION'), alan('SERIAL'), Date.now()).run();
        // Profil servisi akışında cihaz yanıtı Safari'ye taşır — teşekkür sayfasına at.
        return new Response('', { status: 302, headers: { Location: 'https://cactuscafes.com/ios-kayit/tamam.html', ...NO_STORE } });
      } catch (e) {
        return new Response('Hata: ' + String(e && e.message || e), { status: 400, headers: NO_STORE });
      }
    }

    // ─── /api/ios/cihazlar — kayıtlı cihaz listesi (yönetim) ───
    if (url.pathname === '/api/ios/cihazlar' && request.method === 'GET') {
      const yetkili = await verifyYonetim(env, request.headers.get('X-Cactus-Key'));
      if (!yetkili) return json({ ok: false, error: 'yetkisiz' }, 401, NO_STORE);
      await ensureIosTable(env);
      const r = await env.ADISYON_DB.prepare(
        'SELECT udid, urun, surum, seri, ts FROM ios_cihazlar ORDER BY ts DESC'
      ).all();
      return json({ ok: true, cihazlar: r.results || [] }, 200, NO_STORE);
    }

    // Diğer her şey → statik dosya
    return env.ASSETS.fetch(request);
  },
};

// Cron mantığı ayrı worker'dan çalışır (src/cron.js + wrangler-cron.toml):
// assets'li worker'larda cron trigger kaydolmuyor (wrangler 3 ve 4 ile doğrulandı;
// schedule sessizce atlanıyor). cactus-kafe-cron worker'ı aynı D1'e bağlanıp
// bu fonksiyonu 10 dk'da bir çağırır.
export { vardiyaZamanliKontrol };
