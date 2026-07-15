# 🌵 Cactus Coffee — iPhone Uygulaması

Bu klasörde **hazır bir Xcode projesi** var (`CactusCoffee.xcodeproj`).
Terminal, Node, ek kurulum **gerekmez** — indir, çift tıkla, imzala, gönder.

Uygulama, cactuscafes.com'u uygulama penceresinde açar. Menü/fiyat/kampanya
değişikliklerin uygulama güncellemesi gerektirmeden anında uygulamada görünür.
Telefon/WhatsApp/Instagram linkleri otomatik olarak ilgili uygulamada açılır;
internet yoksa "Tekrar Dene" ekranı çıkar.

---

## Adım 1 — Projeyi Mac'e indir (2 dk)

1. Mac'te tarayıcıdan: **github.com/cactuscafes/cactus-kafe** → yeşil **Code** düğmesi → **Download ZIP**.
2. ZIP'i aç → `app` klasörüne gir → **`CactusCoffee.xcodeproj`** dosyasına çift tıkla. Xcode açılır.

## Adım 2 — İmzala ve dene (5 dk)

1. Xcode menüsü → **Settings → Accounts → +** → Apple Developer hesabının Apple ID'siyle gir (yalnızca ilk sefer).
2. Sol paneldeki en üstteki **CactusCoffee** projesine tıkla → ortadaki **Signing & Capabilities** sekmesi → **Team** listesinden hesabını seç. (Hata/uyarı kalmamalı.)
3. Üstteki cihaz seçiciden bir **iPhone simülatörü** seç → **▶** düğmesi. Uygulama açılıp siteyi göstermeli.
4. Kendi iPhone'unda denemek istersen: telefonu kabloyla bağla, cihaz seçiciden telefonu seç → ▶. (Telefonda Ayarlar → Genel → VPN ve Aygıt Yönetimi'nden geliştiriciye güven demen istenebilir.)

## Adım 3 — App Store'a gönder (~30 dk, çoğu form doldurma)

1. **appstoreconnect.apple.com** → Uygulamalarım → **+ → Yeni Uygulama**:
   - Platform: iOS · Ad: **Cactus Coffee** · Birincil dil: Türkçe
   - Bundle ID: **com.cactuscafes.coffee** (listede çıkması için önce 2. adımın yapılmış olması gerekir; çıkmazsa developer.apple.com → Identifiers'dan elle ekle)
   - SKU: `cactus1`
2. Xcode'da üstteki cihaz seçiciyi **Any iOS Device (arm64)** yap → menüden **Product → Archive** → pencerede **Distribute App → App Store Connect → Upload** (hepsinde varsayılanlarla devam).
3. App Store Connect'te sürüm sayfasını doldur:
   - **Ekran görüntüleri:** uygulamayı simülatörde aç, ⌘S ile 6.7" ve 6.1" boyutlarında görüntü al (simülatör türünü değiştirerek).
   - **Açıklama:** sadakat kartını öne çıkar — "7 yıldız topla, içeceğin bizden. Menü, kampanyalar ve dijital sadakat kartın cebinde."
   - **Gizlilik:** "Veri Türleri" → yalnızca *İletişim Bilgisi → Telefon Numarası*, "Uygulama İşlevselliği" amacıyla, kimliğe bağlı, izleme yok.
   - **İnceleme Bilgileri** notuna: "Sadakat kartını test etmek için: [test telefon numarası yazın]".
4. **İncelemeye Gönder.** Sonuç genelde 1-3 gün içinde gelir.

## Reddedilirse (panik yok)

Apple bazen site-sarmalayıcı uygulamaları "4.2 Minimum Functionality" ile reddeder.
Bu olursa cevap yazma hakkın var; ayrıca push bildirimi gibi yerel bir özellik
ekleyerek yeniden göndermek genellikle yeterli oluyor — o noktada bana haber ver,
projeye ekleyeyim.

## Sonraki sürümler

Site değişikliği için hiçbir şey yapma. Uygulamanın kendisi değişirse (ikon, isim):
Xcode'da projeye tıkla → General → Version'ı yükselt (1.1) → Archive → Upload.
