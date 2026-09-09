# Cactus Kafe — Proje Devir / Onboarding

Bu doküman projeye yeni bir Claude Code sohbetinde devam etmek için hazırlanmıştır.

## Proje
- **Repo:** github.com/cactuscafes/cactus-kafe (branch: `main`)
- **Ana dizin:** `/Users/bulut/Desktop/cactus-site`
- **Yayın:** Cloudflare Pages → cactuscafes.com (push → otomatik deploy, ~1-2 dk)

## Dosyalar
- `adisyon.html` — Podyumpark POS/adisyon (`SUBE='podyum'`)
- `adisyon-fsm.html` — FSM POS/adisyon (`SUBE='fsm'`)
- `admin.html` — yönetim paneli (raporlar, menü, e-posta, WhatsApp test)
- `index.html`, `menu.html`, `kart.html` (sadakat kartı), `iletisim.html`, `galeri.html`
- `sw.js` (service worker v3), `manifest.json` (Podyum PWA), `manifest-fsm.json` (FSM PWA), `_headers` (cache control)

## Backend
- **Worker:** `https://cactus-rapor-api.batuhanbulut.workers.dev`
- **Kaynak:** `~/Desktop/cactus-rapor-api` (bu repoda değil; `npx wrangler deploy` ile yayınlanır)
- `GET /ayar/cek` (public) & `POST /ayar/kaydet` → site ayarları (saatler, kampanya, şerit, puanlar, telefon); sayfalar `site-ayarlar.js` ile uygular, admin "⚙️ Site Ayarları" paneli yönetir. Kullanıcı rehberi: `YONETIM.md`
- Endpointler:
  - `GET /sync/durum?sube=<sube>&since=0` → masalar + siparişler
  - `POST /sync/masalar` `{sube, masalar}` → masalar blob'unu **last-write-wins** saklar
  - `GET /menu/cek?sube=<key>` & `POST /menu/kaydet` `{sube,menu}` → generic KV (menü, favoriler, şifre, notlar, masa-versiyon için de kullanılır)
  - `POST /islem/kaydet`, `GET /islem/listele`, `POST /islem/iptal` → satış/ciro
  - `/rapor/*`, `/siparis/hazir`, `/basvuru/*`, `/sikayet/*`, `/ziyaret/*`
- **Dikkat:** `/sync/durum` yanıtındaki `guncelleme` alanı GLOBAL (per-masa değil) → conflict çözümünde kullanılamaz.

## Yedekleme (D1)
`.github/workflows/d1-yedek.yml` — her gün 03:00. İki yöntemi sırayla dener:

1. **`wrangler d1 export`** → tam SQL dump (şema + veri), `.sql.gz`.
   Token'da **Account · D1 · Edit** izni ister; export bir POST endpoint'i, salt okuma yetmiyor.
   İzin yoksa `Authentication error [code: 10000]` ile düşer.
2. **Worker API'si** → `GET /api/events?sube=&since=&limit=` sayfalanarak taranır, `.ndjson.gz`.
   Token gerektirmez, 1. yol düşünce otomatik devreye girer. Veri-only; şema `schema-adisyon-events.sql`.
   Betik: `.github/scripts/d1-yedek-api.sh` (şube listesi workflow'daki `SUBELER` env'i).

İzin eklenince akış kendiliğinden 1. yola döner — workflow'u değiştirmek gerekmez.

- **Nerede:** deponun orphan `d1-yedek` dalı, `yedek/<db>-<tarih>.{sql,ndjson}.gz`.
  Saklama: son 30 gün bire bir, öncesinde her ayın 1'i (24 ay). Ayrıca 14 günlük artifact.
- **Doğrulama:** boş/bozuk yedek dala YAZILMAZ (SQL'de şema aranır, NDJSON'da zorunlu alanlar).
- **Geri yükleme:** `d1-yedek` dalındaki `README.md`. NDJSON→SQL çevirici:
  `.github/scripts/ndjson-to-sql.py` (INSERT OR IGNORE, tekrar çalıştırmak güvenli).
  Son 30 gün içindeki kazalar için önce Cloudflare Time Travel denenmeli.
- **Elle:** `npm run d1:yedek` (wrangler yolu, D1 izni ister). Çıktı gitignore'da.
- **Kapsam dışı:** menü/ayar/rapor verileri D1'de değil, `cactus-rapor-api` worker'ının
  KV'sinde; onların yedeği bu akışta yok.

