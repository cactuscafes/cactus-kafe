# Cactus 3B — Faz 0

[3B Oyun Yol Haritası](../3D-OYUN-YOLHARITASI.md)'nın **Faz 0** çıktısı: kamera, ışık,
zemin ve hareket eden bir küp — üç platforma dışa aktarılabilir hâlde.

Amaç oyun yapmak değil. Amaç **zinciri kurmak**: proje açılıyor, çalışıyor,
Windows/Web/Android olarak paketleniyor ve bunu CI de yapabiliyor. Bu zincir
ilk günden kurulmazsa, altıncı ayda oyununu paketleyemediğin gün öğrenirsin.

---

## Kurulum

1. **Godot 4.7.x**'i indir: <https://godotengine.org/download> (kurulum gerektirmez,
   tek dosya). Standart sürüm yeterli; C# yazmayacaksan .NET sürümüne gerek yok.
2. Godot'yu aç → **Import** → bu klasördeki `project.godot` dosyasını seç.
3. İlk açılışta içe aktarım yapar (`.godot/` klasörü oluşur; depoya girmez).
4. **F5** ile çalıştır.

### Kontroller

| Tuş | İş |
|---|---|
| `W A S D` / yön tuşları | Hareket (kamera yönüne göre) |
| `Shift` | Koşma |
| `Space` | Zıplama |
| Fare | Kamerayı çevir |
| `Esc` | Fare kilidini bırak / geri al (tarayıcıda geri almak için sahneye tıkla) |

Sol üstteki bilgi kutusu FPS, kare süresini (**bütçe 16.6 ms**), draw call sayısını
ve GPU adını gösterir. Bu üç sayıya bakma alışkanlığı Faz 6'daki optimizasyon
işinin yarısıdır.

---

## Duman testi

```bash
godot --headless --path oyun3d --script res://testler/faz0_test.gd
```

Pencere açmadan çalışır, ~2,5 saniyelik fizik simüle eder ve şunu kanıtlar:
ana sahne yükleniyor, betikler derleniyor, girdi eylemleri kurulu, yerçekimi ve
zemin çarpışması çalışıyor, karakter girdiye hareketle yanıt veriyor. Çıkışta
konum ve kat edilen mesafeyi yazar; başarısızlıkta `1` döner, yani CI'da da
kullanılabilir — `.github/workflows/oyun3d-web.yml` dışa aktarımdan önce bunu
çalıştırıyor.

Ekran görüntüsü bir kanıt değildir; sayı kanıttır. Faz 1'de bu dosyanın yanına
karakterin zıplama yüksekliğini ve rampa tırmanışını ölçen testler gelecek.

---

## Dışa aktarım

Şablonlar bir kez indirilir: **Editör → Dışa Aktarım Şablonlarını Yönet → İndir**.

Ardından hazır ön ayarları kopyala:

```bash
cp export_presets.cfg.ornek export_presets.cfg
```

Gerçek `export_presets.cfg` bilerek `.gitignore`'dadır: Godot bu dosyaya Android
imza anahtarının parolasını da yazar. Şablon sürüm kontrolünde, sırlar dışarıda.

| Hedef | Ön ayar | Not |
|---|---|---|
| Windows | `Windows` | `cikti/windows/cactus3d.exe` |
| Web | `Web` | `cikti/web/index.html` — yerelde `python3 -m http.server` ile aç, `file://` çalışmaz |
| Android | `Android` | JDK 17 + Android SDK gerekir; Editör Ayarları → Export → Android'de yollar ve debug keystore tanımlanır |

Komut satırından:

```bash
godot --headless --export-release "Web" ../cikti/web/index.html
```

**Web notu:** tarayıcı hedefi `gl_compatibility` renderer ile çalışır
(`project.godot` içinde ayarlı). Masaüstündeki `forward_plus` ile aynı gölge ve
efektleri beklemeyin — bu bir hata değil, platform farkı. Aynı proje iki farklı
render yolundan geçtiğinde neyin değiştiğini görmek, Faz 6'nın ön hazırlığı.

**VRAM doku sıkıştırması:** Web ve Android ön ayarlarındaki
`vram_texture_compression` seçenekleri, `project.godot` içindeki
`textures/vram_compression/import_s3tc_bptc` ve `import_etc2_astc` ayarları
açık değilse dışa aktarımı "configuration errors" diyerek durdurur. İkisi de
açık geliyor; kapatmayın.

