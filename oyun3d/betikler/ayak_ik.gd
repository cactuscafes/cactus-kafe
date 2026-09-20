class_name AyakIK
extends SkeletonModifier3D
## Ayak IK: karakterin ayaklarını zemine oturtur (Faz 12).
##
## NEDEN VAR: Faz 11'e kadar model rampada bütün olarak yatıyordu
## (`oyuncu.gd::_zemine_yatir`) — ucuz ve uzaktan işe yarayan bir numara, ama
## yakından bakınca bir ayak havada kalıyor, diğeri zemine gömülüyor. Basamakta
## ise ikisi de yanlış. Ayak IK bunu ayak ayak çözüyor: her ayağın altına ışın
## atılıyor, bacak zincirinin açıları o noktaya ULAŞACAK şekilde hesaplanıyor.
##
## İKİ KEMİKLİ ANALİTİK ÇÖZÜM: uyluk ve baldır uzunlukları sabit, hedefe olan
## mesafe biliniyor — üçgenin açıları kosinüs teoremiyle doğrudan çıkıyor.
## Yinelemeli çözücüye (FABRIK/CCD) gerek yok; iki kemikte kapalı form hem
## daha hızlı hem de her karede AYNI cevabı veriyor (yinelemeli çözücüler
## kare kare titreyebiliyor).
##
## IŞIN NEREDE ATILIYOR: `_physics_process` içinde, `_process_modification`
## içinde değil. Fizik sorgusu fizik karesi dışında yapılınca Godot uyarı
## veriyor ve sonuç bir kare bayat oluyor; modifiye ediciye hazır sonuç
## veriliyor.

## Kemik adları — `araclar/karakter.py` ile aynı.
const UYLUK := ["BacakSol", "BacakSag"]
const BALDIR := ["DizSol", "DizSag"]
const AYAK := ["AyakSol", "AyakSag"]
const KOK := "Kalca"

## Ayak bileğinin zeminden yüksekliği. `_ready` bunu rest pozundan ÖLÇÜYOR;
## buradaki değer yalnızca ayak kemiği bulunamazsa kullanılan yedek. Elle
## yazılan bir sayı, karakter değişince sessizce yanlış kalıyor.
@export var bilek_yuksekligi := 0.10
## Işın ayak hizasından bu kadar yukarıdan başlar, bu kadar aşağı iner.
@export var isin_yukari := 0.45
## Aşağı menzil bacağın ulaşabileceğinden biraz uzun: uyluk + baldır (0,52)
## eksi bilek yüksekliği (0,10) artı çömelme payı (0,35) ≈ 0,77. Daha kısası
## basamaktan inerken zemini hiç görmez, daha uzunu zaten erişilemeyen bir
## hedef bulur ve bacağı boşuna geriyor.
@export var isin_asagi := 0.8
## Kalçanın inebileceği en fazla mesafe: bir ayak çok aşağıdaysa karakter
## çömelir. Sınırsız bırakmak, uçurum kenarında karakteri yere yapıştırıyor.
@export var azami_comelme := 0.35
## Yumuşatma: IK hedefleri kare kare zıplamasın (basamakta "takırdama").
@export var yumusatma := 12.0
@export_flags_3d_physics var zemin_katmani := 1 | 32

var _uyluk: Array[int] = [-1, -1]
var _baldir: Array[int] = [-1, -1]
var _ayak: Array[int] = [-1, -1]
var _kok := -1
var _uyluk_uzunluk := 0.0
var _baldir_uzunluk := 0.0
## Ayak kemiğinin YEREL uzayında tabanın yukarı bakan ekseni. Rest pozundan
## bir kez çıkarılıyor: ayak kemiği ileri-aşağı bakıyor, yani tabanın normali
## kemiğin eksenlerinden hiçbiri değil.
var _taban_ekseni: Array[Vector3] = [Vector3.UP, Vector3.UP]

## Fizik karesinde doldurulan hedefler (dünya uzayı).
var _hedef: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
var _normal: Array[Vector3] = [Vector3.UP, Vector3.UP]
var _vardi: Array[bool] = [false, false]
## Hedef ilk kez dolduruldu mu? Yumuşatma ilk karede uygulanmamalı — ayak
## sahnenin orijininden hedefe doğru süzülerek gelir.
var _baslatildi: Array[bool] = [false, false]
var _comelme := 0.0

