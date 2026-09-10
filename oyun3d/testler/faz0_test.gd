extends SceneTree
## Faz 0 duman testi — pencere açmadan çalışır.
##
##   godot --headless --path oyun3d --script res://testler/faz0_test.gd
##
## Ne kanıtlar: ana sahne yükleniyor, betikler derleniyor, girdi eylemleri
## kurulu, yerçekimi ve zemin çarpışması çalışıyor, karakter girdiye tepki
## veriyor. Ekran görüntüsü yerine sayı; CI'da da aynen çalışır.

const ADIM := 150          # ~2.5 sn fizik
const BEKLENEN_Y := 0.5    # 1x1x1 kutu, zemin y=0 -> merkez y=0.5

var _sahne: Node3D
var _oyuncu: CharacterBody3D
var _baslangic: Vector3
var _kare := 0
var _hatalar: Array[String] = []

func _initialize() -> void:
	# --script kipinde autoload'lar yüklenmez; motorun yaptığını elle yapıyoruz.
	root.add_child(load("res://betikler/girdi.gd").new())
	_sahne = load("res://sahneler/ana.tscn").instantiate()
	root.add_child(_sahne)
	_oyuncu = _sahne.get_node("Oyuncu")

func _physics_process(_delta: float) -> bool:
	_kare += 1
	if _kare == 1:
		# Konumlar ancak düğümler ağacın içindeyken okunabilir.
		_baslangic = _oyuncu.global_position
		if not InputMap.has_action("ileri"):
			_bitir(["Girdi eylemi 'ileri' kurulmadı"])
			return true
		Input.action_press("ileri")
		return false
	if _kare < ADIM:
		return false
	Input.action_release("ileri")

	var son := _oyuncu.global_position
	var mesafe := Vector2(son.x - _baslangic.x, son.z - _baslangic.z).length()

	if not _oyuncu.is_on_floor():
		_hatalar.append("Karakter zemine oturmadı (y=%.2f)" % son.y)
	if absf(son.y - BEKLENEN_Y) > 0.05:
		_hatalar.append("Zemin yüksekliği beklenenden farklı: %.2f ≠ %.2f" % [son.y, BEKLENEN_Y])
	if mesafe < 1.0:
		_hatalar.append("Karakter 'ileri' girdisine hareketle yanıt vermedi (%.2f m)" % mesafe)
	if _sahne.get_node_or_null("HUD/Bilgi") == null:
		_hatalar.append("HUD etiketi bulunamadı")

	print("konum: %s -> %s   yatay mesafe: %.2f m   zeminde: %s" % [
		_baslangic, son, mesafe, _oyuncu.is_on_floor(),
	])
	_bitir(_hatalar)
	return true

func _bitir(hatalar: Array) -> void:
	if hatalar.is_empty():
		print("FAZ 0 TESTI: GECTI")
	else:
		for h: String in hatalar:
			printerr("  ! " + h)
		print("FAZ 0 TESTI: KALDI")
		quit(1)
