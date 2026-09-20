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

@export_group("Ezme")
## Düşmanın üstüne inince kazanılan sıçrama. Zıplamadan biraz düşük:
## zincirleme ezme ödül olmalı ama sonsuz yükselme aracı olmamalı.
@export var ezme_sicramasi := 0.85

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

@export_group("Animasyon")
## Gövdenin zemin eğimine yatma payı (0 = hiç, 1 = eğimin tamamı).
## Ayak IK'sı işin çoğunu yaptığı için 1 fazla geliyor; bkz. `_zemine_yatir`.
@export_range(0.0, 1.0) var govde_yatirma := 0.35
## Ayak IK etkisinin saniyede değişme hızı (yere inince açılır, havada kapanır).
@export var ik_gecis_hizi := 6.0

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

var _ayak_ik: AyakIK

var _durum: AnimationNodeStateMachinePlayback

func _ready() -> void:
	add_to_group("oyuncu")
	can = can_max
	_dogum = global_position
	_ziplama_hizi = sqrt(2.0 * _yercekimi * ziplama_yuksekligi)
	_agac.active = true
	_durum = _agac.get("parameters/playback")
	_ayak_ik_kur()

## Ayak IK'sı sahneye elle değil koddan ekleniyor: modifiye edici Skeleton3D'nin
## ÇOCUĞU olmak zorunda, iskelet ise içe aktarılmış glTF sahnesinin içinde.
## Sahnede oraya düğüm koymak "editable instance" gerektirir; model her
## yeniden üretildiğinde (araclar/karakter.py) o bağ kopar. Koddan eklemek
## modelin yeniden üretilmesine dayanıklı.
func _ayak_ik_kur() -> void:
	var iskelet := _model.get_node_or_null("iskelet/Skeleton3D") as Skeleton3D
	if iskelet == null:
		push_warning("Ayak IK: iskelet bulunamadı, model değişmiş olabilir")
		return
	_ayak_ik = AyakIK.new()
	_ayak_ik.name = "AyakIK"
	_ayak_ik.influence = 0.0   # ilk kare havada sayılıyor; _ik_isle açıyor
	iskelet.add_child(_ayak_ik)

func _physics_process(delta: float) -> void:
	var yerde := is_on_floor()
	_kojot = kojot_suresi if yerde else maxf(_kojot - delta, 0.0)
	_tampon = tampon_suresi if Input.is_action_just_pressed("ziplama") else maxf(_tampon - delta, 0.0)

	_dikey(delta, yerde)
	_yatay(delta, yerde)
	_onceki_dikey = velocity.y

	move_and_slide()

	_ezme_kontrolu()
	if is_on_floor() and not yerde:
		yere_indi.emit(absf(_onceki_dikey))
		# Hafif inişte ses çıkarmak gürültü olur; eşik koyuyoruz.
		if absf(_onceki_dikey) > 3.0:
			Ses.cal("inis", 1.0)
	_adim_sesi(delta)

	_animasyon(yerde)
	_zemine_yatir(delta)
	_ik_isle(delta, is_on_floor())
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
	# Girdinin BOYU da anlamlı: ekrandaki çubuk yarım itilirse yarım hız.
	# Klavyede boy zaten 1 olduğu için bir şey değişmiyor. Yönü normalize edip
	# gücü ayrı tutmak şart — normalize etmeden çapraz basmak 1.41 kat hız verir.
	var guc := minf(girdi.length(), 1.0)
	var taban := _kol.global_transform.basis
	var yon := taban.x * girdi.x + taban.z * girdi.y
	yon.y = 0.0
	if yon.length_squared() > 0.0:
		yon = yon.normalized()

	var hiz := kosma_hizi if Input.is_action_pressed("kosma") else yurume_hizi
	var hedef := yon * hiz * guc
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

## Düşmanın üstüne düşüldü mü? move_and_slide'ın kaydettiği çarpışmalara
## bakıyoruz: normali yukarı bakıyorsa ve düşüyorsak, üstüne binmişiz demektir.
## Ayrı bir Area3D yerine bunu kullanmak, "yandan değdim ama ezdim sayıldı"
## hatasını kökten engelliyor.
func _ezme_kontrolu() -> void:
	if velocity.y > 1.0:
		return
	for i in get_slide_collision_count():
		var carpisma := get_slide_collision(i)
		var hedef := carpisma.get_collider()
		if hedef == null or not hedef.is_in_group("dusman"):
			continue
		if carpisma.get_normal().y < 0.55:
			continue   # yandan çarptık, üstüne binmedik
		if hedef.has_method("ezildi"):
			hedef.ezildi()
		velocity.y = _ziplama_hizi * ezme_sicramasi
		return

## Ayak IK'sını havada kapatır, yerde açar.
##
## Havada zemin ışını ya boşa gidiyor ya da altından geçen bir platformu
## buluyor; ikisinde de bacaklar saçmalıyor. Kapatma ANİ DEĞİL: etkiyi bir
## karede 1'den 0'a düşürmek, zıplamanın ilk karesinde bacakları yerinden
## sıçratıyor (IK pozundan animasyon pozuna atlama). Harmanlama bunu
## zıplamanın kendi süresine yayıyor.
func _ik_isle(delta: float, yerde: bool) -> void:
	if _ayak_ik == null:
		return
	var hedef := 1.0 if yerde else 0.0
	_ayak_ik.influence = move_toward(_ayak_ik.influence, hedef, delta * ik_gecis_hizi)

## Modeli zeminin eğimine hafifçe yatırır.
##
## FAZ 12'DE KÜÇÜLDÜ: bu, kutu karakterde ayak IK'sının yerine geçen ucuz
## numaraydı — bütün gövdeyi yokuşa yatırıyordu. Artık ayaklar zemine kendi
## oturuyor (`betikler/ayak_ik.gd`), gövdeyi de tam eğime yatırmak fazladan
## oluyor: karakter yokuşta öne kapaklanmış görünüyor. Kalan pay bilinçli —
## rampaya girerken gövdenin hafif yaslanması eğimi okunur kılıyor.
## Eğim `Yon` düğümüne uygulanıyor: animasyonlar `Yon/Model`in dönüşünü
## yazıyor, ikisi çakışmasın diye.
func _zemine_yatir(delta: float) -> void:
	var hedef := Vector3.ZERO
	if _zemin_isini.is_colliding():
		var n := _zemin_isini.get_collision_normal()
		# Normali karakterin baktığı yöne göre ileri/yan eğime çevir.
		var ileri := -_yon.global_transform.basis.z
		var yan := _yon.global_transform.basis.x
		hedef = Vector3(-asin(clampf(n.dot(ileri), -1.0, 1.0)), 0.0,
			asin(clampf(n.dot(yan), -1.0, 1.0))) * govde_yatirma
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
	# Ağdaysak sunucuya haber ver: doğum noktasına dönmek meşru bir ışınlanma,
	# hile değil. Bildirmezsek paketlerimiz düşer ve rakiplerin ekranında
	# donmuş görünürüz.
	Ag.yerel_isinlanma()
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
