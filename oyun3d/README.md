# Cactus 3B — oyun projesi

[3B Oyun Yol Haritası](../3D-OYUN-YOLHARITASI.md)'nın uygulandığı yer.
Şu an **Faz 4** bitti: parkurda düşman var, oyuncunun canı var ve vuruşlar
hissediliyor.

| Faz | Ne geldi |
|---|---|
| **0** | Godot projesi, "merhaba küp", üç platforma dışa aktarım zinciri, CI |
| **1** | Üçüncü şahıs karakter + animasyon durum makinesi, parkur bölümü, toplanabilir/tuzak/kontrol noktası/hareketli platform, bölüm akışı, davranış testleri |
| **2** | Blender varlık hattı: 5 modellenmiş nesne, ortak doku atlası, UV paketleme, glTF dışa/içe aktarım, ölçek-eksen-yoğunluk testleri, Git LFS |
| **3** | Ana menü, duraklatma, ayarlar, bitiş ekranı, ses (10 parça, sentezlenmiş), ayar/rekor kaydı, arayüz testleri, itch.io paketi |
| **4** | Durum makineli düşman + NavigationAgent3D, can/hasar/dokunulmazlık, vuruş duraklaması, ekran sarsıntısı, parçacık, zemin eğimine yatma, yapay zekâ testleri |

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

### Oyunun akışı

Ana menü → bölüm → (Esc ile duraklatma) → bitiş ekranı → tekrar ya da menü.
Ayarlar hem menüden hem duraklatmadan açılıyor; aynı panel, tek yerde.

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
godot --headless --path oyun3d res://testler/dusman_testi.tscn   # yapay zekâ, hasar
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

## Düşman ve dövüş (Faz 4)

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

