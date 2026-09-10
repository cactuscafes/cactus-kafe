@tool
extends StaticBody3D
## Ölçüsü ve rengi editörden ayarlanabilen tek parça platform.
##
## Mesh, çarpışma şekli ve materyal `resource_local_to_scene` işaretli: her
## örnek kendi kopyasını alır, yoksa bir platformun ölçüsünü değiştirmek
## hepsini birden değiştirirdi. Godot'da en sık düşülen kuyulardan biri budur.

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
	if not is_node_ready():
		return
	(_gorsel.mesh as BoxMesh).size = olcu
	(_carpisma.shape as BoxShape3D).size = olcu
	(_gorsel.material_override as StandardMaterial3D).albedo_color = renk
