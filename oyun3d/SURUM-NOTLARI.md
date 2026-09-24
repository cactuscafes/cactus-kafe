# Sürüm notları — Cactus 3B

Anlamlı sürümleme: **BÜYÜK.KÜÇÜK.YAMA**. Çıkışa kadar `0.x`, çıkışta `1.0.0`.
Tek kaynak `betikler/urun.gd` içindeki `SURUM` sabiti — oyun içi krediler,
telemetri olayları, basın kiti ve mağaza metni hep oradan okuyor.

> **Sürüm numarasını değiştirirken:** `betikler/urun.gd` → `SURUM`,
> `project.godot` → `config/version`, `sunucu/package.json` → `version`,
> `basin/index.html` altbilgisi. Dördü ayrı yerde; `grep -rn "0\.17\.0" oyun3d`
> hepsini gösteriyor. Yanlış sürümü yayınlamanın bedeli, geri bildirimin hangi
> yapıdan geldiğini bilememektir.

---

## 0.17.0 — İçerik ölçeği 2: iki yeni bölüm (Faz 17)

- **Altı bölüm sekiz oldu.** Faz 9 "iki bölüm bir demo, altı bölüm bir oyun"
  diyerek dört bölüm eklemişti. O zamandan beri oyuna üç düşman türü (Faz 14),
  konumlu ses (Faz 15) ve bir canavar (Faz 16) girdi — ama hiçbiri YENİ bir
  bölümde kullanılmamıştı; hepsi mevcut bölümlere sonradan serpiştirildi.
- **Bölüm 7 — "Kum Kanyonu": siper bölümü.** Oyunun mağaza metninde iddia
  ettiği ("siper gerçekten siperdir: diken duvardan geçmez") ama hiçbir
  bölümün öğretmediği şey. İki atıcı çapraz ateş hattında, platoların
  üstündeki sütunlar o hatları kesiyor; ilerlemek "sütundan sütuna, atış
  arasında" demek. Zemin ölümcül ama platolar geniş ve boşluklar 2,5 m:
  baskı tek eksende, nerede durduğunda.
- **Bölüm 8 — "Diken Ana'nın İni": rövanş.** Üç düşman türü sırayla
  (hatırlatma), sonra canavarla ikinci karşılaşma. Canavar **tek satır kod
  yazılmadan** zorlaştı: dört can, %18 kısa nefes, üç yerine beş diken,
  dört saldırılık kalıp — hepsi bölüm verisindeki `boss.ayarlar` sözlüğünde.
  Faz 16'nın "veriden ayarlanabilir boss"u ilk kez gerçekten sınandı.
- **Bölüm 6 yeniden adlandırıldı**: "Son Tırmanış" → "Zirve Dövüşü". Artık
  son değil, ilk karşılaşma.
- **Ölçülen ders: ölümlerin sebebi sandığın şey değil.** Bölüm 7'nin ilk
  ölçümü 24 ölümdü ve suçlu atıcılar sanılmıştı — "Faz 14'ün hatasını
  tekrarladık" diye. Değilmiş: ölümcül zeminin üstüne koyduğum bir
  SALINCAK, botun rotasını kendine çekiyor ve onu arka arkaya düşürüyordu.
  Salıncak kaldırıldı: **24 ölüm → 1 ölüm**, bölüm bitişe ulaşıldı. İki
  baskıyı üst üste bindiren şey menzilli düşman değil, bekleme baskısıydı.
- **Bölümler sekizde de doğrulanıyor**: bitirilebilirlik (`bolum_hatti_testi`),
  denge (bot sekizini de oynuyor), aydınlatma (`gorsel_testi`) ve performans
  bütçeleri yeni iki bölümü de kapsıyor.

## 0.16.0 — Boss: dövüşün doruğu (Faz 16)

- **Bölüm sonu canavarı.** Dokuz kemikli, 158 üçgenlik, 2,43 m boyunda bir
  yaratık (`araclar/boss_karakter.py`) ve sekiz animasyon: bosta, yürüme,
  çarpma, atış, sersem, sarsılma, kükreme, yenildi. Düşmanla aynı rig hattını
  (`araclar/rig.py`) ve aynı atlası kullanıyor — yeni doku, yeni malzeme yok.
- **Dört evreli kalıp.** BEKLE → TELGRAF → VURUŞ → SERSEM. Telgraf oyuncunun
  kaçma penceresi (çarpmada 0,45 sn, atışta 0,38 sn); sersem canavarın açığı.