Karakter modeli rampada dik durmuyor, zeminin normaline yatıyor. Gerçek ayak
IK'sı iskelet ister; bu, kutu karakterde aynı işi gören ucuz sürümü. Eğim
`Yon` düğümüne uygulanıyor — animasyonlar `Yon/Model`in dönüşünü yazıyor,
ikisi çakışmasın diye.

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
hassasiyeti, tam ekran) ve `kayit.cfg` (en iyi süre, o turdaki ölüm, oynanma
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

## Karakter ve animasyon

Karakter kutulardan kurulu; `Yon/Model` altındaki uzuvlar birer `Node3D` pivot.
Animasyonlar `araclar/animasyon_uret.gd` ile **kodla üretiliyor**:

```bash
godot --headless --path oyun3d --script res://araclar/animasyon_uret.gd
```

Üretilenler: `animasyon/oyuncu.tres` (bosta, yürüme, koşma, zıplama, düşme) ve
`animasyon/oyuncu_agac.tres` (durum makinesi).

Neden kodla: Faz 1'de rig'li bir model yok — Mixamo bir Adobe hesabı istiyor.
Kutu karakterde animasyon, düğüm dönüşlerinin zamana bağlı değeri demek; sinüsle
üretmek elle keyframe koymaktan hızlı ve tekrarlanabilir. **Faz 2'de** Blender'dan
gerçek model gelince bu üretici silinecek, animasyonlar GLB ile birlikte gelecek —
`AnimationTree` yapısı aynen kalabilir. Öğrenilmesi gereken şey zaten o yapı.

**Durum makinesi:** `yer` (bosta ↔ yürüme ↔ koşma arasında bir `BlendSpace1D`,
karışım konumunu yatay hız sürüyor), `zipla`, `dusme`. Geçişleri `oyuncu.gd`
`travel()` ile tetikliyor.

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

Karakterin maskesi zemin + platform; Area3D'lerin maskesi yalnızca oyuncu.
Böylece çiçekler birbirini, tuzak platformu tetiklemiyor.

---

## Klasör düzeni

```
oyun3d/
├── project.godot            Ayarlar, autoload, renderer, çarpışma katmanı isimleri
├── sahneler/
│   ├── ana.tscn             Bölüm: parkur, tuzak, çiçekler, bitiş, HUD
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
│   ├── dusman.gd            Durum makineli düşman
│   ├── menu/                Ana menü, ayarlar paneli, duraklatma, bitiş
│   ├── oyuncu.gd            Hareket, zıplama, animasyon sürücüsü
│   ├── kamera.gd            SpringArm3D üçüncü şahıs kamera
│   ├── oyun.gd              Bölüm akışı: sayaç, süre, ölüm, bitiş
│   ├── platform.gd          @tool — ölçü/renk uygular
│   ├── toplanabilir.gd · tuzak.gd · kontrol_noktasi.gd · bitis.gd
│   ├── hareketli_platform.gd
│   └── hud.gd               Durum + kare bütçesi
├── ses/                     Sentezlenmiş ses efektleri ve müzik
├── navigasyon/bolum1.tres   Pişirilmiş navigasyon örgüsü
├── arayuz/tema.tres         Ortak buton/etiket teması
├── default_bus_layout.tres  Master / SFX / Müzik bus'ları
├── varliklar/               Modellenmiş nesneler (.gltf + .bin) ve atlas.png
│   └── olcum.json           Blender'ın raporu = Godot testinin sözleşmesi
├── animasyon/               Üretilmiş animasyon kütüphanesi ve durum makinesi
├── araclar/
│   ├── animasyon_uret.gd    Animasyon üretici (Godot)
│   ├── modeller.py          Varlık üretici (Blender/bpy)
│   ├── sesler.py            Ses üretici
│   └── navmesh_uret.gd      Navigasyon örgüsü üretici
└── testler/
    ├── bolum_testi.gd       Oynanış davranışları
    ├── varlik_testi.gd      Varlık hattı
    ├── arayuz_testi.gd      Menü, ayar, kayıt, duraklatma
    └── dusman_testi.gd      Yapay zekâ, hasar, navigasyon
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
| Bölüm testleri (7 test) | ✅ hepsi geçti |
| Varlık testleri (5 varlık) | ✅ hepsi geçti |
| Web dışa aktarımı | ✅ `index.wasm` + `index.pck` |
| Windows dışa aktarımı | ✅ geçerli PE32+ ikili |
| Arayüz testleri (6 grup) | ✅ hepsi geçti |
| Düşman testleri (6 grup) | ✅ hepsi geçti |
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

## Faz 5'te sırada ne var

Yol haritasına göre Faz 5 **dikey dilim**: 15 dakikalık, son kalitede tek
bölüm; 60 saniyelik trailer; Steam sayfası. Açık kalan uçlar:

- **Karakter modeli** — karakter hâlâ kutu. Modellenmiş + rig'li bir kaktüs
  gelince `animasyon_uret.gd` emekli olur, `AnimationTree` yapısı kalır.
- **Prop çarpışması** — süsleme nesnelerinin çarpışması yok. Godot'nun glTF
  içe aktarıcısı, Blender'da adı `-col` ile biten mesh'ler için otomatik
  `StaticBody3D` üretir; sandık ve kayaya bu uygulanacak.
- **Malzeme paylaşımı** — beş nesnenin beş ayrı malzemesi var, hepsi aynı
  atlası gösteriyor. Tek malzemeye indirmek draw call düşürür (Faz 6).
- **İkinci bölüm** — şu an tek bölüm var; `oyun.gd` bölüm yükleyicisine
  dönüşecek.
- **Düşmana can ve geri bildirim** — düşman şu an ölümsüz; oyuncunun karşılık
  verme yolu yok. Dikey dilimde ya bir saldırı mekaniği ya da kaçınma
  odaklı tasarım netleşmeli.
- **Kök hareketi (root motion) ve gerçek ayak IK'sı** — ikisi de iskeletli
  model ister; rig'li karakterle birlikte gelir.