## Adisyon Sync Mimarisi — Per-Masa Last-Write-Wins (v9)
Eski item-level CRDT kırılgandı (masalar kayboluyor + ödenen masalar geri açılıyordu). Kökten yeniden yazıldı:
- Her masaya versiyon: `_mv[i]` = son değişiklik ms. localStorage: `cactus_masalar_mv` / cloud key: `cactus_masa_mv_<sube>`
- `effVer(masa) = max(_mv[i], item ts'lerinin en büyüğü)` — mv yokken item ts ile kıyas; boş (ödenmiş) masa için mv belirleyici
- **Push** (`_doPushMasalar`): GET masalar+mv → her masa için yeni versiyon kazanır → merged'i POST + local'i merged ile senkronla
- **Poll** (`_masalarSyncCek`): server versiyonu yeniyse uygula, lokal yeniyse push tetikle
- `saveMasalar`: değişen masaların `_mv`'sini `Date.now()` ile bump eder (diff vs `_sonKayit`)
- Gece 04:00: worker cron + lokal `geceKontrolu` + `_staleGunKontrolu` (cycle değişimi) `_mv`'yi sıfırlar
- `_staleItemFiltrele`: reset noktası (04:00 TR) öncesi item'ları filtreler
- **Kaldırılan eski kod:** `_itemBirlestir`, `_sonPushSnap`, `_masaYerelDegisti`, `_degisenMasalar`, retry/race-window

### Neden iki bug da çözüldü
- **Masa kaybolması:** yeni eklenen masanın effVer'i (item ts=şimdi) server'dan büyük → asla overwrite edilmez
- **Ödenen masa geri açılması:** ödeme masayı boşaltıp versiyonu `şimdi` yapar → stale cihazın eski ts'inden büyük → propagate eder, geri açılmaz

## localStorage durumu
- **Cloud-sync (cihazlar arası):** masalar, masa-versiyon (`_mv`), menü, favoriler, **şifre**, sipariş notları (`cactus_notlar`), webhook URL, admin rapor e-posta
- **Kasıtlı lokal:** `cactus_gh_token` (güvenlik), `cactus_kart_tel` (KVKK), `cactus_music`, admin local cache (`cactus_admin_menu/kat/oncu`), `cv_*`/`cactus_gece_sifir`/`cactus_masalar_cycle` (marker)

## Bilinen durum / bekleyen işler
- Server'da eski bug'dan kalma stale masalar olabilir → gece 04:00 cron temizler veya **Yönet > 🌙 Gün Sonu** ile elle
- Eski duplicate ciro kayıtları server'da duruyor; ciro hesabı `_islemDeduplica` ile bunları saymıyor (gösterimde temiz)
- **WhatsApp gece raporu (CallMeBot) KURULMADI** — kullanıcının CallMeBot apikey vermesi bekleniyor (telefon: 905380146600)
- **Yarım kalan istek:** "Ödeme Al"a hesabı 2/3/4'e bölme (kişi başı eşit bölme) seçeneği eklenecekti — henüz başlanmadı
  - Mevcut ödeme tipleri: Nakit / Kredi Kartı / Böl (nakit+kart tutar bölme). İstenen: kişi sayısına bölme.

## Test
- Preview config: `.claude/launch.json` → ad `cactus-main`, port 4203, ana dizini serve eder
- `preview_start` ile başlat, `preview_eval` ile gerçek server'a karşı test
- Çift tıklama koruması: `odemeOnayla` içinde `_odemeIslemde` flag (1.5sn)
- İşlem ID'si dedupe: `SUBE-masa-toplam-floor(now/10000)` (10sn pencerede aynı içerik tek kayıt)

## Son commitler (en yeni → eski)
- `c420ea5` masa sync per-masa LWW (CRDT kaldırıldı) — **en kritik**
- `9432c4e` ciro duplicate dedupe (gösterimde temiz toplam)
- `d9abca9` ödeme çift tıklama koruması (ciro 2x bug'ı)
- `1e2e56f` notlar + webhook + admin e-posta cloud sync
- `08f3c59` Yönet/Raporlar şifresi cloud sync
- `119317d` anasayfa performans (kasma) optimizasyonu
