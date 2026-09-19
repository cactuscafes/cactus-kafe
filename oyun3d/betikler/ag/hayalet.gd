extends Node3D
## Kayıttan oynatılan hayalet.
##
## Fizik yok, çarpışma yok, yalnızca aradeğerlenmiş konum ve yön. Hayaletin
## oyuncuyu itmesi ya da ona takılması yarışı bozar; hayalet bir GÖRÜNTÜdür.

@onready var _yon: Node3D = $Yon

func uygula(durum: Dictionary) -> void:
	global_position = durum["konum"]
	_yon.rotation.y = durum["yon"]
	# GÖRÜNÜRLÜĞÜ YALNIZCA DEĞİŞİNCE YAZ. Aynı değeri her karede atamak
	# Godot'da ucuz değil: görünürlük alt ağaca yayılıyor ve bu tek satır,
	# hayalet oynarken kareyi ölçülebilir biçimde pahalılaştırıyordu (botun
	# denge ölçümü hayaletli bölümde 60 kat yavaşlayınca fark edildi —
	# gerçek cihazda da bedeli var).
	var gorunur: bool = not durum["bitti"]
	if visible != gorunur:
		visible = gorunur
