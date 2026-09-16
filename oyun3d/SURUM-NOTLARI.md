# Sürüm notları — Cactus 3B

Anlamlı sürümleme: **BÜYÜK.KÜÇÜK.YAMA**. Çıkışa kadar `0.x`, çıkışta `1.0.0`.
Tek kaynak `betikler/urun.gd` içindeki `SURUM` sabiti — oyun içi krediler,
telemetri olayları, basın kiti ve mağaza metni hep oradan okuyor.

> **Sürüm numarasını değiştirirken:** `betikler/urun.gd` → `SURUM`,
> `project.godot` → `config/version`, `sunucu/package.json` → `version`,
> `basin/index.html` altbilgisi. Dördü ayrı yerde; `grep -rn "0\.8\.0" oyun3d`
> hepsini gösteriyor. Yanlış sürümü yayınlamanın bedeli, geri bildirimin hangi
> yapıdan geldiğini bilememektir.

---

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

- [ ] Bölüm sayısı hedefe ulaştı (en az 6 — iki bölüm bir demo, altı bölüm bir oyun)
- [ ] 20 kişiye oynatıldı, geri bildirim işlendi
- [ ] Gerçek telefonda APK denendi (bu ortamda Android SDK yok)
- [ ] Tuş atama ekranı (erişilebilirliğin en çok istenen maddesi)
- [ ] Trailer'a ses eklendi
- [ ] Steam sayfası yayında ve wishlist toplanıyor
