# Cactus — Kendi Kendine Yönetim Rehberi

Bu rehber "hangi işi nereden yaparım" sorusunun cevabıdır. Buradaki her iş **yapay zekâ / geliştirici gerektirmez** — admin panelinden veya adisyondan yapılır.

Admin paneli: **cactuscafes.com/admin** (yönetim parolası ile)

---

## Günlük işler

| İş | Nereden |
|---|---|
| Ürün fiyatı değiştir / ürün ekle-sil | Admin → **Menü** → düzenle → sağ üst **🚀 Yayınla** |
| Ürün fotoğrafı / açıklaması | Admin → **Menü** → ürün kartında 📷 / ✏️ |
| Ürün tükendi işaretle | Admin → **Tükendi** (veya Menü'de ürün kartından) |
| Ana sayfadaki öne çıkan 4 ürün | Admin → **Öne Çıkan** → Yayınla |
| Günün cirosu, açık masalar | Admin → **Bugün** / **Canlı Masalar** |
| Geçmiş raporlar, yoğun saatler | Admin → **Raporlar** / **Yoğun Saatler** |
| İş başvurularını gör | Admin → **Başvurular** (yeni gelen kırmızı rozetle görünür) |
| Şikayet & önerileri gör | Admin → **Şikayet & Öneri** |
| Müşteri sadakat kartına bak / bedava kullan | Admin → **Sadakat Kartı** |

> **Yayınla rozeti:** Menüde kaydedilmiş ama yayınlanmamış değişiklik varsa üstteki
> Yayınla butonunda **sayı** görünür. Basınca neyin değişeceğinin listesi çıkar.

## ⚙️ Site Ayarları (yeni)

Admin → **Site Ayarları** — buradaki her şey **Kaydet**'e basınca anında canlıya geçer:

- **Çalışma saatleri** (şube başına hafta içi/sonu) — ana sayfa, iletişim, "şu an açık/kapalı"
  rozetleri ve Google'ın gördüğü saat bilgisi otomatik güncellenir. Bayram saatinde tek yer burası.
- **Duyuru şeridi** — menü sayfalarının üstündeki kayan yazı; şube başına metin + aç/kapa.
- **FSM açılış popup'ı** (ör. "tatlıya çay ikram") — metinler + aç/kapa.
  Biçim: `*kelime*` altın italik, `**kelime**` kalın, satır sonu = alt satır.
- **Podyumpark kampanya popup'ı** — başlık, fiyat, metin + aç/kapa + **bitiş tarihi**
  (tarih geçince popup kendiliğinden kapanır; şerit metnini elle güncellemeyi unutma).
- **Google puanları** (4.8 · 218 yorum rozetleri) — birkaç ayda bir tazele.
- **Telefon** — sitedeki tüm telefon linkleri.

## Sayfa metinleri ve fotoğrafları

| Sayfa | Nereden |
|---|---|
| Ana sayfa (index) metin + fotoğraflar | Admin → **Ana Sayfa** → öğenin üzerine gel → ✏️/📷 → **Yayınla** |
| İletişim sayfası metinleri | Admin → **İletişim** → aynı yöntem |
| Menü sayfası başlıkları | Admin → **Menü Sayfası** |

> Bu editörler değişikliği doğrudan GitHub'a işler; site ~30 saniyede güncellenir.
> İlk kullanımda GitHub token'ı sorar — token **yalnızca bu repoya yazma** yetkili
> (fine-grained) olmalı. Geniş yetkili classic token kullanma; token'ı kimseyle paylaşma.

## Adisyon tarafı (kasiyer cihazı)

- Sipariş, masa, ödeme, hesap bölüşme, iskonto → **Kasiyer** sekmesi
- Sadakat yıldızı ekleme → **Yıldız** sekmesi (telefonla)
- Gider girişi → **Gider** · Kasa açılış/mutabakat → **Raporlar** içinde
- Adisyon menü fiyatları → **Yönet** (admin Menü ile aynı veriyi kullanır)

## Yapay zekâ / geliştirici gerektirenler

Şunlar hâlâ kod işi: yeni sayfa/bölüm eklemek, tasarım değişikliği, yeni özellik
(quiz soruları, fal metinleri gibi gömülü içerikler dahil), QR kodu yeniden üretmek,
Turnstile/altyapı ayarları. Bunlar dışında her günlük operasyon yukarıdaki panellerden döner.

## Sorun giderme

- **"Değişiklik sitede görünmüyor"** — 1-2 dk bekle; olmadıysa sayfayı Ctrl/Cmd+Shift+R ile yenile.
  Adisyon cihazında sol alttaki sürüm rozetine dokun (zorla güncelleme).
- **"Yayınla hata verdi"** — internet bağlantısını kontrol et, tekrar dene; sorun sürerse
  diğer şubenin menüsü korunur, veri kaybolmaz (yayın diğer şubeyi okuyamazsa kendini iptal eder).
- **Yönetim parolası** — worker'da tanımlı (`ADMIN_PASS`); değiştirmek kod/terminal işi.
