extends Node
## Hayalet kaydı ve oynatma testleri.
##
##   godot --headless --path oyun3d res://testler/hayalet_testi.tscn
##
## Hayalet, ağ tarafının temeli: aynı veri biçimi sunucuya gönderilecek.
## Bu yüzden aradeğerleme, kayıt/yükleme ve "hangi tur kaydedilir" kuralı
## burada sabitleniyor.

var _hatalar: Array[String] = []

func _ready() -> void:
	await get_tree().process_frame
	_calis()

func _dogrula(kosul: bool, mesaj: String) -> void:
	if not kosul:
		_hatalar.append(mesaj)

func _bekle(kare: int) -> void:
	for i in kare:
		await get_tree().physics_frame

func _calis() -> void:
	_aradegerleme_testi()
	_yakin_zaman_testi()
	await _kayit_yukleme_testi()
	await _tur_kaydi_testi()
	await _oynatma_testi()
	await _yavas_tur_testi()

	if _hatalar.is_empty():
		print("HAYALET TESTI: GECTI")
		get_tree().quit(0)
	else:
		for h: String in _hatalar:
			printerr("  ! " + h)
		print("HAYALET TESTI: KALDI (%d)" % _hatalar.size())
		get_tree().quit(1)

func _ornek_kayit() -> HayaletKayit:
	var k := HayaletKayit.new()
	k.bolum = "test"
	k.aralik = 0.1
	k.ekle(Vector3(0, 0, 0), 0.0, 0.0)
	k.ekle(Vector3(1, 0, 0), PI * 0.5, 4.0)
	k.ekle(Vector3(2, 0, 0), PI, 8.0)
	return k

func _aradegerleme_testi() -> void:
	var k := _ornek_kayit()
	var orta := k.ornekle(0.05)
	_dogrula(orta["konum"].distance_to(Vector3(0.5, 0, 0)) < 0.001,
		"Örnekler arası konum aradeğerlenmedi: %s" % orta["konum"])
	_dogrula(absf(orta["hiz"] - 2.0) < 0.001, "Hız aradeğerlenmedi: %.2f" % orta["hiz"])
	_dogrula(not orta["bitti"], "Tur ortasında 'bitti' işaretlendi")

	var son := k.ornekle(5.0)
	_dogrula(son["bitti"], "Kaydın sonunda 'bitti' işaretlenmedi")
	_dogrula(son["konum"].distance_to(Vector3(2, 0, 0)) < 0.001,
		"Kayıt sonrası son konumda durulmadı")

	# Açı aradeğerlemesi 359° -> 1° arasında ters yöne dönmemeli.
	var a := HayaletKayit.new()
	a.aralik = 0.1
	a.ekle(Vector3.ZERO, deg_to_rad(359.0), 0.0)
	a.ekle(Vector3.ZERO, deg_to_rad(1.0), 0.0)
	var aci: float = a.ornekle(0.05)["yon"]
	var derece := fposmod(rad_to_deg(aci), 360.0)
	print("açı aradeğerleme: 359° ile 1° arası -> %.1f°" % derece)
	_dogrula(derece > 355.0 or derece < 5.0,
		"Açı ters yönden dolandı: %.1f° (lerp_angle kullanılmalı)" % derece)

func _yakin_zaman_testi() -> void:
	var k := _ornek_kayit()
	_dogrula(absf(k.en_yakin_zaman(Vector3(1.1, 0, 0)) - 0.1) < 0.001,
		"En yakın örnek bulunamadı")
	_dogrula(absf(k.en_yakin_zaman(Vector3(1.9, 0, 0)) - 0.2) < 0.001,
		"En yakın örnek (son) bulunamadı")

func _kayit_yukleme_testi() -> void:
	var k := _ornek_kayit()
	k.bolum = "test_kayit"
	k.sure = 12.5
	k.olum = 2
	_dogrula(k.kaydet() == OK, "Hayalet diske yazılamadı")
	var okunan := HayaletKayit.yukle("test_kayit")
	_dogrula(okunan != null, "Hayalet diskten okunamadı")
	if okunan != null:
		_dogrula(absf(okunan.sure - 12.5) < 0.001, "Süre kayıptan sağ çıkmadı")
		_dogrula(okunan.ornek_sayisi() == 3,
			"Örnek sayısı %d, 3 olmalı" % okunan.ornek_sayisi())
		_dogrula(okunan.konumlar[1].distance_to(Vector3(1, 0, 0)) < 0.001,
			"Konumlar kayıptan sağ çıkmadı")
	await _bekle(1)

