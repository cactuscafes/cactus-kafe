# Projeler / Bölüm Haritası

Bu repo (`cactuscafes/cactus-kafe`) tek bir Git deposu ama içinde **birden çok
bağımsız iş** duruyor. Bu dosya "hangi bölüm nerede" sorusunun cevabıdır —
Claude Code'da bir bölüm üzerinde çalışırken sadece o klasöre bakmak yeter.

> **Yayın:** `main` dalına push → GitHub Pages `cactuscafes.com` olarak yayınlar
> (`.github/workflows/pages.yml`, repo kökü servis edilir). Ayrıca aynı push
> Cloudflare Worker'ı da dağıtır (`.github/workflows/deploy.yml` → `src/`).
> **Kökteki her dosya/klasör canlı siteye çıkar** — buraya ilgisiz proje koyma.

---

## Bu repodaki bölümler

### 🎮 Oyunlar — `oyunlar/`

`cactuscafes.com/oyunlar/`

| Dosya | Oyun |
|---|---|
| `oyunlar/index.html` | Oyun listesi (giriş sayfası) |
| `oyunlar/jump.html` | Cactus Jump |
| `oyunlar/hafiza.html` | Cactus Hafıza (kart eşleştirme) |
| `oyunlar/merdiven.html` | Kahve Merdiveni |
| `oyunlar/basket.html` | Cactus Basket |
| `oyunlar/odul.js` | Ödül kaydı — skor eşiğini geçince sadakat kartına ödül yazar |

- Klasör kendi içinde kapalıdır; kök varlıklara `../` ile bağlanır
  (`../favicon.svg`, `../logo-trans.png`, `../manifest-site.json`).
- Ödüller `cactus-rapor-api` üzerindeki `/kart/oyun-odul*` uçlarına yazılır;
  kasada `admin.html` → **Oyun Ödülleri** ve `adisyon.html` içinden kullanılır.
  Bu uç adları API sözleşmesidir — oyun dosyaları taşınsa da değişmez.
- Siteden giriş: `index.html`, `menu-podyum.html`, `kart.html`, `iletisim.html`
  üstündeki **🎮 Oyun** bağlantısı → `oyunlar/`.
- Kökteki `oyunlar.html`, `oyun.html`, `oyun-hafiza.html`, `oyun-merdiven.html`,
  `oyun-basket.html` artık **sadece yönlendirme kabuğu** (eski paylaşımlar ve
  yer imleri için). İçlerinde oyun kodu yok; trafik kalmadığına emin olunca
  silinebilir.

### 🧾 Yeni Adisyon karşılama — `yeniadisyon/`

`cactuscafes.com/yeniadisyon`

| Dosya | İş |
|---|---|
| `yeniadisyon/index.html` | Personel karşılama — yeni adisyon sistemine giriş |
| `yeniadisyon/kurulum/index.html` | Cihaz kurulumu (Ana Ekrana Ekle adımları) |

- Klasör tamamen kapalıdır: sadece kök varlıklara mutlak yolla bağlanır
  (`/favicon.svg`, `/logo-light.png`) ve `cactus-adisyon.batuhanbulut.workers.dev`
  worker'ına gider. Bu repodaki başka hiçbir sayfa buraya bağlanmaz.

### ☕ Ana site (cactuscafes.com)

`index.html` · `menu.html` · `menu-podyum.html` · `menu-baski.html` ·
`qr-menu.html` · `iletisim.html` · `kart.html` (sadakat kartı) ·
`kampanya-poster.html` · `og-image.html` · `gizlilik.html`
Veri/yardımcı: `menu-data.json` · `menu-i18n.js` · `site-ayarlar.js` ·
`style.css` · `manifest-site.json` · `sw.js` · `_headers` · `CNAME`

### 🖥 Adisyon & yönetim (POS)

`adisyon.html` (Podyumpark) · `adisyon-fsm.html` (FSM) · `adisyon-app.html` ·
`admin.html` · `rapor.html` · `rapor-hook-podyum.js` · `rapor-hook-fsm.js` ·
`adisyon-menu.json` · `manifest.json` · `manifest-fsm.json`
Kullanım rehberi: [`YONETIM.md`](YONETIM.md) — mimari: [`ONBOARDING.md`](ONBOARDING.md)

### ⚙️ Worker (API)

`src/index.js` (API) · `src/cron.js` (vardiya zamanlayıcı) ·
`wrangler.toml` · `wrangler-cron.toml` · `schema-adisyon-events.sql` ·
`.assetsignore`

### 📱 Uygulamalar ve kurulum sayfaları

| Yol | İş |
|---|---|
| `app/` | Cactus Coffee iOS uygulaması (Xcode projesi, GitHub Actions ile derlenir) |
| `kur-fad12bdb/` | Adisyon APK / iOS kurulum sayfası (gizli adres) |
| `ios-kayit/` | iPhone cihaz kaydı |
| `hooplegend/` | Hoop Legend oyunu (ayrı PWA + APK, kendi `sw.js`'i var) |
| `besharf/gizlilik/` | Beş Harf gizlilik politikası |
| `kahvemerdiveni/gizlilik/` | Kahve Merdiveni gizlilik politikası |
| `cactus-jump-gizlilik.html` | Cactus Jump (iOS) gizlilik politikası |
| `hoopcoach-privacy.html`, `hoopcoach-support.html` | Hoop Coach mağaza sayfaları |

### 🔧 Diğer

`jsqr.js` · `qrcode-gen.js` · `qr-*.svg/png` (QR üretimi) ·
`trendyol-podyum-sync.md` (Trendyol Go menü eşitleme talimatı) · `Arşiv.zip`

---

## Bu repoda **olmayan** projeler

Aşağıdakiler ayrı işler; kodları bu depoda değil ve buraya konmamalı —
kök klasördeki her şey `cactuscafes.com` altında yayınlandığı için başka
alan adına ait kod burada durursa yanlış adreste canlıya çıkar.

### vivaldimenu.com

- **Kaynak:** `~/Desktop/vivaldi-site` (yalnızca yerel disk — GitHub'a hiç
  gönderilmemiş, `cactuscafes` hesabında karşılığı yok).
- **İlişkili repo:** [`cactuscafes/vivaldi-adisyon-app`](https://github.com/cactuscafes/vivaldi-adisyon-app)
  — `vivaldi-site/adisyon.html`'i Android/iOS'a saran Capacitor kabuğu.
  Web arayüzünün derlenmiş bir kopyası orada `www/` altında duruyor
  (`npm run sync` ile `vivaldi-site`'tan tazeleniyor).
- **API:** uygulama her zaman `https://vivaldimenu.com` adresine gider.
- Kendi Claude Code projesi olarak açmak için `vivaldi-site` bir GitHub
  reposuna push edilmeli; şu an ortada tek başına duran kaynak yok.

### vivaldiprofessional.com

- **Kaynak:** `~/Desktop/vivaldi-profesyonel` (yalnızca yerel disk).
  `.claude/launch.json` içinde `npx wrangler dev --port 4520` ile açılan bir
  Cloudflare Worker projesi olarak tanımlı.
- GitHub'da **hiçbir** karşılığı yok; bu repoda da tek satır referansı yok.
- Kendi projesi olarak açmak için önce bir repoya push edilmesi gerekiyor.

> Her ikisi de ayrı repo olduğunda Claude Code'da `cactus-kafe`'den bağımsız
> birer proje olarak görünür.
