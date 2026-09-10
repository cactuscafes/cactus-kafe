extends Area3D
## Dikenli alan: değen karakteri son kontrol noktasına yollar.

func _ready() -> void:
	body_entered.connect(_giren)

func _giren(govde: Node3D) -> void:
	if govde.has_method("oldur"):
		govde.oldur()