- **Tek açık, tek kural: canavar yalnızca SERSEM evresinde hasar alıyor.** Her
  an vurulabilseydi dövüş "yeterince zıpla" olurdu. Yanlış anda üstüne
  binmek hasar vermiyor ama oyuncuyu sektiriyor: "vuramadım" ile "yanlış
  yaptım" arasındaki farkı anlatan şey o sektirme.
- **Zorluk ritimle artıyor, sayıyla değil.** Her vuruşta canavar kükrüyor;
  bekleme %25 kısalıyor, sersem penceresi daralıyor, kalıba bir saldırı daha
  ekleniyor. Canı 3 — ama üçüncü vuruş birinciyle aynı dövüş değil.
- **İki saldırı, iki mesafe.** Yakında alan hasarlı çarpma, uzakta üç dikenli
  yelpaze. Seçim mesafeye bağlı: hem uzakta beklemek hem dibinde durmak
  cezalı, yoksa dövüşün tek doğru yanıtı "uzakta bekle" olurdu.
- **Bitiş kilitli.** Bölüm 6'da canavar yenilmeden çıkış açılmıyor
  (`OYUN_BOSS_BEKLIYOR`); doruk noktasını atlayıp çıkışa yürümek, dövüşü
  isteğe bağlı bir süse çevirirdi. Zirve alanı dövüşe yer açmak için
  büyütüldü.
- **Gerilim müziği canavarı iki düşman sayıyor.** Faz 15'in katmanlı müziği
  boss karşılaşmasında tavana yakın kalıyor.
- **Boss testi** (`testler/boss_testi`): rig ve animasyon denetimi, SERSEM
  dışında 42 deneme boyunca hasar ALMAMASI, betikle baştan sona oynanan tam
  bir dövüş (652 kare), ritmin gerçekten hızlanması (1,10 → 0,83 → 0,62 sn)
  ve bitiş kilidinin canavar yenilince açılması.
- **Denge ölçer donuyordu — düzeltildi.** Bot bir bölümü BİTİRDİĞİNDE bitiş
  ekranı `get_tree().paused = true` yapıyor; bot da ölçer de duraklanabilir
  düğümlerdi, ikisi de o karede donuyor ve `await bot.bitti` sonsuza kadar
  bekliyordu. Belirtisi şuydu: süreç yaşıyor, CPU dönüyor, hiçbir çıktı yok.
  İkisi de `PROCESS_MODE_ALWAYS` oldu, her bölüm başında duraklatma
  sıfırlanıyor, ve bir nöbetçi 60 sn gerçek zamanda ilerleme olmazsa NEDENİNİ
  yazıp 1 ile çıkıyor — CI'da sessiz zaman aşımı yerine okunur bir hata.

## 0.15.0 — Ses: konum, çevre ve katmanlı müzik (Faz 15)

- **3B ses.** Dünyadaki olaylar artık geldikleri yerden duyuluyor
  (`Ses.cal_3b`): düşmanın saldırısı, dikenin taşa saplanması, uzaktaki bir
  ölüm. Oyuncunun kendi sesleri (adım, zıplama, hasar, ezme) bilerek 2B
  kaldı — kendi sesini kamera açısına göre sağdan solda duymamak için.
- **Dinleyici karaktere yaklaştırıldı.** 3B ses varsayılan olarak kameradan
  duyuluyordu, yani karakterin 5 m arkasından. `AudioListener3D` kameranın
  altında ama karaktere doğru 2,6 m kaydırılmış: konum karakterin, yön
  kameranın.
- **Çevre sesi.** 8 saniyelik rüzgâr döngüsü (döngü noktası çapraz
  geçişli) + rastgele aralıklarla kuş ötüşü. Kuşlar döngünün içinde değil:
  gömülü bir kuş üçüncü tekrarda sahte duyuluyor.
- **Katmanlı, uyarlanan müzik.** Sakin taban ve gerilim katmanı AYNI ANDA
  çalıyor; gerilim, peşine düşen düşman sayısına göre açılıp kapanıyor
  (açılış hızlı, kapanış yavaş). İki katman aynı uzunlukta ve aynı akorlar
  üzerine kurulu, yoksa açıldığı anda akort tutmaz.
- **Kısma (ducking).** Ölüm, kontrol noktası, bitiş ve düşman ölümünde
  müzik 0,5 sn geri çekiliyor. Kısma BUS'a değil oynatıcıya uygulanıyor:
  bus oyuncunun ayarı, oraya yazmak her ölümde müzik seviyesini biraz daha
  düşürürdü.