**CI:** `.github/workflows/oyun3d-web.yml` aynı işi Ubuntu'da elle tetiklemeyle
yapar (Actions → *3B Oyun — Web Derlemesi* → Run workflow). Derleme artifact
olarak iner. Godot sürümünü iş akışı girdisinden değiştirebilirsin.

---

## Klasör düzeni

```
oyun3d/
├── project.godot            Proje ayarları, autoload, renderer seçimi
├── icon.svg                 Uygulama ikonu
├── export_presets.cfg.ornek Üç hedefin ön ayarı (kopyalanacak şablon)
├── sahneler/
│   ├── ana.tscn             Zemin, ışık, gökyüzü, basamaklar, HUD
│   └── oyuncu.tscn          Küp gövde + çarpışma + kamera yayı
└── betikler/
    ├── girdi.gd             Autoload: girdi eylemlerini kurar
    ├── oyuncu.gd            Yerçekimi, kamera yönüne göre hareket, zıplama
    └── hud.gd               FPS / kare süresi / draw call
```

`oyuncu.tscn` ayrı bir sahne ve `ana.tscn` içine örneklenmiş durumda. Bu Godot'nun
temel çalışma biçimi: her şey bir sahne, sahneler iç içe geçer. Faz 1'de karakter
bu dosyada büyüyecek, ana sahne hiç değişmeyecek.

### Girdi eylemleri nerede?

`betikler/girdi.gd` içinde, kodda. Sebebi: proje dosyasının Godot sürümleri
arasında elle taşınabilir kalması. **Faz 1'in ilk işi** bunları
*Proje → Proje Ayarları → Girdi Haritası* paneline taşımak olsun — oyuncuya tuş
atama ekranı yazacaksan zaten oraya ihtiyacın var.

---

## Git LFS

Depo kökündeki `.gitattributes`, LFS kurallarını **yalnızca `oyun3d/` altına**
uygular; sitedeki mevcut fotoğraflar bilinçli olarak kapsam dışı. Klonlayan her
makinede bir kez:

```bash
git lfs install
```

İlk `.glb` veya `.png`'yi eklemeden önce bunu yapmayı unutma; sonradan geçmişi
LFS'e taşımak çok daha zahmetli.

---

## Bu iskeletin doğrulanmış durumu

Godot **4.7.2** ile, bu depoda gerçekten çalıştırıldı:

| Adım | Durum |
|---|---|
| `--headless --import` | ✅ hatasız |
| Duman testi | ✅ geçti — karakter 2,5 sn'de 11,56 m yol aldı, `y = 0.50` zeminde |
| Web dışa aktarımı | ✅ `index.wasm` + `index.pck` üretildi |
| Windows dışa aktarımı | ✅ `cactus3d.exe` üretildi |
| Tarayıcıda açılış | ✅ Chromium'da WebGL2 ile sahne çizildi, HUD okundu |
| Android dışa aktarımı | ⚠️ denenmedi — Android SDK (`platform-tools` + `build-tools`) gerekiyor, o ortamda indirilemedi |

Android tarafı sizin makinenizde ilk kurulumda hallolacak: Godot → Editör
Ayarları → Export → Android bölümüne SDK yolunu ve debug keystore'u tanıtın.
Godot APK'yı imzalamak için SDK'nın `apksigner`'ını, cihaza atmak için
`adb`'sini kullanıyor.

---

## Faz 0 kontrol listesi

- [ ] Godot 4.7.x kuruldu, proje açıldı, F5 ile küp koşuyor
- [ ] Dışa aktarım şablonları indirildi
- [ ] Windows derlemesi alındı ve çalıştırıldı
- [ ] Web derlemesi alındı ve yerel sunucudan açıldı
- [ ] Android APK alındı ve telefona kuruldu
- [ ] `git lfs install` çalıştırıldı
- [ ] CI iş akışı bir kez elle tetiklendi ve yeşil döndü

Hepsi işaretlendiğinde Faz 0 bitti; [Faz 1](../3D-OYUN-YOLHARITASI.md)
başlıyor: `CharacterBody3D` yerine gerçek karakter, Mixamo animasyonları,
`AnimationTree` ile geçişler.
