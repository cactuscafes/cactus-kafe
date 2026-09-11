extends Node
## Ağ testinin SUNUCU tarafı. Tek başına anlamlı değil; `ag_testi.sh` çalıştırır.
##
## Bilinen bir yol izliyor: yarıçapı 5 m olan çember. İstemci, aldığı konumların
## çember üstünde olup olmadığına bakarak doğrulama yapabiliyor — iki sürecin
## saatlerini eşitlemeye gerek kalmadan.

const PORT := 8911
const YARICAP := 5.0
const SURE := 9.0

var _t := 0.0
var _sahte: CharacterBody3D
## İstemci testini bitirip çıkınca listeden düşüyor; ölçümü tepe değerle
## yapmak gerekiyor, son değerle değil.
var _en_cok := 0

func _ready() -> void:
	Ag.kendi_adim = "Sunucu"
	var hata := Ag.sunucu_baslat(PORT)
	if hata != OK:
		print("SONUC {\"hata\":\"sunucu acilamadi\"}")
		get_tree().quit(1)
		return
	_sahte = preload("res://testler/sahte_oyuncu.tscn").instantiate()
	add_child(_sahte)
	_sahte.global_position = Vector3(YARICAP, 1.0, 0.0)   # yolun başlangıcı
	Ag.yerel_oyuncuyu_ayarla(_sahte)
	Ag.yerel_isinlanma()
	print("sunucu hazır, port %d" % PORT)

func _physics_process(delta: float) -> void:
	_t += delta
	_en_cok = maxi(_en_cok, Ag.oyuncular.size())
	_sahte.global_position = Vector3(cos(_t) * YARICAP, 1.0, sin(_t) * YARICAP)
	_sahte.get_node("Yon").rotation.y = _t
	if _t >= SURE:
		print("SONUC %s" % JSON.stringify({
			"reddedilen": Ag.reddedilen_paket(),
			"oyuncu_sayisi": _en_cok,
			"siralama": Ag.siralama().size(),
		}))
		get_tree().quit(0)
