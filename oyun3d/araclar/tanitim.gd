extends Node
## Tanıtım (trailer) çekimi — oyunu kendi kendine oynatır.
##
##   xvfb-run -a godot --path oyun3d --rendering-driver opengl3 \
##     --audio-driver Dummy --write-movie /tmp/tanitim.avi --fixed-fps 24 \
##     res://araclar/tanitim.tscn
##
## Godot'nun Movie Maker kipi (--write-movie) sabit adımla çalışır: kare
## başına ne kadar sürerse sürsün çıktı akıcı olur. Yazılımsal GPU'da bile
## düzgün video verir; sadece uzun sürer.
##
## NEDEN BETİKLE: Trailer elle oynayıp ekran kaydı alarak da çekilir, ama her
## değişiklikten sonra baştan oynamak gerekir. Betikle çekim tekrarlanabilir:
## bölüm değişti, tek komutla yeni trailer.

## Bekleme fizik karesiyle sayılıyor (60 Hz), video karesiyle değil (24 fps).
## İkisini karıştırmak trailer'ı 31 saniye yerine 12 saniye yapıyordu: Movie
## Maker video karesini sabitler, fizik hızını değil.
@onready var KARE := float(Engine.physics_ticks_per_second)

## Çekimler: süre (sn), hazırlık (oyuncuyu/kamerayı kur), basılı tutulan tuşlar
var _cekimler: Array[Dictionary] = []
var _bolum: Node3D
var _oyuncu: CharacterBody3D
var _kol: SpringArm3D
var _yazi: Label
var _perde: ColorRect

func _ready() -> void:
	await get_tree().process_frame
	_bolum = (load("res://sahneler/bolum1.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(_bolum)
	await get_tree().process_frame
	_oyuncu = _bolum.get_node("Oyuncu")
	_kol = _oyuncu.get_node("KameraKolu")
	_arayuzu_sadelestir()
	_yazi_katmani()
	_cekimleri_kur()
	await _oynat()
	get_tree().quit(0)

## Trailer'da ölçüm satırı ve duraklatma menüsü olmaz.
func _arayuzu_sadelestir() -> void:
	var hud := _bolum.get_node_or_null("HUD")
	if hud != null:
		hud.get_node("Olcum").visible = false
	var duraklat := _bolum.get_node_or_null("Duraklat")
	if duraklat != null:
		duraklat.queue_free()

func _yazi_katmani() -> void:
	var katman := CanvasLayer.new()
	katman.layer = 20
	add_child(katman)
	_perde = ColorRect.new()
	_perde.color = Color(0.04, 0.06, 0.05, 1.0)
	_perde.anchor_right = 1.0
	_perde.anchor_bottom = 1.0
	katman.add_child(_perde)
	_yazi = Label.new()
	_yazi.anchor_right = 1.0
	_yazi.anchor_bottom = 1.0
	_yazi.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_yazi.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_yazi.add_theme_font_size_override("font_size", 64)
	_yazi.add_theme_color_override("font_color", Color(0.404, 0.702, 0.529))
	_yazi.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_yazi.add_theme_constant_override("outline_size", 8)
	katman.add_child(_yazi)

func _cekimleri_kur() -> void:
	_cekimler = [
		{"yazi": "CACTUS 3B", "sure": 2.0, "perde": 1.0},
		# 1. Başlangıç: karakteri tanıt, kamerayı yavaşça çevir.
		{"sure": 3.0, "kur": func() -> void:
			_yerlestir(Vector3(0, 1.2, 8), 0.0), "kamera_don": 0.35},
		# 2. Koşu ve basamaklar üstünde zıplama.
		{"sure": 4.5, "kur": func() -> void:
			_yerlestir(Vector3(0, 1.2, 2), 0.0), "tuslar": ["ileri", "kosma"],
			"zipla": [0.7, 1.9, 3.1]},
		# 3. Çiçek toplama.
		{"sure": 2.5, "kur": func() -> void:
			_yerlestir(Vector3(0, 3.8, -12.5), 0.0), "tuslar": ["ileri"]},
		# 4. Rampa tırmanışı.
		{"sure": 3.5, "kur": func() -> void:
			_yerlestir(Vector3(4, 2.0, -14.5), 0.0), "tuslar": ["ileri", "kosma"]},
		{"yazi": "DÜŞMANLAR", "sure": 1.4, "perde": 0.55},
		# 5. Düşman fark eder ve kovalar.
		{"sure": 3.5, "kur": func() -> void:
			_yerlestir(Vector3(2, 4.6, -24), 0.0), "tuslar": ["ileri"]},
		# 6. Üstüne zıplayıp ezme.
		{"sure": 3.0, "kur": func() -> void: _ezme_kur(), "zipla": [0.15]},
		{"yazi": "İKİ BÖLÜM", "sure": 1.4, "perde": 0.55},
		# 7. Hareketli platform.
		{"sure": 3.5, "kur": func() -> void:
			_yerlestir(Vector3(4, 4.6, -33), 0.0), "tuslar": ["ileri"]},
		{"yazi": "CACTUS 3B\n\nyakında", "sure": 2.6, "perde": 1.0},
	]

func _ezme_kur() -> void:
	var dusman := _bolum.get_node_or_null("Dusmanlar/Dusman1")
	if dusman != null:
		_yerlestir(dusman.global_position + Vector3(0, 3.2, 0.2), 0.0)
		_oyuncu.velocity = Vector3(0, -2, 0)

func _yerlestir(konum: Vector3, yon: float) -> void:
	_oyuncu.global_position = konum
	_oyuncu.velocity = Vector3.ZERO
	_kol.rotation.y = yon
	_kol.rotation.x = deg_to_rad(-14.0)

func _oynat() -> void:
	for cekim: Dictionary in _cekimler:
		if cekim.has("kur"):
			(cekim["kur"] as Callable).call()
		_yazi.text = cekim.get("yazi", "")
		_perde.color.a = cekim.get("perde", 0.0)

		var tuslar: Array = cekim.get("tuslar", [])
		for t: String in tuslar:
			Input.action_press(t)
		var zipla: Array = cekim.get("zipla", [])
		var gecen := 0.0
		var sonraki_zipla := 0
		var kare_sayisi := int(cekim["sure"] * KARE)
		for k in kare_sayisi:
			await get_tree().physics_frame
			gecen += 1.0 / KARE
			if cekim.has("kamera_don"):
				_kol.rotation.y += float(cekim["kamera_don"]) / KARE
			if sonraki_zipla < zipla.size() and gecen >= float(zipla[sonraki_zipla]):
				sonraki_zipla += 1
				Input.action_press("ziplama")
				await get_tree().physics_frame
				Input.action_release("ziplama")
		for t: String in tuslar:
			Input.action_release(t)
