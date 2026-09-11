extends CharacterBody3D
## Durum makineli düşman: devriye → fark et → kovala → saldır → çekil.
##
## Durum makinesi tek bir enum ve tek bir `match` ile duruyor. "if kovaliyor
## and not saldiriyor and gordu" gibi bayrak yığını yerine bunu tercih etmenin
## sebebi: her an TEK bir durumda olunduğu koda bakınca görülüyor, ve yeni
## durum eklemek eskileri bozmuyor.

enum Durum { DEVRIYE, FARKETTI, KOVALA, SALDIRI, CEKIL, YENILDI }

signal durum_degisti(yeni: Durum)
signal yenildi

@export_group("Devriye")
## Başlangıç noktasına göre ikinci devriye ucu.
@export var devriye_ucu := Vector3(6.0, 0.0, 0.0)
@export var devriye_hizi := 1.9

@export_group("Algı")
@export var gorus_mesafesi := 14.0
## Toplam görüş açısı (derece). Arkadan yaklaşmak işe yarasın diye 360 değil.
@export var gorus_acisi := 120.0
@export var unutma_mesafesi := 24.0
@export var unutma_suresi := 3.0

@export_group("Can")
@export var can := 2

@export_group("Saldırı")
@export var kovalama_hizi := 4.3
@export var saldiri_menzili := 2.1
@export var hasar := 1
## Vuruştan önceki bekleme: oyuncuya kaçma penceresi verir. Bu olmadan
## saldırı "haksız" hissettirir.
@export var hazirlik := 0.38
@export var toparlanma := 0.75
@export var cekilme_suresi := 0.9

var durum := Durum.DEVRIYE
var _zaman := 0.0
var _baslangic := Vector3.ZERO
var _devriye_hedefi := Vector3.ZERO
var _oyuncu: Node3D
var _kayip := 0.0
var _yenilme_zamani := 0.0
var _yercekimi: float = float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))

@onready var _ajan: NavigationAgent3D = $Ajan
@onready var _gorus: RayCast3D = $Gorus
@onready var _model: Node3D = $Model
@onready var _parcacik: CPUParticles3D = $Parcacik

func _ready() -> void:
	add_to_group("dusman")
	_baslangic = global_position
	_devriye_hedefi = _baslangic + devriye_ucu
	_oyuncu = get_tree().get_first_node_in_group("oyuncu")

func _physics_process(delta: float) -> void:
	if _oyuncu == null:
		# Sahne sırasına güvenme: oyuncunun _ready'si bu düğümden sonra
		# çalışıyorsa gruba henüz girmemiş olur.
		_oyuncu = get_tree().get_first_node_in_group("oyuncu")
	if not is_on_floor():
		velocity.y -= _yercekimi * delta
	else:
		velocity.y = 0.0
	_zaman -= delta

	if durum == Durum.YENILDI:
		_yenilme(delta)
		move_and_slide()
		return

	match durum:
		Durum.DEVRIYE: _devriye(delta)
		Durum.FARKETTI: _farketti()
		Durum.KOVALA: _kovala(delta)
		Durum.SALDIRI: _saldiri()
		Durum.CEKIL: _cekil()
		Durum.YENILDI: pass

	move_and_slide()

# --- durumlar --------------------------------------------------------------

func _devriye(_delta: float) -> void:
	if _goruyor_mu():
		_gec(Durum.FARKETTI)
		return
	var fark := _devriye_hedefi - global_position
	fark.y = 0.0
	if fark.length() < 0.6:
		_devriye_hedefi = (_baslangic if _devriye_hedefi != _baslangic
			else _baslangic + devriye_ucu)
		return
	_yurut(fark.normalized(), devriye_hizi)

func _farketti() -> void:
	_yurut(Vector3.ZERO, 0.0)
	# Kısa duraklama: oyuncuya "fark edildim" sinyalini okuma süresi verir.
	_model.scale = _model.scale.lerp(Vector3(1.15, 0.9, 1.15), 0.25)
	if _zaman <= 0.0:
		_gec(Durum.KOVALA)

func _kovala(delta: float) -> void:
	_model.scale = _model.scale.lerp(Vector3.ONE, 0.2)
	if _oyuncu == null:
		_gec(Durum.DEVRIYE)
		return
	var mesafe := global_position.distance_to(_oyuncu.global_position)
	if mesafe <= saldiri_menzili:
		_gec(Durum.SALDIRI)
		return

	_kayip = 0.0 if _goruyor_mu() else _kayip + delta
	if _kayip > unutma_suresi or mesafe > unutma_mesafesi:
		_devriye_hedefi = _baslangic
		_gec(Durum.DEVRIYE)
		return

	_ajan.target_position = _oyuncu.global_position
	if _ajan.is_navigation_finished():
		_yurut(Vector3.ZERO, 0.0)
		return
	var sonraki := _ajan.get_next_path_position()
	var yon := sonraki - global_position
	yon.y = 0.0
	if yon.length_squared() > 0.0001:
		_yurut(yon.normalized(), kovalama_hizi)

