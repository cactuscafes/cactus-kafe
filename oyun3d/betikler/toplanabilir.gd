extends Area3D
## Toplanabilir kaktüs çiçeği.

signal alindi

@export var donme_hizi := 2.2
@export var salinim := 0.18

var _t := 0.0
var _taban := 0.0

@onready var _gorsel: Node3D = $Gorsel

func _ready() -> void:
	add_to_group("toplanabilir")
	_taban = position.y
	# Aynı anda doğan nesneler aynı fazda salınmasın diye rastgele kaydırma.
	_t = randf() * TAU
	body_entered.connect(_giren)

func _process(delta: float) -> void:
	_t += delta
	_gorsel.rotation.y += donme_hizi * delta
	position.y = _taban + sin(_t * 2.0) * salinim

func _giren(_govde: Node3D) -> void:
	Ses.cal("toplama", 0.8)
	alindi.emit()
	queue_free()
