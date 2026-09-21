# Mağaza sayfası — Cactus 3B

Faz 5'in yayın ayağı. Oyun sayfası açmak teknik değil **metin** işi: Steam'de
bir oyunun ilk 30 saniyesi kapsül görseli, kısa açıklama ve trailer'dan ibaret.
Aşağıdakiler kopyalanıp yapıştırılacak hâlde; rakamları çıkıştan önce güncelle.

---

## Kısa açıklama (Steam: en fazla 300 karakter)

**TR**
> Kaktüs Parkuru'nda çölün dikenleri arasında zıpla, çiçekleri topla, dikenli
> düşmanların üstüne bin. Kısa, hızlı, rekor kırmaya dayalı bir 3B platform
> oyunu. Altı bölüm, tek oturuşta bitiyor — ama en iyi sürene kolay kolay
> ulaşamayacaksın.

**EN**
> Hop across a thorny desert, collect the blooms, and bounce off spiny foes.
> Cactus 3D is a short, fast, record-chasing 3D platformer. Six levels, one
> sitting — beating your own best time is the hard part.

## Uzun açıklama

> **Çöl seni beklemiyor.**
>
> Cactus 3B, tek oturuşta bitirilen bir 3B platform oyunu. Dikenli tarlaların
> üstünden basamak taşlarına atlıyor, hareketli platformlara yetişiyor, kule
> tepesindeki çıkışa tırmanıyorsun. Yolda sekiz kaktüs çiçeği ve seni fark
> edince peşine düşen üç tür dikenli düşman var.
>
> **Zıplama hissi önce gelir.** Kenardan düştükten sonra hâlâ zıplayabilirsin
> (coyote süresi), havadayken bastığın zıplama yere değince hatırlanır, tuşu
> erken bırakırsan alçak zıplarsın. Fark edilmeyen, ama olmayınca hissedilen
> şeyler.
>
> **Düşmanlar adil.** Seni 120 derecelik bir koni içinde ve engel yoksa
> görürler — arkadan yaklaşabilir, platformun arkasına saklanabilirsin.
> Saldırıdan önce hazırlanırlar; kaçmak için bir anın vardır. Üç türün de
> kendi açığı var: kovalayanın üstüne binilir, zıplayan indikten sonra bir an
> savunmasız kalır, uzaktan diken atanın yakın dövüşü yoktur — yanına varmak
> yeter. Siper gerçekten siperdir: diken duvardan geçmez.
>
> **Rekor senin rakibin.** Her bölüm süreni ve ölümünü kaydeder. Bölümü
> bitirmek kolay; temiz bitirmek değil.

## Özellikler (madde madde)

- Altı bölüm: parkur, kule tırmanışı, diken köprüsü, hareketli platform terası,
  düşman bahçesi ve hepsini birden isteyen final
- Tuş atama ekranı ve erişilebilirlik ayarları
- Üç düşman türü: kovalayan, üstüne zıplayan ve uzaktan diken atan
- Coyote süresi, zıplama tamponu, değişken zıplama yüksekliği
- Bölüm başına süre ve ölüm rekoru
- Tarayıcıda oynanır — indirme yok
- Türkçe arayüz

## Etiketler

`Platformer` · `3D Platformer` · `Precision Platformer` · `Speedrun` ·
`Singleplayer` · `Colorful` · `Short` · `Casual` · `Indie`

---

## Trailer

```bash
# 1) Kaydet (bu depoda, betikle — elle oynamaya gerek yok)
godot --path oyun3d --rendering-driver opengl3 --audio-driver Dummy \
  --write-movie cikti/tanitim.avi --fixed-fps 24 res://araclar/tanitim.tscn

# 2) Sıkıştır (standart ffmpeg ile)
ffmpeg -i cikti/tanitim.avi -c:v libx264 -preset slow -crf 20 \
  -pix_fmt yuv420p -movflags +faststart cikti/tanitim.mp4
```

Çekim listesi `araclar/tanitim.gd` içinde `_cekimleri_kur()` fonksiyonunda;
her çekim bir sözlük: süre, oyuncunun konumu, basılı tutulan tuşlar, zıplama
anları. Bölüm değişince trailer'ı elden geçirmek yerine listeyi düzelt ve
komutu yeniden çalıştır.

> **Neden betikle:** Trailer'ı elle oynayıp ekran kaydı alarak da çekebilirsin,
> ama her değişiklikten sonra baştan oynaman gerekir. Movie Maker kipi sabit
> adımla çalıştığı için yavaş makinede bile akıcı çıktı verir.

**Steam trailer kuralları:** en az 1280×720, tercihen 1920×1080; ilk 5 saniyede
oynanış görünmeli (logo ile başlama); ses seviyesi -12 dB civarı; süre 60–90 sn.
Trailer sayfanın en üstünde otomatik oynar — ilk kare bir ekran görüntüsü kadar
önemli.

---

> **Takvim:** aşağıdaki sıranın ne zaman yapılacağı
> [`CIKIS-PLANI.md`](CIKIS-PLANI.md) içinde geri sayım olarak yazılı.

## Steam sayfası açma sırası

1. **Steamworks hesabı** — partner.steamgames.com, şirket/şahıs bilgileri, vergi
   formu (W-8BEN Türkiye için). Bu kısım 1–2 hafta sürebiliyor.
2. **Steam Direct ücreti** — ürün başına **100 USD**. Oyun 1.000 USD brüt gelire
   ulaşınca iade ediliyor.
3. **Mağaza sayfası varlıkları:**
   | Görsel | Ölçü |
   |---|---|
   | Ana kapsül (header) | 460×215 |
   | Küçük kapsül | 231×87 |
   | Dikey kapsül | 374×448 |
   | Kütüphane kapsülü | 600×900 |
   | Kütüphane arka planı | 1920×620 |
   | Ekran görüntüsü (en az 5) | 1920×1080 |
4. **Metin** — yukarıdaki kısa/uzun açıklama, etiketler, sistem gereksinimleri.
5. **İnceleme** — Valve sayfayı elle inceliyor (2–5 iş günü). Reddedilirse
   sebep yazılı gelir, düzeltip yeniden gönderiyorsun.
6. **Yayın tarihi** — sayfa yayına girdikten **en az 2 hafta** sonrası seçilebilir.
   Wishlist toplamak için bu süre kısa; 2–3 ay önce sayfa açmak normal.

## Çıkıştan önce

- [ ] Sayfa yayında ve wishlist toplanıyor (hedef: çıkışta **7.000+**)
- [ ] Demo yayında (Steam Next Fest başvurusu için şart)
- [ ] Trailer 60–90 sn, ilk 5 saniyede oynanış
- [ ] 5+ ekran görüntüsü, her biri farklı bir şey gösteriyor
- [x] Basın kiti hazır: [`basin/index.html`](basin/index.html) — künye, TR/EN
      açıklama, yedi 1920×1080 ekran görüntüsü, kullanım izni, iletişim
- [ ] 20 kişiye oynatıldı ve geri bildirim işlendi (Faz 3'ten devreden görev)

> **Uyarı:** Sayfa açmadan önce oyunun bitmesini bekleme. Wishlist zaman ister;
> sayfa ne kadar erken açılırsa çıkış günü o kadar iyi olur. Ama boş bir sayfa
> da zarar verir — trailer ve ekran görüntüleri hazır olmadan açma.
