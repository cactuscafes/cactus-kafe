# 🌵 Cactus Coffee — iPhone Uygulaması

Uygulama artık **GitHub'da otomatik derleniyor, imzalanıyor ve App Store'a yükleniyor.**
Mac'te Xcode açmana gerek yok — tarayıcıdan bir düğmeye basman yeterli.

## Uygulama ne yapıyor?

| Sekme | İçerik |
|---|---|
| ☕ **Menü** | cactuscafes.com/menu-podyum canlı menüsü (sitede değişen her şey anında görünür) |
| ⭐ **Sadakat Kartı** | **Tamamen native:** kart oluşturma/görüntüleme, yıldız ızgarası, bedava içecek hakkı, kasada gösterilecek numara + QR, son işlemler, çekerek yenileme, çevrimdışı görünüm, paylaşma |
| 📞 **İletişim** | **Native:** arama, WhatsApp, Apple Haritalar yol tarifi, Instagram, paylaşma |

---

# BİR KEZ yapılacak kurulum (~5 dk)

Apple, kendi hesabına ait bir anahtar olmadan yükleme kabul etmiyor. Bu anahtarı
bir kez oluşturup GitHub'a tanıtıyoruz; sonrası tamamen otomatik.

## 1. App Store Connect API anahtarı oluştur

1. **appstoreconnect.apple.com** → sağ üstten **Users and Access**
2. Üstteki **Integrations** sekmesi → **App Store Connect API** → **Team Keys**
3. **+** düğmesi → Name: `GitHub Otomasyon` → Access: **App Manager** → **Generate**
4. Oluşan satırdan **Download API Key** ile `AuthKey_XXXXXXXXXX.p8` dosyasını indir
   *(bu dosya yalnızca bir kez indirilebilir — masaüstünde dursun)*
5. Aynı sayfadan not al: **KEY ID** (10 karakter) ve en üstteki **Issuer ID** (uzun uuid)

## 2. Takım kimliğini (Team ID) öğren

**developer.apple.com/account** → **Membership details** → **Team ID** (10 karakter).

## 3. GitHub'a 4 secret ekle

**github.com/cactuscafes/cactus-kafe** → **Settings** → sol menü **Secrets and variables**
→ **Actions** → **New repository secret** ile dört tane ekle:

| Name | Value |
|---|---|
| `ASC_KEY_ID` | 1. adımdaki KEY ID |
| `ASC_ISSUER_ID` | 1. adımdaki Issuer ID |
| `ASC_KEY_P8` | `.p8` dosyasını metin düzenleyicide aç, **tüm içeriği** yapıştır (`-----BEGIN PRIVATE KEY-----` satırı dahil) |
| `APPLE_TEAM_ID` | 2. adımdaki Team ID |

> Secret'lar şifrelenir; iş akışı loglarında görünmez ve dışarıdan okunamaz.

---

# HER yüklemede yapılacak (30 saniye)

1. **github.com/cactuscafes/cactus-kafe** → **Actions** sekmesi
2. Soldan **iOS — App Store'a yükle** → sağdaki **Run workflow**
3. **Build numarası:** bir öncekinden büyük bir sayı yaz (ilk otomatik yükleme için `3`)
4. **İncelemeye gönder:** işaretlersen build yüklendikten sonra sürümü Apple'a
   otomatik gönderir; işaretlemezsen sadece yükler, göndermeyi sen yaparsın
5. **Run workflow** → yeşil tik gelene kadar bekle (~15-40 dk; çoğu süre Apple'ın
   build'i işlemesi)

İş akışı sırasıyla şunları yapar: derler → otomatik imzalar → App Store Connect'e
yükler → build işlenene kadar bekler → sürüme bağlar → inceleme notlarını yazar →
(istersen) incelemeye gönderir.

## Notlar

- **Ekran görüntüleri** App Store'da zaten duruyor; değiştirmek istersen App Store
  Connect → sürüm sayfasından yükleyebilirsin (zorunlu değil).
- **İnceleme notu metni** `app/inceleme-notu.txt` dosyasındadır; Apple'ın 4.2
  gerekçesine cevap verecek şekilde yazıldı, otomatik gönderilir.
- **Ret gelirse** mesajı paylaş; gerekli düzeltmeyi yapıp yeni build numarasıyla
  iş akışını tekrar çalıştırırız.
- **Site değişiklikleri** (menü, fiyat, kampanya) uygulama güncellemesi gerektirmez.

## Mac'te elle yapmak istersen (opsiyonel)

`app/CactusCoffee.xcodeproj` çift tık → **Signing & Capabilities → Team** seç →
simülatörde **▶** ile dene. Yükleme için **Any iOS Device → Product → Archive →
Distribute App → App Store Connect → Upload**.
