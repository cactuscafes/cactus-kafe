extends Node
## Bölüm akışı: toplananlar, süre, ölüm, bitiş, yeniden başlama.
##
## Oyun durumu tek bir yerde duruyor; karakter ve nesneler sadece sinyal
## gönderiyor. Faz 4'te bölüm sayısı artınca burası bir sahne yükleyicisine
## dönüşecek, ama arayüz aynı kalacak.

signal durum_degisti
signal bolum_bitti(rekor: bool)

@export var bolum_kimligi := "bolum1"
@export var oyuncu_yolu: NodePath = ^"../Oyuncu"
@export var hedef_toplanabilir := 0

var toplanan := 0
var yenilen := 0
var olum := 0
var sure := 0.0
var bitti := false
var mesaj := ""

var _oyuncu: CharacterBody3D

func _ready() -> void:
	_oyuncu = get_node(oyuncu_yolu)
	_oyuncu.olduruldu.connect(_olunce)

	# YALNIZCA bu bölümün içindekiler. Global grubu doğrudan saymak, aynı anda
	# iki bölüm ağaçtayken (geçiş animasyonu, önizleme, test) diğer bölümün
	# çiçeklerini de sayıyordu: bölüm 8 yerine 16 çiçek istiyordu.
	var cicekler := _bolumdekiler("toplanabilir")
	for dugum in cicekler:
		dugum.alindi.connect(_toplayinca)
	for dugum in _bolumdekiler("dusman"):
		dugum.yenildi.connect(_dusman_yenilince)
	hedef_toplanabilir = cicekler.size()
	durum_degisti.emit()

## Verilen gruptaki düğümlerden yalnızca bu bölümün ağacında olanlar.
func _bolumdekiler(grup: String) -> Array[Node]:
	var kok := get_parent()
	var sonuc: Array[Node] = []
	for dugum in get_tree().get_nodes_in_group(grup):
		if kok != null and kok.is_ancestor_of(dugum):
			sonuc.append(dugum)
	return sonuc

func _process(delta: float) -> void:
	if not bitti:
		sure += delta
	if not bitti and Input.is_action_just_pressed("yeniden"):
		get_tree().reload_current_scene()

func _toplayinca() -> void:
	toplanan += 1
	mesaj = ""
	durum_degisti.emit()

func _dusman_yenilince() -> void:
	yenilen += 1
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
		mesaj = ""
		Ses.cal("bitis")
		var rekor := Ayarlar.sonuc_kaydet(bolum_kimligi, sure, olum)
		bolum_bitti.emit(rekor)
	durum_degisti.emit()

func kontrol_noktasi(nokta: Vector3) -> void:
	_oyuncu.dogum_noktasi_ayarla(nokta)
	mesaj = "Kontrol noktası"
	durum_degisti.emit()
