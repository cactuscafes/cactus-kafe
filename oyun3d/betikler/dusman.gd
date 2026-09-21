extends CharacterBody3D
class_name Dusman
## Durum makineli düşman: devriye → fark et → kovala → saldır → çekil.
##
## Durum makinesi tek bir enum ve tek bir `match` ile duruyor. "if kovaliyor
## and not saldiriyor and gordu" gibi bayrak yığını yerine bunu tercih etmenin
## sebebi: her an TEK bir durumda olunduğu koda bakınca görülüyor, ve yeni
## durum eklemek eskileri bozmuyor.
##
## FAZ 14 — İSKELET ANİMASYONU: düşman artık rig'li
## (`araclar/dusman_karakter.py`). Her duruma bir animasyon karşılık geliyor
## ve geçişleri `_gec()` yapıyor.
##
## NEDEN AnimationTree DEĞİL: oyuncuda `AnimationTree` var çünkü yürüme ile
## koşma arasını HIZLA karıştırmak gerekiyor (BlendSpace1D). Düşmanın durumu
## ayrık: ya devriyede ya kovalıyor ya saldırıyor — karıştırılacak bir eksen
## yok. AnimationTree eklemek, durum makinesinin İKİNCİ bir kopyasını
## (ağacın kendi makinesini) bu dosyayla eşzamanlı tutmak demekti. Tek
## makine, tek doğruluk kaynağı; geçiş yumuşaklığını `play()`in harman
## süresi veriyor.
##
## FAZ 14 — ALT TÜRLER: `dusman_hoplayan.gd` ve `dusman_atici.gd` bu dosyayı
## GENİŞLETİYOR. Ortak olan her şey (algı, devriye, unutma, ezilme, erime)
## burada; alt tür yalnızca kovalama ve saldırı davranışını değiştiriyor.

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

@export_group("Ses")
## Türün sesini ayıran perde kaydırması (yarım ton). Aynı ses bankasını
## kullanan üç türün birbirinden AYIRT EDİLMESİ gerekiyor; ayrı ses dosyaları
## yerine perde kullanmak, ses bütçesini üçe katlamadan aynı işi görüyor.
## Küçük düşman tiz, iri düşman pes — gözün gördüğü boyu kulak da duyuyor.
@export var ses_perdesi := 0.0

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
var _erime_malzemeleri: Array[ShaderMaterial] = []
var _yercekimi: float = float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))

## Durum -> animasyon. Karşılığı olmayan durum (CEKIL) kovalama animasyonunu
## sürdürüyor: geri çekilme de bir yürüyüş.
const ANIMASYON := {
	Durum.DEVRIYE: "yurume", Durum.FARKETTI: "farketti", Durum.KOVALA: "kosma",
	Durum.SALDIRI: "saldiri", Durum.CEKIL: "kosma",
}
## Geçiş harmanı: 0 olursa poz zıplıyor, 0,3'ten uzunsa saldırı hazırlığı geç
## okunuyor ve oyuncu tepki penceresini kaçırıyor.
const HARMAN := 0.12
## Animasyonların ÖLÇÜLDÜĞÜ hızlar (araclar/dusman_karakter.py::HIZ ile aynı;
## `dusman_testi` ikisini karşılaştırıyor). Bu düşmanın hızı farklıysa
## animasyon aynı oranda hızlanıyor — alt türler hızı değiştirdiğinde ayak
## kayması kendiliğinden düzeliyor.
const ANIM_YURUME_HIZI := 1.9
const ANIM_KOSMA_HIZI := 4.3

@onready var _ajan: NavigationAgent3D = $Ajan
@onready var _gorus: RayCast3D = $Gorus
@onready var _model: Node3D = $Model
@onready var _parcacik: CPUParticles3D = $Parcacik
@onready var _oynatici: AnimationPlayer = $Model/Gorsel/AnimationPlayer

func _ready() -> void:
	add_to_group("dusman")
	_baslangic = global_position
	_devriye_hedefi = _baslangic + devriye_ucu
	_oyuncu = get_tree().get_first_node_in_group("oyuncu")
	_animasyon_kur()

