extends CharacterBody3D
## Faz 1 karakteri: yürüme/koşma, zıplama, eğim, animasyon durum makinesi.
##
## Faz 0'daki sürümden farkı, "çalışıyor" ile "iyi hissettiriyor" arasındaki
## fark: coyote süresi, zıplama tamponu, değişken zıplama yüksekliği, havada
## azaltılmış kontrol ve karakterin gittiği yöne yumuşak dönmesi. Hiçbiri
## oyuncunun fark ettiği şeyler değil; yokluğu fark ediliyor.

signal olduruldu
signal yere_indi(hiz: float)
signal can_degisti(can: int, en_fazla: int)

@export_group("Hareket")
@export var yurume_hizi := 4.2
@export var kosma_hizi := 7.4
@export var yer_ivmesi := 60.0
@export var hava_ivmesi := 22.0
@export var yer_surtunmesi := 55.0
@export var donus_hizi := 12.0

@export_group("Can")
@export var can_max := 3
## Hasardan sonra dokunulmazlık: iki düşmanın arasında kalınca canın bir
## karede bitmesini engeller. Yanıp sönme bunun görünür hâli.
@export var dokunulmazlik_suresi := 1.25
@export var geri_tepme := 7.5

@export_group("Zıplama")
@export var ziplama_yuksekligi := 1.65
## Zemini terk ettikten sonra zıplamanın hâlâ kabul edildiği süre.
@export var kojot_suresi := 0.12
## Havadayken basılan zıplamanın yere değince hatırlanma süresi.
@export var tampon_suresi := 0.14
## Zıplama tuşu erken bırakılınca dikey hız bu oranla kesilir.
@export var kisa_ziplama_orani := 0.45
@export var dusme_carpani := 1.35

var _yercekimi: float = float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
var _ziplama_hizi := 0.0
var _kojot := 0.0
var _tampon := 0.0
var _dogum := Vector3.ZERO
var _onceki_dikey := 0.0
var _adim_yolu := 0.0
var can := 3
var _dokunulmazlik := 0.0

@onready var _kol: SpringArm3D = $KameraKolu
@onready var _yon: Node3D = $Yon
@onready var _agac: AnimationTree = $AnimationTree
@onready var _zemin_isini: RayCast3D = $ZeminIsini
@onready var _model: Node3D = $Yon/Model
@onready var _parcacik: CPUParticles3D = $Parcacik

var _durum: AnimationNodeStateMachinePlayback

func _ready() -> void:
	add_to_group("oyuncu")
	can = can_max
	_dogum = global_position
	_ziplama_hizi = sqrt(2.0 * _yercekimi * ziplama_yuksekligi)
	_agac.active = true
	_durum = _agac.get("parameters/playback")

func _physics_process(delta: float) -> void:
	var yerde := is_on_floor()
	_kojot = kojot_suresi if yerde else maxf(_kojot - delta, 0.0)
	_tampon = tampon_suresi if Input.is_action_just_pressed("ziplama") else maxf(_tampon - delta, 0.0)

	_dikey(delta, yerde)
	_yatay(delta, yerde)
	_onceki_dikey = velocity.y

	move_and_slide()

	if is_on_floor() and not yerde:
		yere_indi.emit(absf(_onceki_dikey))
		# Hafif inişte ses çıkarmak gürültü olur; eşik koyuyoruz.
		if absf(_onceki_dikey) > 3.0:
			Ses.cal("inis", 1.0)
	_adim_sesi(delta)

	_animasyon(yerde)
	_zemine_yatir(delta)
	_dokunulmazligi_isle(delta)

## Adım sesi zamana değil KAT EDİLEN YOLA bağlı: koşarken sıklaşır,
## yavaşlarken seyrelir, dururken kesilir. Zamana bağlarsan yürürken de
## koşarken de aynı ritimde tıkırdar ve kulağa yanlış gelir.
func _adim_sesi(delta: float) -> void:
	const ADIM_ARALIGI := 2.1  # metre
	if not is_on_floor():
		_adim_yolu = ADIM_ARALIGI * 0.6  # yere değer değmez ilk adım gelsin
		return
	_adim_yolu += Vector2(velocity.x, velocity.z).length() * delta
	if _adim_yolu >= ADIM_ARALIGI:
		_adim_yolu = 0.0
		Ses.adim_cal()

func _dikey(delta: float, yerde: bool) -> void:
	if not yerde:
		# Düşerken yerçekimini artırmak zıplamayı "ağır" değil "canlı" hissettirir.
		var carpan := dusme_carpani if velocity.y < 0.0 else 1.0
		velocity.y -= _yercekimi * carpan * delta
	elif velocity.y < 0.0:
		velocity.y = 0.0

	if _tampon > 0.0 and _kojot > 0.0:
		velocity.y = _ziplama_hizi
		_tampon = 0.0
		_kojot = 0.0
		_durum.travel("zipla")
		Ses.cal("zipla", 1.5)
	elif velocity.y > 0.0 and Input.is_action_just_released("ziplama"):
		velocity.y *= kisa_ziplama_orani

