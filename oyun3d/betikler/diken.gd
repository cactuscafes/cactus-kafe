class_name Diken
extends Area3D
## Atıcı düşmanın fırlattığı diken (Faz 14).
##
## NEDEN ALAN (Area3D), MERMİ GÖVDESİ (RigidBody3D) DEĞİL: dikenin fiziğe
## ihtiyacı yok — düz gidiyor, çarpınca yok oluyor. RigidBody üç şey getirirdi:
## çözücü maliyeti, oyuncuyu itme gibi istenmeyen tepkiler ve kare hızına
## bağlı belirsizlik. Alan ise "neye değdim" sorusunu doğrudan cevaplıyor.
##
## HIZLI CİSİM TUZAĞI: 14 m/s giden bir diken 60 FPS'te kare başına 23 cm
## atlıyor; ince bir duvarın içinden geçebilir. Bu yüzden hareket her karede
## ışınla önceden sınanıyor (`_carpisma_var_mi`), sonra uygulanıyor.

signal carpti

@export var hiz := 14.0
@export var hasar := 1
## Menzil sonu: bu kadar metre gittikten sonra kendiliğinden yok oluyor.
## Ömür yerine MESAFE: hız değişirse menzil aynı kalıyor.
@export var menzil := 26.0

var _yon := Vector3.FORWARD
var _yol := 0.0
var _sahibi: Node3D

func kur(yon: Vector3, sahibi: Node3D) -> void:
	_yon = yon.normalized()
	_sahibi = sahibi
	look_at(global_position + _yon, Vector3.UP)

func _ready() -> void:
	add_to_group("mermi")
	body_entered.connect(_degdi)

func _physics_process(delta: float) -> void:
	var adim := hiz * delta
	var engel := _carpisma_var_mi(adim)
	if engel != null:
		_degdi(engel)
		return
	global_position += _yon * adim
	_yol += adim
	if _yol > menzil:
		queue_free()

## Karenin atlayacağı yol boyunca ışın: ince duvarı delip geçmesin.
func _carpisma_var_mi(adim: float) -> Node3D:
	var uzay := get_world_3d().direct_space_state
	var sorgu := PhysicsRayQueryParameters3D.create(
		global_position, global_position + _yon * (adim + 0.12),
		collision_mask)
	# Atan düşmanın kendi gövdesine takılmasın: namlu ucu onun içinde.
	if _sahibi != null:
		sorgu.exclude = [_sahibi.get_rid()]
	var vurus := uzay.intersect_ray(sorgu)
	return vurus.get("collider") as Node3D if not vurus.is_empty() else null

func _degdi(govde: Node3D) -> void:
	if govde == _sahibi:
		return
	if govde != null and govde.has_method("hasar_al"):
		var itme := Vector3(_yon.x, 0.0, _yon.z)
		govde.hasar_al(hasar, itme.normalized() if itme.length() > 0.01 else Vector3.FORWARD)
	carpti.emit()
	queue_free()
