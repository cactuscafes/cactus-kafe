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
- `index.html`, `menu-podyum.html` (asıl menü), `menu.html` (yönlendirme), `kart.html` (sadakat kartı), `iletisim.html`
- `src/index.js` + `src/cron.js` — `cactus-kafe` worker'ı (olay günlüğü/bordro/vardiya), bkz. Backend
- `sw.js` (service worker v3), `manifest.json` (Podyum PWA), `manifest-fsm.json` (FSM PWA), `_headers` (cache control)

## Backend
**İki ayrı worker var** — hangi işin hangisinde olduğunu karıştırmamak önemli.

### 1) `cactus-rapor-api.batuhanbulut.workers.dev` — menü, rapor, sadakat, formlar
- **Kaynak:** `~/Desktop/cactus-rapor-api` (bu repoda değil; `npx wrangler deploy` ile yayınlanır)
- `GET /ayar/cek` (public) & `POST /ayar/kaydet` → site ayarları (saatler, kampanya, şerit, puanlar, telefon); sayfalar `site-ayarlar.js` ile uygular, admin "⚙️ Site Ayarları" paneli yönetir. Kullanıcı rehberi: `YONETIM.md`
- `GET /menu/cek?sube=<key>` & `POST /menu/kaydet` `{sube,menu}` → generic KV
  (menü, favoriler, şifre, notlar, webhook, günlük gider için de kullanılıyor)
- `POST /islem/kaydet`, `GET /islem/listele`, `POST /islem/iptal` → satış/ciro
- `POST /auth/login` → yönetim token'ı (`X-Cactus-Key` başlığıyla gönderilir)
- `/rapor/*`, `/kart/*`, `/siparis/hazir`, `/basvuru/*`, `/sikayet/*`, `/ziyaret/*`
- `GET /sync/durum`, `POST /sync/masalar` → **artık masa durumunu sürmüyor** (v9 kalıntısı, aşağıya bak).
  Eski uyarı bilgi olsun diye kalsın: `/sync/durum` yanıtındaki `guncelleme` alanı GLOBAL'dir,
  per-masa değildir — conflict çözümünde kullanılamaz. v11 bu yüzden zaten kullanmıyor.

### 2) `cactus-kafe.batuhanbulut.workers.dev` — olay günlüğü + D1 (kodda `EV_API`)
- **Kaynak BU repoda:** `src/index.js` (+ `src/cron.js`), config `wrangler.toml`.
  Cron ayrı worker: `wrangler-cron.toml` → `cactus-kafe-cron`.
- **D1:** `cactus-adisyon-events` (binding `ADISYON_DB`) — şema `schema-adisyon-events.sql`
- **Service binding `RAPOR` → `cactus-rapor-api`:** yönetim token doğrulaması bunun üzerinden
  yapılıyor; worker içinden aynı hesabın workers.dev adresine düz `fetch` engelli olduğu için şart.
- `POST /api/events` `{events:[...]}` → olay yaz · `GET /api/events?sube=&since=<seq>` → olay çek
- `GET/POST /api/stok`, `POST /api/malzeme-bildir` → stok ve eksik malzeme
- `GET /api/vardiya`, `POST /api/vardiya-giris` (PIN **server-side** doğrulanır), `GET /api/vardiya-gecmis`
- `GET/POST /api/bordro`, `/api/ios/*` (cihaz kaydı), `/api/kart-sil`
- Masa durumunun tek doğru kaynağı burası.
- **Dikkat:** cactuscafes.com GitHub Pages'ten servis ediliyor; bu worker'a yalnızca
  workers.dev üzerinden erişiliyor, custom domain route'ları bilinçli olarak yok.

## Adisyon Sync Mimarisi — Event-Sourced (v11) ← GÜNCEL
Masa durumu artık snapshot senkronuyla değil, **append-only olay günlüğüyle** tutuluyor.
State türetilmiş bir değer: olayların sıralı replay'i.

