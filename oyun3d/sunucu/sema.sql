-- Cactus 3B telemetri — anonim oynanış olayları.
--
-- NEDEN SABİT SÜTUN, JSON DEĞİL: JSON blob'a her şey yazılır, kimse de ne
-- yazıldığını bilmez. Sabit sütun şeması aynı zamanda gizlilik sözleşmesidir:
-- burada olmayan bir alan veritabanına GİREMEZ. Ad, e-posta, IP, cihaz
-- kimliği, konum için sütun yok — bilerek.
--
-- oturum: oyunun her açılışında üretilen rastgele numara. İstemcide diske
-- yazılmıyor, yani iki oturum aynı kişiye bağlanamıyor. Tek işi, bir
-- oturumdaki olayları sıraya dizmek ("başladı → öldü → bıraktı").
CREATE TABLE IF NOT EXISTS olaylar (
  seq        INTEGER PRIMARY KEY AUTOINCREMENT,  -- sunucu tarafı sıra
  oturum     TEXT NOT NULL,                      -- kalıcı olmayan oturum numarası
  ad         TEXT NOT NULL,                      -- bolum_basladi | olum | bolum_bitti | bolum_birakildi
  bolum      TEXT,                               -- bölüm kimliği
  t          INTEGER NOT NULL,                   -- istemci saati (referans)
  server_ts  INTEGER NOT NULL,                   -- sunucu saati (otorite)
  surum      TEXT NOT NULL,                      -- oyun sürümü
  demo       INTEGER NOT NULL DEFAULT 0,         -- 0/1
  sure       REAL,                               -- bölüm başından beri saniye
  x          REAL,                               -- ölüm/bırakma konumu (0.5 birime yuvarlı)
  y          REAL,
  z          REAL,
  toplanan   INTEGER,
  olum       INTEGER,
  yenilen    INTEGER
);

-- "Bu bölümde nerede ölünüyor?" sorgusu: ad + bolum üzerinden gruplama.
CREATE INDEX IF NOT EXISTS idx_ad_bolum ON olaylar(ad, bolum);
-- Huni ve zaman aralığı sorguları.
CREATE INDEX IF NOT EXISTS idx_server_ts ON olaylar(server_ts);
-- Bir oturumun akışını sırayla okumak için.
CREATE INDEX IF NOT EXISTS idx_oturum ON olaylar(oturum, seq);