func _saldiri() -> void:
	_yurut(Vector3.ZERO, 0.0)
	if _oyuncu != null:
		_bak(_oyuncu.global_position - global_position)
	# Hazırlık: model geriye çekilir, sonra ileri savrulur.
	var oran := clampf(1.0 - _zaman / hazirlik, 0.0, 1.0)
	_model.scale = Vector3(1.0 - 0.18 * oran, 1.0 + 0.22 * oran, 1.0 - 0.18 * oran)
	if _zaman > 0.0:
		return
	# Vuruş anı: oyuncu hâlâ menzilde mi?
	if _oyuncu != null and _oyuncu.has_method("hasar_al"):
		var fark := _oyuncu.global_position - global_position
		if fark.length() <= saldiri_menzili * 1.25:
			_oyuncu.hasar_al(hasar, Vector3(fark.x, 0.0, fark.z).normalized())
	_gec(Durum.CEKIL)

func _cekil() -> void:
	_model.scale = _model.scale.lerp(Vector3.ONE, 0.2)
	if _oyuncu != null:
		var geri := global_position - _oyuncu.global_position
		geri.y = 0.0
		if geri.length_squared() > 0.001:
			_yurut(geri.normalized(), devriye_hizi * 1.3)
			_bak(-geri)
	if _zaman <= 0.0:
		_gec(Durum.KOVALA)

## Oyuncu üstüne bindiğinde çağrılır. Yenildiyse true döner.
func ezildi() -> bool:
	if durum == Durum.YENILDI:
		return false
	can -= 1
	Ses.cal("ezme", 1.5)
	Efekt.sarsint(0.3)
	Efekt.vurus_duraklamasi(0.07, 0.06)
	_parcacik.restart()
	if can > 0:
		# Hayatta kaldı: ezilip yayılıyor ve saldırıya geçiyor.
		_model.scale = Vector3(1.4, 0.5, 1.4)
		_gec(Durum.KOVALA)
		return false
	_gec(Durum.YENILDI)
	return true

## Yenilme: büzülerek kayboluyor. Anında silmek yerine yarım saniye
## göstermek, oyuncunun "ben yaptım" bağlantısını kurması için gerekli.
func _yenilme(delta: float) -> void:
	_yenilme_zamani += delta
	velocity.x = move_toward(velocity.x, 0.0, 30.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 30.0 * delta)
	_model.scale = _model.scale.lerp(Vector3(0.05, 0.05, 0.05), minf(1.0, delta * 6.0))
	_model.rotation.y += delta * 9.0
	if _yenilme_zamani > 0.55:
		queue_free()

# --- yardımcılar -----------------------------------------------------------

func _gec(yeni: Durum) -> void:
	if durum == yeni:
		return
	durum = yeni
	match yeni:
		Durum.YENILDI:
			_zaman = 0.0
			Ses.cal("dusman_oldu")
			# Çarpışmayı kapat: yenilen düşmanın üstünde durulmasın.
			$Carpisma.set_deferred("disabled", true)
			set_collision_layer_value(7, false)
			yenildi.emit()
		Durum.FARKETTI:
			_zaman = 0.45
			Ses.cal("dusman_farketti", 1.0)
		Durum.SALDIRI:
			_zaman = hazirlik
			Ses.cal("dusman_saldiri", 1.5)
		Durum.CEKIL:
			_zaman = cekilme_suresi
		_:
			_zaman = toparlanma
	durum_degisti.emit(yeni)

func _yurut(yon: Vector3, hiz: float) -> void:
	var hedef := yon * hiz
	velocity.x = move_toward(velocity.x, hedef.x, 30.0 * get_physics_process_delta_time() * 8.0)
	velocity.z = move_toward(velocity.z, hedef.z, 30.0 * get_physics_process_delta_time() * 8.0)
	if hiz > 0.0 and yon != Vector3.ZERO:
		_bak(yon)

func _bak(yon: Vector3) -> void:
	var duz := Vector3(yon.x, 0.0, yon.z)
	if duz.length_squared() < 0.0001:
		return
	_model.rotation.y = lerp_angle(_model.rotation.y, atan2(-duz.x, -duz.z), 0.25)

## Mesafe + görüş açısı + engel kontrolü. Üçü birden: oyuncu arkadan
## yaklaşabilsin ve platformun arkasına saklanabilsin.
func _goruyor_mu() -> bool:
	if _oyuncu == null:
		return false
	var fark := _oyuncu.global_position - global_position
	if fark.length() > gorus_mesafesi:
		return false
	var duz := Vector3(fark.x, 0.0, fark.z)
	if duz.length_squared() > 0.0001:
		var bakis := -_model.global_transform.basis.z
		if duz.normalized().dot(Vector3(bakis.x, 0.0, bakis.z).normalized()) \
				< cos(deg_to_rad(gorus_acisi * 0.5)):
			return false
	# Gövde bu düğümde döndürülmüyor (yalnızca Model dönüyor), bu yüzden
	# dünya farkı doğrudan ışının hedefi olarak kullanılabiliyor.
	_gorus.target_position = fark
	_gorus.force_raycast_update()
	return not _gorus.is_colliding()