- **Tür başına düşman sesi**: aynı ses bankası, perde kaydırmasıyla ayrışan
  üç tür (küçük tiz, iri pes) + atıcının kendi atış ve çarpma sesi.
- **Ses testi** (`testler/ses_testi`): koddaki her `Ses.cal("...")` adının
  kütüphanede olduğunu doğruluyor (yazım hatası sessizce sesi yok ediyor),
  öksüz ses dosyası arıyor, havuzun büyümediğini, 3B sesin doğru konumdan
  çaldığını, kısmanın eski seviyeye döndüğünü ve iki müzik katmanının
  eşzamanlı kaldığını ölçüyor.

## 0.14.0 — Düşmanlar: rig ve dövüş derinliği (Faz 14)

- **Rig'li düşman.** Düşman artık kemikli: gövde, çene, iki bacak ve kuyruk
  (6 kemik, 128 üçgen) — `araclar/dusman_karakter.py`. Yürüyor, çiğniyor,
  ezilince çöküyor. Hareketi taklit eden ölçek oynatması (`_model.scale`)
  emekli oldu; her duruma bir animasyon karşılık geliyor.
- **Ortak rig hattı.** İskelet kurma, ağırlık, poz yazma, f-eğrisi erişimi ve
  glTF dışa aktarımı `araclar/rig.py`'ye taşındı; oyuncu ve düşman aynı hattı
  kullanıyor. Oyuncunun modeli bit bit aynı çıkıyor (ölçüm dosyası değişmedi).
- **İki yeni düşman türü.** `hoplayan` zıplayarak saldırıyor (çömel → sıçra →
  in → topar; inişte savunmasız), `atici` uzaktan diken atıyor (yerinden
  kıpırdamıyor, siper işe yarıyor). İkisi de `dusman.gd`yi genişletiyor:
  algı, devriye, unutma, ezilme ve erime ortak.
- **Düşman türü bölüm verisinden.** `bolum_tasarimi/*.gd` içinde
  `{"tur": "atici", "ayarlar": {...}}`; tür ve bölüme özel ayarlar veriden
  geliyor.
- **Atıcı bölüm 3'ten geri alındı.** Ölçüldü: zemini baştan sona ölümcül bir
  bölümde menzilli düşman botun süresini 45 sn'den 105 sn'ye, ölümünü 7'den
  15'e çıkardı. Menzili kısaltmak kurtarmadı; yeni tehdit, hatanın ucuz
  olduğu bölüm 5'te tanıtılıyor.
- **Atlas artık tekrarlanabilir.** `hash(ad)` Python'da süreç başına rastgele
  (`PYTHONHASHSEED`); doku her üretimde farklı çıkıyordu. `crc32` ile sabit.
- Düşman testi büyüdü: rig ve animasyon denetimi, hoplayanın gerçekten yerden
  kesilmesi ve savunmasız penceresi, atıcının yerinden oynamaması, dikenin
  ince duvarı DELMEMESİ (hızlı cisim tünelleme sınavı).

## 0.13.0 — Dünya sanatı ve aydınlatma (Faz 13)

- **Aydınlatma tek yerden.** Altı bölüm artık aynı `sahneler/ortam.tscn`
  örneğini kullanıyor: anahtar + dolgu ışığı, gökyüzünden ortam ışığı,
  ayarlanmış gölge kademeleri (yakın kademe dar, en uzak 65 m), havadan
  perspektifli sis. Bölüme özel olan yalnızca sanat yönü — gök renkleri,
  sis, güneş açısı, bulut miktarı.
- **Gökyüzü gölgelendiricisi.** Degrade + bulut bandı + güneş diski
  (`golgeler/gok.gdshader`). Üç renkli düz degrade gitti; ekranın üçte biri
  artık gökyüzü.
- **Dünya malzemesi.** Kutular tek renk olmaktan çıktı
  (`golgeler/dunya.gdshader`): dünya uzayında üç eksenli gürültü, yan
  yüzlerde tabakalar, üst yüzlerde ağarma ve kutunun dibine doğru karartma.
  Doku yok — desen konumdan üretiliyor, her ölçekte aynı sıklıkta.