func _ready() -> void:
	var iskelet := get_skeleton()
	if iskelet == null:
		return
	for i in 2:
		_uyluk[i] = iskelet.find_bone(UYLUK[i])
		_baldir[i] = iskelet.find_bone(BALDIR[i])
		_ayak[i] = iskelet.find_bone(AYAK[i])
	_kok = iskelet.find_bone(KOK)
	# Kemik uzunlukları rest pozundan ölçülüyor: karakter değişirse IK da
	# kendiliğinden uyar, elle sayı girilmez.
	if _uyluk[0] >= 0 and _baldir[0] >= 0 and _ayak[0] >= 0:
		_uyluk_uzunluk = iskelet.get_bone_rest(_baldir[0]).origin.length()
		_baldir_uzunluk = iskelet.get_bone_rest(_ayak[0]).origin.length()
	for i in 2:
		if _ayak[i] >= 0:
			var dinlenme := iskelet.get_bone_global_rest(_ayak[i])
			_taban_ekseni[i] = (dinlenme.basis.inverse() * Vector3.UP).normalized()
			bilek_yuksekligi = dinlenme.origin.y

func _physics_process(delta: float) -> void:
	var iskelet := get_skeleton()
	if iskelet == null or not is_instance_valid(iskelet):
		return
	var uzay := iskelet.get_world_3d().direct_space_state
	var en_derin := 0.0
	for i in 2:
		if _uyluk[i] < 0:
			_vardi[i] = false
			continue
		# Işın ayağın ŞU ANKİ yerinden değil, kalçanın altından atılıyor:
		# animasyon ayağı havaya kaldırdığında ışın da havaya kalkar ve ayak
		# zemini "kaçırır". Kalça sabit referans.
		var kalca := iskelet.global_transform * iskelet.get_bone_global_pose(_uyluk[i]).origin
		var bas := kalca + Vector3.UP * isin_yukari
		var son := kalca - Vector3.UP * isin_asagi
		var sorgu := PhysicsRayQueryParameters3D.create(bas, son, zemin_katmani)
		var vurus := uzay.intersect_ray(sorgu)
		_vardi[i] = not vurus.is_empty()
		if _vardi[i]:
			var hedef: Vector3 = vurus["position"] + Vector3.UP * bilek_yuksekligi
			_hedef[i] = _hedef[i].lerp(hedef, clampf(delta * yumusatma, 0.0, 1.0)) \
				if _baslatildi[i] else hedef
			_baslatildi[i] = true
			_normal[i] = vurus["normal"] as Vector3
			en_derin = minf(en_derin, _hedef[i].y - kalca.y + _uyluk_uzunluk + _baldir_uzunluk)
	# Bir ayak bacağın uzanabileceğinden aşağıdaysa kalça iniyor (çömelme).
	var istenen := clampf(-en_derin, 0.0, azami_comelme) if en_derin < 0.0 else 0.0
	_comelme = lerpf(_comelme, istenen, clampf(delta * yumusatma * 0.5, 0.0, 1.0))

## Godot iskelet pozlarını güncellerken burayı çağırıyor: animasyon çoktan
## uygulanmış, biz üstüne yazıyoruz. Sıra önemli — animasyondan ÖNCE yazsaydık
## animasyon bizi ezerdi.
func _process_modification() -> void:
	var iskelet := get_skeleton()
	if iskelet == null or _uyluk_uzunluk <= 0.0:
		return
	var etki := influence
	if etki <= 0.001:
		return

	if _kok >= 0 and _comelme > 0.001:
		var poz := iskelet.get_bone_pose_position(_kok)
		iskelet.set_bone_pose_position(_kok, poz - Vector3.UP * _comelme * etki)

	var ters := iskelet.global_transform.affine_inverse()
	for i in 2:
		if not _vardi[i] or _uyluk[i] < 0 or _baldir[i] < 0:
			continue
		var kalca_poz := iskelet.get_bone_global_pose(_uyluk[i]).origin
		var hedef: Vector3 = ters * _hedef[i]
		# Diz nereye kırılacak? Karakterin ileri yönü (-Z) kutup vektörü;
		# olmasaydı diz rastgele bir yana, hatta geriye kırılırdı.
		var kutup := Vector3.FORWARD
		var cozum := _iki_kemik(kalca_poz, hedef, _uyluk_uzunluk, _baldir_uzunluk, kutup)
		if cozum.is_empty():
			continue
		# Etki ile harmanlama: havadayken IK kapanırken poz zıplamasın.
		var diz: Vector3 = cozum["diz"]
		var bilek: Vector3 = cozum["bilek"]
		_kemigi_yonelt(iskelet, _uyluk[i], kalca_poz, diz, etki)
		_kemigi_yonelt(iskelet, _baldir[i], diz, bilek, etki)
		# Ayak, bacağı takip ederse yokuşta burnu havaya kalkıyor: bacak
		# döndü, ayak onun çocuğu. Tabanı zeminin normaline yaslamak IK'nın
		# yarısı — bileği doğru yere koymak yeterli değil, ayağın da doğru
		# AÇIDA durması gerekiyor.
		_ayagi_yasla(iskelet, _ayak[i], (ters.basis * _normal[i]).normalized(),
			_taban_ekseni[i], etki)

