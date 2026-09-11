extends Node
## Ağ testinin İSTEMCİ tarafı: sunucudan gelen durumu ölçer ve doğrular.
##
## Ölçülenler:
##  1. Durum paketleri geliyor mu (tampon doluyor mu)
##  2. Aradeğerlenmiş konum sunucunun çemberi üstünde mi (yarıçap ~5 m)
##  3. Hareket akıcı mı — ardışık kareler arasında ışınlanma yok
##  4. Sunucu doğrulaması hile paketini reddediyor mu

const PORT := 8911
const YARICAP := 5.0
const OLCUM_SURESI := 6.0

var _sahte: CharacterBody3D
var _t := 0.0
var _olcumler := 0
var _yaricap_hatasi := 0.0
var _en_buyuk_adim := 0.0
var _onceki := Vector3.INF
var _toplam_yol := 0.0
var _hile_gonderildi := false

func _ready() -> void:
	Ag.kendi_adim = "İstemci"
	var hata := Ag.katil("127.0.0.1", PORT)
	if hata != OK:
		print("SONUC {\"hata\":\"baglanilamadi\"}")
		get_tree().quit(1)
		return
	_sahte = preload("res://testler/sahte_oyuncu.tscn").instantiate()
	add_child(_sahte)
	_sahte.global_position = Vector3(0.0, 1.0, 0.0)
	Ag.yerel_oyuncuyu_ayarla(_sahte)
	Ag.yerel_isinlanma()

func _physics_process(delta: float) -> void:
	if not Ag.bagli:
		return
	_t += delta
	# İstemci de makul bir yol izliyor ki sunucu paketlerini kabul etsin.
	_sahte.global_position = Vector3(0.0, 1.0, _t * 2.0)

	var durum := Ag.uzak_durum(1)
	if not durum.is_empty():
		var konum: Vector3 = durum["konum"]
		_olcumler += 1
		_yaricap_hatasi = maxf(_yaricap_hatasi,
			absf(Vector2(konum.x, konum.z).length() - YARICAP))
		if _onceki != Vector3.INF:
			var adim := _onceki.distance_to(konum)
			_en_buyuk_adim = maxf(_en_buyuk_adim, adim)
			_toplam_yol += adim
		_onceki = konum

	# Ölçümün ortasında bir "ışınlanma" paketi gönder: sunucu reddetmeli.
	if not _hile_gonderildi and _t > OLCUM_SURESI * 0.6:
		_hile_gonderildi = true
		Ag._durum_bildir.rpc_id(1, Vector3(900.0, 0.0, 900.0), 0.0, 99.0)

	if _t >= OLCUM_SURESI:
		print("SONUC %s" % JSON.stringify({
			"olcum": _olcumler,
			"yaricap_hatasi": snappedf(_yaricap_hatasi, 0.001),
			"en_buyuk_adim": snappedf(_en_buyuk_adim, 0.001),
			"toplam_yol": snappedf(_toplam_yol, 0.01),
		}))
		get_tree().quit(0)