- **Uzak manzara.** `betikler/manzara.gd` ufku kapatan geniş zemini, 24
  mesa siluetini ve serpiştirilen kaya/kaktüsü çalışma anında kuruyor;
  yerleşim bölüm kimliğinden gelen tohumla üretildiği için her açılışta
  aynı. Tamamı çarpışmasız — bölüm grafını yanıltmaması şart.
- **Grafik ön ayarı.** Ayarlar panelinde düşük / orta / yüksek. Düşükte
  gölge, dolgu ışığı ve serpinti kapalı; yüksekte ayrıca parlama ve SSAO.
  İlk açılışta tarayıcı ve mobil "orta", masaüstü "yüksek" başlıyor.
- **Görsel test.** `testler/gorsel_testi` bölümü gerçekten çizip karenin
  parlaklığını ve karşıtlığını ölçüyor (bütçe `gorsel_butce.json`), ayrıca
  ortam/sis/gölge kurulumunu ve manzaranın çarpışmasız olduğunu doğruluyor.

## 0.12.0 — Animasyon cilası (Faz 12)

- **Ayak IK.** Karakterin ayakları artık zemine oturuyor
  (`betikler/ayak_ik.gd`). Her ayağın altına ışın atılıyor, bacak zinciri
  hedefe kosinüs teoremiyle çözülüyor, ayak tabanı zeminin normaline
  yaslanıyor; bir ayak diğerinden alçaktaysa kalça çömeliyor (en fazla
  0,35 m). Rampada ölçülen bilek hatası 8,8 cm'den 0,2 cm'ye, basamakta
  6,1 cm'den 0,1 cm'ye indi.
- **Bacak iki kemiğe bölündü.** İskelet 7 kemikten 11'e çıktı: uyluk, baldır
  ve ayak. Tek kemikli bacakta çözülecek bir zincir, kırılacak bir diz yoktu;
  IK'nın ön koşulu bu. Yürüme ve koşmada diz artık gerçekten bükülüyor.
- **Adım temposu ölçümle belirleniyor.** `araclar/karakter.py` animasyonun
  adım boyunu pozu değerlendirip ÖLÇÜYOR (yürüme 0,89 m, koşma 1,46 m) ve
  çevrim süresini oyunun hızına göre hesaplıyor. Ayağın yerdeki kayması
  4,3 kattan 2,0 kata indi; bütçe `karakter_testi` içinde.
- **Gövde yatırması küçüldü.** Faz 11'e kadar bütün gövde yokuşa yatıyordu —
  ayak IK'sının yerine geçen ucuz numaraydı. Artık payı 0,35; ayaklar işi
  kendi yapıyor.
- **Ayak IK testi.** `testler/ayak_ik_testi` düz zemin, rampa, basamak ve
  havada olmak üzere dört durumu ölçüyor. Modifiye edicinin yazdığı poz
  dışarıdan okunamadığı için test iskelete ikinci bir "prob" modifiye edici
  takıyor — ölçülen şey deriye giden pozun ta kendisi.

## 0.11.0 — Karakter (Faz 11)

- **Kaktüs karakter.** Oyuncu artık beş kutu değil: Blender'da modellenmiş,
  yedi kemikle rig'lenmiş, skinning'li ve iskelet animasyonlu bir kaktüs
  (`araclar/karakter.py` → `varliklar/oyuncu.gltf`). 96 üçgen, 1,72 m.
- **Yordamsal animasyon üreticisi emekli oldu.** `araclar/animasyon_uret.gd`
  ve ürettiği kütüphane silindi; animasyonlar glTF ile geliyor. Durum makinesi
  (`animasyon/oyuncu_agac.tres`) ve `oyuncu.gd` bir satır bile değişmedi —
  hareket dili (genlik, süre, faz) bilerek korundu.
- **Draw call düştü.** Altı ayrı mesh yerine tek skinned mesh: bölüm başına
  ~13 draw call (bolum1 82 → 69). Performans bütçeleri yeni sayılara indirildi;
  eski bütçe yeni regresyonu yakalamazdı.
- **Karakter testi.** `testler/karakter_testi` kemik adlarını, skin'i, dokuyu,
  boyu ve animasyon sürelerini doğruluyor; en önemlisi karakteri OYNATIP
  koşarken bacağın kaç radyan salındığını ölçüyor (0,85 rad) — "animasyon
  çalışıyor görünüyor ama kemik kıpırdamıyor" hatası ancak böyle yakalanıyor.
- Dikenler geometride değil dokuda: atlasa `oyuncu` bölgesi eklendi.

## 0.10.0 — Otomatik oyuncu ve denge (Faz 10)

