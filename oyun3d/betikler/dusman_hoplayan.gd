extends Dusman
## Hoplayan düşman: yürümez, zıplayarak saldırır (Faz 14).
##
## NEDEN VAR: temel düşman yerde koşuyor, yani oyuncu zıplayarak ondan
## kaçabiliyor ve istediği an üstüne inebiliyor. Hoplayan bunu tersine
## çeviriyor — havada da tehlike var. Karşılığında ADİL bir açık veriyor:
## indikten sonra toparlanma penceresinde savunmasız.
##
## RİTİM: çömel (telgraf) → sıçra → in → topar. Dört evre de görünür;
## oyuncunun ne zaman kaçıp ne zaman üstüne bineceği bu ritimden okunuyor.

@export_group("Hoplama")
## Çömelme (telgraf) süresi. Kısaltmak kaçınılmaz, uzatmak etkisiz yapar.
@export var comelme := 0.34
## Sıçramanın dikey hızı ve yatay menzili.
@export var sicrama_hizi := 7.2
@export var sicrama_menzili := 5.5
## İniş sonrası savunmasız pencere: oyuncunun üstüne binme fırsatı.
@export var toparlanma_suresi := 0.7

enum Evre { BEKLE, COMEL, HAVADA, TOPAR }

var _evre := Evre.BEKLE
var _evre_zamani := 0.0

func _ready() -> void:
	super()
	# Yakın dövüş yok: hasarı sıçramanın kendisi veriyor.
	saldiri_menzili = 0.0
	# Hoplayan tek vuruşta yenilir: havada geçirdiği süre onu zaten zor hedef
	# yapıyor, üstüne iki can vermek "hiç ölmüyor" hissi veriyordu.
	can = 1
	# Küçük ve mavimsi: zıplayan şey küçük olmalı, gözde "hafif" duruyor.
	_gorunum(Color(0.62, 0.78, 1.35), 0.82)
	gorus_mesafesi = 12.0

## Kovalama yerine hoplama döngüsü.
func _kovala(delta: float) -> void:
	if _oyuncu == null:
		_gec(Durum.DEVRIYE)
		return
	var fark := _oyuncu.global_position - global_position
	var mesafe := fark.length()
	_kayip = 0.0 if _goruyor_mu() else _kayip + delta
	if _kayip > unutma_suresi or mesafe > unutma_mesafesi:
		_evre = Evre.BEKLE
		_gec(Durum.DEVRIYE)
		return

	_evre_zamani -= delta
	match _evre:
		Evre.BEKLE:
			_yurut(Vector3.ZERO, 0.0)
			_bak(fark)
			_oynat("bosta")
			if mesafe < sicrama_menzili * 1.6:
				_evre = Evre.COMEL
				_evre_zamani = comelme
				_oynatici.play("zipla", 0.08)
				_oynatici.speed_scale = 1.0
		Evre.COMEL:
			_yurut(Vector3.ZERO, 0.0)
			_bak(fark)
			if _evre_zamani <= 0.0:
				_sicra(fark)
		Evre.HAVADA:
			# Havada yön değiştirmiyor: sıçrama bir KARAR, oyuncu onu okuyup
			# yana kaçabilmeli. Havada takip eden bir düşmandan kaçış yok.
			if is_on_floor() and _evre_zamani <= 0.0:
				_evre = Evre.TOPAR
				_evre_zamani = toparlanma_suresi
				_oynatici.play("ezildi", 0.06)
				Ses.cal("inis", 0.9)
		Evre.TOPAR:
			_yurut(Vector3.ZERO, 0.0)
			if _evre_zamani <= 0.0:
				_evre = Evre.BEKLE

func _sicra(fark: Vector3) -> void:
	_evre = Evre.HAVADA
	# En az 0,12 sn havada sayılıyor: ilk karede zemin hâlâ altında.
	_evre_zamani = 0.12
	var duz := Vector3(fark.x, 0.0, fark.z)
	var uzaklik := minf(duz.length(), sicrama_menzili)
	if duz.length_squared() > 0.001:
		duz = duz.normalized()
		_bak(duz)
	# Yatay hız, havada kalma süresine göre: menzil kadar gitmeli, daha fazla
	# değil. Süre = 2·v_dikey / g (tam balistik).
	var sure := 2.0 * sicrama_hizi / _yercekimi
	velocity = Vector3(duz.x * uzaklik / sure, sicrama_hizi, duz.z * uzaklik / sure)
	Ses.cal("dusman_saldiri", 1.4)

## Havadayken oyuncuya değerse hasar veriyor. Temel sınıfın menzilli yakın
## dövüşü kapalı olduğu için tek hasar kaynağı bu.
func _physics_process(delta: float) -> void:
	super(delta)
	if durum == Durum.YENILDI or _evre != Evre.HAVADA:
		return
	if _oyuncu == null or not _oyuncu.has_method("hasar_al"):
		return
	var fark := _oyuncu.global_position - global_position
	if fark.length() < 1.3:
		var itme := Vector3(fark.x, 0.0, fark.z)
		if _oyuncu.hasar_al(hasar, itme.normalized() if itme.length() > 0.01 else Vector3.FORWARD):
			# Vurdu: sıçrama biter, toparlanmaya geçer. Aynı sıçramada iki kez
			# vurmasın diye evre hemen değişiyor.
			_evre = Evre.TOPAR
			_evre_zamani = toparlanma_suresi
