# Tasarım MCP Kurulumu — Stitch + Nano Banana + 21st.dev

Bu doküman `cactuscafes.com` sitesini üç MCP sunucusuyla adım adım güzelleştirmek için
hazırlandı. Config dosyası repoda: **`.mcp.json`**. Anahtarlar: **`.env`** (git'e girmez).

> Sitenin **tasarım sistemi** (token katmanları, erişilebilirlik kuralları, doğrulama
> yöntemi) ayrı dosyada: [`TASARIM-SISTEMI.md`](TASARIM-SISTEMI.md). Üretilen tasarımı
> koda çevirirken oradaki token'ları kullan.

---

## 1. Üç araç, üç ayrı iş

Bunlar birbirinin alternatifi değil — bir hattın üç halkası. Karıştırırsan zaman kaybedersin.

| Araç | Ne yapar | Çıktısı | Bu sitede kullanım |
|---|---|---|---|
| **Google Stitch** | Metin promptundan **tam sayfa düzeni** üretir | Ekran + HTML/CSS | Sayfanın iskeletini/kompozisyonunu yeniden kurmak |
| **21st.dev (21st MCP)** | 10.000+ React/Tailwind bileşen katalogu + AI bileşen üretimi | Bileşen kodu | Tek tek parça fikri: nav, kart, galeri, footer |
| **Nano Banana** | Gemini 3 Pro Image ile **görsel** üretir/düzenler | PNG/JPG | Hero fotoğrafı, OG görseli, doku, ürün çekimi rötuşu |

Kısaca: **Stitch = düzen, 21st = parça, Nano Banana = piksel.**

---

## 2. Kurulum

### 2.1 Anahtarlar

```bash
cp .env.example .env
```

`.env` içine doldur:

- `GEMINI_API_KEY` → https://aistudio.google.com/apikey
  Anahtar ücretsiz ama **görsel üretimi ücretli katman ister** (pay-as-you-go).
- `API_KEY_21ST` → https://21st.dev/mcp
  Not: eski Magic konsolundan alınan anahtarlar sıfırlandı, yenisini buradan üret.
- Stitch → anahtar gerekmez, OAuth ile (aşağıda).

Claude Code'u anahtarlar ortamda olacak şekilde başlat:

```bash
set -a && source .env && set +a && claude
```

### 2.2 Stitch — iki auth yolu

Proxy anahtarsız çalışmaz. Ölçülen hata:

```
✖ Proxy server error: StitchProxy requires an API key (STITCH_API_KEY)
  or access token (STITCH_ACCESS_TOKEN)
```

**Yol A — API anahtarı (basit).** `.env`'de `STITCH_API_KEY` doldur, bitti.
Paylaşılan/commit'lenmiş config için bu yol daha öngörülebilir.

**Yol B — OAuth (gcloud).**

```bash
npx @_davideast/stitch-mcp init      # gcloud kurulumu + OAuth + client config
npx @_davideast/stitch-mcp doctor    # kontrol listesi
```

`doctor` şunları sırayla denetler — hepsi ✓ olmalı:

```
- Google Cloud CLI          - kullanıcı kimlik doğrulaması
- application credentials   - ADC quota project
- aktif proje
```

Sistemde zaten gcloud varsa `.env`'de `STITCH_USE_SYSTEM_GCLOUD=1` yap; ayrı bir
gcloud kurulumu indirmesin.

> **Dikkat:** `init`'in `-c/--client` seçeneği **kendi MCP config'ini yazar**.
> Bu repoda zaten commit'li bir `.mcp.json` var. İkisi birden olursa iki ayrı
> `stitch` sunucusu tanımlanmış olur. `init`'i çalıştırırken client yapılandırmasını
> atla, ya da `.mcp.json`'daki `stitch` girdisini sil — ikisinden biri.

Google Cloud projende **faturalandırma açık** ve `stitch.googleapis.com` etkin
olmalı; "Permission Denied" alırsan sebep neredeyse her zaman budur.

### 2.3 Doğrulama

```bash
claude mcp list
```

Üçü de `connected` görünmeli.

**Anahtar boşsa sunucu hiç başlamaz** — "bağlanır ama işlev vermez" değil. Ölçülen
hatalar:

| Sunucu | Anahtar boşken |
|---|---|
| `nano-banana` | `GEMINI_API_KEY environment variable is required` |
| `stitch` | `StitchProxy requires an API key … or access token` |
| `21st` | yetkilendirme ister (OAuth / API key) |

Yani `claude mcp list`'te `failed` görüyorsan ilk bakılacak yer `.env`. Projedeki `.mcp.json`'ı Claude Code ilk açılışta
onaylamanı ister — kabul et.

### 2.4 Alternatif: 21st'i plugin olarak kurmak

```bash
claude plugin marketplace add 21st-dev/magic-mcp
/plugin install 21st
```

`.mcp.json` yerine bunu tercih edersen `21st` bloğunu config'ten çıkar, çift kurulum olmasın.

---

## 3. Bu repoya özel — okumadan başlama

Kurulumdan sonra insanların takıldığı yer burası:

1. **Bu site vanilla HTML.** 25 kök HTML dosyası, CSS'in tamamı `<style>` içinde inline,
   build adımı yok, React yok, Tailwind yok.
   Ortak token katmanları: `tipografi.css`, `renkler.css`, `bosluk.css` — üçü de
   yalnızca `:root` değişkeni içerir. Yeni kod bunları kullanmalı; ham hex veya
   rastgele punto yazma. Ayrıntı: [`TASARIM-SISTEMI.md`](TASARIM-SISTEMI.md).
2. **21st.dev React + Tailwind üretir.** Çıktısını olduğu gibi yapıştıramazsın.
   Doğru kullanım: 21st'i **referans** olarak al, kodu bu sitenin CSS diline çevir.
   Bunu bana yaptır — "şu bileşeni al, `renkler.css`/`tipografi.css` token'larıyla
   vanilla CSS'e çevir" de.
3. **Stitch çıktısı da yabancı bir HTML/CSS'tir.** `build_site` ile aldığın kodu doğrudan
   `index.html` üzerine yazma; kompozisyon kararlarını (boşluk ritmi, tipografi ölçeği,
   grid) alıp mevcut markup'a uygula.
4. **Fontlar sabit:** `Fraunces` (serif, başlıklar) + `Inter` (gövde). Üretilen tasarım
   başka font öneriyorsa ya reddet ya da bilinçli karar ver — marka kimliği bu ikisi.
5. **Ağır sayfalara dokunma:** `admin.html`, `adisyon.html`, `adisyon-fsm.html` (250-330 KB)
   POS/yönetim ekranları. Bunlar operasyon kritik; güzelleştirme işi **vitrin sayfalarında**.

---

## 4. Çalışma akışı (altı adım)

Sayfa başına tek tur. Sıra önemli — tersten gidersen görsel ürettiğin şey düzene oturmaz.

### Adım 1 — Baseline al
Değiştirmeden önce mevcut halin ekran görüntüsü + Lighthouse skoru. Kıyas yoksa
"güzelleşti mi" sorusu tartışmaya döner.

### Adım 2 — Stitch'te düzeni kur
Stitch'te proje aç, sayfanın yeni kompozisyonunu üret. Sonra buradan:

```
stitch build_site ile <projectId> içindeki ekranları çek,
"/" → ana sayfa olacak şekilde. Kodu bana ver, uygulamadan önce
mevcut index.html ile farkını anlat.
```

Araçlar: `build_site`, `get_screen_code`, `get_screen_image`.
Terminalden gözatmak için: `npx @_davideast/stitch-mcp view --projects`

### Adım 3 — 21st ile parçaları seç
Düzen oturunca boşlukları bileşenle doldur:

```
21st search ile "sticky navbar with scroll blur" ara, 3 alternatif göster.
Sonra seçtiğimi style.css token'larıyla vanilla CSS'e çevir.
```

Araçlar: `search`, `get_component`, `generate`, `iterate_generation`, `get_inspiration`, `search_logo`.
(`generate` sadece hesabında AI erişimi açıksa listelenir.)

### Adım 4 — Nano Banana ile görselleri üret
Metin ve düzen yerindeyken görsel üret — tersi değil, çünkü kadraj düzene bağlı.

```
nano-banana generate_image:
  prompt: "Bursa Nilüfer'de bir specialty kahve dükkanı, gün ışığı,
           ahşap tezgah, sıcak toprak tonları, sinematik, insan yok"
  aspectRatio: "16:9"
  imageSize: "2K"
  outputPath: "foto-hero-podyum2-yeni.jpg"
```

Araçlar: `generate_image`, `edit_image`, `describe_image`.
Modeller: `gemini-3-pro-image-preview` (Pro, varsayılan), `gemini-2.5-flash-preview-05-20` (hızlı).
En oran: `1:1, 3:4, 4:3, 9:16, 16:9`. Boyut: `1K/2K/4K`.

Mevcut fotoğrafı sıfırdan üretmek yerine **düzeltmek** çoğu zaman daha iyi:
`edit_image` ile "arka plandaki dağınıklığı temizle, ışığı dengele" gibi.

### Adım 5 — Uygula ve ölç
Değişikliği uygula, sonra kontrol et:

- Mobil 360px'te yatay kaydırma var mı
- Hero LCP görseli hâlâ `preload` ediliyor mu (`index.html` içinde iki `<link rel="preload">` var — masaüstü/mobil ayrı)
- `sw.js` içindeki `VERSION` artırıldı mı (şu an `cactus-v76`), yoksa kullanıcı eski sayfayı görür
- Lighthouse skoru baseline'ın altına düştü mü

### Adım 6 — Yayınla
`main`'e push → Cloudflare Pages otomatik deploy (~1-2 dk).

---

## 5. Sayfa sayfa durum

Temel geçiş (erişilebilirlik, düzen hataları, token katmanları) **yapıldı**:

| Alan | Durum |
|---|---|
| Kontrast (WCAG AA) | Ölçülen tüm açık sayfalarda gerçek AA-altı **yok** |
| Ölü grid sütunları | `index.html`'de üç yerde düzeltildi |
| Hero ağırlığı | 474 KB → **148 KB** (AVIF), mobil 278 → 89 KB |
| Navigasyon emojisi | Krom emojiler temizlendi (oyun/illüstrasyon/veri korundu) |
| Tipografi ölçeği | 9 sayfada uygulandı; taban 11px, izleme em |
| Renk paleti | `renkler.css`; 178 ham hex token'a çevrildi |
| Boşluk ölçeği | `bosluk.css`; nav altı boşluk ölçülen nav yüksekliğine bağlandı |

**Tasarım turları bundan sonra başlıyor** — yukarıdakiler hijyen, asıl kompozisyon
işi değil. MCP araçlarıyla yapılacaklar:

| Sayfa | Ne | Hangi araç |
|---|---|---|
| `menu-podyum.html` | Kategori navigasyonu + ürün kartı; ürün görselleri eksik | 21st + Nano Banana |
| `kart.html` | Damga grid'i görsel dil olarak zayıf | Stitch |
| `oyunlar.html` + `oyun-*.html` | Ortak bir oyun-hub kimliği yok | Stitch |
| `iletisim.html` | Harita/saat/şube kartı düzeni | 21st |
| `og-image.html` → `og-image.jpg` | Yeniden üret, 1200×630 | Nano Banana |


---

## 6. Tasarım brief'i ve prompt'lar

### 6.1 Marka brief'i — Stitch'e her seferinde bunu ver

Bu blok sitenin gerçek token değerlerinden yazıldı. Olduğu gibi yapıştır; çıktı
zaten `renkler.css` / `tipografi.css` diline yakın gelir, çeviri mekanik kalır.

```
MARKA: Cactus Coffee — Bursa Nilüfer, Podyumpark. Kahve, snack & tatlı.
TON: Editoryal ve sakin. Bol beyaz alan, büyük tipografi, az sayıda öge.
     Kalabalık değil; her bölüm tek bir şey söylesin.

RENK (bunlar sabit, değiştirme):
  Altın #c8a86a   — DEKORATİF: çizgi, kenarlık, koyu zeminde metin
  Altın #8a6b2f   — açık zeminde METİN ve BUTON (beyazda 4.97:1)
  Mürekkep #1a1a1a · Kâğıt #f8f6f2 · Latte #f0ece4
  Yeşil ailesi: espresso #0b1a07 · coffee #1a3310 · mocha #2c4a1e

  KURAL: açık zeminde altın metin/buton İÇİN #8a6b2f kullan.
  #c8a86a beyazda 2.3:1 — WCAG AA'yı geçmez, sadece dekoratif.

TİPOGRAFİ (sabit):
  Başlık: Fraunces (serif), weight 300, italik vurgu için <em>
  Gövde:  Inter, weight 300-400
  Ölçek:  11 / 13 / 15 / 17 / 21px, başlık clamp(32px,4vw,52px), hero clamp(56px,8vw,110px)
  TABAN 11px — bunun altında metin YOK, buton metni en az 12px.
  Büyük harf etiketlerde izleme em cinsinden, en fazla 0.28em.
  Gövde satır yüksekliği 1.75.

BOŞLUK:
  Bölüm dolgusu clamp(72px,9vw,120px), kenar boşluğu clamp(20px,5vw,60px)
  Sabit nav var; ilk içerik nav yüksekliği (76px) + nefes kadar aşağıdan başlar.

TEKNİK KISIT:
  Çıktı vanilla HTML/CSS'e çevrilecek. React yok, Tailwind yok, build yok.
  Grid'lerde sabit sütun sayısı verme; auto-fit kullan (kart sayısı değişiyor).
  Mobil öncelikli; 360px'te yatay kaydırma olmayacak.
```

### 6.2 Stitch — tam sayfa

Yukarıdaki brief'i yapıştır, sonra:

```
Bu markanın <sayfa adı> sayfasını tasarla.
Bölümler: <...>
Her bölüm için kompozisyon kararını gerekçesiyle söyle (neden bu hiyerarşi,
neden bu boşluk). Kodu sonra isteyeceğim.
```

Sonra koda geçerken:

```
stitch build_site ile <projectId> içindeki ekranları çek.
Kodu bana ver ama UYGULAMA — önce mevcut sayfayla farkını anlat.
```

### 6.3 21st — bileşen

```
21st search: "<bileşen tarifi>"
3 alternatif göster. Seçtiğimi vanilla HTML/CSS'e çevir:
Tailwind class'ı olmasın, renkler var(--c-altin-ink) gibi token olsun,
puntolar var(--t-body) gibi token olsun.
```

### 6.4 Nano Banana — görsel

```
generate_image, aspectRatio 16:9, imageSize 2K:
"Bursa'da bir specialty kahve dükkanı, doğal gün ışığı, açık ahşap tezgah,
sıcak nötr palet, sığ alan derinliği, sinematik, insan yok, otantik kadraj —
stok fotoğraf hissi olmasın"
```

Marka tutarlılığı için `images` parametresiyle mevcut `foto-hero-podyum2.jpg`'yi
referans ver. Önce `gemini-2.5-flash-preview-05-20` ile taslak çıkar, beğendiğini
`gemini-3-pro-image-preview` ile yeniden üret — Pro görsel başına ~$0.13.

**Fotoğraf üstüne metin gelecekse:** hero'da öğrenildi — global karartma yerine
metin bloğunun arkasına odaklı bir perde koy, fotoğrafın kenarları aydınlık kalsın.


## 7. Kalite kapıları

Her turdan sonra bunları geçmeden yayına alma:

- [ ] 360px genişlikte yatay kaydırma yok
- [ ] Hero LCP < 2.5s (preload link'leri `type="image/avif"` ile yerinde)
- [ ] Kontrast **tarayıcıda ölçüldü** — kaynağa bakarak değil; yarı saydam zeminler
      alfa kompozitlendi (bkz. TASARIM-SISTEMI.md §6)
- [ ] Açık zeminde altın metin/buton `--c-altin-ink`, dekoratif olan `--c-altin`
- [ ] Ham hex veya rastgele punto yazılmadı — token kullanıldı
- [ ] 11px altı metin yok (maket/baskı istisnaları hariç, bkz. §4)
- [ ] Fraunces + Inter dışında font yüklenmiyor
- [ ] `sw.js` `VERSION` sabiti artırıldı
- [ ] Üretilen görseller sıkıştırıldı (hero < 250 KB hedef; AVIF tercih)
- [ ] Menü/fiyat verisi `menu-data.json`'dan geliyor, HTML'e gömülmedi

---

## 8. Maliyet

- **Stitch** — beta boyunca ücretsiz (GCP faturalandırması açık olmalı)
- **21st.dev** — ücretsiz katman var, AI üretimi kotalı
- **Nano Banana Pro** — görsel başına ~$0.13 (2K) / ~$0.24 (4K).
  20 görsellik bir tur ≈ $3-5. Önce `flash` modelle taslak çıkar, beğendiğini Pro ile yeniden üret.

---

## 9. Bilinen sınır — Claude Code web oturumu

Bu üç sunucu **yerel Claude Code'da** çalışır. Claude Code'un bulut (web) oturumunda
ağ çıkışı kısıtlı: `21st.dev` ve `stitch.withgoogle.com` egress proxy tarafından
bloklanıyor. Yani tasarım turlarını kendi makinende çalıştır; bulut oturumunu
kod düzenleme, inceleme ve deploy için kullan.