- **Bot bölümleri gerçekten oynuyor.** `betikler/bot/otomatik_oyuncu.gd`
  gerçek girdiyle (`Input.action_press`) oynuyor: kamerayı hedefe çevirip
  yürüyor, kenarda zıplıyor, hareketli platformu bekleyip biniyor, ölünce
  kontrol noktasından devam ediyor. Karakteri ışınlayan bir bot hiçbir şey
  kanıtlamazdı — zıplama hissi ve hava kontrolü ölçülmemiş olurdu.
- **Denge ölçümü.** `araclar/denge_olc.gd` her bölümü bota oynatıp süre, ölüm,
  zıplama sayısı ve zorlanılan geçişleri yazıyor; `denge_butce.json` sınırları
  aşılırsa CI kırmızıya dönüyor. Sayılar insan süresi değil: bölümün
  DEĞİŞTİĞİNİ yakalamak için.
- **Par turu.** Botun turu `res://hayaletler/` altında oyunla birlikte
  geliyor. İlk kez oynayanın da yarışacak biri oluyor; HUD "par turu −1,20"
  yazıyor. Kendi turun daha hızlıysa hayalet ona dönüyor.
- **Ortak bölüm grafı.** Faz 9'un doğrulayıcısındaki geometri
  `betikler/bolum_grafi.gd` içine taşındı; test ile bot aynı grafı kullanıyor.
  İki ayrı uygulama, testin "geçilebilir" dediği boşluğu botun geçememesi
  demek olurdu.
- **Bot bir kare bütçesi hatası buldu.** Hayalet her karede `visible` atıyordu;
  değer değişmese bile görünürlük alt ağaca yayıldığı için hayalet oynarken
  kare ~60 kat pahalılaşıyordu. Tek satırlık düzeltme ölçümü 120 saniyeden
  1 saniyeye indirdi — gerçek cihazda da ödenen bir bedeldi.
- **Eğik platformlar parçalanıyor.** Rampa tek eksen hizalı kutu olarak
  temsil edilince "4,1 m yukarıda" görünüyordu; artık eğim ekseni boyunca
  parçalara bölünüyor ve her parçanın kendi yüksekliği var.

## 0.9.0 — İçerik ölçeği (Faz 9)

- **Dört yeni bölüm.** Diken Köprüsü (dar taşlar), Rüzgâr Terası (hareketli
  platformlar), Kaya Bahçesi (düşman baskısı), Son Tırmanış (hepsi birden).
  Oyun iki bölümden **altı** bölüme çıktı; süre ~20 dakikadan ~45 dakikaya.
- **Bölüm hattı.** Bölümler artık veriden üretiliyor: `bolum_tasarimi/bolumN.gd`
  (koordinatlar ve tasarım gerekçesi) → `araclar/bolum_uret.gd` →
  `sahneler/bolumN.tscn`. Her bölümün 250 satırlık ortak iskeleti (HUD,
  duraklatma, bitiş ekranı, hayalet kaydedici, ortam) artık kopyalanmıyor.
- **Bitirilebilirlik doğrulayıcısı.** `testler/bolum_hatti_testi` duraklar
  arası zıplama menzilini oyuncunun kendi değerlerinden hesaplayıp doğuştan
  bitişe yol arıyor; çiçekler ve kontrol noktaları da erişilebilir olmalı.
- **Bölüm 2 onarıldı.** Doğrulayıcı ilk çalıştığında bölüm 2'nin
  BİTİRİLEMEZ olduğunu buldu: başlangıç platformundan en yakın basamak 15 m
  ötede, diğerleri 5 m yukarıdaydı ve zemin baştan sona dikenliydi. Kuleye
  dört giriş taşı eklendi.
- **Tuş atama ekranı.** Ayarlar > Tuş atama: sekiz eylemin birincil tuşu
  değiştirilebiliyor, çakışma reddediliyor, ok tuşları ve oyun kolu
  bağlamaları korunuyor, varsayılana dönülebiliyor.
- Ana menü altı bölümde iki sütuna geçiyor; ayarlar paneli büyüdü.

## 0.8.0 — Ticari sürüm hazırlığı (Faz 8)

- **Demo sürümü.** `demo` özellik etiketiyle dışa aktarıldığında oyun tek
  bölüme iniyor, bitişte "tam sürüm" notu gösteriyor. Ayrı bir kod dalı değil,
  aynı yapının kısıtlı hâli: demoyu güncellemeyi unutmak mümkün değil.
