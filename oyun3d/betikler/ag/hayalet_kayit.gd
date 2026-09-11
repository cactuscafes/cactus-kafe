class_name HayaletKayit
extends Resource
## Bir turun kaydı: sabit aralıkla örneklenmiş konum, yön ve hız.
##
## BOYUT HESABI: 20 Hz × 60 sn × (12 bayt konum + 4 yön + 4 hız) = ~24 KB.
## Her kareyi kaydetmek üç kat büyütür ve hiçbir şey kazandırmaz — aradaki
## değerler zaten doğrusal aradeğerlemeyle geri geliyor. Ağ üzerinden
## taşınacak veride "ne kadar sık" sorusu her zaman ilk sorudur.
##
## Paketlenmiş diziler (PackedVector3Array vb.) bilerek: Array[Vector3] her
## eleman için ayrı Variant tutar, bu boyutta 3-4 kat yer kaplar.

@export var bolum := ""
@export var sure := 0.0
@export var olum := 0
@export var aralik := 0.05
@export var konumlar := PackedVector3Array()
@export var yonler := PackedFloat32Array()
@export var hizlar := PackedFloat32Array()
## Kaydı kimin attığı (skor tablosu için).
@export var oyuncu_adi := ""
@export var zaman_damgasi := 0

func ornek_sayisi() -> int:
	return konumlar.size()

func ekle(konum: Vector3, yon: float, hiz: float) -> void:
	konumlar.append(konum)
	yonler.append(yon)
	hizlar.append(hiz)

## t saniyesindeki durum. Örnekler arasında doğrusal aradeğerleme yapar;
## yön açısı için lerp_angle (359° ile 1° arasında ters yöne dönmesin).
func ornekle(t: float) -> Dictionary:
	if konumlar.is_empty():
		return {}
	var oran := t / aralik
	var i := int(floor(oran))
	if i < 0:
		return {"konum": konumlar[0], "yon": yonler[0], "hiz": hizlar[0], "bitti": false}
	if i >= konumlar.size() - 1:
		var son := konumlar.size() - 1
		return {"konum": konumlar[son], "yon": yonler[son], "hiz": hizlar[son], "bitti": true}
	var f := oran - float(i)
	return {
		"konum": konumlar[i].lerp(konumlar[i + 1], f),
		"yon": lerp_angle(yonler[i], yonler[i + 1], f),
		"hiz": lerpf(hizlar[i], hizlar[i + 1], f),
		"bitti": false,
	}

## Verilen konuma en yakın örneğin zamanı. Hayalet farkı ("önündesin /
## arkandasın") bununla hesaplanıyor: aynı YERDE hayalet saatin kaçtı?
func en_yakin_zaman(konum: Vector3, ipucu := 0) -> float:
	if konumlar.is_empty():
		return 0.0
	# Baştan sona aramak yerine son bulunan yerin çevresine bakıyoruz:
	# oyuncu parkurda ilerliyor, bir önceki eşleşme iyi bir tahmin.
	var bas := maxi(0, ipucu - 40)
	var son := mini(konumlar.size(), ipucu + 120)
	var en_iyi := bas
	var en_kisa := INF
	for i in range(bas, son):
		var uzaklik := konumlar[i].distance_squared_to(konum)
		if uzaklik < en_kisa:
			en_kisa = uzaklik
			en_iyi = i
	return float(en_iyi) * aralik

static func yol(bolum_kimligi: String) -> String:
	return "user://hayaletler/%s.res" % bolum_kimligi

static func yukle(bolum_kimligi: String) -> HayaletKayit:
	var y := yol(bolum_kimligi)
	if not ResourceLoader.exists(y):
		return null
	return ResourceLoader.load(y, "", ResourceLoader.CACHE_MODE_IGNORE) as HayaletKayit

func kaydet() -> Error:
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path("user://hayaletler"))
	return ResourceSaver.save(self, HayaletKayit.yol(bolum))
