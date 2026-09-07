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
