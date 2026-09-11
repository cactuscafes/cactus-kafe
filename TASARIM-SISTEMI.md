# Tasarım Sistemi — Token Katmanları ve Kurallar

Bu doküman sitenin tasarım sistemini ve ona ulaşırken öğrenilenleri kayda geçirir.
MCP araçlarının kurulumu ayrı dosyada: [`TASARIM-MCP.md`](TASARIM-MCP.md).

---

## 1. Üç katman

| Dosya | İçerik |
|---|---|
| `tipografi.css` | punto ölçeği, izleme (em), satır yüksekliği |
| `renkler.css` | marka paleti + erişilebilir metin eşleri |
| `bosluk.css` | bölüm ritmi, kenar boşluğu, nav altı boşluk |

**Üçü de yalnızca `:root` token'ı içerir — tek bir seçici bile yok.** Bu bilinçli.
Her sayfanın kendi `<style>` bloğu var; ortak dosyaya seçici koysaydık her sayfada
özgüllük ve sıra kavgası çıkardı. Seçici içermeyen dosya hiçbir şeyle çakışamaz;
yalnızca değer sağlar.

### Kullanım

```html
<link rel="stylesheet" href="tipografi.css">
<link rel="stylesheet" href="renkler.css">
<link rel="stylesheet" href="bosluk.css">
```

Sonra kendi kurallarında `var(--t-body)`, `var(--c-altin-ink)`, `var(--sp-nav)`.

### Sert bağımlılık

Bu dosyalardan biri yüklenmezse o sayfanın **inline stilleri dahil** tüm ilgili
değerleri çöker. `var(--x,#fallback)` bunu önlerdi ama hex'i yüzlerce yere geri
getirirdi — yani kaldırdığımız tekrarı. Sert bağımlılık bilinçli seçildi;
`<head>`'deki her stylesheet zaten böyle davranır.

**`iletisim.html` özel durum:** kendi `:root`'u yok, token'larını `style.css`'ten
alıyor. `style.css` de `var(--c-*)` kullandığı için `iletisim.html`'in
`renkler.css`'i yüklemesi şart. Zincirleme bağımlılık.

---

## 2. Renk: dekoratif vs metin

Marka altını `#c8a86a` beyaz üzerinde **2.3:1** — WCAG AA'nın (4.5:1) epey altında.
Bu yüzden palet ikiye ayrılır:

| Token | Kullanım | Beyazda |
|---|---|---|
| `--c-altin` | **dekoratif**: çizgi, kenarlık, koyu zeminde metin | 2.3:1 |
| `--c-altin-ink` | **metin/buton** (açık zemin) | 4.97:1 |
| `--c-altin-ink2` | hover | 6.99:1 |

Aynı ayrım `style.css`'te `--mist` (dekoratif) / `--label-ink` (etiket metni) olarak
da var.

### İsim çakışması uyarısı

Denetimde çıkanlar — ortak katmana **mevcut isimleri** taşımamanın sebebi:

```
--gold   → #c8a86a (index) · #b8965a (style.css, qr-menu) · #2d5a27 YEŞİL (menu-podyum)
--ink    → #0a0a0a (style.css) · #eef0f4 AÇIK (hoopcoach)
--accent → #1a1a1a (style.css) · #e8a03a (hoopcoach)
```

`--gold` bir sayfada yeşil. Ortak tanım sayfaların bir kısmını **sessizce** yanlış
renge çevirirdi. Onun için `renkler.css` değere göre adlandırılmış (`--c-altin`,
`--c-yesil`) ve sayfalar yerel isimlerini buna bağlıyor:

```css
/* menu-podyum.html */  :root{ --gold:var(--c-yesil); }
```

---

## 3. `var()` nerede ÇALIŞMAZ

Hex → token dönüşümünde bu üç bağlama **dokunulmadı**, teknik sebeplerle:

