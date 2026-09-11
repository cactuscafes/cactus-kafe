extends Node
## Ekran kontrolleri testi — gerçek dokunma olayları üretip ölçüyor.
##
##   godot --headless --path oyun3d res://testler/dokunmatik_testi.tscn
##
## Telefon kontrollerini elle test etmek en pahalı iş: APK al, telefona at,
## kur, oyna. Burada `Input.parse_input_event` ile parmak taklit ediliyor;
## APK yalnızca son doğrulama için gerekiyor.
##
## GERÇEK PENCERE ŞART — bu test `--headless` ile ÇALIŞMAZ:
##
##   xvfb-run -a godot --path oyun3d --rendering-driver opengl3 \
##     --audio-driver Dummy res://testler/dokunmatik_testi.tscn
##
## Sebebi: başsız kipte pencere boyutu (0,0) ve `canvas_items` esneme dönüşümü
## dokunuş koordinatlarını 20 katına çıkarıyor; (200,500) ekrana (4000,10000)
## olarak geliyor. Dokunmatik girdi doğası gereği pencereli bir konu.

var _hatalar: Array[String] = []
var _bolum: Node3D
var _oyuncu: CharacterBody3D
var _katman: CanvasLayer

func _ready() -> void:
	await get_tree().process_frame
	_calis()

func _dogrula(kosul: bool, mesaj: String) -> void:
	if not kosul:
		_hatalar.append(mesaj)

func _bekle(kare: int) -> void:
	for i in kare:
		await get_tree().physics_frame

## Ekranın sol/sağ yarısında bir parmak.
func _dokun(konum: Vector2, basili: bool, indeks := 0) -> void:
	var olay := InputEventScreenTouch.new()
	olay.index = indeks
	olay.position = konum
	olay.pressed = basili
	Input.parse_input_event(olay)
	# Olay bir sonraki karede işleniyor ve _process gücü ondan sonra yazıyor.
	# 2 kare beklemek "çubuk çalışmıyor" gibi görünmesine yol açıyordu.
	await _bekle(6)

func _surukle(nereden: Vector2, nereye: Vector2, indeks := 0) -> void:
	var olay := InputEventScreenDrag.new()
	olay.index = indeks
	olay.position = nereye
	olay.relative = nereye - nereden
	Input.parse_input_event(olay)
	await _bekle(6)

