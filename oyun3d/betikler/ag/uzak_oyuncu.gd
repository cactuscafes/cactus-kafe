extends Node3D
## Başka bir oyuncunun görüntüsü.
##
## Fizik yok: gelen durumu çiziyor. Uzak karakteri yerel olarak simüle etmek
## (dead reckoning) daha akıcı görünür ama iki taraf ayrışınca karakter
## "kayarak" düzeliyor. Yarış oyununda tampondan aradeğerleme daha dürüst:
## gördüğün şey rakibin gerçekten bulunduğu yer, 120 ms öncesi.

var kimlik := 0

@onready var _yon: Node3D = $Yon
@onready var _etiket: Label3D = $Ad

func kur(oyuncu_kimligi: int, ad: String) -> void:
	kimlik = oyuncu_kimligi
	if _etiket != null:
		_etiket.text = ad

func _process(_delta: float) -> void:
	var durum := Ag.uzak_durum(kimlik)
	if durum.is_empty():
		visible = false
		return
	visible = true
	global_position = durum["konum"]
	_yon.rotation.y = durum["yon"]
