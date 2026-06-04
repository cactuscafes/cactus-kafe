-- Event-sourced adisyon sync — append-only event log
-- Square/Toast/OtterPOS yaklaşımı: her aksiyon (ekle, sil, ödeme) bir event.
-- Client state = events.reduce(). Çakışma yok, kayıp yok.
CREATE TABLE IF NOT EXISTS adisyon_events (
  seq         INTEGER PRIMARY KEY AUTOINCREMENT,  -- server-side ardışık sıra (zaman sırasıyla)
  id          TEXT NOT NULL UNIQUE,               -- client UUID — duplicate korumalı
  sube        TEXT NOT NULL,                      -- 'podyum' | 'fsm'
  type        TEXT NOT NULL,                      -- ITEM_ADD | ITEM_SUB | ITEM_DEL | MASA_CLEAR | MASA_PAY
  masa        INTEGER,                            -- masa numarası (1-34)
  payload     TEXT NOT NULL,                      -- JSON: ürün bilgisi vs.
  ts          INTEGER NOT NULL,                   -- client Date.now() (referans)
  server_ts   INTEGER NOT NULL,                   -- server tarafı Date.now() (otorite)
  cihaz_id    TEXT NOT NULL                       -- hangi cihaz yarattı (audit)
);

-- Şube bazlı sıralı listeleme için
CREATE INDEX IF NOT EXISTS idx_sube_seq ON adisyon_events(sube, seq);
-- Polling için: hızlı "since=N" sorgusu
CREATE INDEX IF NOT EXISTS idx_sube_server_ts ON adisyon_events(sube, server_ts);
