# Tasarım MCP Kurulumu — Stitch + Nano Banana + 21st.dev

Bu doküman `cactuscafes.com` sitesini üç MCP sunucusuyla adım adım güzelleştirmek için
hazırlandı. Config dosyası repoda: **`.mcp.json`**. Anahtarlar: **`.env`** (git'e girmez).

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

### 2.2 Stitch (tek seferlik OAuth)

```bash
npx @_davideast/stitch-mcp init      # gcloud + OAuth sihirbazı
npx @_davideast/stitch-mcp doctor    # sağlık kontrolü
```

`init` gcloud kurulumunu, OAuth'u ve MCP client config'ini kendi halleder.
Google Cloud projende **faturalandırma açık** ve `stitch.googleapis.com` etkin olmalı;
"Permission Denied" alırsan sebep neredeyse her zaman budur → `doctor --verbose`.

Zaten gcloud kuruluysa `.mcp.json`'daki `stitch` bloğuna şunu ekle:

```json
"env": { "STITCH_USE_SYSTEM_GCLOUD": "1" }
```

### 2.3 Doğrulama

```bash
claude mcp list
```

Üçü de `connected` görünmeli. Projedeki `.mcp.json`'ı Claude Code ilk açılışta
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
   build adımı yok, React yok, Tailwind yok (`style.css` ortak stiller, `:root` içinde
   `--ink / --paper / --stone / --gold` token'ları).
2. **21st.dev React + Tailwind üretir.** Çıktısını olduğu gibi yapıştıramazsın.
   Doğru kullanım: 21st'i **referans** olarak al, kodu bu sitenin CSS diline çevir.
   Bunu bana yaptır — "şu bileşeni al, `style.css` token'larıyla vanilla CSS'e çevir" de.
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

## 5. Sayfa sayfa somut plan

Öncelik sırasıyla, en yüksek getiri üstte:

| Sayfa | Şu anki durum | Ne yapılacak | Hangi araç |
|---|---|---|---|
| `index.html` | Hero + menü + hakkında + şubeler + IG şeridi | Tipografi ölçeği ve boşluk ritmini yeniden kur; `.section-about` iki kez tekrar ediyor, ayrıştır | Stitch → 21st |
| `menu.html` / `menu-podyum.html` | 161 KB, ürün listesi | Kategori navigasyonu + ürün kartı; ürün görselleri eksik | 21st + Nano Banana |
| `iletisim.html` | Basit iletişim | Harita/saat/şube kartı düzeni | 21st |
| `kart.html` | Sadakat kartı | Damga grid'i görsel dil olarak zayıf | Stitch |
| `oyunlar.html` + `oyun-*.html` | 4 mini oyun | Ortak bir oyun-hub kimliği yok | Stitch |
| `og-image.html` → `og-image.jpg` | Sosyal paylaşım görseli | Yeniden üret, 1200×630 | Nano Banana |

Hero fotoğrafları (`foto-hero-podyum2.jpg` 486 KB, mobil sürümü 284 KB) ayrıca
**boyut olarak da** ağır — Nano Banana ile yeniden üretirken 2K yeter, sonra sıkıştır.

---

## 6. Hazır prompt şablonları

**Stitch — tam sayfa:**
```
Bursa'da bir specialty kahve dükkanı için ana sayfa. Marka: sıcak toprak tonları,
krem zemin (#f8f6f2), altın vurgu (#b8965a), koyu mürekkep (#0a0a0a).
Başlıklar Fraunces serif, gövde Inter. Editoryal ve sakin — bol beyaz alan,
büyük tipografi, az sayıda öge. Bölümler: tam ekran hero, menü önizleme,
hikâye, iki şube, Instagram şeridi, footer. Mobil öncelikli.
```

**21st — bileşen:**
```
21st search: "editorial product card with image, title, price, minimal border"
3 sonuç göster, sonra seçtiğimi vanilla HTML/CSS'e çevir —
Tailwind class'ı olmasın, style.css'teki --gold/--paper/--ink token'larını kullan.
```

**Nano Banana — görsel:**
```
generate_image, aspectRatio 16:9, imageSize 2K:
"Doğal gün ışığı alan modern bir kahve dükkanı iç mekânı, açık ahşap tezgah,
espresso makinesi, sıcak nötr palet, sığ alan derinliği, sinematik, insan yok,
stok fotoğraf hissi olmayan otantik kadraj"
```

Marka tutarlılığı için: Nano Banana'ya `images` parametresiyle mevcut
`foto-hero-podyum2.jpg`'yi referans ver — palet ve mekân hissi korunur.

---

## 7. Kalite kapıları

Her turdan sonra bunları geçmeden yayına alma:

- [ ] 360px genişlikte yatay kaydırma yok
- [ ] Hero LCP < 2.5s (preload link'leri yerinde)
- [ ] Metin/zemin kontrastı ≥ 4.5:1 (altın `#b8965a` beyaz üstünde **yetersiz** — sadece dekoratif kullan)
- [ ] Fraunces + Inter dışında font yüklenmiyor
- [ ] `sw.js` `VERSION` sabiti artırıldı
- [ ] Üretilen görseller sıkıştırıldı (hero < 250 KB hedef)
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
