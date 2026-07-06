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
async function verifyYonetim(token) {
  if (!token || String(token).length < 8) return false;
  try {
    const r = await fetch(RAPOR_API_BASE + '/kart/listele', {
      headers: { 'X-Cactus-Key': String(token) },
    });
    return r.status === 200;
  } catch (e) {
    return false;
  }
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
        // Bildirim numarası (boş → genel numara: env.WA_PHONE ya da D1 '_wa_')
        wa_phone: d.wa_phone || '',
        // Geç kalma uyarı saati "HH:MM" İstanbul (boş = kapalı)
        gec_saat: d.gec_saat || '',
      };
    }
  } catch (e) {}
  return { personel: [], acilis: [], kapanis: [], wa_phone: '', gec_saat: '' };
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
          for (const evt of events) {
            const res = await postEvent(env, evt);
            if (res.ok && res.accepted) accepted++;
            else if (!res.ok) lastErr = res.error;
          }
          vardiyaChecklistKancasi(env, ctx, events);
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
      return json({ ok: true, ts: Date.now() });
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
      const yetkili = await verifyYonetim(token);
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
            if (!(await verifyYonetim(token))) return json({ ok: false, error: 'unauthorized' }, 401, NO_STORE);
            // wa_ready: Green API kimliği + alıcı numara çözülebiliyor mu (secret veya D1) — kurulum ipucu için
            const wa = await resolveWa(env, cfg);
            const waReady = !!(wa.instance && wa.token && wa.phone);
            const waDefMask = wa.defaultPhone ? (String(wa.defaultPhone).replace(/\D/g, '').slice(0, 6) + '••••') : '';
            // green_set: kimlik zaten kayıtlı mı (token asla dönmez); env_wa: secret'lardan mı geliyor
            const greenSet = !!(wa.instance && wa.token);
            const envWa = !!(env.GREEN_INSTANCE && env.GREEN_TOKEN);
            return json({ ok: true, personel: cfg.personel, acilis: cfg.acilis, kapanis: cfg.kapanis, wa_phone: cfg.wa_phone, gec_saat: cfg.gec_saat, wa_default: waDefMask, wa_ready: waReady, green_set: greenSet, env_wa: envWa }, 200, NO_STORE);
          }
          // Herkese açık: sadece isimler + maddeler (PIN ve numara asla dönmez)
          return json({ ok: true, personel: (cfg.personel || []).map(function (p) { return p && p.ad; }).filter(Boolean), acilis: cfg.acilis, kapanis: cfg.kapanis }, 200, NO_STORE);
        }
        if (request.method === 'POST') {
          const token = request.headers.get('X-Cactus-Key') || '';
          if (!(await verifyYonetim(token))) return json({ ok: false, error: 'unauthorized' }, 401, NO_STORE);
          const body = await request.json();
          const sube = body.sube;
          if (sube !== 'fsm' && sube !== 'podyum') return json({ ok: false, error: 'sube required' }, 400, NO_STORE);
          const gecSaat = String(body.gec_saat || '').trim();
          const cfg = {
            personel: Array.isArray(body.personel) ? body.personel.map(function (p) { return { ad: String((p && p.ad) || '').trim(), pin: String((p && p.pin) || '').trim() }; }).filter(function (p) { return p.ad; }) : [],
            acilis: Array.isArray(body.acilis) ? body.acilis.map(String) : [],
            kapanis: Array.isArray(body.kapanis) ? body.kapanis.map(String) : [],
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

    // ─── /api/vardiya-giris — PIN'li giriş/çıkış (herkese açık ama PIN ile korumalı) ───
    // POST { sube, ad, pin, aksiyon('giris'|'cikis'), cihaz_id }
    //   → PIN doğru ise vardiya event'i kaydeder; girişte WhatsApp bildirimi gönderir
    if (url.pathname === '/api/vardiya-giris' && request.method === 'POST') {
      try {
        await ensureVardiyaTable(env);
        const body = await request.json();
        const sube = body.sube;
        const ad = String(body.ad || '').trim();
        const pin = String(body.pin || '').trim();
        const aksiyon = body.aksiyon === 'cikis' ? 'cikis' : 'giris';
        if (sube !== 'fsm' && sube !== 'podyum') return json({ ok: false, error: 'sube required' }, 400, NO_STORE);
        if (!ad || !pin) return json({ ok: false, error: 'Ad ve PIN gerekli' }, 200, NO_STORE);
        const cfg = await getVardiyaCfg(env, sube);
        const kisi = (cfg.personel || []).find(function (p) { return p && p.ad === ad; });
        if (!kisi) return json({ ok: false, error: 'Personel bulunamadı' }, 200, NO_STORE);
        if (!kisi.pin || kisi.pin !== pin) return json({ ok: false, error: 'PIN hatalı' }, 200, NO_STORE);
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

    // Diğer her şey → statik dosya
    return env.ASSETS.fetch(request);
  },

  // Cron (wrangler.toml [triggers]): gece özeti + geç kalma uyarısı
  async scheduled(event, env, ctx) {
    ctx.waitUntil(vardiyaZamanliKontrol(env).catch(function () {}));
  },
};
