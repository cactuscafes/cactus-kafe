extends Dusman
class_name Boss
## Bölüm sonu canavarı: kalıp → açık → vuruş (Faz 16).
##
## NEDEN VAR: üç düşman türü öğretiyor, hiçbiri SINAMIYOR. Final bölümü
## zorluğu yoğunlukla kuruyordu; yoğunluk bir doruk değil, aynı şeyin daha
## fazlası. Boss, öğrenilen üç şeyi (zamanlama, mesafe, siper) tek bir
## karşılaşmada arka arkaya soruyor.
##
## DÖVÜŞÜN RİTMİ — dört evre, üç kez tekrar:
##   BEKLE    canavar oyuncuya yürüyor
##   TELGRAF  saldırı pozu alıyor (kollar havada / kafa geri) — KAÇMA PENCERESİ
##   VURUŞ    çarpma (yakın, alan hasarı) ya da diken yağmuru (uzak)
##   SERSEM   yoruldu: kafa yerde, gövde çökük — ÜSTÜNE BİNME PENCERESİ
##
## TEK AÇIK, TEK KURAL: canavara yalnızca SERSEM evresinde hasar veriliyor.
## Her an vurulabilseydi dövüş "yeterince zıpla" olurdu; hiç vurulamasaydı
## oyuncu ne yapacağını bilemezdi. Açığın ne zaman olduğunu animasyon
## söylüyor — poz diğerlerinden bariz farklı (bkz. araclar/boss_karakter.py).
##
## EVRE GEÇİŞİ: her vuruşta bir can gidiyor, canavar kükreyip hızlanıyor ve
## bir saldırı daha ekliyor. Zorluk sayılarla değil RİTİMLE artıyor: aynı
## kalıp, daha az nefes.

const DIKEN := preload("res://sahneler/diken.tscn")

signal can_degisti(can: int, en_fazla: int)
signal evre_degisti(evre: int)

enum Evre { BEKLE, TELGRAF, VURUS, SERSEM }

@export_group("Dövüş")
@export var can_max := 3
## Saldırı arası bekleme; her evrede kısalıyor.
@export var bekleme := 1.1
## Telgraf süresi — `carpma`/`atis` animasyonlarındaki hazırlık kadar.
## Bunu kısaltmak saldırıyı kaçınılmaz yapar; oyuncunun penceresi bu sayı.
@export var carpma_telgrafi := 0.45
@export var atis_telgrafi := 0.38
## Çarpmanın menzili ve hasarı.
@export var carpma_menzili := 4.6
@export var carpma_hasari := 1
## Sersem (savunmasız) süresi. Kısası dövüşü imkânsız, uzunu komik yapıyor.
@export var sersem_suresi := 2.4
## Kaç saldırıdan sonra yoruluyor (evre 1). Sonraki evrelerde bir artıyor.
@export var kalip_uzunlugu := 2
@export var yurume_hizi := 2.6
## Diken yağmurundaki mermi sayısı ve açılma açısı (derece).
@export var yagmur_adedi := 3
@export var yagmur_acisi := 22.0

var evre := Evre.BEKLE
var _evre_zamani := 0.0
var _kalan_saldiri := 0
var _sersem_mi := false

func _ready() -> void:
	super()
	add_to_group("boss")
	can = can_max
	# Devriye yok: canavar arenasında bekliyor.
	devriye_ucu = Vector3.ZERO
	_devriye_hedefi = _baslangic
	# Yakın dövüş menzili sıfır: hasarı kalıplar veriyor, temas değil.
	saldiri_menzili = 0.0
	gorus_mesafesi = 26.0
	gorus_acisi = 220.0
	unutma_mesafesi = 40.0
	_kalan_saldiri = kalip_uzunlugu

## Boss'un animasyon kümesi farklı: koşmuyor, "sersem" pozunda bekliyor.
func _donguye_alinacaklar() -> Array[String]:
	return ["yurume", "bosta", "sersem"]

func _ilk_animasyon() -> String:
	return "bosta"

func _yenilme_animasyonu() -> String:
	return "yenildi"

## Kovalama yerine dövüş döngüsü. Temel sınıf oyuncuyu görünce KOVALA'ya
## geçiyor; boss orada bu döngüyü işletiyor.
func _kovala(delta: float) -> void:
	if _oyuncu == null:
		_gec(Durum.DEVRIYE)
		return
	_evre_zamani -= delta
	var fark := _oyuncu.global_position - global_position
	var duz := Vector3(fark.x, 0.0, fark.z)
	var mesafe := duz.length()

	match evre:
		Evre.BEKLE:
			_bak(duz)
			# Menzilin dışındaysa yürüyerek yaklaşıyor; içindeyse bekliyor.
			if mesafe > carpma_menzili * 0.75:
				_yurut(duz.normalized(), yurume_hizi)
				_oynat("yurume", yurume_hizi / ANIM_YURUME_HIZI)
			else:
				_yurut(Vector3.ZERO, 0.0)
				_oynat("bosta")
			if _evre_zamani <= 0.0:
				_saldiriyi_sec(mesafe)
		Evre.TELGRAF:
			# Telgraf sırasında DURUYOR: hem poz okunsun hem oyuncu kaçacak
			# yeri seçebilsin. Yürüyerek saldıran bir canavardan kaçış yok.
			_yurut(Vector3.ZERO, 0.0)
			_bak(duz)
			if _evre_zamani <= 0.0:
				_vur(duz)
		Evre.VURUS:
			_yurut(Vector3.ZERO, 0.0)
			if _evre_zamani <= 0.0:
				_kalan_saldiri -= 1
				if _kalan_saldiri <= 0:
					_sersemle()
				else:
					_evreye_gec(Evre.BEKLE, bekleme)
		Evre.SERSEM:
			_yurut(Vector3.ZERO, 0.0)
			if _evre_zamani <= 0.0:
				_sersem_mi = false
				_kalan_saldiri = kalip_uzunlugu
				_evreye_gec(Evre.BEKLE, bekleme * 0.6)

