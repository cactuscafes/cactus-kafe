# Çıkış planı — Cactus 3B

Takvim **mutlak tarihlerle değil, geri sayımla** yazılı: oyunun ne zaman
biteceğini bugünden bilemezsin, ama çıkış gününü seçtiğinde bu listeyi o günün
üzerine oturtabilirsin. `Ç` = çıkış günü.

> Valve'in kuralları ve tarihleri değişiyor. Başvurmadan önce Steamworks
> belgelerinden doğrula; buradaki süreler plan yapmak için, taahhüt değil.

---

## Geri sayım

| Zaman | İş | Neden |
|---|---|---|
| **Ç − 6 ay** | Steamworks hesabı, vergi formu (Türkiye için W-8BEN), Steam Direct ücreti (ürün başına 100 USD) | Hesap onayı 1–2 hafta sürebiliyor; ücret 1.000 USD brüt gelirde iade ediliyor |
| **Ç − 5 ay** | Trailer + 5 ekran görüntüsü + kapsül görselleri | Sayfa bunlarsız açılmamalı; boş sayfa zarar verir |
| **Ç − 4,5 ay** | **Mağaza sayfasını aç**, wishlist toplamaya başla | Wishlist zaman ister. Sayfa ne kadar erken açılırsa çıkış günü o kadar iyi |
| **Ç − 4 ay** | Demo yapısını hazırla ve yayınla (`demo` ön ayarı) | Next Fest başvurusu için demonun **yayında** olması gerekiyor |
| **Ç − 4 ay** | Telemetri sunucusunu yayınla, `TELEMETRI_URL`'i doldur | Demo verisi ancak toplanırsa işe yarar; çıkıştan sonra toplamak geç |
| **Ç − 3,5 ay** | **Steam Next Fest'e başvur** | Kayıt festivalden haftalar önce kapanıyor. Bir oyun **yalnızca bir kez** katılabiliyor — demoyu cilalamadan harcama |
| **Ç − 3 ay** | Next Fest haftası: her gün yayıncı/izleyici sorularına yanıt | Festival trafiği tek seferlik; o hafta bilgisayarın başında ol |
| **Ç − 2,5 ay** | Telemetri özetini oku, demoyu düzelt | `sunucu/`'nun `/ozet` ucu: ölüm haritasının ilk üç noktası = bölümün istemeden zor üç yeri |
| **Ç − 2 ay** | Basın ve içerik üreticisi listesi + ilk e-postalar | İnceleme yazısı hazırlanmak için süre ister |
| **Ç − 6 hafta** | İçerik üreticilerine Steam anahtarı (embargo: çıkış günü) | Video kurgusu bir haftadan uzun sürüyor |
| **Ç − 1 ay** | Fiyat, bölge fiyatlandırması, çıkış tarihi Steamworks'e girildi | Tarih, sayfa yayına girdikten en az 2 hafta sonrası olabiliyor |
| **Ç − 2 hafta** | Yapı Steam'e yüklendi, indirilebilir dahili sürüm testi | Yükleme günü ilk kez deneme: klasik hata |
| **Ç − 1 hafta** | Sürüm notları, basın kiti güncel, sosyal gönderiler yazılı | Çıkış günü yazı yazacak vaktin olmayacak |
| **Ç − 1 gün** | Son yapı, mağaza sayfası son okuma, yedek plan | "Son dakika düzeltmesi" en çok çıkış gününde bozuyor |
| **Ç günü** | Yayına al, e-postaları gönder, gün boyu yorumları yanıtla | İlk 48 saat Steam algoritması için belirleyici |
| **Ç + 1 hafta** | İlk yama: çıkış haftasında gelen raporlar | Hızlı yama, inceleme puanını kurtarır |
| **Ç + 1 ay** | İlk indirim planı, geri bildirimi 1.1 sürümüne dök | Steam ilk indirimde 30 gün bekletiyor |

---

## Demo stratejisi

Demo **oyunun ilk bölümü**, kesilmiş bir hâli değil. `Bolumler.liste()` demo
yapısında tek bölüm döndürüyor; bitişte tam sürüm notu ve (mağaza adresi
doldurulduğunda) dilek listesi düğmesi çıkıyor.

Üç kural:

1. **Demo bitmiş hissettirmeli.** Yarıda kesilen demo, oyunun yarım olduğunu
   düşündürür. Bölüm bitiyor, süre kaydediliyor, bitiş ekranı çıkıyor.
2. **Demo güncel kalmalı.** Ayrı kod dalı yok: demo, aynı yapının `demo`
   etiketiyle dışa aktarılmış hâli. Oyun düzelince demo da düzeliyor.
3. **Demo ölçülmeli.** Telemetri açık olan oyuncularda nerede bırakıldığı
   görülür. "Demo iyi mi?" sorusunun cevabı, bırakma noktalarının dağılımı.

---

## Basın ve içerik üreticisi listesi

İsimleri buraya yazmıyoruz — liste, oyunun **türünü gerçekten oynayan**
kişilerden kurulur ve her oyunda yeniden kurulur. Toplama yöntemi:

1. Steam'de Cactus 3B'ye benzeyen 10 oyunu bul (3B platform, kısa, rekor).
2. Her birinin mağaza sayfasındaki "Curator"ları ve YouTube'da adını arattığında
   çıkan kanalları not et. Abone sayısı değil, **o oyunu oynamış olması** önemli.
3. Türkiye tarafı için: Türkçe oyun haber siteleri ve bağımsız oyun kanalları.
4. E-posta adreslerini kanalın "hakkında" bölümünden al; toplu e-posta gönderme
   servisi kullanma, tek tek yaz.

**E-posta şablonu** (kısa tut; uzun e-posta okunmuyor):

> Konu: Cactus 3B — 45 dakikalık bir 3B platform oyunu (Steam anahtarı ekte)
>
> Merhaba [ad],
>
> [oyun adı] videonuzu izledim; Cactus 3B de aynı damarda: çölde geçen, tek
> oturuşta biten, rekor kovalamaya dayalı bir 3B platform oyunu. Tarayıcıda
> da oynanıyor.
>
> Trailer: [bağlantı] · Basın kiti: cactuscafes.com/oyun3d/basin/
> Steam anahtarı: [anahtar] (embargo yok, istediğiniz zaman yayınlayabilirsiniz)
>
> Görsel ve videoları para kazandığınız içeriklerde de serbestçe
> kullanabilirsiniz; telif talebi göndermiyoruz.
>
> İyi çalışmalar,
> Cactus Cafe — batuhanbulut@cactuscafes.com

---

## Çıkış günü kontrol listesi

- [ ] Yapı Steam'de "default" dalında ve indirilip oynandı
- [ ] Mağaza sayfası metni son okumadan geçti (yazım hatası = güven kaybı)
- [ ] Basın kiti güncel: sürüm numarası, ekran görüntüleri, trailer bağlantısı
- [ ] `betikler/urun.gd` içindeki `MAGAZA_URL` dolu (demo içindeki düğme için)
- [ ] Sürüm numarası dört yerde de aynı (bkz. `SURUM-NOTLARI.md`)
- [ ] Telemetri sunucusu ayakta (`/saglik`) ve `/ozet` anahtarı elinde
- [ ] Sosyal gönderiler ve e-postalar yazılı, gönderilmeyi bekliyor
- [ ] Yorumları yanıtlamak için gün boşaltıldı