| Bağlam | Neden |
|---|---|
| SVG sunum özniteliği — `stroke="#c8a86a"` | `var()` öznitelikte çözülmez; yalnızca CSS özelliğinde. İkonlar renksiz kalır. |
| `<meta name="theme-color" content="#0b1a07">` | Tarayıcı literal renk bekler. |
| JS veri dizisi — `var YEDEK_RENK=[['#2d5a27',…]]` | CSS bağlamı değil. |

`.style.color='var(--c-altin)'` **çalışır** (CSSOM geçerli kabul eder) — ama
yalnızca hover'da devreye girdiği için durağan ölçümle doğrulanamaz, ayrıca test
edilmeli.

---

## 4. Tipografi: neyin ölçeğe girmediği

Taban **11px**; ölçümde 8-10px metinler (butonlar dahil) okunmuyordu.

**İzleme `em` cinsinden.** `letter-spacing:4px`, 8px metinde 0.5em (kelime harf
dizisine dönüşür), 16px'te 0.25em. px izleme punto değişince oranı bozar.

### Bilinçli istisnalar — ölçeğe girmez

Bunlar **okunacak metin değil**; boyutları içinde bulundukları grafiğin oranına bağlı:

- Sadakat kartı maketi (`index.html`, `kart.html` `.dk-*`) — 10px
- Telefon maketi içi (`.app-tel .rk-alt`) — 10px
- Hafıza oyunu kart arkası markası (`.yuz.arka .marka`) — 7px

**`menu-baski.html` tamamen ölçek dışı.** `@page{size:A4}`, ölçüler mm cinsinden.
Baskıda 10.7px ≈ 8pt, normal bir menü gövde puntosu; kâğıdın çözünürlüğü ekranınkinin
kat kat üstünde. Ekran eşiğini oraya uygulamak yanlış olur, üstelik sayfa A4'e
sığmayabilir. **Farklı ortam, farklı ölçüt.**

**Devre dışı kontroller** WCAG 1.4.3'ten muaf — `kart.html`'in `<button disabled>`'ı
ve `cactus-jump-test`'in `.katil-btn.pasif`'i koyulaştırılmadı; pasif butonu aktif
gibi göstermek durum bilgisini bozar.

---

## 5. Boşluk: üç ayrı kaygı

Tek bir "boşluk" yok. Kodda hepsi aynı `padding` içinde karışmıştı:

| Kaygı | Token | Neye bağlı |
|---|---|---|
| Bölüm ritmi | `--sp-section` / `--sp-section-dar` | tasarım tercihi |
| Sayfa kenar boşluğu | `--sp-gutter` | ekran genişliği |
| Sabit nav altını boşaltma | `--sp-nav` | **nav yüksekliği** |

Üçüncüyü birinciye katmak cazip (ikisi de büyük dikey padding) ama nav'a bir satır
eklendiğinde bütün bölüm ritmi kayardı.

`--sp-nav-yuk:76px` **tarayıcıda ölçüldü** (nav 1440px'te 71-75, 390px'te 67-71).
Sayfalar bunu 90/120/160px diye elle yazıyordu ve hiçbiri nav yüksekliğini takip
etmiyordu.

**İki ritim basamağı var** çünkü kodda iki ritim yaşıyor: vitrin sayfaları geniş
(100-120px), yoğun sayfalar dar (56-72px). Tek değere zorlamak menüyü gereksiz
seyreltirdi.

---

## 6. Doğrulama yöntemi

Bu turlarda tekrar tekrar işe yarayan şeyler.

### Kaynağı regex'le okuma, tarayıcıda ölç

Üç kez, statik aramanın göremediği kusur ancak hesaplanmış değeri ölçünce çıktı:

- `menu-podyum`'un aktif nav rengi **JS ile** atanıyordu
- `iletisim`'in bazı kuralları sayfada değil **`style.css`'te**ydi (iki kez düşüldü)
- `.menu-header-eyebrow` kuralı doğruydu ama `@keyframes caTrack` **`fill-mode:both`**
  ile bitip son kareyi sabitliyor, kuralı eziyordu

### Kontrast ölçerken alfa kompozitle

