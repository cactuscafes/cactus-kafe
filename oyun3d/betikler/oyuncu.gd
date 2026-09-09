extends CharacterBody3D
## Faz 0 karakteri: yerçekimi, kamera yönüne göre hareket, zıplama.
##
## Faz 1'de bunun yerine gerçek bir karakter gelecek (AnimationTree ile
## yürü/koş/zıpla geçişleri). Buradaki iskelet aynen kalabilir.

@export var hiz := 5.0
@export var kosma_carpani := 1.7
@export var ziplama_hizi := 4.8
@export var ivme := 14.0
@export var fare_hassasiyeti := 0.0022
## Bu yüksekliğin altına düşen karakter başlangıca döner.
@export var dusme_siniri := -20.0

var _yercekimi: float = float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
var _baslangic := Vector3.ZERO
var _fare_serbest := false

@onready var _yay: Node3D = $KameraYayi

func _ready() -> void:
	_baslangic = global_position
	_fare_kilitle(true)

func _unhandled_input(olay: InputEvent) -> void:
	if olay is InputEventMouseMotion and not _fare_serbest:
		var fare := olay as InputEventMouseMotion
		_yay.rotation.y -= fare.relative.x * fare_hassasiyeti
		_yay.rotation.x = clampf(
			_yay.rotation.x - fare.relative.y * fare_hassasiyeti,
			deg_to_rad(-55.0),
			deg_to_rad(25.0)
		)
	elif olay.is_action_pressed("fare_birak"):
		_fare_kilitle(_fare_serbest)
	elif olay is InputEventMouseButton:
		# Tarayıcı ve mobilde fare kilidi ancak kullanıcı tıklamasıyla açılabilir.
		var dugme := olay as InputEventMouseButton
		if dugme.pressed and _fare_serbest:
			_fare_kilitle(true)

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _yercekimi * delta
	elif Input.is_action_just_pressed("ziplama"):
		velocity.y = ziplama_hizi

	# Girdi, kameranın baktığı yöne göre dünya yönüne çevrilir.
	var girdi := Input.get_vector("sol", "sag", "ileri", "geri")
	var taban := _yay.global_transform.basis
	var yon := taban.x * girdi.x + taban.z * girdi.y
	yon.y = 0.0
	if yon.length_squared() > 0.0:
		yon = yon.normalized()

	var carpan := kosma_carpani if Input.is_action_pressed("kosma") else 1.0
	var hedef := yon * hiz * carpan
	velocity.x = move_toward(velocity.x, hedef.x, ivme * delta)
	velocity.z = move_toward(velocity.z, hedef.z, ivme * delta)

	move_and_slide()

	if global_position.y < dusme_siniri:
		global_position = _baslangic
		velocity = Vector3.ZERO

func _fare_kilitle(kilitli: bool) -> void:
	_fare_serbest = not kilitli
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if kilitli else Input.MOUSE_MODE_VISIBLE