## Animasyonların oyunun hızına bağlanması: yürüme animasyonu `dusman_karakter`
## içinde 1,9 m/s'ye göre ölçüldü. Bu düşmanın devriye hızı farklıysa
## (alt türler değiştiriyor) animasyon aynı oranda hızlanıyor, yoksa ayak
## kayması görünür oluyor.
func _animasyon_kur() -> void:
	if _oynatici == null:
		return
	for ad in _donguye_alinacaklar():
		var anim := _oynatici.get_animation(ad)
		if anim == null:
			# Eksik animasyon SESSİZ kalmamalı: alt tür kendi listesini
			# vermeyi unuttuysa düşman donuk duruyor ve sebebi aranıyor.
			push_warning("Düşman animasyonu eksik: %s" % ad)
			continue
		anim.loop_mode = Animation.LOOP_LINEAR
	_oynat(_ilk_animasyon())

## Döngüye alınacak animasyonlar — alt tür kendi kümesini veriyor. Boss'un
## "kosma"sı yok, hoplayanın "zipla"sı var; ortak liste ikisine de uymuyor.
func _donguye_alinacaklar() -> Array[String]:
	return ["yurume", "kosma", "bosta"]

func _ilk_animasyon() -> String:
	return "yurume"

func _yenilme_animasyonu() -> String:
	return "ezildi"

## Animasyon oynatır. Aynı animasyon zaten oynuyorsa baştan başlatmıyor —
## her karede `play()` çağırmak animasyonu ilk karesinde dondurur.
func _oynat(ad: String, hiz := 1.0) -> void:
	if _oynatici == null or not _oynatici.has_animation(ad):
		return
	if _oynatici.current_animation != ad:
		_oynatici.play(ad, HARMAN)
	_oynatici.speed_scale = hiz

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
		# Ucu döndü: bir an durup nefesleniyor. Durmuş bir düşmanın yürüme
		# animasyonunu oynatmak ayakları boşluğa kaydırır.
		_devriye_hedefi = (_baslangic if _devriye_hedefi != _baslangic
			else _baslangic + devriye_ucu)
		_oynat("bosta")
		return
	_yurut(fark.normalized(), devriye_hizi)
	_oynat("yurume", devriye_hizi / ANIM_YURUME_HIZI)

func _farketti() -> void:
	# Kısa duraklama: oyuncuya "fark edildim" sinyalini okuma süresi verir.
	# İrkilmeyi artık animasyon taşıyor (Faz 14); eskiden model ölçeği
	# esnetiliyordu.
	_yurut(Vector3.ZERO, 0.0)
	if _zaman <= 0.0:
		_gec(Durum.KOVALA)

func _kovala(delta: float) -> void:
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
	# Animasyon GERÇEKLEŞEN hıza bağlı, hedeflenen hıza değil: duvara dayanmış
	# ya da yavaşlamış bir düşmanın bacakları da yavaşlıyor.
	var suanki := Vector2(velocity.x, velocity.z).length()
	_oynat("kosma", clampf(suanki / ANIM_KOSMA_HIZI, 0.35, 2.0))

func _saldiri() -> void:
	_yurut(Vector3.ZERO, 0.0)
	if _oyuncu != null:
		_bak(_oyuncu.global_position - global_position)
	# Hazırlık animasyonu (geri yaylanma → öne savrulma) `_gec`te başladı.
	# Vuruş anı animasyonun kendisinden değil `hazirlik` sayacından geliyor:
	# hasarın zamanlaması oynanışa ait bir sayı, animasyona değil.
	if _zaman > 0.0:
		return
	# Vuruş anı: oyuncu hâlâ menzilde mi?
	if _oyuncu != null and _oyuncu.has_method("hasar_al"):
		var fark := _oyuncu.global_position - global_position
		if fark.length() <= saldiri_menzili * 1.25:
			_oyuncu.hasar_al(hasar, Vector3(fark.x, 0.0, fark.z).normalized())
	_gec(Durum.CEKIL)

func _cekil() -> void:
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
	# Ezme sesi 3B DEĞİL: oyuncu tam üstünde, kendi vuruşu. 3B yapmak onu
	# kamera açısına göre sağa sola kaydırıyor ve vuruşun ağırlığını alıyor.
	Ses.cal("ezme", 1.5)
	Efekt.sarsint(0.3)
	Efekt.vurus_duraklamasi(0.07, 0.06)
	_parcacik.restart()
	if can > 0:
		# Hayatta kaldı: eziliyor, sonra saldırıya geçiyor. Ezilme animasyonu
		# kovalamanın üstüne oynatılıyor — durum KOVALA ama gövde hâlâ
		# toparlanıyor; oyuncuya "vurdum ama ölmedi" geri bildirimi bu.
		_gec(Durum.KOVALA)
		_oynatici.play("ezildi", 0.05)
		return false
	_gec(Durum.YENILDI)
	return true