## Kosinüs teoremi: kalça ve bilek arasındaki mesafeden diz açısı çıkıyor.
func _iki_kemik(kalca: Vector3, hedef: Vector3, l1: float, l2: float,
		kutup: Vector3) -> Dictionary:
	var fark := hedef - kalca
	var uzaklik := fark.length()
	if uzaklik < 0.0001:
		return {}
	# Zincir hedefe yetişemiyorsa sonuna kadar uzanıyor (bacak düz).
	uzaklik = clampf(uzaklik, absf(l1 - l2) + 0.001, l1 + l2 - 0.001)
	var yon := fark.normalized()
	var eksen := yon.cross(kutup)
	if eksen.length_squared() < 0.0001:
		eksen = yon.cross(Vector3.RIGHT)
	eksen = eksen.normalized()
	var aci := acos(clampf((l1 * l1 + uzaklik * uzaklik - l2 * l2)
		/ (2.0 * l1 * uzaklik), -1.0, 1.0))
	var uyluk_yonu := yon.rotated(eksen, aci)
	var diz := kalca + uyluk_yonu * l1
	return {"diz": diz, "bilek": kalca + yon * uzaklik}

## Ayağı zemine yaslar: tabanın normali zeminin normaline döndürülüyor.
## En kısa dönüş kullanılıyor (Quaternion(a, b)) — ayağın ileri yönü
## olabildiğince korunuyor, yalnızca yatıklığı düzeliyor.
func _ayagi_yasla(iskelet: Skeleton3D, kemik: int, normal: Vector3,
		taban: Vector3, etki: float) -> void:
	if kemik < 0 or normal.length_squared() < 0.0001:
		return
	var poz := iskelet.get_bone_global_pose(kemik)
	var suanki := (poz.basis * taban).normalized()
	if suanki.dot(normal) < -0.99:
		return   # tam ters: en kısa dönüş tanımsız, dokunma
	var istenen := Basis(Quaternion(suanki, normal)) * poz.basis
	var harman := poz.basis.get_rotation_quaternion().slerp(
		istenen.get_rotation_quaternion(), etki)
	iskelet.set_bone_global_pose(kemik, Transform3D(Basis(harman), poz.origin))

## Kemiği A'dan B'ye baktırır. Godot'da kemiğin kendi +Y'si kemik yönüdür.
func _kemigi_yonelt(iskelet: Skeleton3D, kemik: int, bas: Vector3, uc: Vector3,
		etki: float) -> void:
	var yon := (uc - bas)
	if yon.length_squared() < 0.000001:
		return
	yon = yon.normalized()
	var suanki := iskelet.get_bone_global_pose(kemik)
	var yan := suanki.basis.x
	if absf(yan.dot(yon)) > 0.99:
		yan = Vector3.RIGHT if absf(yon.dot(Vector3.RIGHT)) < 0.9 else Vector3.FORWARD
	var z := yan.cross(yon).normalized()
	var x := yon.cross(z).normalized()
	var istenen := Basis(x, yon, z).orthonormalized()
	var harman := suanki.basis.get_rotation_quaternion().slerp(
		istenen.get_rotation_quaternion(), etki)
	iskelet.set_bone_global_pose(kemik, Transform3D(Basis(harman), bas))
