@tool
extends StaticBody3D
## Ölçüsü ve rengi editörden ayarlanabilen tek parça platform.
##
## Çarpışma şekli ve materyal `resource_local_to_scene` işaretli: her örnek
## kendi kopyasını alır, yoksa bir platformun ölçüsünü değiştirmek hepsini
## birden değiştirirdi.
##
## Mesh ise BİLEREK ortak (`varliklar/birim_kutu.tres`) ve ölçü, mesh'in
## boyutuna değil düğümün ölçeğine yazılıyor. Sebebi Faz 6: aynı mesh'i
## paylaşan görseller tek MultiMesh'te birleştirilebiliyor (bkz.
## `birlestirici.gd`). Her platformun kendi mesh'i olsaydı gruplanamazlardı.

@export var olcu := Vector3(4.0, 0.5, 4.0):
	set(deger):
		olcu = deger
		_uygula()
@export var renk := Color(0.55, 0.47, 0.34):
	set(deger):
		renk = deger
		_uygula()

@onready var _gorsel: MeshInstance3D = $Gorsel
@onready var _carpisma: CollisionShape3D = $Carpisma

func _ready() -> void:
	_uygula()

func _uygula() -> void:
	if not is_node_ready() or not is_instance_valid(_gorsel):
		return
	_gorsel.scale = olcu
	(_carpisma.shape as BoxShape3D).size = olcu
	(_gorsel.material_override as StandardMaterial3D).albedo_color = renk