**Ayrı worker:** `EV_API = https://cactus-kafe.batuhanbulut.workers.dev`
(rapor/menü/sadakat hâlâ `cactus-rapor-api`'de — ikisi farklı worker.)

- **Yazma** (`_pushEvent(type, masa, payload)`): olay `{id, sube, type, masa, payload, ts, cihaz_id}`
  olarak üretilir → `_eventLog` + `_pendingEvents`'e eklenir → `_applyEvent` ile **iyimser**
  uygulanır (arayüz beklemez) → `_evSave()` → 30 ms sonra `_evSync` tetiklenir.
- **Senkron** (`_evSync`): açılışta 100 ms, sonra `setInterval(_evSync, 2000)` — 2 saniyede bir.
  Tek uçuş kilidi `_evSyncInFlight`. Aynı çağrıda hem push hem pull:
  - push: `POST /api/events {events}` — bekleyenlerden **en fazla 100 tanesi**; başarılıysa
    o id'ler `_pendingEvents`'ten düşer (offline'da kuyrukta birikir)
  - pull: `GET /api/events?sube=<sube>&since=<_lastSeq>` — id'ye göre dedupe, `_lastSeq`
    yanıttaki `last_seq` ile ilerler, yeni olay varsa `_rebuildMasalar()` + yeniden çizim
- **Replay** (`_rebuildMasalar`): masalar sıfırlanır, log `server_ts || ts` ile sıralanır
  (eşitlikte `id` ile tie-break), tek tek uygulanır. **Bayat gün koruması:** son 04:00
  sıfırlama noktasından (`_resetNoktasiMs()`) eski olaylar uygulanmaz. Sanity guard: reset
  noktası 0'dan büyük, geçmişte ve 25 saatten yeni değilse filtre hiç uygulanmaz (taze veri korunur).
- **Olay tipleri** (`_applyEvent`): `ITEM_ADD`, `ITEM_SUB`, `ITEM_DEL`, `MASA_CLEAR`, `MASA_PAY`
  (`adisyon.html`'de ayrıca bir `ITEM_GONDER` dalı var ama hiç üretilmiyor — bkz. Bilinen durum)
- **Masa dışı olaylar** (`masa: null`): `checklist` istemciden `_pushEvent` ile;
  `vardiya` ise **sunucuda** üretilir — `POST /api/vardiya-giris` PIN'i server-side doğrular,
  olay istemciye pull ile gelir. Yani log'a tek yazan istemci değil.
- **localStorage:** `cactus_evlog_<sube>` (son **2000** olay), `cactus_evpending_<sube>`, `cactus_evseq_<sube>`
- `saveMasalar` artık **yalnızca localStorage yedeği** — push tetiklemez. Yeni state değişikliği
  yapan her yol `_pushEvent`'ten geçmek zorunda.
- **admin.html aynı kaynağı okur:** `_cmApplyEvent`, adisyon'daki reducer'ın kopyasıdır;
  "Bugün" cirosu ve "Canlı Masalar" event log'dan indirgenir (eskiden rapor-api snapshot'ından
  okunuyordu ve Podyum cirosunu eksik gösteriyordu).

### v9 Per-Masa Last-Write-Wins — ÖLÜ KOD (silinmedi, kapatıldı)
`adisyon.html` ve `adisyon-fsm.html` içinde `_doPushMasalar` ve `_masalarSyncCek`
fonksiyonlarının **ilk satırı koşulsuz `return`** (`// v11: event-sourced sync devrede`).
Gövdeleri hâlâ dosyada duruyor ama hiç çalışmıyor. Aynı şekilde `_mv`, `_effVer`,
`_itemMerge`, `_masaKazanan`, `_tombstone` da atıl. `/sync/durum` ve `/sync/masalar`
artık masa durumunu **sürmüyor**.

Neden vardı (tasarım geçmişi): ondan önceki item-level CRDT "bu masa ödendiği için boş"
durumunu ifade edemiyordu — masalar kayboluyor, ödenen masalar geri açılıyordu. v9 bunu
per-masa versiyonla çözdü; v11 ise sorunu tümden ortadan kaldırdı, çünkü ödeme de
silme de artık birer olay.

## localStorage durumu
- **Olay günlüğü (cihazlar arası, `/api/events`):** `cactus_evlog_<sube>`, `cactus_evpending_<sube>`,
  `cactus_evseq_<sube>` — masa durumunun gerçek kaynağı. `cactus_masalar` yalnızca türetilmiş yedek.
- **Cloud-sync (generic KV, `/menu/cek`+`/menu/kaydet`):** menü, favoriler, **şifre**,
  sipariş notları (`cactus_notlar`), webhook URL, admin rapor e-posta, günlük gider (`harcama_<sube>_<tarih>`)
- **Kasıtlı lokal:** `cactus_gh_token` (güvenlik), `cactus_kart_tel` (KVKK), `cactus_music`, admin local cache (`cactus_admin_menu/kat/oncu`), `cv_*`/`cactus_gece_sifir`/`cactus_masalar_cycle` (marker)
- **Atıl:** `cactus_masalar_mv` / `cactus_masa_mv_<sube>` — v9 kalıntısı, artık yazılmıyor

## Bilinen durum / bekleyen işler
- `ITEM_GONDER` yalnızca `adisyon.html`'in reducer'ında bir `case` olarak duruyor; hiçbir yerde
  üretilmiyor, FSM reducer'ında hiç yok. Ölü dal.
- `ITEM_GONDER` dışında bilinen ölü kod kalmadı; `_iskonto` kalıntısı temizlendi
  (aşağıdaki "Tamamlananlar"a bak).
- Server'da eski bug'dan kalma stale masalar olabilir → gece 04:00 cron temizler veya **Yönet > 🌙 Gün Sonu** ile elle
- Eski duplicate ciro kayıtları server'da duruyor; ciro hesabı `_islemDeduplica` ile bunları saymıyor (gösterimde temiz)
- **WhatsApp gece raporu (CallMeBot) KURULMADI** — kullanıcının CallMeBot apikey vermesi bekleniyor (telefon: 905380146600)

### Tamamlananlar (eski "bekleyen" kayıtları)
- ✅ Kişi başı bölme yapıldı: "Ödeme Al"da **👥 Kişi** seçeneği var (`odemeSecim('kisi')`,
  `kisiSay`/`kisiGuncelle`, en az 2 kişi). Ödeme tipleri: Nakit / Kart / Böl / Kişi.
- ✅ Masa aktarımı tek yola indirildi: **`_masaTransferEt(kaynak, hedef)`** (her iki adisyon
  dosyasında, `transferYap`'ın hemen üstünde). `transferYap`, `masaAktar` ve `masaTasi` artık
  yalnızca girdi toplayıp bu fonksiyonu çağıran ince sarmalayıcılar.
  **Yeni bir aktarım girişi eklenecekse yine buradan geçmeli** — doğrudan `masalar` mutasyonu
  `_rebuildMasalar` replay'inde geri alınır.
  - `masaAktar` (Yönet paneli) olay üretmiyordu → aktarımlar geri alınıyor, diğer cihazlara gitmiyordu.
  - `masaTasi` ("↔ Taşı" butonu, **her iki dosyada**) `window.aktifMasa` okuyordu; `aktifMasa`
    `let` ile tanımlı olduğu için window'a hiç bağlanmaz → fonksiyon her çağrıda erken dönüyordu.
    Buton bugüne kadar hiçbir şey yapmıyordu, artık çalışıyor.

## Graphify (bilgi grafiği)
Repoyu grep'lemek yerine sorgulanabilir bir grafiğe çeviren `/graphify` skill'i kurulu:
`.claude/skills/graphify/` (proje kapsamında — repoyu klonlayan herkeste çalışır).

**CLI kurulumu (her makinede bir kez):** `pip install graphifyy` (macOS'ta gerekirse `pipx install graphifyy`).
Paket adı `graphifyy`, komut `graphify`. Python 3.10+ ister.

**Kullanım:**
- `/graphify .` — Claude Code içinden tam tarama (HTML/MD dahil; kavram çıkarımını asistan yapar)
- `graphify update .` — kod değişince artımlı tazeleme, LLM/API maliyeti yok
- `graphify query "soru"` · `graphify path "A" "B"` · `graphify explain "X"` · `graphify god-nodes`
- `graphify hook install` — post-commit hook, grafiği commit sonrası günceller (lokal, commit'lenmez)

**Bu repoda bilinmesi gerekenler:**
- `.html` graphify'da *doc* sayılır → AST ile değil, LLM kavram çıkarımıyla işlenir. Yani
  `--code-only` çalıştırırsan `admin.html`, `adisyon*.html`, `index.html`, `menu-podyum.html`,
  `kart.html` grafiğe **girmez** — projenin asıl mantığı bu dosyalarda olduğu için tam tarama
  (`/graphify .`) daha değerli.
- Şu an commit'li grafik yok: `graphify-out/` .gitignore'da (yeniden üretilebilir, ~2.6 MB).
- `.graphifyignore` vendor dosyaları (`jsqr.js`, `qrcode-gen.js`) ve medyayı eler.
- `.sql` şeması için ek gerekir: `pip install "graphifyy[sql]"` (yoksa `schema-adisyon-events.sql` atlanır).

## İskonto nasıl çalışıyor (sorulmadan cevap)
Kalıcı bir "masa iskontosu" **yok** — iskonto ödeme oturumuna ait:
- Değer `#iskonto-tl` DOM input'unda durur; `_iskontoHesapla()` bunu `_secKalemler` ile birlikte okur.
- `odemeAl()` ödeme modalı her açıldığında input'u temizler (`// İskonto sıfırla`) — her iki dosyada.
- Ödeme modalı `.moverlay` ile tam ekran engelleyici katman (`inset:0; z-index:500`), yani modal
  açıkken masa aktarımı tıklanamaz.

Sonuç: iskonto masadan masaya sızamaz, masa aktarımında ayrıca sıfırlamaya gerek yok.
(Bu not, "aktarımda iskonto sıfırlansın mı?" sorusu tekrar gündeme gelmesin diye burada.)

`adisyon.html`'in patch katmanında eskiden ikinci bir `_iskonto` değişkeni ve onu adisyon
panelinde gösteren bir `renderAdisyon` wrapper'ı vardı; değişkene `0`'dan başka değer hiç
atanmadığı için gösterim hiç çalışmadı ve içindeki `hesaplaToplamHam()` bu dosyada hiç
tanımlı değildi. İkisi de kaldırıldı — panelde iskonto satırı göstermek gerekirse
`_iskontoHesapla()` üzerinden yeniden yazılmalı, eski wrapper geri getirilmemeli.

## Test
- Preview config: `.claude/launch.json` → ad `cactus-main`, port 4203, ana dizini serve eder
- `preview_start` ile başlat, `preview_eval` ile gerçek server'a karşı test
- Çift tıklama koruması: `odemeOnayla` içinde `_odemeIslemde` flag (1.5sn)
- İşlem ID'si dedupe: `SUBE-masa-toplam-floor(now/10000)` (10sn pencerede aynı içerik tek kayıt)

## Sync mimarisinin sürüm geçmişi
> Bu liste elle tutuluyor ve eskiyebilir — güncel hâli için `git log --oneline`.

- **v11 — event-sourced** (güncel): masa durumu `/api/events` olay günlüğünden replay ile türetiliyor.
- **v9 — per-masa LWW**: `_doPushMasalar`/`_masalarSyncCek` ile snapshot senkronu. Kod dosyada
  duruyor ama **kapalı**. Zamanında "en kritik" değişiklikti; v11 bunu devraldı.
- **v9 öncesi — item-level CRDT**: kaldırıldı. "Bu masa ödendiği için boş" durumunu ifade
  edemiyordu → masalar kayboluyor, ödenen masalar geri açılıyordu.

Diğer kalıcı düzeltmeler: ciro duplicate dedupe (`_islemDeduplica`), ödeme çift tıklama
koruması (`_odemeIslemde`), notlar/webhook/admin e-posta cloud sync, Yönet/Raporlar şifresi
cloud sync, ana sayfa performans optimizasyonu.
