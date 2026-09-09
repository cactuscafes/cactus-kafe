# Profesyonel 3B Oyun Geliştirme — Yol Haritası (Cactus)

Bu doküman, mevcut durumdan (web tabanlı 2B/3B mini oyunlar) **profesyonel seviyede 3B oyun**
üretimine geçiş planıdır. Sırayla uygulanacak şekilde yazıldı; her fazın somut çıktısı var.

---

## 0. Başlangıç noktası — bu repoda zaten olanlar

| Ne | Nerede | Ne anlama geliyor |
|---|---|---|
| 2B canvas oyunları | `oyun-basket.html`, `oyun-hafiza.html`, `oyun-merdiven.html`, `tuglakirici/`, `mayintarlasi/`, `limonyilani/` | Oyun döngüsü, girdi, skor, ses zaten biliniyor |
| **Gerçek bir 3B oyun** | `hooplegend/sahne3d.js` (Three.js bundle, 4118 satır) + `oyuncu.glb` | 3B sahne, kamera, glTF karakter, atış fiziği yazılmış |
| Mobil paketleme | `hooplegend/hooplegend.apk`, `app/CactusCoffee.xcodeproj` | Android + iOS paketleme deneyimi var |
| Mağaza süreci | Cactus Jump kapalı test, gizlilik + veri silme sayfaları, AdMob | Play Console / App Store bürokrasisi biliniyor |
| Altyapı | Cloudflare Worker + D1 + KV, GitHub Actions yedekleme | Backend, CI ve veri kalıcılığı biliniyor |

**Sonuç:** Eksik olan "3B'ye başlamak" değil. Eksik olan üç şey:
1. **Derinlik** — render pipeline, animasyon sistemi, fizik, optimizasyon bilgisi
2. **Üretim hattı (pipeline)** — modelleme → rig → animasyon → oyun içi, tekrarlanabilir biçimde
3. **Bitmiş ürün** — 10+ dakika oynanan, cilalı, mağazada satılan bir oyun

Yol haritası bu üç eksiği kapatmak üzerine kuruludur.

---

## 1. İlk karar: hangi yol?

### A) Web-3B yolu (Three.js / Babylon.js / PlayCanvas)
- **Artısı:** Mevcut becerinin doğrudan devamı. Dağıtım = `git push`. Poki / CrazyGames gibi
  portallar web oyunlarına gelir paylaşımı ödüyor. Cactus markasıyla entegre.
- **Eksisi:** "Profesyonel oyun geliştiricisi" iş piyasası bu dili konuşmuyor. Konsol yok,
  Steam zayıf, büyük ölçekli içerik üretimi zor.
- **2026 durumu:** WebGPU tüm büyük tarayıcılarda temel (baseline) hâle geldi; Three.js'in
  WebGPU renderer'ı üretime hazır. Yani web 3B artık ciddi grafik kaldırabiliyor.

### B) Motor yolu (Godot / Unity / Unreal)
- **Artısı:** Editör, sahne aracı, animasyon sistemi, fizik, profil aracı, konsol/Steam çıkışı hazır.
  Sektörün ortak dili. Portföyün başkasına anlatılabilir hâle gelir.
- **Eksisi:** 2–3 ay öğrenme yatırımı; yeni bir düşünme biçimi (sahne grafiği, prefab/scene, ECS).

### Önerim
**B'ye geç, A'yı gelir ve hızlı portföy kanalı olarak koru.** Web'de kazandığın hızlı geri
bildirim döngüsünü kaybetme; ama asıl derinliği motorda kazan.

### Motor seçimi

