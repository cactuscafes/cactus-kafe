# 🌵 Cactus Coffee — iPhone Uygulaması

`CactusCoffee.xcodeproj` hazır bir Xcode projesidir. Terminal, Node, ek kurulum
**gerekmez** — indir, çift tıkla, imzala, gönder.

## Uygulama ne yapıyor?

| Sekme | İçerik |
|---|---|
| ☕ **Menü** | cactuscafes.com/menu-podyum canlı menüsü (sitede değişen her şey anında görünür) |
| ⭐ **Sadakat Kartı** | **Tamamen native (SwiftUI):** kart oluşturma/görüntüleme, yıldız ızgarası, bedava içecek hakkı, kasada gösterilecek numara + QR, son işlemler, çekerek yenileme, çevrimdışı görünüm, paylaşma |
| 📞 **İletişim** | **Native:** arama, WhatsApp, Apple Haritalar yol tarifi, Instagram, paylaşma |

Sadakat kartı sunucudaki `/kart/*` API'sini kullanır; kart bilgisi cihazda saklandığı
için internet yokken de görünür. Uygulama açık temaya kilitlidir (marka rengi krem/yeşil).

---

## 1. Projeyi Mac'e indir (2 dk)

1. **github.com/cactuscafes/cactus-kafe** → yeşil **Code** → **Download ZIP**.
   *(Daha önce indirdiysen eski klasörü sil — kod güncellendi.)*
2. ZIP'i aç → `app` klasörü → **`CactusCoffee.xcodeproj`** çift tık.

## 2. İmzala ve dene (5 dk)

1. Sol panelde en üstteki **CactusCoffee** → **Signing & Capabilities** → **Team:** hesabını seç.
2. Üstteki cihaz seçiciden bir **iPhone simülatörü** → **▶**.
3. Üç sekmeyi de gez. Sadakat Kartı sekmesinde kendi numaranla **"Telefonla gör"** dene.
4. Beğendiğin 3-5 ekranda **⌘S** ile ekran görüntüsü al (Sadakat Kartı ekranı mutlaka olsun).

## 3. Yükle (10 dk)

1. Cihaz seçici → **Any iOS Device (arm64)**.
2. **Product → Archive** → Organizer açılır → **Distribute App → App Store Connect → Upload**.
3. "Upload Successful" → App Store Connect'te 15-30 dk içinde işlenir (bu yükleme **1.0 (2)**).

## 4. Yeniden incelemeye gönder

appstoreconnect.apple.com → Cactus Coffee → **1.0** sürüm sayfası:

1. **Build** bölümünde eskisini kaldır, **1.0 (2)**'yi seç.
2. Ekran görüntülerini yenileriyle değiştir.
3. **App Review Information → Notes** kutusuna şunu yapıştır (İngilizce, Apple'a cevap):

```
Thank you for the feedback regarding Guideline 4.2.

This build adds substantial native functionality beyond the web content:

1. Loyalty Card tab — a fully native SwiftUI experience: customers create and view
   their loyalty card in the app, see their star progress, free-drink credits and
   transaction history, display a scannable QR code and phone number at the counter,
   pull to refresh, and share the program. Card data is cached on device so it
   remains available offline.
2. Contact tab — native actions: call, WhatsApp, Apple Maps directions, Instagram
   and system share sheet.
3. Menu tab — our live café menu.

To test the loyalty card, enter any Turkish phone number starting with 05
(for example 0555 111 22 33) and a name. No password or sign-in is required.
```

4. **Save → Add for Review → Submit for Review**.

---

## Notlar

- **Sürüm numarası:** Bu yükleme build 2. Bir sonraki yüklemede Xcode'da projeye tıkla →
  **General → Build** değerini 3 yap (aynı numara ikinci kez yüklenemez).
- **Ret gelirse:** mesajı olduğu gibi paylaş; gerekirse push bildirimi gibi ek native
  özellik ekleyip yeni build çıkarırız.
- **Site değişiklikleri** (menü, fiyat, kampanya) uygulama güncellemesi gerektirmez.