Yarı saydam zeminleri (`rgba(255,255,255,.06)` bir koyu bölümün üstünde) opak sanan
ölçüm 2-10 kat şişik rakam verir. `index.html` 25 → 8, `kart.html` 8 → 3,
`cactus-jump-test` 19 → 2.

Fotoğraf üstündeki metin CSS'ten okunamaz; **arkadaki gerçek pikselleri** örnekle.

### Refactor türüne göre ölçüt

| Tür | Başarı ölçütü |
|---|---|
| Saf refactor (hex → token) | **sıfır fark** — her ögenin hesaplanmış rengi birebir aynı |
| Düzen değişikliği (boşluk ölçeği) | taşma yok + ekran görüntüsü + neyin değiştiğinin raporu |

Saf refactor'da: eski sürümü ayrı bir git worktree'den başka portta sun, **aynı anda**
ölç. Farklı zamanlarda alınan iki anlık görüntü karşılaştırılamaz.

### Gürültü tabanını ölç

Oyun sayfaları rastgele/geçici durum üretir (`oyun-merdiven`'de `.tas.yeni` sınıfı
JS'ten geçici eklenir, 160ms animasyon tetikler). Aynı sürümü **iki kez** örnekleyip
aradaki farkı gürültü tabanı olarak al; gerçek farktan düş.

### Hizalanmayı kontrol et

Sıraya dayalı karşılaştırmada `<head>`'e eklenen bir `<link>` her şeyi kaydırır.
Kapsamı `body *` tut; öge sayısı değiştiyse karşılaştırmayı **reddet** — sessizce
yanlış hizalanmış bir diff'e güvenme.

### Hover'ı ayrıca ölç

`onmouseover="this.style.color='…'"` durağan parmak izinde görünmez. `mouseover`/
`mouseout` tetikleyip öncesi/üstünde/sonrası üçlüsünü ölç.

### "Hiçbir şey değişmedi" ölü kod demek olabilir

`iletisim.html`'de `--sp-nav`'ı `.page-hero`'ya uyguladım, ölçüm sıfır değişiklik
gösterdi. Sebep: `.page-hero` markup'ta **hiç kullanılmıyordu**. Gerçek boşluk
inline stildeydi. Ölçüm olmasaydı ölü kuralı düzeltip geçecektim.

### Bağlamı konumla belirle, tahminle değil

Hex'in öncesindeki 90 karaktere regex uygulayan sınıflandırıcı 189 hex'in 147'sini
yanlış etiketledi (`<style>` etiketi çoğu zaman daha uzakta). Doğrusu: blokların
**konum aralıklarını** önceden çıkarıp indekse göre sınıflandırmak.

### Toplu arama-değiştirmeden kaçın

`#c8a86a → #8a6b2f` toplu değişimi `menu-podyum.html`'de 20 yeri değiştirdi; çoğu
**koyu zemindeydi** ve orada eski değer doğruydu. Geri alındı, hedefli düzeltildi.

---

## 7. Kapsam dışı

| Ne | Neden |
|---|---|
| `admin.html`, `adisyon*.html`, `adisyon-fsm.html` | Operasyon kritik POS/yönetim araçları. Kendi büyük paletleri var; emoji orada hızlı ayırt edici işlevsel ikon. |
| `menu-baski.html` | A4 baskı sayfası — ayrı ortam, ayrı ölçüt |
| `hooplegend/`, `ios-kayit/`, `besharf/` | Ayrı ürünler, kafe sitesinin kromu değil |

---

## 8. Bilinen sınırlar

- SVG öznitelikleri, `<meta theme-color>` ve JS veri dizilerindeki hex'ler token
  değil (bkz. bölüm 3)
- `oyun-hafiza.html` / `oyun-merdiven.html`'de `:root` yok; renkler doğrudan
  kurallarda, token'a bağlanmadı
- `--sp-section` yalnızca `index.html`'de bölüm kurallarına uygulandı; diğer
  sayfaların bölüm dolguları hâlâ kendi değerlerinde