## Bir tur oynayıp kaydın oluştuğunu doğrula.
func _tur_kaydi_testi() -> void:
	DirAccess.remove_absolute(
		ProjectSettings.globalize_path(HayaletKayit.yol("bolum1")))
	var bolum: Node3D = (load("res://sahneler/bolum1.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(bolum)
	await _bekle(10)
	var oyun := bolum.get_node("Oyun")
	var kaydedici := bolum.get_node("HayaletKaydedici")
	_dogrula(not kaydedici.hayalet_var, "Kayıt yokken hayalet var sanıldı")

	var oyuncu: CharacterBody3D = bolum.get_node("Oyuncu")
	Input.action_press("ileri")
	await _bekle(90)
	Input.action_release("ileri")

	oyun.toplanan = oyun.hedef_toplanabilir
	oyun.bitirmeyi_dene()
	await _bekle(5)

	var kayit := HayaletKayit.yukle("bolum1")
	_dogrula(kayit != null, "Tur bitti ama hayalet kaydedilmedi")
	if kayit != null:
		print("tur kaydı: %d örnek, %.2f sn, aralık %.2f" % [
			kayit.ornek_sayisi(), kayit.sure, kayit.aralik])
		_dogrula(kayit.ornek_sayisi() > 20,
			"Örnek sayısı çok az: %d" % kayit.ornek_sayisi())
		_dogrula(absf(kayit.sure - oyun.sure) < 0.2,
			"Kaydedilen süre turla uyuşmuyor (%.2f / %.2f)" % [kayit.sure, oyun.sure])
	get_tree().paused = false
	bolum.queue_free()
	await _bekle(3)

## Kayıt varken bölüm açılınca hayalet oynatılmalı ve kayıtlı yolu izlemeli.
func _oynatma_testi() -> void:
	var bolum: Node3D = (load("res://sahneler/bolum1.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(bolum)
	await _bekle(10)
	var kaydedici := bolum.get_node("HayaletKaydedici")
	_dogrula(kaydedici.hayalet_var, "Kayıt varken hayalet açılmadı")
	if not kaydedici.hayalet_var:
		bolum.queue_free()
		return

	var hayalet: Node3D = kaydedici.get_child(0)
	var kayit := HayaletKayit.yukle("bolum1")
	await _bekle(60)
	var oyun := bolum.get_node("Oyun")
	var beklenen: Vector3 = kayit.ornekle(oyun.sure)["konum"]
	# HUD etiketi de görünmeli. Bu satır bir hatadan sonra eklendi: HUD'ın
	# _ready'si kaydediciden önce çalıştığı için etiket hep kapalı kalıyordu
	# ve hiçbir test bunu görmüyordu.
	var etiket: Label = bolum.get_node("HUD").get_node("%Hayalet")
	_dogrula(etiket.visible, "Hayalet varken HUD etiketi görünmüyor")
	_dogrula(etiket.text.contains("hayalet"),
		"HUD etiketinde hayalet farkı yazmıyor: '%s'" % etiket.text)

	var sapma := hayalet.global_position.distance_to(beklenen)
	print("oynatma: %.2f sn'de hayalet %s, kayıt %s (sapma %.2f m)" % [
		oyun.sure, hayalet.global_position, beklenen, sapma])
	_dogrula(sapma < 0.5, "Hayalet kayıtlı yoldan sapıyor (%.2f m)" % sapma)
	get_tree().paused = false
	bolum.queue_free()
	await _bekle(3)

## Daha YAVAŞ tur kaydı ezmemeli: hayalet "geçilmesi gereken en iyi tur".
func _yavas_tur_testi() -> void:
	var once := HayaletKayit.yukle("bolum1")
	var bolum: Node3D = (load("res://sahneler/bolum1.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(bolum)
	await _bekle(10)
	var oyun := bolum.get_node("Oyun")
	oyun.sure = once.sure + 30.0
	oyun.toplanan = oyun.hedef_toplanabilir
	oyun.bitirmeyi_dene()
	await _bekle(5)

	var sonra := HayaletKayit.yukle("bolum1")
	print("yavaş tur: kayıt %.2f sn, yeni tur %.2f sn -> saklanan %.2f sn" % [
		once.sure, oyun.sure, sonra.sure])
	_dogrula(absf(sonra.sure - once.sure) < 0.01,
		"Daha yavaş tur hayaleti ezdi (%.2f -> %.2f)" % [once.sure, sonra.sure])
	get_tree().paused = false
	bolum.queue_free()
	await _bekle(3)
