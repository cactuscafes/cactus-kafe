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
        const res = await postEvent(env, body.event || body);
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

    // Diğer her şey → statik dosya
    return env.ASSETS.fetch(request);
  },
};
