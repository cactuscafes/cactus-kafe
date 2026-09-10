extends Area3D
## Bitiş alanı.

@export var oyun_yolu: NodePath = ^"../../Oyun"

func _ready() -> void:
	body_entered.connect(_giren)

func _giren(govde: Node3D) -> void:
	if govde.has_method("oldur"):
		get_node(oyun_yolu).bitirmeyi_dene()
