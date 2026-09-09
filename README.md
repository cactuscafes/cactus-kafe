# D1 yedekleri — cactus-adisyon-events

Bu dal **otomatik** doldurulur (`.github/workflows/d1-yedek.yml`, her gün 03:00).
Elle commit atma; buraya atılan şey bir sonraki budamada silinebilir.

Saklama: son 30 gün bire bir, öncesinde her ayın 1'i (24 ay).

## İki dosya biçimi

| Dosya | İçerik | Ne zaman üretilir |
|---|---|---|
| `yedek/cactus-adisyon-events-<tarih>.sql.gz` | Tam dump: şema + veri | Token'da `D1 · Edit` izni varsa |
| `yedek/cactus-adisyon-events-<tarih>.ndjson.gz` | Yalnız veri, satır başına bir event | İzin yokken (worker API'si üzerinden) |

NDJSON yedeklerde şema yok — o, ana daldaki `schema-adisyon-events.sql` dosyasında.
`.sql.gz` görmek istiyorsan tokene izni ekle: dash.cloudflare.com/profile/api-tokens
→ token → Permissions → **Account · D1 · Edit**. Akış kendiliğinden o yola döner.

## Bakmak

```bash
git fetch origin d1-yedek && git checkout d1-yedek
gunzip -c yedek/cactus-adisyon-events-2026-01-01.ndjson.gz | head -3 | jq .
gunzip -c yedek/cactus-adisyon-events-2026-01-01.ndjson.gz | wc -l    # event sayısı
```

## Geri yükleme

**Önce dene:** son 30 gün içindeki bir kaza için Cloudflare Time Travel daha
hızlı ve kayıpsız — yedek dosyasına hiç gerek yok:

```bash
npx wrangler d1 time-travel info cactus-adisyon-events
npx wrangler d1 time-travel restore cactus-adisyon-events --timestamp <unix-ts>
```

**SQL yedekten** (30 günü aşan geçmiş ya da veritabanının tümden kaybı):

```bash
gunzip -k yedek/cactus-adisyon-events-2026-01-01.sql.gz
# Güvenli yol — önce yeni bir veritabanına yükleyip içeriğe bak:
npx wrangler d1 create cactus-adisyon-events-geri-yukleme
npx wrangler d1 execute cactus-adisyon-events-geri-yukleme --remote --file yedek/cactus-adisyon-events-2026-01-01.sql
```

**NDJSON yedekten** — önce şemayı kur, sonra satırları INSERT'e çevir.
Çevirici ana dalda: `.github/scripts/ndjson-to-sql.py`

```bash
npx wrangler d1 execute cactus-adisyon-events --remote --file schema-adisyon-events.sql
gunzip -c yedek/cactus-adisyon-events-2026-01-01.ndjson.gz \
  | python3 .github/scripts/ndjson-to-sql.py > geri.sql
npx wrangler d1 execute cactus-adisyon-events --remote --file geri.sql
```

`INSERT OR IGNORE` sayesinde mevcut kayıtlar korunur, yalnız eksikler eklenir
(`id` sütunu UNIQUE) — komutu iki kez çalıştırmak kayıt çoğaltmaz.
`seq` yeniden üretilir (AUTOINCREMENT); sıralama `server_ts` ile korunur.
Canlı veritabanına dokunmadan önce mutlaka o anın yedeğini al.