func _yatay(delta: float, yerde: bool) -> void:
	var girdi := Input.get_vector("sol", "sag", "ileri", "geri")
	var taban := _kol.global_transform.basis
	var yon := taban.x * girdi.x + taban.z * girdi.y
	yon.y = 0.0
	if yon.length_squared() > 0.0:
		yon = yon.normalized()

	var hiz := kosma_hizi if Input.is_action_pressed("kosma") else yurume_hizi
	var hedef := yon * hiz
	var degisim := (yer_ivmesi if yerde else hava_ivmesi) * delta
	if yon == Vector3.ZERO and yerde:
		degisim = yer_surtunmesi * delta

	velocity.x = move_toward(velocity.x, hedef.x, degisim)
	velocity.z = move_toward(velocity.z, hedef.z, degisim)

	if yon != Vector3.ZERO:
		var hedef_aci := atan2(-yon.x, -yon.z)
		_yon.rotation.y = lerp_angle(_yon.rotation.y, hedef_aci, donus_hizi * delta)

func _animasyon(yerde: bool) -> void:
	var yatay := Vector2(velocity.x, velocity.z).length()
	# 0 = boşta, 0.45 = yürüme, 1 = koşma. Blend space arasını dolduruyor.
	var oran := remap(yatay, 0.0, kosma_hizi, 0.0, 1.0)
	_agac.set("parameters/yer/blend_position", clampf(oran, 0.0, 1.0))

	if yerde:
		if _durum.get_current_node() != "yer":
			_durum.travel("yer")
	elif velocity.y < -0.5 and _durum.get_current_node() != "dusme":
		_durum.travel("dusme")

## Modeli zeminin eğimine yatırır — rampada dik durmak yerine yokuşa uyar.
## Gerçek ayak IK'sı iskelet ister; bu, kutu karakterde aynı işi gören ucuz
## sürümü. Eğim `Yon` düğümüne uygulanıyor: animasyonlar `Yon/Model`in
## dönüşünü yazıyor, ikisi çakışmasın diye.
func _zemine_yatir(delta: float) -> void:
	var hedef := Vector3.ZERO
	if _zemin_isini.is_colliding():
		var n := _zemin_isini.get_collision_normal()
		# Normali karakterin baktığı yöne göre ileri/yan eğime çevir.
		var ileri := -_yon.global_transform.basis.z
		var yan := _yon.global_transform.basis.x
		hedef = Vector3(-asin(clampf(n.dot(ileri), -1.0, 1.0)), 0.0,
			asin(clampf(n.dot(yan), -1.0, 1.0)))
	_yon.rotation.x = lerpf(_yon.rotation.x, hedef.x, minf(1.0, delta * 8.0))
	_yon.rotation.z = lerpf(_yon.rotation.z, hedef.z, minf(1.0, delta * 8.0))

func _dokunulmazligi_isle(delta: float) -> void:
	if _dokunulmazlik <= 0.0:
		return
	_dokunulmazlik -= delta
	# Yanıp sönme: dokunulmazlığın bittiği an oyuncuya görünür olmalı.
	_model.visible = _dokunulmazlik <= 0.0 or fmod(_dokunulmazlik, 0.16) > 0.08
	if _dokunulmazlik <= 0.0:
		_model.visible = true

## Hasar alır. Dokunulmazlık sürerken sessizce yutulur; alındıysa true döner.
func hasar_al(miktar: int, yon: Vector3) -> bool:
	if _dokunulmazlik > 0.0 or can <= 0:
		return false
	can -= miktar
	_dokunulmazlik = dokunulmazlik_suresi
	var duz := Vector3(yon.x, 0.0, yon.z)
	if duz.length_squared() > 0.001:
		velocity = duz.normalized() * geri_tepme + Vector3.UP * 4.0
	Ses.cal("hasar")
	Efekt.sarsint(0.5)
	Efekt.vurus_duraklamasi()
	_parcacik.restart()
	can_degisti.emit(can, can_max)
	if can <= 0:
		oldur()
	return true

## Tuzağa düşen ya da haritadan çıkan karakteri son kontrol noktasına döndürür.
func dogum_noktasi_ayarla(nokta: Vector3) -> void:
	_dogum = nokta

func oldur() -> void:
	Ses.cal("olum")
	Efekt.sarsint(0.35)
	olduruldu.emit()
	global_position = _dogum
	velocity = Vector3.ZERO
	_kojot = 0.0
	_tampon = 0.0
	can = can_max
	_dokunulmazlik = 0.6   # doğduğu anda üstünde duran düşman anında vurmasın
	_model.visible = true
	can_degisti.emit(can, can_max)

func dokunulmaz_mi() -> bool:
	return _dokunulmazlik > 0.0

## Testler ve hile kodları için: dokunulmazlığı hemen bitirir.
func dokunulmazligi_bitir() -> void:
	_dokunulmazlik = 0.0
	_model.visible = true

func zeminde_mi() -> bool:
	return is_on_floor() or _zemin_isini.is_colliding()
