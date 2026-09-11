extends Node3D
## Kayıttan oynatılan hayalet.
##
## Fizik yok, çarpışma yok, yalnızca aradeğerlenmiş konum ve yön. Hayaletin
## oyuncuyu itmesi ya da ona takılması yarışı bozar; hayalet bir GÖRÜNTÜdür.

@onready var _yon: Node3D = $Yon

func uygula(durum: Dictionary) -> void:
	global_position = durum["konum"]
	_yon.rotation.y = durum["yon"]
	visible = not durum["bitti"]
