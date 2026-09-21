# Cactus 3B — oyun projesi

[3B Oyun Yol Haritası](../3D-OYUN-YOLHARITASI.md)'nın uygulandığı yer.
Şu an **Faz 14** bitti: düşmanlar rig'lendi ve çoğaldı — kemikli düşman
modeli, zıplayarak saldıran ve uzaktan diken atan iki yeni tür, oyuncuyla
paylaşılan rig hattı.
Yayın hâlâ sizde — [MAGAZA.md](MAGAZA.md), [CIKIS-PLANI.md](CIKIS-PLANI.md).

| Faz | Ne geldi |
|---|---|
| **0** | Godot projesi, "merhaba küp", üç platforma dışa aktarım zinciri, CI |
| **1** | Üçüncü şahıs karakter + animasyon durum makinesi, parkur bölümü, toplanabilir/tuzak/kontrol noktası/hareketli platform, bölüm akışı, davranış testleri |
| **2** | Blender varlık hattı: 5 modellenmiş nesne, ortak doku atlası, UV paketleme, glTF dışa/içe aktarım, ölçek-eksen-yoğunluk testleri, Git LFS |
| **3** | Ana menü, duraklatma, ayarlar, bitiş ekranı, ses (10 parça, sentezlenmiş), ayar/rekor kaydı, arayüz testleri, itch.io paketi |
| **4** | Durum makineli düşman + NavigationAgent3D, can/hasar/dokunulmazlık, vuruş duraklaması, ekran sarsıntısı, parçacık, zemin eğimine yatma, yapay zekâ testleri |
| **5** | Ezme mekaniği ve düşman canı, ikinci bölüm (dikey kule), bölüm kütüğü + bölüm başına rekor, betikle çekilen trailer, mağaza metni |
| **6** | Performans ölçüm hattı ve bütçe, MultiMesh birleştirme (−%40 draw call), VRAM doku sıkıştırma, iki shader, TR/EN lokalizasyon, erişilebilirlik seçenekleri, görsel çekme aracı |
| **6+** | Telefon kontrolleri: analog çubuk, zıpla/koş/duraklat, parmakla kamera |
| **7** | **Ağ uzmanlığı**: hayalet yarış (kayıt/oynatma/fark), gerçek zamanlı yarış (otorite, doğrulama, aradeğerleme tamponu), lobi, iki süreçli ağ testi |
| **8** | Ticari sürüm hazırlığı: demo yapısı, varsayılan kapalı anonim telemetri + Worker, basın kiti, çıkış planı, sürüm notları |
| **9** | İçerik ölçeği: **dört yeni bölüm**, veriden bölüm üreten hat, bitirilebilirlik doğrulayıcısı (bölüm 2'nin bitirilemez olduğunu buldu), tuş atama ekranı |
| **10** | **Otomatik oyuncu**: bölümleri gerçek girdiyle oynayan bot, denge ölçümü ve bütçesi, oyunla gelen par turları, ortak bölüm grafı |
| **11** | **Karakter**: Blender'da modellenip rig'lenen, skinning'li ve iskelet animasyonlu kaktüs; yordamsal animasyon üreticisi emekli oldu, draw call bölüm başına ~13 düştü |
| **12** | **Animasyon cilası**: iki kemikli bacak (7 → 11 kemik), ayak IK'sı (rampa/basamak), ölçüyle belirlenen adım temposu (kayma 4,3 → 2,0 kat), ayak IK testi |
| **13** | **Dünya sanatı ve aydınlatma**: paylaşılan ışık kurulumu (anahtar + dolgu, gökyüzünden ortam), gökyüzü ve dünya gölgelendiricileri, uzak manzara (mesa siluetleri + serpinti), grafik ön ayarı, görsel test |
| **14** | **Düşmanlar**: rig'li düşman (6 kemik, 7 animasyon), ortak rig hattı (`araclar/rig.py`), iki yeni tür (hoplayan, atıcı), veriden tür seçimi, mermi ve tünelleme testi |

---

## Kurulum

1. **Godot 4.7.x** indir: <https://godotengine.org/download> (kurulum gerektirmez, tek dosya).
2. Godot → **Import** → bu klasördeki `project.godot`.
3. İlk açılışta içe aktarım yapar (`.godot/` oluşur, depoya girmez).
4. **F5** ile çalıştır.

### Kontroller

| Tuş | İş |
|---|---|
| `W A S D` / yön tuşları | Hareket (kamera yönüne göre) |
| `Shift` | Koşma |
| `Space` | Zıplama — basılı tutmak yükseltir, erken bırakmak alçaltır |
| Fare | Kamera |
| `R` | Bölümü yeniden başlat |
| `Esc` | Fare kilidini bırak / geri al (tarayıcıda geri almak için sahneye tıkla) |

Oyun kolu da tanımlı: sol çubuk hareket, sağ çubuk kamera, A zıplama, LB koşma.

Tuşlar değiştirilebilir: **Ayarlar > Tuş atama**. Ok tuşları ve oyun kolu
bağlamaları her zaman duruyor, çakışan atama reddediliyor — oyuncunun kendini
oyundan kilitlemesi mümkün değil.

### Oyunun akışı

Ana menü → bölüm → (Esc ile duraklatma) → bitiş ekranı → tekrar ya da menü.
Ayarlar hem menüden hem duraklatmadan açılıyor; aynı panel, tek yerde.

### Bölümler

| # | Bölüm | Ritim |
|---|---|---|
| 1 | Kaktüs Parkuru | Yatay: dikenli tarla üstünde basamak taşları, rampa, hareketli platform, kule |
| 2 | Dikenli Kule | Dikey: spiral tırmanış, iki asansör platformu, tepede çıkış |
| 3 | Diken Köprüsü | Dar: zeminin tamamı dikenli, ilerlemenin tek yolu taştan taşa |
| 4 | Rüzgâr Terası | Ritim: dört hareketli platform (ileri, yanal, dikey, çapraz) — beklemeyi öğretiyor |
| 5 | Kaya Bahçesi | Dövüş: zemin güvenli, baskı düşmandan; beş düşman, geniş alanlar |
| 6 | Son Tırmanış | Final: yeni mekanik yok, dördünün hepsi arka arkaya |

Bölümler `betikler/bolumler.gd` kütüğünde. Yeni bölüm eklemek = kütüğe bir
satır: menüdeki düğme, "sonraki bölüm" akışı ve rekor kaydı kendiliğinden
gelir. Rekorlar bölüm başına tutuluyor. Bölüm 1 ve 2 elle yazılmış `.tscn`;
3-6 veriden üretiliyor (bkz. [Bölüm hattı](#bölüm-hattı-faz-9)).

### Bölümün amacı

8 çiçeği topla, dikenli alana düşmeden parkuru geç, sondaki altın platforma çık.
Dikenli alan seni son kontrol noktasına yollar (bayrak direkleri). Süre ve ölüm
sayısı üstte; bölüm bitince ikisi de yazılır. Yaklaşık 2–3 dakikalık bir tur.

---

## Testler

```bash
godot --headless --path oyun3d res://testler/bolum_testi.tscn    # oynanış
godot --headless --path oyun3d res://testler/varlik_testi.tscn   # varlıklar
godot --headless --path oyun3d res://testler/arayuz_testi.tscn   # menü, ayar, kayıt
godot --headless --path oyun3d res://testler/dusman_testi.tscn   # yapay zekâ, hasar, ezme
godot --headless --path oyun3d res://testler/ceviri_testi.tscn   # çeviri bütünlüğü
godot --headless --path oyun3d res://testler/hayalet_testi.tscn  # hayalet kaydı
testler/ag_testi.sh /yol/godot                                   # ağ (iki süreç)
godot --headless --path oyun3d res://testler/bolum_hatti_testi.tscn  # bölüm bitirilebilir mi
godot --headless --path oyun3d res://testler/tus_atama_testi.tscn    # tuş atama
godot --headless --path oyun3d res://testler/karakter_testi.tscn     # model, iskelet, animasyon
godot --headless --path oyun3d res://testler/ayak_ik_testi.tscn      # ayak zemine oturuyor mu
xvfb-run -a godot --path oyun3d --rendering-driver opengl3 \
  --audio-driver Dummy res://testler/gorsel_testi.tscn            # aydınlatma + manzara
godot --headless --path oyun3d res://araclar/denge_olc.tscn          # bot bölümleri oynuyor
testler/telemetri_testi.sh /yol/godot                            # gizlilik + sunucu sözleşmesi

# Bu ikisi gerçek pencere ister (bkz. Telefonda oynamak):
xvfb-run -a godot --path oyun3d --rendering-driver opengl3 --audio-driver Dummy \
  res://testler/dokunmatik_testi.tscn
```

> Testleri **`timeout` ile** koşun (CI öyle yapıyor). Bir test betiği
> derlenmezse Godot hata verip durmuyor: boş sahneyle sonsuza kadar çalışıyor.
> Asılı kalan bir test, çoğu zaman başarısız test değil, derlenmeyen testtir.

Testler `--script` ile değil **sahne olarak** koşuyor. Sebebi: `--script`
kipinde autoload'lar kurulmadan derleme yapılıyor, `Ses` ve `Ayarlar`
tanımsız kalıyor. Sahne olarak koşunca oyun gerçekte nasıl çalışıyorsa test de
öyle çalışır — zaten istenen de bu.

Pencere açmadan çalışır, davranışları **sayıyla** ölçer:

| Test | Ne kanıtlar |
|---|---|
| zemin | Karakter zemine oturuyor, kapsül yüksekliği doğru |
| zıplama | Gerçek zıplama yüksekliği ayarlanan `ziplama_yuksekligi` ile aynı |
| hız | Koşma ve yürüme hızları ayarlarla aynı, Shift gerçekten hızlandırıyor |
| rampa | Karakter eğimi tırmanıyor ve üstünde zemin algılıyor |
| tuzak | Tuzak ölüm sayıyor ve doğum noktasına yolluyor |
| toplanabilir | Çiçek sayacı artıyor; bölümde 8 çiçek var; başlangıçta 0 toplanmış |
| hareketli platform | Karakter platformla birlikte taşınıyor (fark < 0.2 m) |

Başarısızlıkta `1` döner; CI dışa aktarımdan önce bunu çalıştırıyor. Her fazın
testleri bu dosyaya birikir — Faz 2'de Blender'dan gelen modelin ölçeği ve
çarpışma kutusu için testler eklenecek.

Ekran görüntüsü kanıt değildir, sayı kanıttır: "zıplama iyi hissettiriyor"
tartışılır, "zıplama 1.68 m" tartışılmaz.

**`arayuz_testi.gd`** Faz 3'ün "görünür ama denenmesi sıkıcı" işlerini ölçer:
autoload'lar ve ses bus'ları yerinde mi, ayar diske gerçekten yazılıyor mu ve
bus seviyesine düşüyor mu, rekor doğru güncelleniyor mu (daha kötü süre rekoru
bozmamalı), Esc ağacı duraklatıyor mu, duraklatma menüsü `PROCESS_MODE_ALWAYS`
mı (değilse menü de donar ve oyun bir daha açılmaz), çiçekler eksikken bölüm
bitiyor mu, bitişte ekran açılıp rekor kaydediliyor mu.

**`dusman_testi.gd`** elle test edilmesi en pahalı şeyi ölçüyor — yapay zekâyı
görmek için oyunu açıp düşmanın yanına gitmek, beklemek, arkasından dolaşmak
gerekiyor:

| Test | Ne kanıtlar |
|---|---|
| ezme | Üstüne düşmek hasar verip sıçratıyor; **yandan çarpmak ezme sayılmıyor**; canı biten düşman sahneden kalkıyor |
| navigasyon | Örgü taze: iki nokta arasında yol var ve devriye noktası örgünün üstünde |
| devriye | Düşman devriyede hareket ediyor ve 40 m uzaktaki oyuncu yüzünden çıkmıyor |
| farketme | 20 m uzağı fark etmiyor, 6 m öndekini fark ediyor |
| saldırı | Menzile girince saldırıyor ve tam olarak `hasar` kadar can götürüyor |
| dokunulmazlık | İkinci vuruş yutuluyor, süre bitince yeniden hasar alınıyor |
| ölüm | Can bitince doğum noktasına dönülüyor, can doluyor, kısa dokunulmazlık veriliyor |

**`varlik_testi.gd`** ise Blender ile Godot arasındaki sözleşmeyi denetler —
içe aktarımda en sık sessizce kaybedilen şeyler:

| Test | Ne kanıtlar |
|---|---|
| ölçü | Godot'daki AABB, Blender'ın raporladığı ölçüyle aynı (santim/metre karışması yok) |
| eksen | Blender Z-up → Godot Y-up dönüşümü doğru; kaktüs 2.2 m **yukarı** |
| orijin | Nesnenin orijini tabanında: `y = zemin` yazınca oturuyor |
| üçgen | Sayı raporla aynı ve bütçenin altında |
| UV + doku | UV katmanı ve albedo dokusu içe aktarımdan sağ çıkmış |
| bölge | UV'ler nesneye ayrılan atlas dikdörtgeninin dışına taşmıyor |
| renk | Atlastan okunan renk, o bölgenin rengi (V ekseni hatasını yakalayan test) |
| yoğunluk | Teksel/metre Blender'ın raporuyla %15 içinde ve bantta |

---

## Otomatik oyuncu ve denge (Faz 10)

Faz 9'un bıraktığı tek açık madde şuydu: *"bölümler oynanarak dengelenmedi —
geçilebilir ile iyi aynı şey değil."* Faz 10 bunun hesaplanabilir kısmını
yapıyor: bölümleri gerçekten oynayan bir bot.

İki soru, iki araç:

| Soru | Araç | Cevap türü |
|---|---|---|
| "Bu boşluk geçilebilir mi?" | `testler/bolum_hatti_testi` | hesap: 4,2 m boşluk, 6,4 m menzil → geçilir |
| "Bu boşluk kaç denemede geçiliyor?" | `araclar/denge_olc` (bot) | ölçüm: üç denemede bir |

İkincisi denge bilgisidir ve ancak oynayarak çıkar.

### Bot gerçek girdiyle oynuyor

```gdscript
_kol.rotation.y = atan2(-fark.x, -fark.z)   # kamerayı hedefe çevir
Input.action_press("ileri", 1.0)            # ve yürü
```

Karakteri hedefe **ışınlayan** bir bot hiçbir şey kanıtlamazdı: coyote süresi,
zıplama tamponu, hava kontrolü, hareketli platformun taşıması — hiçbiri
ölçülmemiş olurdu. Oyuncu kodu girdinin bottan mı klavyeden mi geldiğini
bilmiyor; ölçtüğümüz şey oyunun kendisi.

Rota `betikler/bolum_grafi.gd`'den geliyor — Faz 9'un doğrulayıcısıyla **aynı**
graf. İki ayrı uygulama olsaydı, testin "geçilebilir" dediği bir boşluğu botun
geçememesi durumunda hangisinin haklı olduğunu anlamanın yolu olmazdı.

### Botun öğrendiği üç şey (ve öğrenirken bulunan hatalar)

- **Havada hedefe yönel.** İlk sürüm zıpladıktan sonra kalkış noktasına
  yöneliyordu; kalkış noktası arkada kaldığı için bot havada geri dönüp
  dikene düşüyordu. Zıplamanın yarısı havada yönlendirmektir.
- **Hareketli platformu bekle.** Binmek zıplamak değil beklemektir: platform
  duruşa gelene kadar durmak gerekiyor. Ayrıca platformun İKİ duruşu tek yer
  sayılmalı, yoksa platform seni taşırken bot "hedef geride kaldı" deyip geri
  dönüyor ve çiçeği alamadan iniyor.
- **Takılınca zıpla.** İleri basıp yerinden oynamıyorsan önünde bir şey var
  (rampanın yan duvarı). Gerçek oyuncu ne yaparsa: önce zıpla, olmazsa başka
  yol dene.

Bot yazarken oyunda değil **modelde** bir hata da çıktı: eğik rampa tek eksen
hizalı kutuyla temsil edilince "üst"ü en yüksek köşe oluyor ve rampa zeminden
4,1 m yukarıda görünüyordu — oysa alçak ucundan yürüyerek çıkılıyor. Artık eğik
kutular eğim ekseni boyunca parçalara bölünüyor.

### Par turu

Botun turu `res://hayaletler/` altına kaydedilip oyunla birlikte geliyor:

```bash
godot --headless --path oyun3d res://araclar/denge_olc.tscn -- --par
```

Faz 7'nin hayalet yarışı yalnızca kendi turunla yarıştırıyordu, yani bölümü ilk
kez oynayan kimseyle yarışmıyordu ve ekrandaki fark satırı boş duruyordu. Artık
ilk turda botun par turu çıkıyor; kendi turun daha hızlıysa hayalet ona dönüyor.
HUD hangisiyle yarıştığını yazıyor: `par turu −1,20` ya da `hayalet +0,40`.

### Ölçüm (bugünkü bot)

```
bolum1   bitişte    47.6 sn   2 ölüm   6/8 çiçek
bolum2   TAKILDI   110.0 sn  30 ölüm   3/10        ← kuleyi tırmanamıyor
bolum3   bitişte    45.5 sn   7 ölüm   5/8
bolum4   bitişte    43.7 sn   4 ölüm   7/9
bolum5   TAKILDI    62.8 sn   1 ölüm   5/10        ← kayanın üstünde takılıyor
bolum6   TAKILDI   110.0 sn  11 ölüm   5/12
```

Altısının tamamı **11 saniyede** ölçülüyor: `--fixed-fps 60` gerçek zaman
senkronizasyonunu kapatıyor, yani 47 saniyelik bölüm 1,5 saniyede oynanıyor.
Bu olmadan ölçüm gerçek zamanda ~8 dakika sürüyordu ve CI'a giremezdi.

Bot bölüm 2, 5 ve 6'da bitişe ulaşamıyor. **Bu botun sınırı, bölümlerin hatası
değil**: bitirilebilirlik `bolum_hatti_testi` tarafından ayrıca hesapla
kanıtlanıyor. `denge_butce.json` bunu böyle yazıyor (`bitis_bekleniyor: false`)
ve o bölümlerde ölçüt "daha kötüye gitmesin"e dönüşüyor. Botun tırmanamadığı
kule yine de bir işaret: bölüm 2 insan için de en zoru ve ilk bakılacak yer
orası.

### Botun bulduğu gerçek hata: her karede `visible`

Ölçüm hayaletli bölümde **60 kat** yavaşladı. Sebep oyunda çıktı:

```gdscript
visible = not durum["bitti"]   # her karede, değer değişmese bile
```

Görünürlük Godot'da alt ağaca yayılıyor; aynı değeri her karede atamak ucuz
değil. Tek satırlık düzeltme (`if visible != gorunur`) ölçümü 120 saniyeden
1 saniyeye indirdi. Bu, gerçek cihazda da hayalet oynarken ödenen bir bedeldi
ve kimse fark etmemişti — bot oyunu binlerce kare boyunca oynamasa
görülmezdi. Profilleyici olmadan bulunan bir kare bütçesi hatası.

### Sayılar ne anlatıyor, ne anlatmıyor

`denge_butce.json` bölüm başına süre ve ölüm sınırı tutuyor; aşılırsa CI
kırmızıya dönüyor. Bu sayılar **insan süresi değil** — botun 40 saniyede
bitirdiği bölümü insan 2-3 dakikada bitirir. İşleri bölümün DEĞİŞTİĞİNİ
yakalamak: aynı bot dün 40 saniyede bitirdiği bölümü bugün 90 saniyede
bitiriyorsa bölüm zorlaşmış demektir.

> **Bot, oyun testinin yerine geçmez.** Eğlenceyi ölçmüyor, kafa karışıklığını
> ölçmüyor, "buradan sonra bıraktım" demiyor. Ölçtüğü şey bitirilebilirlik ve
> sürtünme. Yol haritasının dediği hâlâ geçerli: 20 kişiye oynat, izle.

---

## Bölüm hattı (Faz 9)

"İki bölüm bir demo, altı bölüm bir oyun." Faz 9'un işi içerik ölçeği — ama
dört bölümü elle yazmak, her birinin 350 satırlık `.tscn`'ini kopyalamak
demekti. O 350 satırın ~250'si her bölümde AYNI: HUD, duraklatma, bitiş ekranı,
hayalet kaydedici, birleştirici, ortam, zemin. HUD'a bir etiket eklemek altı
dosyayı elle düzeltmek olurdu.

Bu yüzden tekrar eden kısım **kod**, bölüme özgü kısım **veri** oldu:

```
bolum_tasarimi/bolum3.gd   (koordinatlar + tasarım gerekçesi)
        │
        ▼  godot --headless --path oyun3d res://araclar/bolum_uret.tscn
sahneler/bolum3.tscn       (üretilmiş sahne — elle düzenlenmez)
        │
        ▼  res://araclar/navmesh_uret.tscn      (navigasyon örgüsü)
        ▼  res://testler/bolum_hatti_testi.tscn (bitirilebilir mi?)
        ▼  res://araclar/olcum.tscn             (performans bütçesi)
```

Veri dosyası düz bir sözlük: platformlar, hareketli platformlar, çiçekler,
kontrol noktaları, düşmanlar, süsleme, gökyüzü renkleri. JSON değil GDScript,
çünkü **yorum satırı** yazılabiliyor: "bu boşluk 4,5 m, koşarak geçilir" bilgisi
koordinatın yanında durmazsa altı ay sonra kimse hatırlamıyor.

> **Bölüm 1 ve 2 bilerek elle kaldı.** Yayınlanmış, testleri olan ve elle
> ayarlanmış iki bölümü yeniden üretmenin kazancı yok, riski var. Hattın işi
> yeni bölümler.
>
> **Üretilen sahneler elle düzenlenmez** — bir dahaki çalıştırmada üzerine
> yazılır. Kök düğümde `uretildi` üst verisi bunu söylüyor. Bir bölümü elden
> geçirmek isterseniz veri dosyasını silin; `.tscn` artık sizindir.

### Bitirilebilirlik doğrulayıcısı

Hattın asıl değeri üretim değil, **doğrulama**. Bir bölümü elle oynayıp
"geçilebiliyor" demek, o bölümü her değiştirdiğinde baştan oynamak demek;
dördüncü bölümden sonra kimse yapmıyor.

`testler/bolum_hatti_testi.gd` bitirilebilirliği oynayarak değil hesaplayarak
doğruluyor:

1. **Duraklar** çıkarılıyor: platformların çarpışma kutuları, zemin ve
   hareketli platformların iki duruşu.
2. **Kenarlar** kuruluyor: "buradan şuraya zıplanabilir mi?" Menzil, oyuncunun
   kendi dışa aktarım değerlerinden hesaplanıyor (zıplama yüksekliği 1,65 m,
   koşu hızı 7,4 m/sn, düşme çarpanı 1,35, projenin yerçekimi). Sabit yazsaydım
   zıplama ayarı değiştiğinde test yalan söylemeye başlardı.
3. **Genişlik-öncelikli arama** doğuş noktasından bitişe yol arıyor; çiçekler ve
   kontrol noktaları da erişilebilir bir durağın üstünde olmalı — çiçeklerin
   hepsi toplanmadan bitiş açılmıyor, yani ulaşılamayan tek çiçek bölümü
   bitirilemez yapıyor.

**İlk çalıştırmada bölüm 2'nin BİTİRİLEMEZ olduğunu buldu.** Başlangıç
platformundan en yakın basamak 15 m ötede, diğerleri 5 m yukarıdaydı; zeminin
tamamı dikenli olduğu için inmek de ölüm. Oyun yayına hazırlanıyordu ve ikinci
bölümü kimse baştan sona oynamamıştı (README'de "bölüm 2 dengelenmedi" diye
yazıyordu — dengesizlikten fazlasıymış). Kule tabanına dört giriş taşı eklendi.

Doğrulayıcı üç kez de KENDİ hatasını gösterdi, bunlar modelin sınırları:

- **Dikey paya yer yok.** Yatayda pay bırakmak doğru (hava ivmesi sınırlı), ama
  dikeyde zıplama yüksekliği deterministik. 15 cm pay bırakınca bölüm 1'in
  ilk basamağı (1,55 m) "zıplanamaz" çıkıyordu; oyun yayında ve o basamak
  geçiliyor. Testin gerçeğe uyması gerekiyor, tersi değil.
- **Hareketli platform tek durak değil.** Süpürdüğü alanı tek kutu saymak
  "asansöre zıplanamıyor" diyordu: asansöre ALT ucunda binilir, ÜST ucunda
  inilir. İki duruş ayrı durak, aralarında bedava kenar (binmek = beklemek).
- **Ölçüm anı.** `baslangic_fazi` sıfırdan farklı platformlar daha ilk fizik
  karesinde turun ortasına kayıyor; oradan süpürmek yanlış alan veriyordu.
  Turun başlangıç konumuna geri çekiliyor.

### Bölüm tasarımı: ölçüler

Veri yazarken kullanılan sayılar (hepsi `oyuncu.gd`'den):

| Ölçü | Değer | Sonuç |
|---|---|---|
| Zıplama yüksekliği | 1,65 m | Basamak yükselmesi **1,4 m**'yi geçmiyor |
| Koşu hızı | 7,4 m/sn | Düz boşluk teorik 6,4 m; veride **4,5 m**'yi geçmiyor |
| Yürüme hızı | 4,2 m/sn | Isınma bölümlerinde boşluk **2,5 m** civarı |
| Düşme çarpanı | 1,35 | Yukarı zıplayışta menzil kısalıyor (dy 1,4 m'de 4,6 m) |

---

## Ticari sürüm hazırlığı (Faz 8)

Faz 8'in işi kod kadar **karar**: neyi ölçeceğin, neyi paylaşacağın, ne zaman
yayınlayacağın. Üçü de depoda yazılı — `CIKIS-PLANI.md` (geri sayım takvimi),
`SURUM-NOTLARI.md` (sürüm geçmişi), `MAGAZA.md` (mağaza metni), `basin/`
(basın kiti).

### Demo sürümü

Demo ayrı bir kod dalı **değil**: aynı yapının `demo` özellik etiketiyle dışa
aktarılmış hâli (`export_presets.cfg.ornek` içindeki 3 ve 4 numaralı ön
ayarlar). `Urun.demo` açıkken:

- `Bolumler.liste()` yalnızca ilk bölümü döndürüyor — bölüm sayacı, "sonraki
  bölüm" düğmesi ve bitiş ekranı bu listeden besleniyor, dolayısıyla tek yerden
  kısıtlamak yetiyor;
- ana menüde "demo" alt başlığı, bitişte tam sürüm notu çıkıyor;
- `Urun.MAGAZA_URL` doluysa dilek listesi düğmesi görünüyor, boşsa gizleniyor.

> **Neden ayrı dal değil:** ayrı demo dalı tutmak, demoyu güncellemeyi
> unutmanın en kısa yolu. Aynı yapıdan dışa aktarınca oyun düzelince demo da
> düzeliyor. Karşılığında bir risk var: demo yapısı tam sürümün içeriğini de
> taşır. Bu yüzden kısıtlama **içerik listesinde**, bölüm dosyalarında değil —
> ileride ücretli bölümler eklenirse demo ön ayarına `exclude_filter` de
> gerekecek.

`arayuz_testi.gd` demo kipini açıp bölüm sayısını, "sonraki bölüm" davranışını
ve demo notunu ölçüyor. Test olmasaydı demoyu ancak dışa aktarıp oynayarak
görebilirdin.

### Anonim telemetri (varsayılan kapalı)

Faz 8'in asıl sorusu: **demo nerede kopuyor?** Yirmi kişiyi omzundan izlemek en
iyi yöntemdir ama ölçeklenmez; ölüm haritası ölçeklenir.

Gizlilik üç kuralla korunuyor ve üçü de kodda:

1. `Ayarlar.telemetri` varsayılan `false` — açık rıza gerekiyor.
2. `Urun.TELEMETRI_URL` depoda boş; boşken `Telemetri.etkin_mi()` false, hiçbir
   olay kuyruğa bile girmiyor.
3. Oturum numarası her açılışta yeniden üretiliyor ve **diske yazılmıyor**:
   iki oturum birbirine bağlanamıyor. Ad, e-posta, IP, cihaz kimliği, konum yok.

Rıza yokken olayın kuyruğa **hiç girmemesi** bilinçli: sonradan rıza verilince
geçmişin gönderilmesi, rızanın anlamını ortadan kaldırırdı.

Sunucu tarafı `sunucu/` altında (Cloudflare Worker + D1). Şema sabit sütunlu,
çünkü **şema gizlilik sözleşmesinin kendisi**: IP veya cihaz kimliği için sütun
yoksa oraya yazılamaz. Olay adları beyaz listede; listede olmayan bir ad gelirse
parti tümden reddediliyor.

> **Tuzak — sessiz sözleşme kayması.** İstemci ile sunucu iki ayrı dilde. Bir
> alan adını oyunda değiştirip sunucuda değiştirmezsen parti sessizce düşer ve
> bunu haftalar sonra "hiç veri gelmiyor" diye fark edersin. Bu yüzden
> `testler/telemetri_testi.sh`, oyunun ürettiği **gerçek gövdeyi** alıp
> Worker'ın **kendi doğrulayıcısından** geçiriyor ve koddaki `Telemetri.olay`
> çağrılarının adlarını sunucunun beyaz listesiyle karşılaştırıyor. Beyaz
> listeden bir adı bilerek bozunca test kalıyor — denendi.

### Basın kiti

`basin/index.html` — tek dosya, çerçevesiz, TR/EN. Künye, açıklama, yedi
1920×1080 ekran görüntüsü, kullanım izni. İzin metni kritik: içerik
üreticileri **para kazandıkları** videoda kullanıp kullanamayacaklarını bilmek
ister; "serbestçe kullanabilirsiniz, telif talebi göndermiyoruz" cümlesi
olmayan bir basın kiti işe yaramaz.

Görseller `araclar/gorsel_cek.gd` ile üretiliyor; elle ekran görüntüsü almakla
farkı, bölüm değişince aynı komutun aynı kadrajları yeniden üretmesi:

```bash
xvfb-run -a godot --path oyun3d --rendering-driver opengl3 --audio-driver Dummy \
  --resolution 1920x1080 res://araclar/gorsel_cek.tscn
cp "$HOME/.local/share/godot/app_userdata/Cactus 3B/gorseller/"*.png oyun3d/basin/gorseller/
```

> **Tuzak — basın kiti oyunun içine giriyordu.** `basin/` klasörü Godot
> projesinin içinde; Godot yedi ekran görüntüsünü doku olarak içe aktarıp
> `.pck`'ye koyuyordu. Web paketi 12,2 MB'tan **8,9 MB**'a indi: klasöre
> `.gdignore` konunca Godot orayı hiç görmüyor. Oyunun yanında duran her klasör
> oyunun parçası değildir — ama Godot'ya söylemezsen öyle sanır.

> **Neden JPEG değil PNG:** `.gitattributes` `oyun3d/**/*.jpg` dosyalarını Git
> LFS'e yolluyor; basın kiti görselleri LFS'e girerse GitHub Pages'te işaretçi
> dosyası servis edilir ve sayfa kırık görsellerle açılır. PNG bilerek LFS
> dışında (üretilen doku atlası da öyle). Yedi kare toplam 2,3 MB; kayıpsız ve
> renkler doğru — 256 renge indirip küçültmeyi denedim, bayraklar sarıdan
> turuncuya kaydı.

---

## Hayalet yarış (Faz 7)

> **Faz 11 notu:** hayalet artık oyuncuyla **aynı modeli** kullanıyor (saydam,
> gölgesiz malzeme). Silueti farklı olan hayalet, yarıştığın şeyin "sen"
> olmadığını söylüyordu. Animasyonunu kayıttaki hız sürüyor: duruyorsa boşta,
> yürüyorsa yürüme, koşuyorsa koşma — durum makinesi yok, iki eşik yetiyor.


En iyi turunuz kaydediliyor ve bir dahaki sefere onunla yarışıyorsunuz.
Ekranın üstünde fark yazıyor: **eksi = hayaletin önündesiniz**.

**Kayıt biçimi** (`betikler/ag/hayalet_kayit.gd`): 20 Hz'de konum, yön ve hız.
60 saniyelik tur ≈ 24 KB. Her kareyi kaydetmek üç kat büyütür ve hiçbir şey
kazandırmaz — aradaki değerler doğrusal aradeğerlemeyle geri geliyor. Ağ
üzerinden taşınacak veride "ne kadar sık" her zaman ilk sorudur; bu yüzden
hayalet, gerçek zamanlı yarışın da provası.

**Fark nasıl hesaplanıyor:** oyuncunun BULUNDUĞU yerde hayaletin saati kaçtı?
Kayıttaki en yakın örneğin zamanı ile şimdiki süre arasındaki fark. Arama
baştan değil, bir önceki eşleşmenin çevresinden başlıyor — oyuncu parkurda
ilerlediği için önceki eşleşme iyi bir tahmin.

Kayıt yalnızca **daha hızlı** turda değişiyor: hayalet "geçilmesi gereken en
iyi tur" olmalı, "en son tur" değil.

## Gerçek zamanlı yarış

Ana menü → **Yarış (ağ)** → *Barındır* ya da adresi yazıp *Katıl*. Barındıran
*Yarışı başlat*'a basınca herkes bölüme geçiyor; rakipler turuncu renkte ve
adları üstlerinde görünüyor.

### Otorite modeli — ve sınırı

Her oyuncu **kendi** karakterini simüle ediyor (istemci otoritesi). Sunucu
gelen konumu doğruluyor: iki paket arasında fiziğin izin verdiğinden hızlı
gidilmişse paket **reddediliyor**.

Bu tam bir hile koruması **değil** ve öyleymiş gibi yazmıyorum: gerçek koruma,
sunucunun kendi simülasyonunu koşturup istemciyi düzeltmesidir
(server-authoritative + reconciliation). Buradaki model ışınlanmanın ve kaba
hız hilesinin önünü kesiyor, yarış oyununda kabul edilebilir bir denge.

**Meşru ışınlanma:** ölünce kontrol noktasına dönmek de "iki paket arasında
30 metre" demek. Sunucuya bildirilmezse oyuncunun her ölümü hile sayılıyor ve
paketleri düşüyor — rakiplerin ekranında donuyor. `Ag.yerel_isinlanma()` bunu
bildiriyor; kötüye kullanılmasın diye 1.5 saniyede birden sık bildirimler yok
sayılıyor.

### Gecikme

Uzak oyuncular **120 ms geriden** oynatılıyor. Tampon olmadan her kayıp
pakette karakter zıplıyor; tamponla elde hep aradeğerlenecek iki örnek
kalıyor. Gördüğünüz şey rakibin gerçekten bulunduğu yer — 120 ms öncesi.

Uzak karakteri yerel olarak simüle etmek (dead reckoning) daha akıcı görünürdü
ama iki taraf ayrışınca karakter "kayarak" düzelir. Yarışta dürüstlük akıcılıktan
önemli.

### Neden `MultiplayerSynchronizer` değil

Durum paketleri elle gönderiliyor. Sebep öğrenme değil denetim: kimin neye
yetkili olduğu, paketin hangi sıklıkta gittiği ve geç gelen paketin ne olacağı
`ag.gd`'de okunabiliyor. Synchronizer bunları gizler; gizlenen şeyi hata
ayıklayamazsınız.

### Ağ testi — iki süreç

```bash
testler/ag_testi.sh /yol/godot
```

Bir Godot sunucu, bir Godot istemci, 127.0.0.1. Ağ kodu tek süreçte test
edilemez: asıl sorular (paket geç gelirse, kaybolursa, **sahte** gelirse ne
olur) ancak iki süreç arasında sorulabiliyor. Bu yüzden diğerleri gibi sahne
değil, kabuk betiği.

Sunucu bilinen bir yol izliyor (5 m yarıçaplı çember); istemci aldığı
konumların çember üstünde olup olmadığına bakıyor — iki sürecin saatlerini
eşitlemeye gerek kalmadan. Ölçülenler: paketler geliyor mu, yarıçap hatası
(< 0.5 m), ardışık kareler arası en büyük adım (< 1 m, ışınlanma yok),
ve sunucunun gönderdiğim **hile paketini** reddedip masum paketleri
reddetmediği.

> Bu son ölçüt bir hata yakaladı: doğrulama, geçen süreyi paketin VARIŞ
> zamanından hesaplıyordu. Ağ dalgalanmasıyla iki paket aynı karede gelince
> "0.001 saniyede 0.25 metre" çıkıp masum paketler reddediliyordu. Yanlış
> pozitif veren doğrulamayı kimse açık bırakmaz, kapatır — o yüzden tabanı
> gönderim aralığının yarısına çekmek güvenliğin kendisi.

### Açık kalan uçlar

- **NAT geçişi yok.** Aynı ağdaki iki cihaz ya da port yönlendirme gerekiyor.
  İnternet üzerinden oynatmak için aracı sunucu (relay) ya da eşleştirme
  servisi lazım — Cloudflare Worker'ınız bu iş için doğal aday.
- **Sunucu simülasyonu yok** (yukarıdaki otorite sınırı).
- **Skor tablosu çevrimdışı.** Hayaletler yalnızca `user://` altında; sunucuya
  yükleyip başkasının hayaletiyle yarışmak bir sonraki adım.

---

## Telefonda oynamak

Oyun ekrandaki kontrollerle telefonda oynanır. Aynı derleme masaüstünde de
çalışır: kontroller **ilk dokunuşta** görünür, klavyeye veya oyun koluna
dönülünce kaybolur. Oyuncuya "mobil sürüm" diye ayrı bir şey sunulmuyor.

| Bölge | Ne yapar |
|---|---|
| Sol yarı | Parmağın indiği yer çubuğun merkezi olur; ittiğin yöne yürür |
| Sağ yarı | Sürükleyerek kamera |
| Sağ alt | **ZIPLA** (basılı tutmak yükseltir) ve **KOŞ** (aç/kapa) |
| Sağ üst | Duraklat (telefonda Esc yok) |

**Girdi kodu hiç değişmedi.** Çubuk ve düğmeler aynı eylemleri basıyor
(`Input.action_press`), kamera sürüklemesi `Girdi.bakis_kaydi` sinyalinden
geçiyor. `oyuncu.gd`'ye tek satır dokunulmadan telefon desteği eklendi —
Faz 1'de girdiyi soyutlamanın karşılığı buydu.

Çubuk **analog**: yarım itersen yarım hızda yürürsün. Bunun için `oyuncu.gd`
artık girdinin yalnızca yönünü değil boyunu da kullanıyor (klavyede boy zaten
1, orada bir şey değişmiyor).

İki ayar gerekliydi:
- `pointing/emulate_mouse_from_touch=false` — açık kalırsa çubuğu sürüklemek
  aynı anda fare hareketi üretiyor ve kamerayı da döndürüyor.
- Telefonda fare kilidi istenmiyor (`DisplayServer.is_touchscreen_available()`);
  tarayıcıda yakalamaya çalışmak hata veriyor.

```bash
# Dokunmatik testi GERÇEK PENCERE ister, --headless ile çalışmaz
xvfb-run -a godot --path oyun3d --rendering-driver opengl3 \
  --audio-driver Dummy res://testler/dokunmatik_testi.tscn
```

Başsız kipte pencere boyutu (0,0) ve `canvas_items` esneme dönüşümü dokunuş
koordinatlarını 20 katına çıkarıyor: (200,500) ekrana (4000,10000) olarak
geliyor. Bu testi yazarken yarım saat "çubuk neden çalışmıyor" diye aradım;
cevap oyunda değil, test ortamındaydı.

> **Tuzak — sabit sayıda kare beklemek.** Testin "klavyeye dönünce kontroller
> gizleniyor mu" adımı bir süre sonra kalmaya başladı; oyunda değişen bir şey
> yoktu. Sebep: girdi olayları **idle** karesinde işleniyor, test ise **fizik**
> karesi sayıyor. Yazılımsal GPU'da tek idle karesi 4–5 fizik karesi sürüyor,
> "3 kare bekle" yetmiyor. Sabit bekleme testi makinenin hızına bağlar; bunun
> yerine `_bekle_kosul()` koşul sağlanana kadar (en fazla 40 kare) bekliyor.
> Yavaş makinede kalan bir test, çoğu zaman yavaş makineyi bulmuş demektir —
> ama burada bulduğu şey oyunun değil, testin kusuruydu.

### Sizde kalan: gerçek cihaz

APK bu ortamda alınamıyor (Android SDK indirilemiyor). Sizin makinenizde:
Godot → Editör Ayarları → Export → Android'e SDK yolunu ve debug keystore'u
tanıtın, sonra `Android` ön ayarıyla dışa aktarın. Telefonda bakılacaklar:

- Düğme boyutları parmağa uyuyor mu (küçük telefonda ZIPLA'ya rahat basılıyor mu)
- Kare hızı — 105 draw call sorun çıkarmamalı ama termal kısıtlamayı ancak
  gerçek cihaz gösterir
- Çentik/kavisli ekranlarda düğmeler kenara sıkışıyor mu

---

## Ölçüm ve optimizasyon (Faz 6)

```bash
xvfb-run -a godot --path oyun3d --rendering-driver opengl3 \
  --audio-driver Dummy res://araclar/olcum.tscn
```

Her bölümü yükleyip 90 kare örnekliyor ve `performans_butce.json`'daki bütçeyle
karşılaştırıyor; aşılırsa çıkış kodu 1 (CI kırmızı).

**FPS ölçmüyoruz.** Bu makinenin GPU'su yok (yazılımsal llvmpipe); ölçülen kare
süresi kimsenin donanımını temsil etmez. Ölçülenler donanımdan bağımsız: draw
call, üçgen sayısı, doku belleği. Bunlar düşerse her donanımda düşer.

### Ne yapıldı, ne kazanıldı

| Değişiklik | bolum1 | bolum2 |
|---|---|---|
| Başlangıç | 137 draw call | 175 |
| Çiçeklerin gölgesi kapatıldı + MultiMesh birleştirme | 85 | 109 |
| Tuzak shader'ı (gölge yok) | **82** | **105** |

**MultiMesh birleştirme** (`betikler/birlestirici.gd`): editörde her platformu
ve süslemeyi ayrı düğüm olarak yerleştirmek doğru — taşıyorsun, ölçüsünü
değiştiriyorsun, görüyorsun. Ama her düğüm en az bir draw call, gölge açıksa
iki. Oyun çalışırken bunlar mesh'e göre gruplanıp tek `MultiMeshInstance3D`'ye
iniyor. Renk farkı, örnek renkleri (`use_colors`) ve malzemede
`vertex_color_use_as_albedo` ile korunuyor.

Bunun için `platform.tscn` ortak bir `birim_kutu.tres` kullanıyor ve ölçü
mesh'in boyutuna değil düğümün ölçeğine yazılıyor: her platformun kendi mesh'i
olsaydı gruplanamazlardı.

**Doku:** atlas VRAM sıkıştırmalı (S3TC + ETC2) ve mipmap'li; diskte 4.1 MB.
Ölçümde 40 MB görünmesinin sebebi yazılımsal Mesa'nın S3TC desteklememesi ve
dokuyu açması — **gerçek donanımda 4 MB**. Bu yüzden `doku_mb` bütçeye dahil
değil. Gölge atlası 4096'dan 2048'e (mobilde 1024) indirildi.

## Dünya sanatı ve aydınlatma (Faz 13)

Faz 12'de karakter düzeldi; durduğu dünya hâlâ düz kum rengi kutulardı. Tek
yönlü ışık, gölgede tek tona düşen yüzler, üç renkli düz bir gökyüzü ve
140 metrede keskin bir çizgiyle biten zemin. Hepsi her karede görünüyordu,
hiçbir test görmüyordu.

### Aydınlatma tek yerden

Altı bölüm aynı `sahneler/ortam.tscn` örneğini kullanıyor. Bölüme özel olan
yalnızca **sanat yönü** — gök renkleri, sis, güneş açısı, bulut miktarı;
teknik kurulum ortak. Önceden ikisi elle yazılmış sahnede, dördü üreticideydi:
gölge ayarını değiştirmek altı yerde aynı değişikliği yapmaktı ve biri
unutulunca "neden burası daha karanlık?" sorusunun cevabı olmuyordu.

| Karar | Neden |
|---|---|
| **Anahtar + dolgu** ışık | Tek ışıkta gölgede kalan iki yüz de aynı tona düşüyor, kutunun kenarı kayboluyor. Dolgu (gökyüzü renginde, 140° yandan, gölgesiz) o yüzleri ayırıyor |
| Ortam ışığı **gökyüzünden** | Gölgeler siyaha değil gökyüzünün mavisine düşüyor. Sabit bir ortam rengi bunu yapamaz |
| Gölge kademeleri 0,055 / 0,15 / 0,38, en uzak **65 m** | Kamera 5 m arkada; keskinlik ilk 4 metrede gerekiyor. Godot'nun varsayılanı bu kadrajda yakını bulanıklaştırıyordu. 65 m'den ötesini zaten sis yutuyor |
| `fog_aerial_perspective = 0.4` | Uzak yüzeyler gökyüzünün rengine kayıyor; derinlik hissi buradan geliyor. Tek renkli sis, arkadaki kayayı öndekiyle aynı tonda boyuyordu |
| `fog_sky_affect = 0.0` | Gökyüzünün kendi degradesi ve bulutu var; üstüne sis binince ufuk düz bir lekeye dönüyor |

### Üç gölgelendirici, üç iş

**`golgeler/gok.gdshader`** — degrade + bulut bandı + güneş diski. Bulutlar
üç oktav değer gürültüsü; ufka doğru sönüyorlar, çünkü çizgide kesilen bulut
"duvar kâğıdı" gibi duruyor. Gökyüzü kare başına bir kez ve derinlik testi
olmadan çiziliyor: ekranın üçte birini doldurmanın bedeli neredeyse yok.

**`golgeler/dunya.gdshader`** — kutulara yüzey veriyor. Üç katman, üçü de
ayrı bir işi görüyor: dünya uzayında üç eksenli gürültü (düz renk olmaması),
yan yüzlerde yatay tabakalar (kaya hissi), ve **kutunun dibine doğru
karartma** — yığılmış kutuların birbirinden ayrılmasını sağlayan şey bu.

> **Neden doku değil:** kutular farklı ölçeklerde; her birine doku açmak UV,
> atlas ve gerilme demekti. Desen dünya KONUMUNDAN üretilince bitişik iki kutu
> aynı desenin devamını taşıyor ve ölçek değişince desenin sıklığı değişmiyor.
> Kutunun kendi tabanından yükseklik `MODEL_MATRIX`ten çıkıyor, bu yüzden
> MultiMesh'te birleştirilmiş platformlarda da doğru çalışıyor.

> **TUZAK — birleştirici ShaderMaterial'ı tanımıyordu.** `birlestirici.gd`
> malzemeyi `as BaseMaterial3D` ile alıp `vertex_color_use_as_albedo`
> açıyordu; ShaderMaterial'da o alan yok, dönüştürme `null` veriyor ve
> malzeme SESSİZCE kayboluyordu — bütün platformlar varsayılan beyaza
> dönüyordu. Artık iki tür de destekleniyor: renk çarpımını gölgelendirici
> kendi yapıyor (`renk * COLOR`), birleştirici yalnızca taban rengi beyaza
> çekiyor.

### Uzak manzara

`betikler/manzara.gd` üç katman kuruyor: ufku kapatan geniş zemin, 24 mesa
silueti ve serpiştirilen kaya/kaktüs. Önceden zemin 140 metrede keskin bir
çizgiyle bitiyordu; oyun "bir masanın üstünde" geçiyormuş gibi duruyordu.

- **Çarpışmasız — bu bir süs değil kural.** Bölümün ulaşılabilirlik grafı
  (`bolum_grafi.gd`) çarpışma kutularından çıkıyor. Manzaraya çarpışma
  eklemek bölüm doğrulayıcısını ve botu sessizce yanıltırdı: "şuraya
  zıplanabiliyor" diyen bir kaya. `gorsel_testi` bunu her koşuda doğruluyor.
- **Oyun alanının dışına.** Serpinti, bütün çarpışma kutularının sardığı
  kutunun (zemin hariç) 7 metre dışına konuyor — oyuncunun gittiği yere
  değil arkasına.
- **Her açılışta aynı.** Yerleşim bölüm kimliğinden gelen tohumdan üretiliyor;
  rastgele olsaydı ekran görüntüsü ve görsel testi anlamını yitirirdi.
- **Dikenli zeminde serpinti yok.** Ölümcül zemine kaktüs dikmek "buraya
  basılabilir" diyor; görsel süs, oynanış işaretini bozamaz.

### Grafik ön ayarı

Ayarlar panelinde düşük / orta / yüksek. Oyun içinde anında uygulanıyor —
oyuncu duraklatma menüsünde farkı görmeli, yeniden başlatmamalı.

| | düşük | orta | yüksek |
|---|---|---|---|
| gölge | – | ✓ | ✓ |
| dolgu ışığı | – | ✓ | ✓ |
| serpinti | – | yarısı | tamamı |
| parlama (glow) | – | – | ✓ |
| SSAO | – | – | ✓ (yalnızca Forward+) |

İlk açılışta tarayıcı ve mobil **orta**, masaüstü **yüksek** başlıyor.
Parlamanın orta ön ayarda kapalı olması ölçülmüş bir karar: Compatibility
yolunda ekran boyu bir mip zinciri açıyor (~11 MB doku belleği) ve bu stilde
kazancı süs düzeyinde.

> **Web kısıtı belirleyici oldu.** Oyunun ana dağıtımı tarayıcı; orada
> Compatibility render yolu çalışıyor ve **SSAO yok**. Bu yüzden derinlik
> ekranda değil MALZEMEDE üretildi: dip karartması, havadan perspektifli sis,
> dolgu ışığı. Üçü de hem masaüstünde hem tarayıcıda aynı çalışıyor.

## Shader'lar

`golgeler/` altında dört shader, dördü de `gl_compatibility` (tarayıcı) ile
uyumlu (`dunya.gdshader` ve `gok.gdshader` yukarıda anlatıldı):

**`tuzak.gdshader`** — dikenli alanda kayan uyarı şeritleri ve nabız.
Erişilebilirlik gerekçesi: tehlike yalnızca kırmızıyla anlatılırsa kırmızı-yeşil
renk körü oyuncu (erkeklerin ~%8'i) zemini tehlikeden ayıramaz. Şerit deseni
renkten bağımsız ikinci bir işaret. Desen dünya koordinatına göre çiziliyor;
UV'ye göre olsaydı 90 m'lik alanda şeritler metrelerce genişlerdi.

**`erime.gdshader`** — yenilen düşman eriyerek kayboluyor. Gürültü dokudan
değil üç satırlık bir karma fonksiyonundan geliyor: ek doku belleği ve içe
aktarım derdi yok. Her düşman malzemenin kendi kopyasını alıyor, yoksa biri
diğerinin erimesini sürüklerdi.

## Lokalizasyon ve erişilebilirlik

Çeviriler `arayuz/ceviriler.csv` (79 anahtar, TR + EN). Godot Control
düğümlerinin metnini kendiliğinden çeviriyor, o yüzden sahnelerde düz metin
yerine anahtar yazılı (`text = "DURAKLAT_DEVAM"`). Kodda üretilen metinler
`tr("HUD_DURUM") % [...]` biçiminde.

Ayarlar ekranından değiştirilenler: dil, ana ses / efekt / müzik, fare
hassasiyeti, tam ekran, **ekran sarsıntısı** (hareket hassasiyeti olanlar için;
kapatmak oynanışı değiştirmiyor) ve **tuş atama**.

### Tuş atama (Faz 9)

Erişilebilirlikte en çok istenen madde: WASD herkese uymuyor — sol elini
kullananlar, tek elle oynayanlar, AZERTY düzeni. "Ok tuşları da var" cevabı
yeterli değil, çünkü zıplama ok tuşlarında yok.

Sekiz eylemin **birincil** tuşu değiştirilebiliyor. İki kilit var ve ikisi de
"oyuncu kendini oyundan kilitleyemesin" diye:

- **İkincil tuşlar ve oyun kolu bağlamaları hiç silinmiyor.** `tuslari_uygula()`
  yalnızca `InputEventKey` olaylarını temizliyor; kumandayla oynayan biri tuş
  atama ekranını açtığı an kumandasını kaybetmemeli.
- **Çakışan atama reddediliyor**, sessizce çözülmüyor. Diğer eylemi boşaltmak
  kolay olurdu ama oyuncu hangi tuşu kaybettiğini fark etmeden kaybederdi.

Atamalar `Ayarlar.tuslar` içinde (`user://ayarlar.cfg`). `Girdi` bunları
kendisi okumuyor: autoload sırasında Girdi, Ayarlar'dan ÖNCE hazırlanıyor, o
yüzden `Ayarlar.uygula()` atamaları Girdi'ye veriyor.

`tus_atama_testi` beş şeyi ölçüyor: atamanın gerçekten **InputMap'e** işlemesi
(ekranda yazı değişip oyunda hiçbir şey olmaması klasik hata), çakışmanın
reddi, oyun kolu bağlamasının korunması, diske yazılıp geri okunması ve
ekranın kendisi (tıkla → tuşa bas → yazı değişsin, Esc vazgeçsin).

`ceviri_testi` eksik çeviriyi yakalıyor — lokalizasyon hatası çökme olarak
gelmiyor, ekranda ham anahtar (`AYAR_GERI`) olarak görünüyor ve çoğu zaman
kimse fark etmiyor. Test, anahtarları **koddan ve sahnelerden tarayıp** tabloyla
karşılaştırıyor.

## Görsel çekme

```bash
xvfb-run -a godot --path oyun3d --rendering-driver opengl3 \
  --audio-driver Dummy res://araclar/gorsel_cek.tscn
```

Mağaza ve belge görselleri için altı kadraj; `user://gorseller/` altına PNG.
Elle ekran görüntüsü almaktan farkı tekrarlanabilir olması: bölüm değişince
aynı komut aynı kadrajları yeniden üretiyor. 1920×1080 için `--resolution`
ekleyin.

---

## Dövüş döngüsü (Faz 5)

Faz 4'te düşman vardı ama oyuncunun karşılık verme yolu yoktu — oyun yarımdı.
Kapatan mekanik **üstüne zıplama**: düşmanın üstüne düşünce hasar veriyor ve
oyuncuyu sektiriyor.

Çarpışma tespiti ayrı bir `Area3D` ile değil, `move_and_slide`'ın kaydettiği
çarpışmalardan yapılıyor: normal yukarı bakıyorsa ve düşüyorsak üstüne
binmişiz demektir. Bu, "yandan değdim ama ezdim sayıldı" hatasını kökten
engelliyor — ve testte ikisi ayrı ayrı doğrulanıyor.

Sıçrama yüksekliği zıplamanın %85'i: zincirleme ezme ödül olmalı ama sonsuz
yükselme aracı olmamalı. Düşman iki vuruşta yeniliyor; ilk vuruşta eziliyor
(yassılıp yaylanıyor) ve saldırıya geçiyor. Yenilince yarım saniye büzülerek
kayboluyor — anında silmek, oyuncunun "ben yaptım" bağlantısını kurmasına
izin vermiyor.

## Tanıtım videosu

```bash
godot --path oyun3d --rendering-driver opengl3 --audio-driver Dummy \
  --write-movie cikti/tanitim.avi --fixed-fps 24 res://araclar/tanitim.tscn
ffmpeg -i cikti/tanitim.avi -c:v libx264 -crf 20 -pix_fmt yuv420p cikti/tanitim.mp4
```

Oyun kendi kendini oynuyor: `araclar/tanitim.gd` içindeki çekim listesi
oyuncuyu sahneye yerleştiriyor, tuşları basılı tutuyor, belirlenen anlarda
zıplatıyor. Godot'nun Movie Maker kipi sabit adımla çalıştığı için yavaş
makinede bile akıcı çıktı veriyor.

Ayrıntı ve Steam kuralları: [MAGAZA.md](MAGAZA.md).

---

## Düşman ve dövüş (Faz 4, 14)

### Üç tür, tek durum makinesi (Faz 14)

| Tür | Nasıl saldırır | Açığı | Nerede tanıtılıyor |
|---|---|---|---|
| **temel** | Kovalar, menzilde yakın dövüş | Üstüne binilir (2 can) | Bölüm 1 |
| **hoplayan** | Çömelir, sıçrar, iniş hasarı verir | İnişten sonra 0,7 sn savunmasız (1 can) | Bölüm 4 |
| **atıcı** | Yerinde durur, diken atar | Yanına varmak: yakın dövüşü yok | Bölüm 5 |

İkisi de `betikler/dusman.gd`yi **genişletiyor**: algı, devriye, unutma,
ezilme ve erime ortak; alt tür yalnızca kovalama ve saldırıyı değiştiriyor.
Tür ve bölüme özel ayarlar veriden geliyor:

```gdscript
{"tur": "atici", "konum": Vector3(-6, 1.4, -12), "aci": 90.0,
 "ayarlar": {"atis_menzili": 9.0}}
```

> **Ölçülen ders: zorluk yerel bir karar değil.** Atıcı önce bölüm 3'e
> konmuştu — geniş bir platformun üstünde, makul görünüyordu. Bot ölçtü:
> **süre 45 sn → 105 sn, ölüm 7 → 15**. Sebep atıcının kendisi değil, bölüm 3'ün
> zemininin baştan sona ölümcül olması: menzilli hasar + geri tepme + dar
> köprü = düşme. Menzili 16 m'den 9 m'ye indirmek kurtarmadı. Atıcı, zemini
> güvenli olan bölüm 5'e taşındı; yeni bir tehdit hatanın UCUZ olduğu yerde
> öğretilir. Bu kararı veren şey sezgi değil Faz 10'un botu oldu.

**Adil olmanın üç kuralı** (atıcıda yazılı, hepsi için geçerli): atıştan önce
görünür hazırlık; mermi duvardan geçmez; atıcı yerinden kıpırdamaz — yaklaşmak
her zaman işe yarar. Kovalayan bir menzilli düşman oyuncuya kazanma yolu
bırakmazdı.

### Rig ve animasyon (Faz 14)

Düşman Faz 13'e kadar kemiksizdi: hareketi `_model.scale` ile ezip germekten
ibaretti — uzaktan iş görüyor, yakından "kayan bir kitle" gibi duruyordu.
Artık altı kemikli (gövde, çene, iki bacak, kuyruk), 128 üçgen, yedi
animasyon. Model oyuncuyla **aynı hattan** çıkıyor: `araclar/rig.py` iskelet
kurmayı, ağırlık atamayı, poz yazmayı ve dışa aktarımı taşıyor;
`dusman_karakter.py` yalnızca kemik tablosunu, mesh'i ve animasyonları veriyor.

> **Neden AnimationTree yok:** oyuncuda var, çünkü yürüme↔koşma arasını hızla
> karıştırmak gerekiyor (BlendSpace1D). Düşmanın durumu ayrık — ya devriyede
> ya kovalıyor ya saldırıyor; karıştırılacak bir eksen yok. AnimationTree
> eklemek, durum makinesinin İKİNCİ bir kopyasını (ağacın kendi makinesini)
> `dusman.gd` ile eşzamanlı tutmak demekti. Tek makine, tek doğruluk kaynağı;
> geçiş yumuşaklığını `play()`in harman süresi veriyor.

Silueti bilerek korundu — yuvarlak ve dikenli, oyuncunun uzun kaktüsünden
farklı. Tehlikeyi renkten önce siluetten tanımak gerekiyor; renk körü oyuncu
için tek ipucu bu. Türler de renk + BOY ile ayrışıyor (hoplayan küçük ve
mavimsi, atıcı iri ve sarımsı): renk tek başına yetmez.

### Durum makinesi

`betikler/dusman.gd` tek bir enum ve tek bir `match` ile duruyor:

```
DEVRIYE ──gördü──► FARKETTI ──0.45 sn──► KOVALA ──menzilde──► SALDIRI
   ▲                                       │                     │
   └────── 3 sn kaybetti / 24 m uzak ──────┘                     │
                                    CEKIL ◄──vuruş──────────────┘
```

"if kovaliyor and not saldiriyor and gordu" gibi bayrak yığını yerine bunu
tercih etmenin sebebi: her an **tek** bir durumda olunduğu koda bakınca
görülüyor ve yeni durum eklemek eskilerini bozmuyor.

**Algı üç koşulun birleşimi:** mesafe (14 m), görüş açısı (120°) ve engel
kontrolü (RayCast3D). Üçü birden olduğu için oyuncu arkadan yaklaşabiliyor ve
platformun arkasına saklanabiliyor. 360° gören düşman adil hissettirmez.

**Hazırlık süresi (0.38 sn) tasarımın kendisi.** Saldırıdan önceki bekleme,
oyuncuya kaçma penceresi verir; olmadığında saldırı "haksız" hissettirir.
Model o sırada geriye çekilip yaylanıyor — okunabilir bir uyarı.

### Yol bulma

`araclar/navmesh_uret.tscn` bölümün navigasyon örgüsünü bir kez pişirip
`navigasyon/bolum1.tres` olarak kaydeder:

```bash
godot --headless --path oyun3d res://araclar/navmesh_uret.tscn
```

> **Seviye değiştiyse bunu yeniden çalıştırın.** Bayat örgü sessizce bozulur:
> düşman görünmez duvarlara çarpar ya da boşlukta yürür. `dusman_testi`
> içindeki yol testi tam bunu yakalamak için var — iki nokta arasında yol
> bulunamıyorsa test kalır.

### Vuruş hissi

Hasar anında dört şey aynı anda oluyor; hiçbiri tek başına yeterli değil:

| Ne | Nerede | Neden |
|---|---|---|
| Vuruş duraklaması (0.08 sn, ×0.05 hız) | `Efekt.vurus_duraklamasi()` | Darbeye ağırlık verir. 0.12 sn'yi geçerse oyun takılıyor sanılır |
| Ekran sarsıntısı (üstel sönümlü) | `Efekt.sarsint()` → `kamera.gd` | Doğrusal sönüm "sallantı", üstel sönüm "darbe" hissi verir |
| Parçacık | `CPUParticles3D` | Nereden vurulduğu görünür |
| Ses + geri tepme + yanıp sönme | `oyuncu.gd` | Dokunulmazlığın ne zaman bittiği okunur olmalı |

`Efekt` autoload'u sarsıntıyı **isteyen** kodla (hasar) **uygulayan** koddan
(kamera) ayırıyor: düşman, oyuncuya vururken kameranın nerede olduğunu bilmek
zorunda kalmıyor.

### Zemine yatma

Karakter modeli rampada dik durmuyor, zeminin normaline yatıyor. Eğim `Yon`
düğümüne uygulanıyor — animasyonlar `Yon/Model`in dönüşünü yazıyor, ikisi
çakışmasın diye.

> **Faz 12 notu:** bu, kutu karakterde ayak IK'sının yerine geçen ucuz
> numaraydı ve bütün gövdeyi yokuşa yatırıyordu. Ayaklar artık zemine kendi
> oturduğu için payı 0,35'e indirildi (`oyuncu.gd::govde_yatirma`): gövdenin
> hafif yaslanması eğimi okunur kılıyor, tamamı yatırmak karakteri yokuşta
> kapaklanmış gösteriyordu.

---

## Ses (Faz 3)

```bash
python3 oyun3d/araclar/sesler.py
```

On parça sentezlenir (`ses/`): iki ayak sesi, zıplama, iniş, toplama, ölüm,
kontrol noktası, bitiş fanfarı, arayüz tıklaması ve 16 saniyelik müzik döngüsü.
Dış bağımlılık yok, toplam 820 KB.

> Normalde ses **indirilir**: freesound.org, Kenney, itch.io ses paketleri. Faz
> 3'ün asıl dersi lisans okumak ve ses seçmektir; bu ortamda o siteler kapalı
> olduğu için üretildi. Gerçek sesle değiştirirken dosya adlarını koruyun, oyun
> kodunda değişiklik gerekmez.

**Bus yapısı** (`default_bus_layout.tres`): Master → SFX (-6 dB) ve Müzik
(-10 dB). Ayarlar ekranındaki üç kaydırıcı doğrudan bu bus'ların desibelini
yazıyor; oyun kodu ses seviyesiyle hiç ilgilenmiyor.

**Adım sesi zamana değil kat edilen yola bağlı.** Zamana bağlarsan yürürken de
koşarken de aynı ritimde tıkırdar ve kulağa yanlış gelir; yola bağlayınca
koşarken sıklaşır, yavaşlarken seyrelir, dururken kesilir. Sesler ayrıca her
çalışta hafifçe farklı perdeden çalıyor — aynı örneğin tıpatıp tekrarı yapay
duyuluyor.

## Ayarlar ve kayıt

İkisi de `user://` altında `ConfigFile`: `ayarlar.cfg` (ses seviyeleri, fare
hassasiyeti, tam ekran, dil, tuş atamaları, **grafik ön ayarı**) ve `kayit.cfg` (en iyi süre, o turdaki ölüm, oynanma
sayısı). `user://` her platformda oyuna ait yazılabilir klasördür — Windows'ta
AppData, tarayıcıda IndexedDB. Proje klasörüne yazmak dışa aktarılmış oyunda
çalışmaz; geliştirirken fark edilmeyen, çıktıktan sonra patlayan bir hatadır.

---

## Varlık hattı (Faz 2)

```bash
pip install bpy pillow
python3 oyun3d/araclar/modeller.py
```

Blender'ın `bpy` modülüyle beş nesne üretilir — kaya, kaktüs, tabela, sandık,
çiçek — UV'leri açılır, ortak atlasa paketlenir, `varliklar/` altına glTF olarak
yazılır. Ölçüler `varliklar/olcum.json` dosyasına raporlanır; Godot tarafındaki
test bu raporu sözleşme olarak kullanır.

**Rig'li varlıklar ayrı hatta** (oyuncu Faz 11, düşman Faz 14): iskelet,
ağırlık ve animasyon gerekiyor. Ortak kısım `araclar/rig.py`, karaktere özgü
kısım kendi betiğinde:

```bash
python3 oyun3d/araclar/karakter.py         # -> varliklar/oyuncu.gltf
python3 oyun3d/araclar/dusman_karakter.py  # -> varliklar/dusman.gltf
```

> **TUZAK — atlas her üretimde farklı çıkıyordu.** Bölge tohumu
> `hash(ad)` ile üretiliyordu; Python'da str hash'i **süreç başına rastgele**
> (`PYTHONHASHSEED`). Yani "tekrarlanabilir" denen hat, her çalıştırmada 4
> MB'lık dokuyu farklı desenle yeniden yazıyordu — fark ancak `git diff`te
> görünüyordu. `crc32` sürümler ve süreçler arası sabit. (Kalan bir
> belirsizlik: `bmesh.ops.bevel` köşe sırası koşudan koşuya değişebiliyor,
> sandığın `.bin`i o yüzden bazen farklı yazılıyor.)

> **Betikle modellemek elle modellemenin yerine geçmez.** Bu ortamda Blender'ın
> arayüzü yok, o yüzden nesneler kodla kuruldu. Fazın asıl kazancı hattın
> kendisi: UV → atlas → malzeme → glTF → Godot → ölçek/eksen doğrulaması.
> Blender'ı kendi makinende açıp aynı nesneleri elle modellediğinde hattın geri
> kalanı olduğu gibi çalışır; sadece `modeller.py`'nin yerine `.blend`
> dosyaların geçer.

### Doku atlası ve teksel yoğunluğu

Tek 2048×2048 doku; her nesneye **yüzey alanıyla orantılı** bir bölge ayrılır
(kaktüs ve kaya 1024², tabela 512×1024, çiçek 512²). Yüzler baskın eksenlerine
göre düzleme yansıtılır ve hepsi *aynı ölçekte* bir raf paketleyiciyle bölgeye
dizilir; sığmazsa yoğunluk kademeli düşürülür.

Neden aynı ölçek: ilk sürüm her yüzü bölgenin tamamına yayıyordu, küçük pah
yüzleri 3000 teksel/m alırken büyük yüzler 200'de kalıyordu. Aynı nesnede
yoğunluk farkı, dokunun bir yerde bulanık bir yerde israf olması demektir.
Şu an hepsi 294–380 teksel/m bandında.

Tek doku + tek malzeme = az draw call. Faz 6'nın optimizasyon işi buradan
kolaylaşacak.

### Neden `.gltf` + `.bin`, `.glb` değil

`.glb` her şeyi tek ikili dosyaya gömer; dokuyu da gömdüğü için beş nesne
atlasın beş kopyasını taşırdı. Ayrık glTF'te `.gltf` **metin** (JSON) — diff'i
okunabilir, LFS dışında tutuldu — `.bin` ikili (LFS), doku ise ortak tek dosya.

### Bu fazda düşülen iki kuyu

1. **V ekseni.** Blender UV'nin başlangıcı sol *alt*, glTF'inki sol *üst*. Dışa
   aktarıcı `v`'yi çevirir, Godot çevirmez. Telafi edilmeyince her nesne
   atlasın dikey aynasındaki bölgeyi örnekler: kaktüs kahverengi, tabela gri
   çıkar. **Sayısal testlerin hiçbiri bunu yakalamadı** — ölçü, üçgen sayısı ve
   teksel yoğunluğu bu hatada bile doğru. Yakalayan şey, atlastan okunan rengi
   ölçen test oldu (`varlik_testi.gd`, madde 6). Test yazarken sorulacak soru
   "doğru mu?" değil, "yanlış olsa hangi sayı değişirdi?".
2. **Bayat içe aktarma önbelleği.** Varlıklar dışarıdaki bir araçla yeniden
   üretilince Godot'nun `.godot/imported/` önbelleği bazen güncellenmiyor;
   `--import` sessizce eski veriyi bırakıyor. Yeniden üretimden sonra:

   ```bash
   rm -rf oyun3d/.godot/imported && godot --headless --path oyun3d --import
   ```

   Bunu bilmeden yarım saat "düzelttiğim şey neden değişmiyor" diye bakılıyor.

---

## Karakter ve animasyon (Faz 11-12)

Karakter artık kutu değil: **modellenmiş, rig'li ve iskeletli** bir kaktüs.
Model, iskelet, skinning ve beş animasyon tek bir Blender betiğinden çıkıyor:

```bash
python3 oyun3d/araclar/karakter.py      # -> varliklar/oyuncu.gltf (+ .bin)
```

```
araclar/karakter.py
  ├── mesh        144 üçgen, 1,72 m (gövde, kafa, iki kol pedi, uyluk/baldır/ayak)
  ├── iskelet     11 kemik: Kalca, Govde, Kafa, KolSol/Sag,
  │               BacakSol/Sag (uyluk), DizSol/Sag (baldır), AyakSol/Sag
  ├── skinning    bölgeye göre ağırlık, eklemlerde iki kemiğe paylaştırma
  ├── adım        poz değerlendirilip ÖLÇÜLÜYOR: yurume 0,89 m, kosma 1,46 m
  └── animasyon   bosta 2,6 · yurume 0,42 · kosma 0,40 · zipla 0,45 · dusme 0,8 sn
```

Faz 1'den beri karakter beş kutuydu ve animasyon, kutuların dönüşünü sinüsle
üreten bir Godot betiğiydi (`animasyon_uret.gd`). O dosyanın kendi yorumunda
yazıyordu: *"Blender'dan gerçek bir model geldiğinde bu dosya silinecek,
AnimationTree yapısı aynen kalabilir."* Faz 11 tam olarak bunu yaptı — üretici
silindi, **durum makinesi ve `oyuncu.gd` bir satır bile değişmedi**. Değişen
şey iskelet; hareket dili (genlikler, süreler, faz farkları) bilerek aynı
tutuldu, oyunun hissi değişmesin diye.

Kazanç yalnızca görsel değil: altı ayrı `MeshInstance3D` yerine tek skinned
mesh, bölüm başına **~13 draw call** düşürdü (bolum1 82 → 69).

### Dikenler mesh'te değil dokuda

Kaburgalar ve dikenler atlasın `oyuncu` bölgesinde çiziliyor. Geometriye diken
koymak üçgeni üçe katlar ve skinning'i zorlaştırır; low-poly stilinde silueti
mesh, detayı doku taşır. Oyuncunun yeşili süslemedeki kaktüsten bilerek daha
açık: oyuncu ekranda bir bakışta bulunmalı.

### Üç tuzak (üçü de sessiz)

- **Karakter bembeyaz çıktı.** Blender'da `img.filepath = "//atlas.png"`
  yazılmıştı; kaydedilmemiş bir blend dosyasında `//` çözümlenmiyor ve dışa
  aktarıcı dokuyu **hata vermeden** atlıyor. glTF'te malzeme var, `images`
  boş. `karakter_testi` artık "albedo_texture null mu" diye bakıyor.
- **Kemiğin yerel ekseni.** Blender'da kemikler kendi +Y'si boyunca uzar;
  bacak kemiği aşağı baktığı için yerel X'i dünya X'iyle aynı yöne bakmaz.
  Salınım işaretleri kemik başına bir kez ölçülüp `_YON` tablosuna yazıldı —
  "sağ bacak ters sallanıyor" hatasının kaynağı hep budur.
- **AnimationTree yanlış oynatıcıya bakıyordu.** `anim_player` yolu **ağaca**
  göre çözülüyor, oyuncuya göre değil. Yanlışsa oyun çalışır, durum makinesi
  geçiş yapar, ama kemikler kıpırdamaz: ekranda buz gibi bir karakter kayar.
  Test bunu "koşarken bacak kaç radyan salınıyor" diye ÖLÇÜYOR (0,85 rad).

> **Testte öğrenilen:** boş sahnede karakter sonsuza kadar düşüyor ve
> `oyuncu.gd` her karede durumu "dusme"ye çekiyordu; testin elle seçtiği
> durumu eziyordu. Animasyon sistemini ölçmek için oyuncunun kendi sürücüsü
> kapatılıyor (`set_physics_process(false)`).

**Durum makinesi:** `yer` (bosta ↔ yürüme ↔ koşma arasında bir `BlendSpace1D`,
karışım konumunu yatay hız sürüyor), `zipla`, `dusme`. Geçişleri `oyuncu.gd`
`travel()` ile tetikliyor.

### Ayak IK — ayaklar zemine oturuyor (Faz 12)

Faz 11'in bıraktığı iki açık madde de "çalışıyor ama yanlış görünüyor"
sınıfındaydı: rampada bir ayak havada kalıyordu, yürürken ayak yerde
kayıyordu. İkisi de testten geçiyor, her ekran görüntüsünde görünüyordu.

```
betikler/ayak_ik.gd  (SkeletonModifier3D)
  fizik karesinde   her kalçanın altına ışın → hedef + zemin normali
  modifiye ederken  kalça çömelmesi → iki kemikli çözüm → ayağı zemine yasla
```

**Neden kapalı form:** uyluk ve baldır uzunlukları sabit, hedefe uzaklık
biliniyor — üçgenin açıları **kosinüs teoremiyle** doğrudan çıkıyor.
Yinelemeli çözücüye (FABRIK/CCD) gerek yok; iki kemikte kapalı form hem daha
hızlı hem de her karede aynı cevabı veriyor (yinelemeli çözücüler kare kare
titreyebiliyor). Kemik uzunlukları rest pozundan okunuyor: karakter
değişirse IK kendiliğinden uyuyor, elle sayı girilmiyor.

**Işın nerede atılıyor:** `_physics_process` içinde ve ayağın şu anki yerinden
değil, **kalçanın altından**. Animasyon ayağı havaya kaldırdığında ışın da
havaya kalkar ve ayak zemini kaçırır; kalça sabit referans. Fizik sorgusunu
modifiye edicinin içinde yapmak da olmaz — Godot fizik karesi dışındaki
sorguya uyarı veriyor.

**Ölçülen sonuç** (`testler/ayak_ik_testi`): rampada bilek hatası **8,8 cm →
0,2 cm**, basamakta **6,1 cm → 0,1 cm**. Düz zeminde fark yok; zaten olmamalı.

Üç tasarım kararı, üçü de sınırı bilerek çiziyor:

- **Çömelme en fazla 0,35 m.** Bir ayak çok aşağıdaysa kalça iniyor. Sınırsız
  bırakmak karakteri uçurum kenarında yere yapıştırıyordu.
- **Aşağı ışın menzili 0,8 m.** Bacağın erişebileceğinden azıcık uzun
  (0,52 bacak − 0,10 bilek + 0,35 çömelme). Daha kısası basamaktan inerken
  zemini hiç görmüyor, daha uzunu erişilemeyen hedefe bacağı boşuna geriyor.
- **Havada etki 0'a iniyor** ama bir karede değil: ani kapanma zıplamanın ilk
  karesinde bacakları yerinden sıçratıyordu.

> **Ayağı yaslamak IK'nın yarısı.** Bileği doğru yere koymak yetmiyor; ayak
> bacağın çocuğu olduğu için yokuşta burnu havaya kalkıyor. Taban, zeminin
> normaline en kısa dönüşle yaslanıyor — ayağın ileri yönü olabildiğince
> korunuyor. Tabanın kemik yerel uzayındaki ekseni rest pozundan bir kez
> çıkarılıyor: ayak kemiği ileri-aşağı baktığı için tabanın normali kemiğin
> eksenlerinden hiçbiri değil.

> **TUZAK — modifiye edicinin yazdığı poz dışarıdan OKUNAMIYOR.** Godot
> modifiye ediciler çalışmadan önce pozu yedekliyor, sonra geri yüklüyor;
> sonuç yalnızca deri (skinning) dönüşümlerine gidiyor ve
> `get_bone_global_pose()` eski değeri veriyor. İlk test bu yüzden "IK hiçbir
> şey yapmıyor" diyordu — oysa yapıyordu. Çözüm: iskelete **ikinci bir
> modifiye edici** ("prob") takmak. Modifiye ediciler çocuk sırasına göre
> zincirleniyor, dolayısıyla prob kendi sırası geldiğinde IK'nın çıktısını
> okuyor — deriye giden pozun ta kendisini.

### Adım temposu ölçüyle belirleniyor (Faz 12)

Gövde bir çevrimde `hiz × sure` metre gidiyor; bacaklar ancak `adim` metre
atabiliyor. Oran ikisinin bölümü: **kayma oranı**. Faz 11'de yürümede 4,3'tü —
ayak yerde dört katı kayıyordu.

Adım boyu artık tahmin edilmiyor, `araclar/karakter.py` içinde **ölçülüyor**:
poz kare kare değerlendirilip iki ayak bileğinin en açık olduğu an bulunuyor
(gövde bir adımda tam o kadar ilerler), çevrim iki adım. Sonuç: yürüme
0,89 m, koşma 1,46 m. Çevrim süresi buradan hesaplanıyor —
`sure = adim × KAYMA_HEDEFI / hiz` — ve anahtarların zamanı ölçekleniyor.

**Neden hedef 1,0 değil:** koşma hızı 7,4 m/s, yani 1,72 m'lik bir karakter
için saniyede 4,3 boy. Kaymayı tamamen kapatmak çevrimi 0,21 sn'ye indirir:
saniyede ~9 adım, görünmez bir pervane. Hızı düşürmek ise Faz 10'un bütün
denge bütçesini ve par turlarını bozar. **2,0** bu ikisinin arasında bilinçli
bir seçim; `karakter_testi` bütçeyi 2,2 olarak bekçiliyor ve `oyuncu.gd`'deki
hızların ölçümdekilerle aynı kaldığını da doğruluyor (biri değişip diğeri
unutulursa kalibrasyon sessizce geçersiz olurdu).

Kaymayı gerçekten bitirecek yol **kök hareketi** (root motion): hızı
animasyonun belirlemesi. Bedeli, oyunun bütün denge bütçesinin yeniden
ayarlanması — Faz 12'nin kapsamı değil, yol haritasında duruyor.

### Kontrolcüde ne var

`betikler/oyuncu.gd` yalnızca "hareket ediyor" değil, iyi hissettiren küçük
şeyleri de içeriyor — hiçbiri oyuncunun fark ettiği, hepsi yokluğu fark edilen
şeyler:

- **Coyote süresi** — platformdan düştükten sonra 0.12 sn zıplama hâlâ kabul edilir
- **Zıplama tamponu** — havadayken basılan zıplama, yere değince 0.14 sn hatırlanır
- **Değişken zıplama** — tuşu erken bırakınca dikey hız kesilir
- **Artan düşme yerçekimi** — inişte yerçekimi 1.35× uygulanır, zıplama "canlı" olur
- **Havada azaltılmış ivme** — havada yön değiştirmek yerdekinden zor
- **Yumuşak dönüş** — model gittiği yöne `lerp_angle` ile döner, anında snap etmez

---

## Çarpışma katmanları

Numara yerine isim kullanın; `project.godot` içinde tanımlı:

| # | İsim | Kim |
|---|---|---|
| 1 | zemin | Zemin, platformlar, rampa |
| 2 | oyuncu | Karakter |
| 3 | tuzak | Dikenli alan (Area3D) |
| 4 | toplanabilir | Çiçekler (Area3D) |
| 5 | kontrol | Kontrol noktaları ve bitiş (Area3D) |
| 6 | platform | Hareketli platform (AnimatableBody3D) |
| 7 | dusman | Düşman gövdeleri |
| 8 | mermi | Atıcının dikeni (Area3D) |

Karakterin maskesi zemin + platform + düşman; Area3D'lerin maskesi yalnızca
oyuncu. Böylece çiçekler birbirini, tuzak platformu tetiklemiyor. Dikenin
maskesi zemin + oyuncu + platform: duvara çarpıyor, oyuncuya vuruyor, ama
onu atan düşmana takılmıyor (atıcı ışın sorgusunda hariç tutuluyor).

---

## Klasör düzeni

```
oyun3d/
├── project.godot            Ayarlar, autoload, renderer, çarpışma katmanı isimleri
├── sahneler/
│   ├── bolum1.tscn          Kaktüs Parkuru (yatay, elle)
│   ├── bolum2.tscn          Dikenli Kule (dikey, elle)
│   ├── bolum3-6.tscn        Üretilmiş bölümler (bolum_tasarimi/ + bolum_uret.gd)
│   ├── tus_atama.tscn       Tuş atama ekranı
│   ├── oyuncu.tscn          Karakter + kamera kolu + AnimationTree
│   ├── platform.tscn        Ölçüsü/rengi ayarlanabilir platform parçası
│   ├── toplanabilir.tscn    Çiçek
│   ├── kontrol_noktasi.tscn Bayrak
│   └── hareketli_platform.tscn
├── betikler/
│   ├── girdi.gd             Autoload: klavye + oyun kolu eylemleri
│   ├── ses.gd               Autoload: ses havuzu, müzik, bus seviyeleri
│   ├── ayarlar.gd           Autoload: ayar + rekor kalıcılığı
│   ├── efekt.gd             Autoload: sarsıntı ve vuruş duraklaması
│   ├── dusman.gd            Durum makineli düşman (temel sınıf)
│   ├── dusman_hoplayan.gd   Zıplayarak saldıran alt tür
│   ├── dusman_atici.gd      Uzaktan diken atan alt tür
│   ├── diken.gd             Atıcının mermisi (Area3D, ışınla ön sınama)
│   ├── bolumler.gd          Autoload: bölüm kütüğü
│   ├── bolum_grafi.gd       Durak/menzil grafı — test ve bot ortak kullanıyor
│   ├── bot/                 Otomatik oyuncu (denge ölçümü, par turu)
│   ├── birlestirici.gd      Statik görselleri MultiMesh'e indirir
│   ├── ortam.gd             Bölümün aydınlatması ve gökyüzü (tek kurulum)
│   ├── manzara.gd           Uzak manzara: ufuk, mesa siluetleri, serpinti
│   ├── ag/                  Ağ: ag.gd, hayalet_kayit.gd, hayalet_kaydedici.gd,
│   │                        hayalet.gd, uzak_oyuncu.gd, uzak_oyuncular.gd
│   ├── dokunmatik.gd        Ekran kontrolleri (çubuk, düğmeler)
│   ├── cubuk_cizimi.gd      Sanal çubuğun çizimi
│   ├── menu/                Ana menü, ayarlar paneli, duraklatma, bitiş
│   ├── oyuncu.gd            Hareket, zıplama, animasyon sürücüsü
│   ├── kamera.gd            SpringArm3D üçüncü şahıs kamera
│   ├── oyun.gd              Bölüm akışı: sayaç, süre, ölüm, bitiş
│   ├── platform.gd          @tool — ölçü/renk uygular
│   ├── toplanabilir.gd · tuzak.gd · kontrol_noktasi.gd · bitis.gd
│   ├── hareketli_platform.gd
│   └── hud.gd               Durum + kare bütçesi
├── bolum_tasarimi/          Bölüm VERİSİ (bolum3.gd … bolum6.gd) — hattın girdisi
├── hayaletler/              Oyunla gelen par turları (botun turu, Faz 10)
├── denge_butce.json         Bot süre/ölüm sınırları (Faz 10)
├── ses/                     Sentezlenmiş ses efektleri ve müzik
├── golgeler/                Shader'lar: tuzak şeritleri, erime, gökyüzü, dünya malzemesi
├── performans_butce.json    Draw call / üçgen bütçeleri
├── navigasyon/              Pişirilmiş navigasyon örgüleri (bölüm başına)
├── MAGAZA.md                Mağaza metni, trailer ve Steam sırası
├── arayuz/tema.tres         Ortak buton/etiket teması
├── default_bus_layout.tres  Master / SFX / Müzik bus'ları
├── varliklar/               Modellenmiş nesneler (.gltf + .bin) ve atlas.png
│   └── olcum.json           Blender'ın raporu = Godot testinin sözleşmesi
├── animasyon/               Durum makinesi (animasyonlar artık glTF ile geliyor)
├── araclar/
│   ├── bolum_uret.gd        Veriden bölüm sahnesi üretici
│   ├── denge_olc.gd         Botu bölümlere salar, denge sayılarını yazar
│   ├── modeller.py          Varlık üretici (Blender/bpy)
│   ├── karakter.py          Rig'li karakter + iskelet animasyonları (bpy)
│   ├── sesler.py            Ses üretici
│   ├── navmesh_uret.gd      Navigasyon örgüsü üretici (her bölüm için)
│   ├── tanitim.gd           Trailer çekimi (oyun kendini oynar)
│   ├── olcum.gd             Performans ölçümü ve bütçe denetimi
│   └── gorsel_cek.gd        Mağaza görselleri
└── testler/
    ├── bolum_testi.gd       Oynanış davranışları
    ├── varlik_testi.gd      Varlık hattı
    ├── arayuz_testi.gd      Menü, ayar, kayıt, duraklatma
    ├── dusman_testi.gd      Yapay zekâ, hasar, navigasyon
    ├── ceviri_testi.gd      Çeviri bütünlüğü
    ├── dokunmatik_testi.gd  Ekran kontrolleri (gerçek pencere ister)
    ├── ayak_ik_testi.gd     Ayak IK: düz zemin, rampa, basamak, havada
    ├── gorsel_testi.gd      Aydınlatma ölçümü + manzara denetimi (pencere ister)
    ├── hayalet_testi.gd     Hayalet kaydı, aradeğerleme, HUD
    └── ag_testi.sh          İki süreçli ağ testi (+ ag_sunucu / ag_istemci)
```

`platform.tscn` içindeki mesh, çarpışma şekli ve materyal
`resource_local_to_scene` işaretli: her örnek kendi kopyasını alır. Bu olmadan
bir platformun ölçüsünü değiştirmek hepsini birden değiştirir — Godot'da en sık
düşülen kuyulardan biri.

---

## Dışa aktarım

Şablonlar bir kez indirilir: **Editör → Dışa Aktarım Şablonlarını Yönet → İndir**.
Sonra ön ayarları kopyala:

```bash
cp export_presets.cfg.ornek export_presets.cfg
```

Gerçek `export_presets.cfg` bilerek `.gitignore`'da: Godot bu dosyaya Android imza
anahtarının parolasını da yazar.

| Hedef | Ön ayar | Not |
|---|---|---|
| Windows | `Windows` | `cikti/windows/cactus3d.exe` |
| Web | `Web` | `cikti/web/index.html` — yerelde sunucudan aç, `file://` çalışmaz |
| Android | `Android` | JDK 17+ ve Android SDK gerekir (Editör Ayarları → Export → Android) |

```bash
godot --headless --export-release "Web" ../cikti/web/index.html
```

**Web notu:** tarayıcı hedefi `gl_compatibility` renderer ile çalışır. Masaüstündeki
`forward_plus` ile aynı gölge ve efektleri beklemeyin — hata değil, platform farkı.
Faz 13'ün aydınlatması bu kısıtla tasarlandı: derinlik ekran uzayında (SSAO)
değil malzemede üretiliyor, böylece iki yolda da aynı görünüyor. SSAO yalnızca
yüksek grafik ön ayarında ve yalnızca Forward+ tarafında devreye giriyor.

**Web + iş parçacığı:** ön ayarda `thread_support` açık; bu, sayfanın
`Cross-Origin-Opener-Policy: same-origin` ve `Cross-Origin-Embedder-Policy:
require-corp` başlıklarıyla sunulmasını şart koşar. Cloudflare Pages'te bunu
`_headers` dosyasına eklemek gerekecek; basit `python3 -m http.server` bu
başlıkları göndermez.

**VRAM doku sıkıştırması:** ön ayarlardaki `vram_texture_compression` seçenekleri,
`project.godot` içindeki `textures/vram_compression/import_s3tc_bptc` ve
`import_etc2_astc` açık değilse dışa aktarımı "configuration errors" diyerek
durdurur. İkisi de açık geliyor; kapatmayın.

**CI:** `.github/workflows/oyun3d-web.yml` — Actions → *3B Oyun — Web Derlemesi*.
Önce bölüm testlerini çalıştırır, sonra web derlemesini artifact olarak bırakır.

---

## Git LFS

Depo kökündeki `.gitattributes`, LFS kurallarını **yalnızca `oyun3d/` altına**
uygular. Klonlayan her makinede bir kez:

```bash
git lfs install
```

Kurallar `.blend`, `.glb`, `.fbx`, `.exr`, `.hdr`, `.ktx2` ve ses dosyaları için
duruyor — yani asıl büyüyecek dosya türleri. Faz 2'nin ürettikleri **bilerek
LFS dışında**:

| Dosya | Boyut | Neden |
|---|---|---|
| `*.gltf` | 1–2 KB | Metin (JSON); diff'i okunabilir kalsın |
| `*.bin` | 2–12 KB | LFS işaretçisi 130 bayt — bu boyutta LFS sadece bağımlılık |
| `atlas.png` | 1.4 MB | Depoda tutulacak kadar küçük |
| `ses/*.wav` | 820 KB | Kısa efektler; uzun müzik `.ogg`'a çevrilip LFS'e |

Atlas ilk hâlinde 6.75 MB'tı: her piksele ayrı gürültü koyuyordum. O gürültü bir
metre öteden zaten görünmüyor ama PNG'yi sıkıştırılamaz yapıyor. Kaba kafes
üstünde aradeğerlenmiş gürültüye geçince dosya 5 kat küçüldü ve doku daha iyi
göründü. Doku büyürse ya da ikinci bir atlas gelirse `*.png` LFS'e taşınmalı.

> **Not:** Bu proje LFS için kurulu ama LFS yolu bu depoda henüz *fiilen*
> denenmedi — geliştirme oturumunun ağ politikası `lfs.github.com` adresini
> kapatıyor. İlk `.blend` veya ses dosyasını eklerken `git lfs install` yapıp
> push'un gerçekten çalıştığını doğrulayın.

---

## Doğrulanmış durum

Godot **4.7.2** ile bu depoda gerçekten çalıştırıldı:

| Adım | Durum |
|---|---|
| `--headless --import` | ✅ hatasız |
| Bölüm testleri (10 test) | ✅ hepsi geçti |
| Varlık testleri (5 varlık) | ✅ hepsi geçti |
| Web dışa aktarımı | ✅ `index.wasm` + `index.pck` |
| Windows dışa aktarımı | ✅ geçerli PE32+ ikili |
| Arayüz testleri (6 grup) | ✅ hepsi geçti |
| Düşman testleri (10 grup) | ✅ hepsi geçti (rig, hoplayan, atıcı, diken/duvar dahil) |
| Çeviri testleri | ✅ 79 anahtar × 2 dil, eksik yok |
| Performans bütçesi | ✅ altı bölüm bütçe içinde (67–81 draw call, en yüksek grafik ön ayarında) |
| Dokunmatik testleri (5 grup) | ✅ hepsi geçti (Xvfb ile) |
| Hayalet testleri (6 grup) | ✅ hepsi geçti |
| Ayak IK testi (4 durum) | ✅ rampada bilek hatası 8,8 → 0,2 cm, basamakta 6,1 → 0,1 cm |
| Görsel test (6 bölüm) | ✅ aydınlatma bütçe içinde, manzara çarpışmasız (Xvfb ile) |
| Ağ testi (iki süreç) | ✅ 359 ölçüm, yarıçap hatası 0.003 m, 1 hile paketi reddedildi |
| Telemetri testi (7 grup) | ✅ gizlilik kuralları geçti |
| Bölüm hattı testi (6 bölüm) | ✅ hepsi bitirilebilir; 100 durağın hepsi erişilebilir |
| Tuş atama testi (5 grup) | ✅ InputMap, çakışma, kilitlenme, kayıt, ekran |
| İstemci–sunucu sözleşmesi | ✅ 3 satır, 4 olay adı, 7 ret kuralı (Node ile) |
| Basın kiti sayfası | ✅ Chromium'da açıldı, 11 görsel yüklendi, konsol hatası yok |
| Demo dışa aktarımı | ✅ Windows + Web; tarayıcıda menü "Demo sürümü — ilk bölüm" ve tek bölüm gösterdi |
| Gerçek telefonda APK | ⚠️ denenmedi — Android SDK bu ortamda yok |
| Tanıtım videosu | ✅ 746 kare / 31 sn, Xvfb + yazılımsal GPU ile çekildi |
| Tarayıcıda açılış | ✅ Chromium'da menü → Enter → oyun → Esc → duraklatma akışı çalıştı |
| Android dışa aktarımı | ⚠️ denenmedi — Android SDK gerekiyor, o ortamda indirilemedi |

---

## itch.io'ya yayınlama

Faz 3'ün son adımı oyunu yayınlamak. Web derlemesi hazır:

1. **Paketi al** — Actions → *3B Oyun — Web Derlemesi* → çalıştır → artifact'ten
   `cactus3d-web.zip`. (Yerelde: `cd cikti/web && zip -r ../cactus3d-web.zip .`)
   `index.html` zip'in **kökünde** olmalı, klasörün içinde değil.
2. **itch.io'da yeni proje** — Kind of project: **HTML**. Zip'i yükle,
   "This file will be played in the browser" işaretle.
3. **Embed ayarları** — Viewport 1280×720, fullscreen butonu açık.
4. **SharedArrayBuffer support: AÇIK.** Bu şart. Web ön ayarında
   `thread_support` açık olduğu için oyun `Cross-Origin-Opener-Policy` ve
   `Cross-Origin-Embedder-Policy` başlıklarını ister; itch.io bu kutucuk
   işaretlenmezse o başlıkları göndermez ve oyun beyaz ekranda kalır.
   (Alternatif: ön ayarda `thread_support` kapatılıp tek iş parçacıklı şablonla
   dışa aktarmak — daha yavaş ama başlık istemez.)
5. **Sayfa metni** — kontroller, süre, "tarayıcıda oynanır" notu ve bir GIF.
   Oynanış GIF'i olmayan itch sayfası tıklanmıyor.

Sonra yol haritasının dediğini yapın: **20 kişiye oynatın ve izleyin.** Nerede
takıldıklarını not alın; konuşmadan izlemek, sorulan sorudan daha çok şey
söyler.

---

## Açık uçlar

Faz 8 bitti; `1.0.0` için kalanlar `SURUM-NOTLARI.md` sonunda listeli. Kodda
açık kalan uçlar:

- **Kök hareketi yok** — animasyonlar yerinde oynuyor, kat edilen yolu kod
  sürüyor. Faz 12 kaymayı 4,3 kattan 2,0 kata indirdi ama bitirmedi; bitirmek
  hızı animasyonun belirlemesi demek (`AnimationTree.root_motion_track`) ve
  Faz 10'un bütün denge bütçesinin yeniden ayarlanması.
- **El IK'sı yok** — ayak IK'sı Faz 12'de geldi (`betikler/ayak_ik.gd`); duvara
  yaslanma ve tutunma aynı modifiye edici altyapısının üstüne kurulabilir.
- **Düşmanların birbirinden haberi yok** — sürü davranışı, çevreleme ve
  "arkadaşım vuruldu" tepkisi yok. Üç tür bir arada dursa da birbirini
  görmüyor; her biri kendi durum makinesini yalnız yaşıyor.
- **Yenilme tek tip** — her düşman aynı erime efektiyle gidiyor ve hepsi aynı
  sesi çıkarıyor. Tür başına ses ve yenilme, ucuz bir kimlik kazancı olurdu.
- **Boss yok** — altı bölümün sonunda öğrenilenleri sınayan tek bir karşılaşma
  yok; final bölümü bunu düşman yoğunluğuyla yapıyor.
- **Prop çarpışması** — süsleme nesnelerinin çarpışması yok. Godot'nun glTF
  içe aktarıcısı, Blender'da adı `-col` ile biten mesh'ler için otomatik
  `StaticBody3D` üretir; sandık ve kayaya bu uygulanacak.
- **Malzeme paylaşımı** — beş nesnenin beş ayrı malzemesi var, hepsi aynı
  atlası gösteriyor. Tek malzemeye indirmek draw call düşürür (Faz 6).
- **Trailer'da ses yok** — Movie Maker ses de yazabiliyor (`.wav` yan dosyası);
  kurgu aşamasında eklenecek.
- **Hiçbir bölüm İNSAN tarafından oynanarak dengelenmedi** — Faz 10'un botu
  altısını da baştan sona oynuyor ve süre/ölüm/çiçek bütçesini tutuyor, ama
  bot eğlenceyi, kafa karışıklığını ve "buradan sonra bıraktım"ı ölçemiyor:
  20 kişiye oynat, izle.
- **Çevre sanatı prosedürel** — Faz 13 dünyayı doldurdu (aydınlatma, malzeme,
  uzak manzara) ama her bölüme kendi kimliğini veren el yapımı yapılar
  (kaya kemerleri, yıkık duvarlar, bitki çeşitliliği) yok. O iş modelleme
  masasında.
- **Oyun kolu tuşları atanamıyor** — tuş atama ekranı yalnızca klavye için.
  Kumanda düğmesi atamak `InputEventJoypadButton` yakalamak demek; aynı ekran
  büyütülebilir.
- **LOD ve occlusion yapılmadı** — şu anki sahne boyutunda gerekmedi; bütçe
  aşılırsa ilk başvurulacak yer orası.
- **APK gerçek cihazda denenmedi** — SDK bu ortamda yok (yukarıdaki liste).