func _evreye_gec(yeni: Evre, sure: float) -> void:
	evre = yeni
	_evre_zamani = sure
	evre_degisti.emit(yeni)

## Yakınsa çarpma, uzaksa diken yağmuru. Seçim mesafeye bağlı: oyuncunun
## uzakta durması da yakında durması da cezalı olmalı, yoksa dövüşün tek
## doğru yanıtı "uzakta bekle" olurdu.
func _saldiriyi_sec(mesafe: float) -> void:
	if mesafe <= carpma_menzili:
		_oynatici.play("carpma", 0.08)
		_evreye_gec(Evre.TELGRAF, carpma_telgrafi)
	else:
		_oynatici.play("atis", 0.08)
		_evreye_gec(Evre.TELGRAF, atis_telgrafi)

func _vur(duz: Vector3) -> void:
	if _oynatici.current_animation == "atis":
		_diken_yagmuru(duz)
		_evreye_gec(Evre.VURUS, 0.35)
		return
	# Çarpma: menzil içindeki oyuncuya alan hasarı. Menzil dairesel;
	# canavarın arkasına geçmek de kaçmak sayılıyor.
	Ses.cal_3b("boss_carp", global_position, 0.4)
	Efekt.sarsint(0.5)
	if _oyuncu != null and _oyuncu.has_method("hasar_al"):
		var fark := _oyuncu.global_position - global_position
		if Vector3(fark.x, 0.0, fark.z).length() <= carpma_menzili:
			_oyuncu.hasar_al(carpma_hasari,
				Vector3(fark.x, 0.0, fark.z).normalized())
	_evreye_gec(Evre.VURUS, 0.45)

## Yelpaze: tek diken kaçılabilir, üç diken yön seçtiriyor.
func _diken_yagmuru(duz: Vector3) -> void:
	if _oyuncu == null:
		return
	Ses.cal_3b("diken_at", global_position + Vector3.UP * 1.6, 0.6)
	var kap := get_parent()
	var orta := (_oyuncu.global_position + Vector3.UP * 0.6) \
		- (global_position + Vector3.UP * 1.6)
	for i in yagmur_adedi:
		var sapma := deg_to_rad(yagmur_acisi) * (float(i) - (yagmur_adedi - 1) * 0.5)
		var yon := orta.rotated(Vector3.UP, sapma)
		var mermi: Area3D = DIKEN.instantiate()
		if kap != null:
			kap.add_child(mermi)
		else:
			get_tree().current_scene.add_child(mermi)
		mermi.global_position = global_position + Vector3.UP * 1.6
		mermi.hasar = hasar
		mermi.kur(yon, self)

func _sersemle() -> void:
	_sersem_mi = true
	_oynatici.play("sersem", 0.15)
	_evreye_gec(Evre.SERSEM, sersem_suresi)

## Üstüne binildi. SERSEM değilken hasar YOK — ama oyuncu yine sektiriliyor:
## "vuramadım" ile "yanlış yaptım" arasındaki fark, sektirmenin kendisi.
func ezildi() -> bool:
	if durum == Durum.YENILDI:
		return false
	if not _sersem_mi:
		Ses.cal("ezme", 3.0, -6.0)
		Efekt.sarsint(0.12)
		return false
	can -= 1
	_sersem_mi = false
	Ses.cal("ezme", 1.0)
	Efekt.sarsint(0.45)
	Efekt.vurus_duraklamasi(0.09, 0.05)
	_parcacik.restart()
	can_degisti.emit(can, can_max)
	if can > 0:
		_kukre()
		return false
	_yenil()
	return true

## Evre değişimi: kükreme, sonra daha kısa nefes ve bir saldırı daha.
func _kukre() -> void:
	_oynatici.play("sarsilma", 0.05)
	Ses.cal_3b("boss_kukre", global_position, 0.3)
	bekleme = maxf(bekleme * 0.75, 0.45)
	sersem_suresi = maxf(sersem_suresi - 0.35, 1.4)
	kalip_uzunlugu += 1
	_kalan_saldiri = kalip_uzunlugu
	yurume_hizi = minf(yurume_hizi * 1.15, 5.0)
	_evreye_gec(Evre.BEKLE, 1.1)
	# Kükreme sarsılmanın üstüne: önce vuruşu yer, sonra doğrulur.
	await get_tree().create_timer(0.45).timeout
	if durum != Durum.YENILDI and is_instance_valid(_oynatici):
		_oynatici.play("kukreme", 0.1)

func _yenil() -> void:
	Ses.cal_3b("boss_kukre", global_position, 0.0, -3.0)
	# Animasyonu `_gec` seçiyor (bkz. `_yenilme_animasyonu`); burada ikinci
	# kez oynatmak çöküşü baştan başlatırdı.
	_gec(Durum.YENILDI)

## Yenilme daha uzun: iri şeyin çöküşü, küçük düşmanın erimesiyle aynı
## sürede biterse "yenildim" hissi oluşmuyor.
func _yenilme(delta: float) -> void:
	_yenilme_zamani += delta
	velocity.x = move_toward(velocity.x, 0.0, 30.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 30.0 * delta)
	var oran := clampf((_yenilme_zamani - 1.1) / 1.0, 0.0, 1.0)
	for mat in _erime_malzemeleri:
		mat.set_shader_parameter("esik", oran)
	if _yenilme_zamani > 2.2:
		queue_free()
