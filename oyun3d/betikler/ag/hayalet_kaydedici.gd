extends Node
## Turu kaydeder ve en iyi turun hayaletini oynatır.
##
## Bölüme eklenince iki iş birden yapıyor: (1) oyuncunun turunu örnekliyor,
## (2) varsa kayıtlı en iyi turu bir hayalet olarak oynatıyor. Bölüm bitince
## tur eskisinden hızlıysa kaydı değiştiriyor.

const ARALIK := 0.05   # 20 Hz

@export var oyun_yolu: NodePath = ^"../Oyun"
@export var oyuncu_yolu: NodePath = ^"../Oyuncu"

## Oyuncunun hayaletten ne kadar önde/geride olduğu (saniye, eksi = önde).
var fark := 0.0
var hayalet_var := false

var _oyun: Node
var _oyuncu: CharacterBody3D
var _kayit: HayaletKayit
var _onceki: HayaletKayit
var _hayalet: Node3D
var _sayac := 0.0
var _ipucu := 0

func _ready() -> void:
	_oyun = get_node(oyun_yolu)
	_oyuncu = get_node(oyuncu_yolu)
	_oyun.bolum_bitti.connect(_bitince)

	_kayit = HayaletKayit.new()
	_kayit.bolum = _oyun.bolum_kimligi
	_kayit.aralik = ARALIK

	_onceki = HayaletKayit.yukle(_oyun.bolum_kimligi)
	hayalet_var = _onceki != null and _onceki.ornek_sayisi() > 1
	if hayalet_var:
		_hayalet = preload("res://sahneler/hayalet.tscn").instantiate()
		add_child(_hayalet)

func _physics_process(delta: float) -> void:
	if _oyun.bitti:
		return
	_sayac -= delta
	if _sayac <= 0.0:
		_sayac = ARALIK
		var yon: Node3D = _oyuncu.get_node("Yon")
		_kayit.ekle(_oyuncu.global_position, yon.rotation.y,
			Vector2(_oyuncu.velocity.x, _oyuncu.velocity.z).length())

	if hayalet_var:
		_hayaleti_oynat()

func _hayaleti_oynat() -> void:
	var durum := _onceki.ornekle(_oyun.sure)
	if durum.is_empty():
		return
	_hayalet.uygula(durum)
	# Fark: oyuncunun BULUNDUĞU yerde hayaletin saati kaçtı?
	var hayalet_zamani := _onceki.en_yakin_zaman(_oyuncu.global_position, _ipucu)
	_ipucu = int(hayalet_zamani / ARALIK)
	fark = _oyun.sure - hayalet_zamani

func _bitince(_rekor: bool) -> void:
	_kayit.sure = _oyun.sure
	_kayit.olum = _oyun.olum
	_kayit.zaman_damgasi = int(Time.get_unix_time_from_system())
	# Kaydı yalnızca daha hızlıysa değiştiriyoruz: hayalet "geçilmesi gereken
	# en iyi tur" olmalı, "en son tur" değil.
	if _onceki == null or _kayit.sure < _onceki.sure:
		var hata := _kayit.kaydet()
		if hata != OK:
			push_warning("Hayalet kaydedilemedi: %d" % hata)
