extends Area3D
## Kontrol noktası: bir kez tetiklenir, doğum noktasını buraya taşır.

@export var oyun_yolu: NodePath = ^"../../Oyun"

var _kullanildi := false

@onready var _bayrak: Node3D = $Bayrak

func _ready() -> void:
	body_entered.connect(_giren)

func _giren(govde: Node3D) -> void:
	if _kullanildi or not govde.has_method("oldur"):
		return
	_kullanildi = true
	_bayrak.rotation_degrees.z = -35.0
	get_node(oyun_yolu).kontrol_noktasi(global_position + Vector3(0.0, 1.0, 0.0))
