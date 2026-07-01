# Trendyol Go menüsünü Podyumpark menüsüyle birebir yapma talimatı

> Bu dosyayı okuyan Claude oturumuna: Görevin, açık Chrome'daki Trendyol Go satıcı panelinde
> (Cactus, restoran ID **318539**, sekme başlığı "GO Yemek") aşağıdaki değişiklikleri yapmak.
>
> **ÖNEMLİ — bloktan kaçınmak için:** SADECE panelin görünür arayüzünden (arama kutusu,
> fiyat kutusu, toggle, kalem/düzenle ikonu, "Yeni Ürün Ekle") tıklayarak ve yazarak çalış.
> `read_network_requests`, `localStorage`, `javascript_tool` ile auth token / Bearer token
> ÇIKARMA veya yazdırma. API'ye (api.tgoapis.com) doğrudan fetch/PUT ATMA. Aksi halde güvenlik
> katmanı tüm yazma işlemlerini bloklar. Her değişiklikten sonra ekran görüntüsüyle doğrula.
>
> Ürünler ekranı: https://partner.tgoyemek.com/meal/318539/menu/products
> (Fiyat satır içi kutudan düzenlenir; "Satışa Açık" toggle ile aç/kapa; kalem ikonu ad/kategori düzenler.)
> Kategoriler ekranı: https://partner.tgoyemek.com/meal/318539/menu/sections

## Fiyat kuralı
Hedef fiyat = Podyum fiyatı ÷ 0,8, en yakın 5'e yuvarla (%20 komisyon). Mevcut ~50 kalem zaten
bu formülle doğru; sadece aşağıda belirtilenlere dokun.

## 1) Fiyat düzelt (arama kutusundan bul → satır içi fiyat kutusuna yaz)
- Kuzu Firarda: 300 → **315**
- Apollo: 300 → **315**
- Zeus: 300 → **315**

## 2) Satışa aç (şu an pasif → toggle'ı aç)
- Kuzu Firarda
- Apollo
- White Chocolate Brownie  (ayrıca adını Brownie yap — bkz. bölüm 5)
- San Sebastian
- Spoonful
- Melisa Çayı
- Kış Çayı

## 3) Satışa kapat (Podyum'da yok)
- Coca Cola  (toggle'ı kapat)
- (Diğer fazlalar zaten pasif: Chai Tea Latte, Cream Puff, Dökme Profiterol, Affogato,
  Mini Kahvatı Tabağı, Egg/Dana Cotto/Hindi Füme Bubble Waffle — dokunma.)

## 4) Yeni ürün ekle ("Yeni Ürün Ekle")
| Ürün | Fiyat | Kategori |
|---|---|---|
| Macchiato | 175 | Sıcak |
| Bardak Süt | 115 | Sıcak |
| Fincan Çay | 100 | Sıcak |
| Ice Caramel Macchiato | 275 | Soğuk |
| Cool Lime | 240 | Vitamin |
| Mavi Kelebek | 250 | Çaylar |

Not: Yeni ürün eklerken panel "ürün talebi/onay" akışı isteyebilir; normaldir, formu doldurup gönder.

## 5) İsim düzelt (kalem/düzenle ikonu → Ürün Adı)
- Cappucino → **Cappuccino**
- Clasic Bubble Waffle → **Classic Bubble Waffle**
- Hibiskus Çayı → **Hibiskus**
- Ev Yapımı Limonata → **Limonata**
- White Chocolate Brownie → **Brownie**
- Damla Su → **Damla Cam Şişe Su**
- Damla Sade Soda → **Sade Soda**
- Kaşarlı Sosyete Tostu → **Kaşarlı Sosyete**
- Sucuklu Sosyete Tostu → **Sucuklu Sosyete**
- Karışık Sosyete Tostu → **Karışık Sosyete**

## 6) Kategori yapısını Podyum'a eşitle (Kategoriler ekranı)
Podyum kategorileri (bu sırayla): Sıcak, Soğuk, Kokteyl, Vitamin, Waffle, Tatlılar, Çaylar, Tostlar, Meşrubat

Kategori adı değişiklikleri:
- Sıcak İçecekler → **Sıcak**
- Soğuk Kahveler → **Soğuk**
- Demleme Bitki Çayları → **Çaylar**
- Atıştırmalıklar → **Tostlar**

Yeni kategori oluştur (yoksa): **Kokteyl**, **Vitamin**, **Waffle**, **Meşrubat**

Ürünleri doğru kategoriye taşı:
- Waffle'lar (Classic/Dubai/Bitter/Caramel Bubble Waffle): Tatlılar → **Waffle**
- Kokteyller (Pink Wind, Kuzu Firarda, Apollo, Zeus): İçecekler → **Kokteyl**
- Vitamin içecekleri (Churchill, Cool Lime, Frozen, Milkshake, Limonata, Çilekli Limonata): İçecekler → **Vitamin**
- Meşrubat (Damla Cam Şişe Su, Sade Soda): İçecekler → **Meşrubat**
- "İçecekler" kategorisi boşalınca sil (veya pasife çek).
- "Bu Restoranın En Sevilenleri" (Favoriler) sistem kategorisidir, düzenlenemez — dokunma.

## Referans: Podyum menüsündeki tüm görünür ürünler (kaynak fiyat → hedef Trendyol fiyatı)
### Sıcak
Espresso 130→165 · Macchiato 140→175 · Americano 180→225 · Cortado 180→225 · Latte 190→240 ·
Caramel Latte 200→250 · Vanilla Latte 200→250 · Hazelnut Latte 200→250 · Flat White 200→250 ·
Cappuccino 190→240 · Mocha 200→250 · White Mocha 200→250 · Filtre Kahve 180→225 ·
Türk Kahvesi 130→165 · Double Türk Kahvesi 170→215 · Dibek Kahvesi 130→165 · Salep 190→240 ·
Sıcak Çikolata 190→240 · Bardak Süt 90→115 · Çay 60→75 · Fincan Çay 80→100
### Soğuk
Ice Americano 200→250 · Ice Latte 210→265 · Ice Flat White 220→275 · Ice Mocha 220→275 ·
Ice White Mocha 220→275 · Ice Caramel Latte 220→275 · Ice Caramel Macchiato 220→275 ·
Ice Hazelnut Latte 220→275 · Ice Vanilla Latte 220→275 · Ice Filtre 200→250
### Kokteyl
Pink Wind 230→290 · Kuzu Firarda 250→315 · Apollo 250→315 · Zeus 250→315
### Vitamin
Churchill 170→215 · Cool Lime 190→240 · Frozen 200→250 · Milkshake 210→265 ·
Limonata 180→225 · Çilekli Limonata 190→240
### Waffle
Classic Bubble Waffle 300→375 · Dubai Bubble Waffle 330→415 · Bitter Bubble Waffle 300→375 ·
Caramel Bubble Waffle 300→375
### Tatlılar
Brownie 290→365 · San Sebastian 290→365 · Spoonful 290→365
### Çaylar
Ihlamur 200→250 · Adaçayı 200→250 · Melisa Çayı 200→250 · Hibiskus 200→250 · Papatya 200→250 ·
Yeşil Çay 200→250 · Kış Çayı 200→250 · Mavi Kelebek 200→250
### Tostlar
Kaşarlı Sosyete 250→315 · Sucuklu Sosyete 250→315 · Karışık Sosyete 280→350
### Meşrubat
Damla Cam Şişe Su 40→50 · Sade Soda 80→100
