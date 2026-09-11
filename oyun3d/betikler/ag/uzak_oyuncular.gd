extends Node3D
## Bölümdeki uzak oyuncuları yönetir.
##
## Ağ katmanı sahneyi, sahne de ağ katmanını tanımıyor: bu düğüm ikisini
## birbirine bağlayan tek yer. Tek oyunculu oynarken hiçbir şey yapmıyor.

@export var oyuncu_yolu: NodePath = ^"../Oyuncu"
@export var oyun_yolu: NodePath = ^"../Oyun"

var _dugumler := {}

func _ready() -> void:
	if not Ag.bagli:
		return
	Ag.yerel_oyuncuyu_ayarla(get_node(oyuncu_yolu))
	Ag.oyuncu_katildi.connect(_ekle)
	Ag.oyuncu_ayrildi.connect(_cikar)
	get_node(oyun_yolu).bolum_bitti.connect(func(_rekor: bool) -> void:
		Ag.bitirdim(get_node(oyun_yolu).sure))
	for kimlik: int in Ag.oyuncular:
		_ekle(kimlik)

func _ekle(kimlik: int) -> void:
	if kimlik == multiplayer.get_unique_id() or _dugumler.has(kimlik):
		return
	var dugum: Node3D = preload("res://sahneler/uzak_oyuncu.tscn").instantiate()
	add_child(dugum)
	var bilgi: Dictionary = Ag.oyuncular.get(kimlik, {})
	dugum.kur(kimlik, bilgi.get("ad", "Oyuncu %d" % kimlik))
	_dugumler[kimlik] = dugum

func _cikar(kimlik: int) -> void:
	if _dugumler.has(kimlik):
		_dugumler[kimlik].queue_free()
		_dugumler.erase(kimlik)
