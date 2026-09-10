extends AnimatableBody3D
## İki nokta arasında gidip gelen platform.
##
## AnimatableBody3D, StaticBody3D'den farklı olarak hızını fizik motoruna
## bildirir; üstündeki CharacterBody3D onunla birlikte taşınır. sync_to_physics
## açık olmazsa karakter platformun üstünde kayar.

@export var uc := Vector3(8.0, 0.0, 0.0)
@export var tur_suresi := 5.0
@export var baslangic_fazi := 0.0

var _baslangic := Vector3.ZERO
var _t := 0.0

func _ready() -> void:
	sync_to_physics = true
	_baslangic = position
	_t = baslangic_fazi * tur_suresi

func _physics_process(delta: float) -> void:
	_t += delta
	var oran := 0.5 - 0.5 * cos(TAU * _t / tur_suresi)
	position = _baslangic + uc * oran