## Yenilme: eriyerek kayboluyor (golgeler/erime.gdshader). Anında silmek
## yerine yarım saniye göstermek, oyuncunun "ben yaptım" bağlantısını kurması
## için gerekli.
const ERIME_SURESI := 0.62

func _yenilme(delta: float) -> void:
	_yenilme_zamani += delta
	velocity.x = move_toward(velocity.x, 0.0, 30.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 30.0 * delta)
	_model.rotation.y += delta * 5.0
	_model.position.y += delta * 0.5
	var oran := clampf(_yenilme_zamani / ERIME_SURESI, 0.0, 1.0)
	for mat in _erime_malzemeleri:
		mat.set_shader_parameter("esik", oran)
	if _yenilme_zamani > ERIME_SURESI:
		queue_free()

## Düşman öldüğünde müziği kısar. Alt türler de aynı yolu kullanıyor.
func _kisma_iste() -> void:
	Ses.kis()

## Alt türlerin görünümü: aynı mesh, farklı renk ve ölçü.
##
## Oyuncunun türü BİR BAKIŞTA ayırt etmesi gerekiyor — davranış farkını
## öğrenebilmesi için önce farkı GÖRMESİ lazım. Ölçü de değişiyor çünkü renk
## tek başına yetmiyor: renk körü oyuncu için ayırt edici olan boy ve siluet
## (aynı gerekçe tuzak şeritlerinde de var).
func _gorunum(renk: Color, olcek: float) -> void:
	_model.scale = Vector3.ONE * olcek
	for dugum in _model.find_children("*", "MeshInstance3D", true, false):
		var mi := dugum as MeshInstance3D
		if mi.mesh == null or mi.mesh.get_surface_count() == 0:
			continue
		var kaynak := mi.mesh.surface_get_material(0) as BaseMaterial3D
		if kaynak == null:
			continue
		# Kopya: kaynak malzeme atlasla paylaşılıyor, üstüne yazmak bütün
		# düşmanları boyardı.
		var kopya := kaynak.duplicate() as BaseMaterial3D
		kopya.albedo_color = renk
		mi.material_override = kopya

## Modelin malzemesini erime shader'ıyla değiştirir. Her örnek kendi
## kopyasını alıyor: iki düşman aynı anda yenilirse biri diğerinin erimesini
## sürüklemesin.
func _erimeyi_baslat() -> void:
	var sablon: ShaderMaterial = preload("res://golgeler/erime_malzeme.tres")
	for dugum in _model.find_children("*", "MeshInstance3D", true, false):
		var mi := dugum as MeshInstance3D
		var mat := sablon.duplicate() as ShaderMaterial
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_erime_malzemeleri.append(mat)

# --- yardımcılar -----------------------------------------------------------

func _gec(yeni: Durum) -> void:
	if durum == yeni:
		return
	durum = yeni
	if ANIMASYON.has(yeni):
		_oynat(ANIMASYON[yeni])
	match yeni:
		Durum.YENILDI:
			_zaman = 0.0
			# Yenilme animasyonu alt türe göre: boss çöküyor ("yenildi"),
			# küçük düşman eziliyor ("ezildi"). Sabit ad yazmak boss'ta
			# "Animation not found" yağmuruna yol açıyordu.
			_oynat(_yenilme_animasyonu())
			_kisma_iste()
			Ses.cal_3b("dusman_oldu", global_position, ses_perdesi)
			# Çarpışmayı kapat: yenilen düşmanın üstünde durulmasın.
			$Carpisma.set_deferred("disabled", true)
			set_collision_layer_value(7, false)
			_erimeyi_baslat()
			yenildi.emit()
		Durum.FARKETTI:
			_zaman = 0.45
			Ses.cal_3b("dusman_farketti", global_position, ses_perdesi + 1.0)
		Durum.SALDIRI:
			_zaman = hazirlik
			Ses.cal_3b("dusman_saldiri", global_position, ses_perdesi + 1.5)
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
