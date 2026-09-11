extends Node
## Bölüm davranış testleri — pencere açmadan çalışır.
##
##   godot --headless --path oyun3d res://testler/bolum_testi.tscn
##
## Her fazın testleri buraya birikir. Her test bir davranışı sayıyla ölçer: zıplama gerçekten ayarlanan yüksekliğe
## çıkıyor mu, karakter rampayı tırmanıyor mu, tuzak doğum noktasına yolluyor
## mu, hareketli platform karakteri taşıyor mu. Bunlar "çalışıyor gibi görünen"
## ama sessizce bozulan şeyler; elle test etmesi en pahalı olanlar da bunlar.

var _sahne: Node3D
var _oyuncu: CharacterBody3D
var _oyun: Node
var _hatalar: Array[String] = []

func _ready() -> void:
	# Ağaç kurulurken add_child yapılamaz ("parent is busy setting up
	# children"): bir kare bekleyip öyle başla.
	await get_tree().process_frame
	_baslat()

func _baslat() -> void:
	_sahne = load("res://sahneler/bolum1.tscn").instantiate()
	get_tree().root.add_child(_sahne)
	_oyuncu = _sahne.get_node("Oyuncu")
	_oyun = _sahne.get_node("Oyun")
	await _bekle(30)

	await _bolum_yapisi_testi()
	await _zemin_testi()
	await _ziplama_testi()
	await _kosma_testi()
	await _rampa_testi()
	await _tuzak_testi()
	await _toplanabilir_testi()
	await _hareketli_platform_testi()

	if _hatalar.is_empty():
		print("BOLUM TESTI: GECTI")
		get_tree().quit(0)
	else:
		for h: String in _hatalar:
			printerr("  ! " + h)
		print("BOLUM TESTI: KALDI (%d)" % _hatalar.size())
		get_tree().quit(1)

func _bekle(kare: int) -> void:
	for i in kare:
		await get_tree().physics_frame

func _isinla(nokta: Vector3) -> void:
	_oyuncu.velocity = Vector3.ZERO
	_oyuncu.global_position = nokta
	await _bekle(45)

func _dogrula(kosul: bool, mesaj: String) -> void:
	if not kosul:
		_hatalar.append(mesaj)

# --- testler ---------------------------------------------------------------

## Her bölüm oynanabilir iskelete sahip mi? Yeni bölüm eklerken unutulan şey
## hep aynı: bitiş alanı, duraklatma katmanı ya da navigasyon örgüsü. Bunlar
## eksikken bölüm açılıyor ve hata vermiyor — sadece bitirilemiyor.
func _bolum_yapisi_testi() -> void:
	for bilgi: Dictionary in Bolumler.LISTE:
		var kimlik: String = bilgi["kimlik"]
		var sahne: Node3D = (load(bilgi["sahne"]) as PackedScene).instantiate()
		get_tree().root.add_child(sahne)
		await _bekle(5)

		for ad in ["Oyuncu", "Oyun", "Bitis", "Duraklat", "BitisEkrani", "Navigasyon"]:
			_dogrula(sahne.get_node_or_null(ad) != null, "%s: %s düğümü yok" % [kimlik, ad])

		var oyun := sahne.get_node("Oyun")
		_dogrula(oyun.bolum_kimligi == kimlik,
			"%s: Oyun düğümünde bölüm kimliği '%s'" % [kimlik, oyun.bolum_kimligi])
		_dogrula(oyun.hedef_toplanabilir >= 8,
			"%s: %d çiçek var, en az 8 olmalı" % [kimlik, oyun.hedef_toplanabilir])

		var bolge: NavigationRegion3D = sahne.get_node("Navigasyon")
		_dogrula(bolge.navigation_mesh != null
			and bolge.navigation_mesh.get_polygon_count() > 0,
			"%s: navigasyon örgüsü boş — navmesh_uret çalıştırılmalı" % kimlik)

		# Oyuncu boşlukta doğmamalı: altında 6 m içinde zemin olmalı.
		var oyuncu: CharacterBody3D = sahne.get_node("Oyuncu")
		var uzay := oyuncu.get_world_3d().direct_space_state
		var sorgu := PhysicsRayQueryParameters3D.create(
			oyuncu.global_position, oyuncu.global_position + Vector3(0, -6, 0), 1)
		var vurus := uzay.intersect_ray(sorgu)
		_dogrula(not vurus.is_empty(), "%s: oyuncu boşlukta doğuyor" % kimlik)

		var dusman_sayisi := 0
		for d in sahne.get_node("Dusmanlar").get_children():
			dusman_sayisi += 1
		print("%-7s %d çiçek, %d düşman, %d navmesh poligonu" % [
			kimlik, oyun.hedef_toplanabilir, dusman_sayisi,
			bolge.navigation_mesh.get_polygon_count()])
		sahne.queue_free()
		await _bekle(3)

func _zemin_testi() -> void:
	await _isinla(Vector3(0, 2.5, 6))
	var y := _oyuncu.global_position.y
	print("zemin: y=%.3f  is_on_floor=%s  toplanan=%d" % [y, _oyuncu.is_on_floor(), _oyun.toplanan])
	# Doğum noktasının dibine çiçek konmamalı: bölüm başlar başlamaz toplanır.
	_dogrula(_oyun.toplanan == 0, "Bölüm başlarken çiçek toplanmış (%d)" % _oyun.toplanan)
	_dogrula(_oyuncu.is_on_floor(), "Karakter zemine oturmadı")
	# Kapsül yarı yüksekliği 0.85; zemin üstü y=0.
	_dogrula(absf(y - 0.85) < 0.06, "Zemin yüksekliği beklenenden farklı: %.3f" % y)

