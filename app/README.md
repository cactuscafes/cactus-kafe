# 🌵 Cactus Coffee — iOS Uygulaması (App Store Rehberi)

Bu klasör, cactuscafes.com'u iPhone uygulamasına çeviren **Capacitor** projesidir.
Uygulama, siteyi uygulama penceresi içinde açar — sitede yaptığın her değişiklik
(menü, fiyat, kampanya) **uygulama güncellemesi gerektirmeden** anında uygulamada görünür.

Aşağıdaki adımların tamamı **Mac'te** yapılır. Toplam süre: ilk seferde ~1 saat
(çoğu Xcode indirmesi), sonraki güncellemelerde ~10 dk.

---

## 1. Kurulum (bir kez)

1. **Xcode'u kur:** App Store'dan "Xcode" (ücretsiz, ~10 GB). İlk açılışta ek bileşenleri onayla.
2. **Node.js kur:** https://nodejs.org → "LTS" sürümünü indir, kur.
3. **Terminal'i aç** ve bu klasöre gel:
   ```
   cd cactus-kafe/app
   npm install
   npx cap add ios
   ```
   Bu komut `ios/` klasörünü (Xcode projesini) oluşturur.

## 2. Xcode'da imzalama (bir kez)

```
npx cap open ios
```
Xcode açılınca:

1. Soldaki gezginde en üstteki **App** projesine tıkla → **Signing & Capabilities** sekmesi.
2. **Team:** Apple Developer hesabını seç (ilk sefer: Xcode → Settings → Accounts → Apple ID'ni ekle).
3. **Bundle Identifier:** `com.cactuscafes.coffee` (dokunma, hazır geliyor).
4. Üstteki cihaz seçiciden kendi iPhone'unu veya bir simülatör seç → **▶ Run** ile dene.

## 3. App Store'a gönderme

1. **App Store Connect'te kayıt:** https://appstoreconnect.apple.com → Uygulamalarım → **+**
   → Yeni Uygulama. Ad: "Cactus Coffee", dil: Türkçe, Bundle ID: `com.cactuscafes.coffee`, SKU: `cactus1`.
2. **Uygulama ikonu:** repo kökündeki `icon-1024.png` hazır (1024×1024). Xcode'da
   `App/Assets.xcassets/AppIcon` içine sürükle.
3. **Arşivle:** Xcode'da üstteki cihaz seçiciyi **Any iOS Device (arm64)** yap →
   menüden **Product → Archive** → açılan pencerede **Distribute App → App Store Connect → Upload**.
4. App Store Connect'te sürümü doldur: ekran görüntüleri (iPhone'da uygulamayı açıp
   ekran görüntüsü almak yeterli), açıklama, gizlilik ("veri toplanmıyor" —
   sadakat kartındaki telefon numarası "İletişim Bilgisi / Uygulama İşlevi" olarak beyan edilir).
5. **İncelemeye gönder.**

## ⚠️ Apple reddi riski ve çözümü

Apple, "sadece web sitesini gösteren" uygulamaları bazen **4.2 Minimum Functionality**
gerekçesiyle reddeder. Şansı artırmak için:

- Açıklamada uygulamanın **sadakat kartı** işlevini öne çıkar ("yıldız biriktir, bedava içecek kazan").
- İnceleme notlarına test için örnek bir telefon numarası yaz (kartı görebilsinler).
- Reddedilirse panik yok: cevap hakkın var; genellikle push bildirimi veya küçük bir
  yerel özellik ekleyince geçer. O noktada tekrar yardım isteyebilirsin.

## Sonraki güncellemeler

Site değişiklikleri için hiçbir şey yapman gerekmez. Yalnızca uygulamanın kendisini
(ikon, isim, yerel ayar) değiştirirsen: sürüm numarasını yükselt → Archive → Upload.