| | Godot 4.7 | Unity 6 | Unreal 5.8 |
|---|---|---|---|
| Maliyet | Tamamen ücretsiz, MIT, pay yok | Personal ücretsiz (< $200k yıllık gelir); Pro ~$2.2k/koltuk/yıl | Ücretsiz; ürün başına ilk $1M sonrası %5 telif |
| Dil | GDScript (Python'a yakın) + C# | C# | C++ + Blueprint |
| Güçlü olduğu yer | Hızlı iterasyon, 2B+3B, küçük ekip, açık kaynak | Mobil, iş ilanları, hazır varlık ekosistemi | Fotogerçekçi, AAA, Nanite/Lumen |
| Öğrenme eğrisi | En düşük | Orta | En yüksek |
| Senin durumuna uygunluk | ★★★ Sen tek kişisin, hızlı bitirmen gerek | ★★☆ Mobil + iş piyasası geçmişinle uyumlu | ★☆☆ Şimdilik erken |

**Seç: Godot 4.7.** Sebebi: tek kişilik ekip, ücretsiz, editör açılışı saniyeler, GDScript ile
JS'ten geçiş neredeyse sürtünmesiz, dışa aktarım (Android/iOS/Web/Windows) tek panelden.
Eğer hedefin *iş bulmak / stüdyoya girmek* ise 6. aydan sonra **Unity 6**'yı ikinci motor olarak ekle.

---

## 2. Profesyonel 3B'nin altı sütunu

Bunlar "kurs bitirince" değil, proje içinde tekrar tekrar uygulayınca oturur.

1. **Matematik ve fizik**
   Vektör (dot / cross), matris, **quaternion** (gimbal lock'tan kaçmak için), lokal↔dünya uzayı
   dönüşümleri, `delta` ile kare bağımsız hareket, raycast, AABB/kapsül çarpışma, impuls.
2. **Render pipeline**
   PBR (albedo / metallic / roughness / normal / AO), ışık türleri, gölge haritası, ortam ışığı
   (HDRI, IBL), post-process (bloom, SSAO, tonemap), **draw call / batching / instancing**, LOD,
   frustum & occlusion culling, alpha sıralama sorunları.
3. **Sanat üretim hattı (art pipeline)**
   Blender: blokla → modelle → retopoloji → UV aç → **texel density** → bake → texture →
   rig (Rigify) → animasyon → **glTF/GLB** ile dışa aktarım. Mixamo ile hazır rig + animasyon
   kısayolu. Import ölçeği, eksen yönü (Y-up vs Z-up), materyal eşleme kuralları.
4. **Oyun mimarisi**
   Sahne/node ya da ECS düşüncesi, durum makinesi (karakter, oyun akışı, menü), girdi soyutlama
   (klavye/gamepad/dokunma tek arayüz), kayıt/yükleme, veri odaklı tasarım (seviye ve denge
   verisi koddan ayrı — `.json`/`.tres`), olay yayını (signal/event bus).
5. **Performans**
   Kare bütçesi: 60 FPS = **16,6 ms**. CPU mu GPU mu darboğaz — profil aracıyla ölç, tahmin etme.
   Mobilde termal kısıtlama, doku bellek bütçesi (KTX2/Basis sıkıştırma), gölge çözünürlüğü,
   fizik adım sayısı, GC/allocation baskısı.
6. **Üretim disiplini**
   Kapsam kontrolü (en büyük indie katili), Git + **Git LFS** (binary varlıklar için şart),
   CI ile otomatik build, oyun testi (playtest) ve geri bildirim döngüsü, mağaza sayfası,
   trailer, pazarlama takvimi.

---

## 3. 12 aylık takvim

Varsayım: **haftada 10–15 saat**. Daha az zaman ayırırsan fazları uzat, sırayı bozma.

### Faz 0 — Kurulum (2 hafta)
- Godot 4.7 kur, Blender kur, Git LFS'i `*.glb *.blend *.png *.wav` için ayarla.
- "Merhaba küp": kamera, ışık, zemin, hareket eden bir küp. Web + Windows + Android dışa aktar.
- **Çıktı:** üç platformda da çalışan boş sahne. Dışa aktarım zincirini ilk günden kur.

### Faz 1 — Temeller (Ay 1)
- `CharacterBody3D` ile üçüncü şahıs karakter: yürüme, koşma, zıplama, eğim, kamera yayı.
- Çarpışma katmanları, raycast ile zemin kontrolü, basit tuzak/platform.
- Mixamo'dan animasyon indir, `AnimationTree` + blend space ile yürü/koş/zıpla geçişleri.
- **Çıktı:** 3 dakikalık oynanabilir platform prototipi.

### Faz 2 — Matematik + Blender (Ay 2)
- Freya Holmér'in vektör/quaternion videoları; her konuyu prototipte uygula
  (ör. hedefe yumuşak dönme = `slerp`).
- Blender: donut eğitimi **değil** — doğrudan oyununa girecek 5 low-poly nesne modelle
  (kaktüs, masa, fincan, sandalye, tabela), UV aç, texture'la, GLB olarak Godot'ya al.
- **Çıktı:** tamamı kendi ürettiğin varlıklardan oluşan bir sahne.

### Faz 3 — **Proje 1: bitmiş küçük oyun** (Ay 3)
- Kapsam: 10 dakikada bitirilen, tek mekaniğe dayalı 3B oyun. Ana menü, ayarlar, ses,
  kayıt, ölüm/yeniden başlama, kredi ekranı — yani **cilalı**.
- itch.io'da yayınla, 20 kişiye oynat, geri bildirim topla.
- **Çıktı:** ilk *bitmiş* 3B oyun. Bu, üçüncü sınıf bir prototipten daha değerli.

### Faz 4 — Animasyon, yapay zekâ, seviye tasarımı (Ay 4–5)
- Durum makineli düşman: devriye → fark et → kovala → saldır → geri çekil (NavigationAgent3D).
- Blend tree, root motion, IK (ayak yerleştirme), hasar/geri tepme geri bildirimi
  (ekran sarsıntısı, hit-stop, parçacık, ses) — "game feel" burada öğrenilir.
- Seviye tasarımı: blockout → oyun testi → sanat. Asla ters sırada değil.

### Faz 5 — **Proje 2: dikey dilim (vertical slice)** (Ay 6)
- 15 dakikalık, son kalitede bir bölüm: nihai sanat, ses, UI, denge.
- 60 saniyelik trailer çek. **Steam sayfası aç** (Steam Direct: ürün başına $100, iade edilebilir).
- **Çıktı:** portföyünün merkez parçası + wishlist toplamaya başlayan bir mağaza sayfası.

### Faz 6 — Derinleşme (Ay 7–8)
- Shader yaz (Godot shading language): su, taramalı çizgi, dissolve, outline, toon.
- Optimizasyon: profil al, draw call düşür, LOD ve occlusion, doku atlası, KTX2.
- Çok platform: aynı oyun PC + mobilde 60 FPS. Girdi ve UI ölçeklenmesi.
- Lokalizasyon (TR/EN), erişilebilirlik (renk körlüğü, tuş atama, altyazı).

### Faz 7 — Uzmanlık (Ay 9–10)
Bir yön seç ve derinleş:
- **Ağ/çok oyunculu:** `MultiplayerSynchronizer`, otorite modeli, client prediction, lag comp.
- **Sistem tasarımı:** envanter, ekonomi, ilerleme eğrisi, prosedürel üretim.
- **Grafik:** özel render pass, GPU parçacık, compute shader.
İş piyasasında seni ayıran şey bu uzmanlıktır.

### Faz 8 — **Proje 3: ticari sürüm** (Ay 11–12)
- Steam demo, Next Fest katılımı, wishlist kampanyası (hedef: çıkıştan önce **7.000+**).
- Basın/içerik üreticisi listesi, basın kiti, çıkış takvimi.
- **Çıktı:** satılan bir oyun. Bu noktadan sonra "profesyonel" lafı senin için doğru.

### Her ay, istisnasız: **bir game jam**
48 saatlik kapsam disiplini, bitirme alışkanlığı ve portföy — üçünü birden verir.
Ludum Dare, GMTK Jam, Global Game Jam, Brackeys Jam, itch.io/jams.

---

## 4. Çalışacağımız siteler

### Motor ve resmî dokümantasyon
- **docs.godotengine.org** — resmî doküman; "Your first 3D game" ile başla
- **learn.unity.com** — Unity Learn (ikinci motor için)
- **dev.epicgames.com/documentation** — Unreal dokümanı
- **threejs.org/docs** · **doc.babylonjs.com** · **playcanvas.com** — web 3B tarafı

### Öğrenme
- **GDQuest** (gdquest.com, YouTube) — Godot'nun en iyi kaynağı
- **Brackeys** (YouTube) — Godot serisi, yeni başlayan için en temiz anlatım
- **Catlike Coding** (catlikecoding.com) — Unity + render matematiği; sektörün klasiği
- **Three.js Journey** (threejs-journey.com, Bruno Simon) — web 3B için en iyi ücretli kurs
- **learnopengl.com** — render pipeline'ın altında ne olduğunu anlamak için
- **Freya Holmér** (YouTube) — vektör, quaternion, spline; matematiği sezgisel anlatır
- **Blender Guru / Grant Abbitt / CG Cookie** — Blender; Grant Abbitt özellikle *oyun için* modelleme
- **GDC / GDC Vault** (YouTube: GDC kanalı) — tasarım ve teknik konuşmalar; ücretsiz olanlar bile hazine
- **Game Programming Patterns** (gameprogrammingpatterns.com) — ücretsiz kitap, mimari için şart

### Varlık (asset) kaynakları
- **Poly Haven** (polyhaven.com) — CC0 HDRI, doku, model. Lisans derdi yok
- **ambientCG** (ambientcg.com) — CC0 PBR dokular
- **Kenney** (kenney.nl) — CC0 low-poly 3B paketler; prototip için ideal
- **Mixamo** (mixamo.com) — ücretsiz otomatik rig + binlerce animasyon
- **Fab** (fab.com) — Epic'in birleşik pazaryeri (eski Quixel + UE Marketplace + Sketchfab store)
- **Sketchfab** (sketchfab.com) — model kütüphanesi ve 3B önizleme
- **itch.io/game-assets** · **OpenGameArt** — indie varlık
- **Freesound** (freesound.org) · **Pixabay** — ses efekti ve müzik (lisansı her seferinde kontrol et)

### Araçlar
- **Blender** (blender.org) — modelleme/rig/animasyon; ücretsiz ve sektörde kabul görüyor
- **Material Maker** (ücretsiz, prosedürel doku) / **Substance 3D Painter** (ücretli, sektör standardı)
- **Krita** veya **GIMP** — doku ve UI grafiği
- **Audacity** — ses düzenleme
- **Git + Git LFS** + **GitHub Actions** — sürüm kontrolü ve otomatik build (zaten kullanıyorsun)
- **Trello / GitHub Projects** — kapsam ve görev takibi

### Yayın ve dağıtım
- **itch.io** — ilk günden yayınla; ücretsiz, hızlı geri bildirim
- **Steamworks** (partner.steamgames.com) — Steam Direct $100/ürün, %30 pay (satış arttıkça düşer)
- **Google Play Console** ($25 tek sefer) · **App Store Connect** ($99/yıl) — ikisini de biliyorsun
- **Poki** (developers.poki.com) · **CrazyGames** (developer.crazygames.com) — web oyunları için
  gerçek gelir paylaşımı; `hooplegend` bu portallara aday
- **Epic Games Store** — seçici ama %12 pay

### Topluluk ve geri bildirim
- **r/gamedev**, **r/godot**, **r/Unity3D** — sorunun cevabı çoğunlukla burada
- **Godot Discord / forum.godotengine.org** — resmî destek kanalları
- **Global Game Jam** (globalgamejam.org) — Türkiye'de fiziksel etkinlik siteleri var; ağ kurmanın en kısa yolu
- **Bluesky / X'te #gamedev, #screenshotsaturday** — düzenli paylaşım = erken kitle
- Türkiye: yerel oyun geliştirici toplulukları ve stüdyo etkinlikleri (Peak, Dream Games, Rollic,
  Spyke, Gram Games, TaleWorlds, Ubisoft İstanbul) — İstanbul'daki meetup'ları takip et

### Pazarlama ve sektör analizi (Faz 5'ten sonra ciddiye al)
- **howtomarketagame.com** (Chris Zukowski) — Steam pazarlaması hakkında veriye dayalı en iyi kaynak
- **GameDiscoverCo** (Simon Carless) — bülten; keşfedilebilirlik verisi
- **SteamDB** (steamdb.info) · **VG Insights** — pazar ve rakip analizi

### İş / kariyer (hedef stüdyoya girmekse)
- **HitmarkerJobs.com**, **WorkWithIndies.com**, **RemoteGameJobs.com** — oyun sektörüne özel ilanlar
- **ArtStation** — teknik sanat portföyü; kod tarafı için GitHub yeterli

---

## 5. "Profesyonel" ne zaman doğru kelime olur?

Üç ölçüt karşılandığında:

1. **Bitirdin ve yayınladın.** Prototip klasörü değil, mağazada duran, insanların oynadığı oyun.
2. **Pipeline'ın var.** Yeni bir karakter fikri → modelleme → rig → animasyon → oyun içi akışını
   tekrarlanabilir ve belgelenmiş biçimde yapabiliyorsun. Başkası ekibe girse aynı yolu izleyebiliyor.
3. **Ölçüyorsun.** Hedef donanımda kararlı 60 FPS, ölçülmüş kare bütçesi, bellek profili.
   "Bende çalışıyor" cümlesi profesyonel bir cümle değil.

**Portföy paketi:** 3 proje + herkese açık kod deposu + 60 saniyelik trailer + en az bir teknik
yazı (ör. "Godot'da karakter kontrolcüsünü nasıl optimize ettim").

---

## 6. Bu hafta yapılacaklar (somut)

- [ ] Godot 4.7 indir, "Your first 3D game" resmî eğitimini bitir (~4 saat)
- [ ] Blender kur, Grant Abbitt'in "low poly for games" serisinden ilk 3 videoyu izle
- [ ] Yeni bir repo aç (`cactus-oyun-3d` gibi), Git LFS'i binary varlıklar için ayarla
- [ ] Küp koşturan bir sahne yap; Windows + Web + Android olarak dışa aktar
- [ ] Bir sonraki game jam'i takvime yaz ve kaydol
- [ ] Freya Holmér'in "Vectors" videosunu izle

---

## 7. Cactus'a özel kısa yol: `hooplegend`'i profesyonelleştir

Sıfırdan başlamak yerine elindeki 3B oyunu profesyonel standarda çekmek, öğrenmenin en hızlı yolu.
Somut iş listesi:

- **Varlık optimizasyonu:** `oyuncu.glb` için Draco/meshopt sıkıştırma, dokular için KTX2/Basis
- **Render:** Three.js WebGPU renderer'a geçiş, WebGL fallback ile (2026'da WebGPU her tarayıcıda temel)
- **Fizik:** elle yazılmış atış hesabı yerine gerçek fizik motoru (Rapier veya Jolt WASM)
- **Kalite kademesi:** cihaz gücüne göre adaptif çözünürlük/gölge (mobil termal kısıtlama için)
- **Profil:** `Stats` + Spector.js ile draw call sayımı, 60 FPS hedefini ölçerek doğrula
- **Dağıtım:** Poki / CrazyGames başvurusu — mevcut lig/skor backend'i zaten var

Bu, Faz 0–2 ile paralel yürütülebilir ve ilk gelir kanalını açar.

---

## Uyarı: en sık yapılan üç hata

1. **Kapsam patlaması.** "Açık dünya RPG" ilk projede öldürür. Bitmiş küçük oyun > bitmemiş büyük oyun.
2. **Eğitim izleme tuzağı.** İzlemek öğrenmek değil. Her eğitimden sonra aynı şeyi *farklı* bir
   problemde uygula.
3. **Sanat önce.** Oynanış blockout ile kanıtlanmadan hiçbir modele zaman harcama.

---

*Bu doküman yaşayan bir plandır; her faz sonunda gözden geçir ve güncelle.*