func _ziplama_testi() -> void:
	await _isinla(Vector3(0, 1.0, 6))
	var taban := _oyuncu.global_position.y
	Input.action_press("ziplama")
	var tepe := taban
	for i in 70:
		await get_tree().physics_frame
		tepe = maxf(tepe, _oyuncu.global_position.y)
		if i == 30:
			Input.action_release("ziplama")
	var yukseklik := tepe - taban
	print("zıplama: %.3f m (hedef %.2f)" % [yukseklik, _oyuncu.ziplama_yuksekligi])
	_dogrula(absf(yukseklik - _oyuncu.ziplama_yuksekligi) < 0.25,
		"Zıplama yüksekliği hedeften uzak: %.2f ≠ %.2f" % [yukseklik, _oyuncu.ziplama_yuksekligi])
	await _bekle(40)

func _kosma_testi() -> void:
	await _isinla(Vector3(0, 1.0, 20))
	Input.action_press("ileri")
	Input.action_press("kosma")
	await _bekle(70)
	var kosma := Vector2(_oyuncu.velocity.x, _oyuncu.velocity.z).length()
	Input.action_release("kosma")
	await _bekle(45)
	var yurume := Vector2(_oyuncu.velocity.x, _oyuncu.velocity.z).length()
	Input.action_release("ileri")
	print("hız: koşma=%.2f  yürüme=%.2f (hedef %.1f / %.1f)" % [
		kosma, yurume, _oyuncu.kosma_hizi, _oyuncu.yurume_hizi])
	_dogrula(absf(kosma - _oyuncu.kosma_hizi) < 0.4, "Koşma hızı tutmuyor: %.2f" % kosma)
	_dogrula(absf(yurume - _oyuncu.yurume_hizi) < 0.4, "Yürüme hızı tutmuyor: %.2f" % yurume)
	_dogrula(kosma > yurume + 1.0, "Shift koşturmuyor")
	await _bekle(20)

func _rampa_testi() -> void:
	# Rampanın alçak ucu: (4, ~1.05, -14)
	await _isinla(Vector3(4, 2.0, -14.0))
	var basla := _oyuncu.global_position
	Input.action_press("ileri")
	await _bekle(150)
	Input.action_release("ileri")
	var son := _oyuncu.global_position
	var tirmanma := son.y - basla.y
	print("rampa: Δy=%.2f  Δz=%.2f" % [tirmanma, son.z - basla.z])
	_dogrula(tirmanma > 1.0, "Rampa tırmanılamadı (Δy=%.2f)" % tirmanma)
	_dogrula(_oyuncu.is_on_floor(), "Rampanın üstünde zemin algılanmadı")
	await _bekle(20)

func _tuzak_testi() -> void:
	var dogum := Vector3(0, 1.2, 6)
	_oyuncu.dogum_noktasi_ayarla(dogum)
	var olum_once: int = _oyun.olum
	await _isinla(Vector3(0, 1.0, -7))
	var uzaklik := _oyuncu.global_position.distance_to(dogum)
	print("tuzak: ölüm %d -> %d, doğuma uzaklık %.2f" % [olum_once, _oyun.olum, uzaklik])
	_dogrula(_oyun.olum > olum_once, "Tuzak ölüm saymadı")
	_dogrula(uzaklik < 2.0, "Karakter doğum noktasına dönmedi (%.2f m)" % uzaklik)

func _toplanabilir_testi() -> void:
	var kalanlar := get_tree().get_nodes_in_group("toplanabilir")
	_dogrula(not kalanlar.is_empty(), "Sahnede toplanabilir kalmadı")
	if kalanlar.is_empty():
		return
	var cicek: Node3D = kalanlar[0]
	var once: int = _oyun.toplanan
	await _isinla(cicek.global_position)
	print("toplanabilir: %d -> %d / %d" % [once, _oyun.toplanan, _oyun.hedef_toplanabilir])
	_dogrula(_oyun.toplanan == once + 1, "Çiçek toplanmadı")
	_dogrula(_oyun.hedef_toplanabilir == 8, "Bölümde 8 çiçek olmalı, %d var" % _oyun.hedef_toplanabilir)

func _hareketli_platform_testi() -> void:
	var platform: Node3D = _sahne.get_node("HareketliPlatform")
	await _isinla(platform.global_position + Vector3(0, 1.06, 0))
	var oyuncu_once := _oyuncu.global_position.z
	var platform_once := platform.global_position.z
	# Pencere kısa: platform kuleye varınca karakter kuleye geçer ve ölçüm
	# "taşınmadı" gibi görünür. Ölçtüğümüz şey taşıma, varış değil.
	await _bekle(40)
	var oyuncu_fark := _oyuncu.global_position.z - oyuncu_once
	var platform_fark := platform.global_position.z - platform_once
	print("platform: oyuncu Δz=%.2f  platform Δz=%.2f" % [oyuncu_fark, platform_fark])
	_dogrula(absf(platform_fark) > 0.5, "Platform hareket etmiyor")
	_dogrula(absf(oyuncu_fark - platform_fark) < 0.2,
		"Karakter platformla taşınmadı (%.2f ≠ %.2f)" % [oyuncu_fark, platform_fark])
	var carpisma := _oyuncu.get_last_slide_collision()
	_dogrula(carpisma != null and carpisma.get_collider() == platform,
		"Karakter ölçüm sonunda platformun üstünde değil")