- **Anonim telemetri (varsayılan kapalı).** Ayarlardan açık rıza verilirse
  bölüm başlangıcı, ölüm konumu, bitirme ve yarıda bırakma olayları anonim
  gönderiliyor. Sunucu adresi depoda boş; boşken hiç çalışmıyor.
- **Telemetri sunucusu.** `sunucu/` altında Cloudflare Worker + D1: katı gövde
  doğrulaması, olay beyaz listesi, `/ozet` ucunda huni ve ölüm haritası.
- **Basın kiti.** `basin/index.html` — künye, TR/EN açıklama, yedi 1920×1080
  ekran görüntüsü, kullanım izni (para kazandıran içerikler dâhil).
- **Çıkış planı.** `CIKIS-PLANI.md`: sayfa açılışından çıkış gününe kadar
  geri sayım takvimi.
- **Testler.** `telemetri_testi` (gizlilik kuralları) ve `telemetri_testi.sh`
  (oyunun ürettiği gerçek gövdeyi Worker'ın kendi doğrulayıcısından geçirir).

## 0.7.0 — Ağ ve hayalet yarış (Faz 7)

- Yerel ağda iki oyunculu deneysel kip: ENet, istemci yetkisi + sunucu
  doğrulaması, 0.12 sn aradeğerleme tamponu.
- Sunucu hareket doğrulaması: paket **üretim** zamanına göre hız sınırı; meşru
  ışınlanmalar (doğuş, kontrol noktası) hızda sınırlı biçimde izinli.
- En iyi turun hayaleti: 20 Hz kayıt, `user://hayaletler/` altında saklanıyor,
  sonraki turda yarı saydam bir kaktüs olarak yarışıyor.
- İki süreçli ağ testi (`testler/ag_testi.sh`).

## 0.6.0 — Derinleşme (Faz 6)

- **Telefon desteği:** ekran kontrolleri (sol yarı analog çubuk, sağ yarı
  kamera), fare taklidi kapalı, mobil renderer ve ETC2 doku sıkıştırması.
- Performans bütçesi ve ölçüm betiği; MultiMesh birleştirme.
- Lokalizasyon (TR/EN), erişilebilirlik ayarları, shader'lar (dikenli tarla,
  düşman erime efekti).

## 0.5.0 — Dikey dilim (Faz 5)

- İkinci bölüm: dikey kule tırmanışı.
- Dövüş döngüsü: can, hasar anı dokunulmazlığı, geri tepme, üstüne binme.
- Tanıtım videosu betiği, mağaza metni, ekran görüntüsü çekme aracı.

## 0.4.0 — Animasyon, yapay zekâ, seviye tasarımı (Faz 4)

- Durum makineli düşmanlar: devriye, fark etme, kovalama, saldırı, çekilme.
- Görüş alanı: 120° koni + engel kontrolü. Arkadan yaklaşmak işe yarıyor.
- Navigasyon ağı çevrimdışı pişiriliyor; AnimationTree + BlendSpace1D.

## 0.3.0 — Bitmiş küçük oyun (Faz 3)

- Ana menü, duraklatma, bitiş ekranı, ayarlar ve kayıt.
- 13 ses efekti, ses yolları, itch.io için web derlemesi.

## 0.2.0 — Varlık hattı (Faz 2)

- Blender `bpy` ile betikten üretilen modeller, tek doku atlası, glTF dışa
  aktarımı. Varlıklar elle değil komutla üretiliyor.

## 0.1.0 — Temeller (Faz 1)

- CharacterBody3D oyuncu kontrolü: coyote süresi, zıplama tamponu, değişken
  zıplama yüksekliği, artırılmış düşüş yerçekimi.
- İlk bölüm, toplanabilirler, kontrol noktaları, üçüncü şahıs kamera.

---

## 1.0.0 için kalanlar

Çıkışta `1.0.0` yazabilmek için gereken, "daha fazla özellik" değil; şunlar:

- [x] Bölüm sayısı hedefe ulaştı: altı bölüm (Faz 9)
- [ ] 20 kişiye oynatıldı, geri bildirim işlendi (bot sayıları üretiyor ama eğlence ölçmüyor)
- [ ] Gerçek telefonda APK denendi (bu ortamda Android SDK yok)
- [x] Tuş atama ekranı (Faz 9)
- [ ] Trailer'a ses eklendi
- [ ] Steam sayfası yayında ve wishlist toplanıyor
