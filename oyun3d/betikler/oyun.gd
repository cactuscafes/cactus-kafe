extends Node
## Bölüm akışı: toplananlar, süre, ölüm, bitiş, yeniden başlama.
##
## Oyun durumu tek bir yerde duruyor; karakter ve nesneler sadece sinyal
## gönderiyor. Faz 4'te bölüm sayısı artınca burası bir sahne yükleyicisine
## dönüşecek, ama arayüz aynı kalacak.

signal durum_degisti

@export var oyuncu_yolu: NodePath = ^"../Oyuncu"
@export var hedef_toplanabilir := 0

var toplanan := 0
var olum := 0
var sure := 0.0
var bitti := false
var mesaj := ""

var _oyuncu: CharacterBody3D

func _ready() -> void:
	_oyuncu = get_node(oyuncu_yolu)
	_oyuncu.olduruldu.connect(_olunce)

	for dugum in get_tree().get_nodes_in_group("toplanabilir"):
		dugum.alindi.connect(_toplayinca)
	hedef_toplanabilir = get_tree().get_nodes_in_group("toplanabilir").size()
	durum_degisti.emit()

func _process(delta: float) -> void:
	if not bitti:
		sure += delta
	if Input.is_action_just_pressed("yeniden"):
		get_tree().reload_current_scene()

func _toplayinca() -> void:
	toplanan += 1
	mesaj = ""
	durum_degisti.emit()

func _olunce() -> void:
	olum += 1
	mesaj = "Kontrol noktasına döndün"
	durum_degisti.emit()

## Bitiş alanı çağırır. Hepsi toplanmadan bölüm bitmez.
func bitirmeyi_dene() -> void:
	if bitti:
		return
	if toplanan < hedef_toplanabilir:
		mesaj = "Önce %d çiçeğin hepsini topla (%d kaldı)" % [
			hedef_toplanabilir, hedef_toplanabilir - toplanan,
		]
	else:
		bitti = true
		mesaj = "Bölüm tamam — %.1f sn, %d ölüm.  R ile yeniden" % [sure, olum]
	durum_degisti.emit()

func kontrol_noktasi(nokta: Vector3) -> void:
	_oyuncu.dogum_noktasi_ayarla(nokta)
	mesaj = "Kontrol noktası"
	durum_degisti.emit()