func _calis() -> void:
	_bolum = (load("res://sahneler/bolum1.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(_bolum)
	await _bekle(20)
	_oyuncu = _bolum.get_node("Oyuncu")
	_katman = _bolum.get_node("Dokunmatik")

	await _gorunurluk_testi()
	await _cubuk_testi()
	await _bakis_testi()
	await _dugme_testi()
	await _klavyeye_donus_testi()

	if _hatalar.is_empty():
		print("DOKUNMATIK TESTI: GECTI")
		get_tree().quit(0)
	else:
		for h: String in _hatalar:
			printerr("  ! " + h)
		print("DOKUNMATIK TESTI: KALDI (%d)" % _hatalar.size())
		get_tree().quit(1)

## Ekran kontrolleri klavyeyle oynayanın yüzüne çıkmamalı; ilk dokunuşta gelmeli.
func _gorunurluk_testi() -> void:
	Girdi.dokunmatik = false
	await _bekle(3)
	_dogrula(not _katman.visible, "Dokunulmadan ekran kontrolleri görünüyor")
	await _dokun(Vector2(200, 500), true)
	_dogrula(_katman.visible, "İlk dokunuşta ekran kontrolleri açılmadı")
	await _dokun(Vector2(200, 500), false)

func _cubuk_testi() -> void:
	var merkez := Vector2(220, 520)
	await _dokun(merkez, true)
	var cubuk: Control = _katman.get_node("%Cubuk")
	_dogrula(cubuk.visible, "Sol yarıya dokununca çubuk görünmedi")

	# Yukarı doğru it: "ileri" basılmalı ve karakter hareket etmeli.
	await _surukle(merkez, merkez + Vector2(0, -95))
	await _bekle(25)
	var guc := Input.get_action_strength("ileri")
	var hiz := Vector2(_oyuncu.velocity.x, _oyuncu.velocity.z).length()
	print("çubuk: ileri gücü %.2f, karakter hızı %.2f m/sn" % [guc, hiz])
	_dogrula(guc > 0.5, "Çubuk 'ileri' eylemini basmadı (%.2f)" % guc)
	_dogrula(hiz > 1.0, "Çubuk itiliyken karakter hareket etmiyor (%.2f)" % hiz)

	# Analog olmalı: yarım itince güç de hız da yarım.
	await _surukle(merkez + Vector2(0, -95), merkez + Vector2(0, -40))
	await _bekle(25)
	var yarim := Input.get_action_strength("ileri")
	var yarim_hiz := Vector2(_oyuncu.velocity.x, _oyuncu.velocity.z).length()
	print("çubuk: yarım itişte güç %.2f, hız %.2f m/sn" % [yarim, yarim_hiz])
	_dogrula(yarim < guc, "Çubuk analog değil: yarım itişte güç düşmedi")
	_dogrula(yarim_hiz < hiz * 0.75,
		"Yarım itişte hız düşmedi (%.2f / %.2f) — girdinin boyu yok sayılıyor"
		% [yarim_hiz, hiz])

	# Parmağı kaldır: eylemler bırakılmalı, yoksa karakter kendi kendine yürür.
	await _dokun(merkez + Vector2(0, -40), false)
	await _bekle(3)
	_dogrula(not Input.is_action_pressed("ileri"),
		"Parmak kalkınca 'ileri' bırakılmadı — karakter kendi kendine yürür")
	_dogrula(not cubuk.visible, "Parmak kalkınca çubuk gizlenmedi")

func _bakis_testi() -> void:
	var kol: SpringArm3D = _oyuncu.get_node("KameraKolu")
	var once := kol.rotation.y
	await _dokun(Vector2(1000, 400), true, 1)
	await _surukle(Vector2(1000, 400), Vector2(1120, 400), 1)
	await _bekle(3)
	var fark := absf(kol.rotation.y - once)
	print("bakış: sağ yarıda sürükleme kamerayı %.3f rad çevirdi" % fark)
	_dogrula(fark > 0.01, "Sağ yarıda sürükleme kamerayı çevirmedi")
	await _dokun(Vector2(1120, 400), false, 1)

func _dugme_testi() -> void:
	var zipla: Button = _katman.get_node("%Zipla")
	var y_once := _oyuncu.global_position.y
	zipla.button_down.emit()
	await _bekle(2)
	_dogrula(Input.is_action_pressed("ziplama"), "ZIPLA düğmesi eylemi basmadı")
	await _bekle(12)
	zipla.button_up.emit()
	await _bekle(2)
	_dogrula(not Input.is_action_pressed("ziplama"), "ZIPLA düğmesi bırakılmadı")
	await _bekle(10)
	print("düğme: zıplama sonrası yükseklik farkı %.2f m" % (_oyuncu.global_position.y - y_once))

	var kos: Button = _katman.get_node("%Kos")
	kos.toggled.emit(true)
	await _bekle(2)
	_dogrula(Input.is_action_pressed("kosma"), "KOŞ düğmesi eylemi basmadı")
	kos.toggled.emit(false)
	await _bekle(2)
	_dogrula(not Input.is_action_pressed("kosma"), "KOŞ düğmesi kapanmadı")

## Klavyeye dönünce ekran kontrolleri çekilmeli: aynı derleme masaüstünde de
## çalışıyor, oyuncunun ekranında gereksiz düğme durmamalı.
func _klavyeye_donus_testi() -> void:
	var tus := InputEventKey.new()
	tus.physical_keycode = KEY_W
	tus.pressed = true
	Input.parse_input_event(tus)
	await _bekle(3)
	_dogrula(not Girdi.dokunmatik, "Klavyeye basınca dokunmatik kipi kapanmadı")
	_dogrula(not _katman.visible, "Klavyeye basınca ekran kontrolleri gizlenmedi")
	tus.pressed = false
	Input.parse_input_event(tus)
	await _bekle(2)
