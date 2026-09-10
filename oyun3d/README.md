# Cactus 3B — oyun projesi

[3B Oyun Yol Haritası](../3D-OYUN-YOLHARITASI.md)'nın uygulandığı yer.
Şu an **Faz 2** bitti: oynanabilir bölüm artık kutulardan değil, modellenmiş
varlıklardan oluşuyor.

| Faz | Ne geldi |
|---|---|
| **0** | Godot projesi, "merhaba küp", üç platforma dışa aktarım zinciri, CI |
| **1** | Üçüncü şahıs karakter + animasyon durum makinesi, parkur bölümü, toplanabilir/tuzak/kontrol noktası/hareketli platform, bölüm akışı, davranış testleri |
| **2** | Blender varlık hattı: 5 modellenmiş nesne, ortak doku atlası, UV paketleme, glTF dışa/içe aktarım, ölçek-eksen-yoğunluk testleri, Git LFS |

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

### Bölümün amacı

8 çiçeği topla, dikenli alana düşmeden parkuru geç, sondaki altın platforma çık.
Dikenli alan seni son kontrol noktasına yollar (bayrak direkleri). Süre ve ölüm
sayısı üstte; bölüm bitince ikisi de yazılır. Yaklaşık 2–3 dakikalık bir tur.

---

## Testler

```bash
godot --headless --path oyun3d --script res://testler/bolum_testi.gd    # oynanış
godot --headless --path oyun3d --script res://testler/varlik_testi.gd   # varlıklar
```

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
│   ├── oyuncu.gd            Hareket, zıplama, animasyon sürücüsü
│   ├── kamera.gd            SpringArm3D üçüncü şahıs kamera
│   ├── oyun.gd              Bölüm akışı: sayaç, süre, ölüm, bitiş
│   ├── platform.gd          @tool — ölçü/renk uygular
│   ├── toplanabilir.gd · tuzak.gd · kontrol_noktasi.gd · bitis.gd
│   ├── hareketli_platform.gd
│   └── hud.gd               Durum + kare bütçesi
├── varliklar/               Modellenmiş nesneler (.gltf + .bin) ve atlas.png
│   └── olcum.json           Blender'ın raporu = Godot testinin sözleşmesi
├── animasyon/               Üretilmiş animasyon kütüphanesi ve durum makinesi
├── araclar/
│   ├── animasyon_uret.gd    Animasyon üretici (Godot)
│   └── modeller.py          Varlık üretici (Blender/bpy)
└── testler/
    ├── bolum_testi.gd       Oynanış davranışları
    └── varlik_testi.gd      Varlık hattı
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
| Web dışa aktarımı | ✅ `index.wasm` + `index.pck` |
| Windows dışa aktarımı | ✅ geçerli PE32+ ikili |
| Tarayıcıda açılış | ✅ Chromium'da WebGL2, parkur ve HUD çizildi |
| Android dışa aktarımı | ⚠️ denenmedi — Android SDK gerekiyor, o ortamda indirilemedi |

---

## Faz 3'te sırada ne var

Yol haritasına göre Faz 3 **bitmiş küçük oyun**: menü, ayarlar, ses, kayıt,
kredi ekranı ve itch.io yayını. Bu fazın açık kalan uçları oraya taşınıyor:

- **Ses** — proje hâlâ tamamen sessiz. Adım, zıplama, toplama, düşme.
- **Karakter modeli** — karakter hâlâ kutu. Modellenmiş + rig'li bir kaktüs
  gelince `animasyon_uret.gd` emekli olur, `AnimationTree` yapısı kalır.
- **Prop çarpışması** — süsleme nesnelerinin çarpışması yok. Godot'nun glTF
  içe aktarıcısı, Blender'da adı `-col` ile biten mesh'ler için otomatik
  `StaticBody3D` üretir; sandık ve kayaya bu uygulanacak.
- **Malzeme paylaşımı** — beş nesnenin beş ayrı malzemesi var, hepsi aynı
  atlası gösteriyor. Tek malzemeye indirmek draw call düşürür (Faz 6).
