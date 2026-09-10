extends SpringArm3D
## Üçüncü şahıs kamera kolu.
##
## SpringArm3D duvara girmeyi kendi çözer: kolun uzunluğu boyunca ışın atar,
## bir şeye çarparsa kamerayı çarpma noktasına çeker. Faz 0'daki düz Node3D
## bunu yapmıyordu; karakteri duvara yaslayınca kamera duvarın içinde kalıyordu.

@export var hassasiyet := 0.0022
@export var en_dusuk := -60.0
@export var en_yuksek := 28.0
@export var oyun_kolu_hizi := 2.6

var _serbest := false

func _ready() -> void:
	# Kol, karakterin dönüşünden etkilenmemeli: kamerayı oyuncu çevirir.
	top_level = true
	kilitle(true)

func _process(delta: float) -> void:
	# Kol karakteri takip eder ama onunla birlikte dönmez.
	var sahip := get_parent() as Node3D
	if sahip != null:
		global_position = sahip.global_position + Vector3(0.0, 1.15, 0.0)

	var bak := Input.get_vector("bak_sol", "bak_sag", "bak_yukari", "bak_asagi")
	if bak != Vector2.ZERO:
		_cevir(bak * oyun_kolu_hizi * delta * 100.0 * hassasiyet)

func _unhandled_input(olay: InputEvent) -> void:
	if olay is InputEventMouseMotion and not _serbest:
		_cevir((olay as InputEventMouseMotion).relative * hassasiyet)
	elif olay.is_action_pressed("fare_birak"):
		kilitle(_serbest)
	elif olay is InputEventMouseButton:
		# Tarayıcı ve mobilde fare kilidi ancak kullanıcı tıklamasıyla açılır.
		var dugme := olay as InputEventMouseButton
		if dugme.pressed and _serbest:
			kilitle(true)

func _cevir(miktar: Vector2) -> void:
	rotation.y -= miktar.x
	rotation.x = clampf(rotation.x - miktar.y, deg_to_rad(en_dusuk), deg_to_rad(en_yuksek))

func kilitle(kilitli: bool) -> void:
	_serbest = not kilitli
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if kilitli else Input.MOUSE_MODE_VISIBLE
