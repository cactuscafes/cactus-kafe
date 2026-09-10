extends SceneTree
## Karakter animasyonlarını ve AnimationTree'yi üretir.
##
##   godot --headless --path oyun3d --script res://araclar/animasyon_uret.gd
##
## Neden kodla üretiliyor: Faz 1'de elimizde rig'li bir model yok (Mixamo hesabı
## gerekiyor). Karakter kutulardan kurulu olduğu için animasyon = düğüm
## dönüşlerinin zaman içindeki değeri; bunu sinüsle üretmek elle keyframe
## koymaktan hem hızlı hem tekrarlanabilir.
##
## Faz 2'de Blender'dan gerçek bir model geldiğinde bu dosya silinecek,
## animasyonlar GLB ile birlikte gelecek. AnimationTree yapısı aynen kalabilir.

const KUTUPHANE := "res://animasyon/oyuncu.tres"
const AGAC := "res://animasyon/oyuncu_agac.tres"

const SOL_BACAK := "Yon/Model/BacakSol:rotation"
const SAG_BACAK := "Yon/Model/BacakSag:rotation"
const SOL_KOL := "Yon/Model/KolSol:rotation"
const SAG_KOL := "Yon/Model/KolSag:rotation"
const GOVDE_KONUM := "Yon/Model:position"
const GOVDE_DONUS := "Yon/Model:rotation"

func _initialize() -> void:
	var kutuphane := AnimationLibrary.new()
	kutuphane.add_animation("bosta", _bosta())
	kutuphane.add_animation("yurume", _adim(0.9, 0.45, 0.28, 0.04, 0.03))
	kutuphane.add_animation("kosma", _adim(0.55, 0.85, 0.55, 0.09, 0.16))
	kutuphane.add_animation("zipla", _zipla())
	kutuphane.add_animation("dusme", _dusme())

	var hata := ResourceSaver.save(kutuphane, KUTUPHANE)
	if hata != OK:
		printerr("Kütüphane kaydedilemedi: %d" % hata)
		quit(1)
		return

	hata = ResourceSaver.save(_agac(), AGAC)
	if hata != OK:
		printerr("Ağaç kaydedilemedi: %d" % hata)
		quit(1)
		return

	print("üretildi: %s + %s" % [KUTUPHANE, AGAC])
	quit(0)

## Boş bir Animation'a değer izi ekler ve iz numarasını döndürür.
func _iz(anim: Animation, yol: String) -> int:
	var i := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(i, NodePath(yol))
	anim.track_set_interpolation_type(i, Animation.INTERPOLATION_LINEAR)
	anim.value_track_set_update_mode(i, Animation.UPDATE_CONTINUOUS)
	return i

## Bir çevrimi ADIM parçaya bölüp her parçaya sinüsle anahtar koyar.
func _cevrim(anim: Animation, iz: int, sure: float, uret: Callable) -> void:
	const ADIM := 8
	for k in ADIM + 1:
		var t := sure * float(k) / float(ADIM)
		anim.track_insert_key(iz, t, uret.call(TAU * float(k) / float(ADIM)))

func _bosta() -> Animation:
	var a := Animation.new()
	a.length = 2.6
	a.loop_mode = Animation.LOOP_LINEAR
	_cevrim(a, _iz(a, GOVDE_KONUM), a.length, func(f: float) -> Vector3:
		return Vector3(0.0, sin(f) * 0.022, 0.0))
	_cevrim(a, _iz(a, SOL_KOL), a.length, func(f: float) -> Vector3:
		return Vector3(sin(f) * 0.05, 0.0, 0.09))
	_cevrim(a, _iz(a, SAG_KOL), a.length, func(f: float) -> Vector3:
		return Vector3(sin(f + PI) * 0.05, 0.0, -0.09))
	_cevrim(a, _iz(a, SOL_BACAK), a.length, func(_f: float) -> Vector3: return Vector3.ZERO)
	_cevrim(a, _iz(a, SAG_BACAK), a.length, func(_f: float) -> Vector3: return Vector3.ZERO)
	_cevrim(a, _iz(a, GOVDE_DONUS), a.length, func(_f: float) -> Vector3: return Vector3.ZERO)
	return a

## Yürüme ve koşma aynı kalıp: kollar ve bacaklar zıt fazda salınır,
## gövde adım başına bir kez alçalıp yükselir ve öne yatar.
func _adim(sure: float, bacak: float, kol: float, zipzip: float, egim: float) -> Animation:
	var a := Animation.new()
	a.length = sure
	a.loop_mode = Animation.LOOP_LINEAR
	_cevrim(a, _iz(a, SOL_BACAK), sure, func(f: float) -> Vector3:
		return Vector3(sin(f) * bacak, 0.0, 0.0))
	_cevrim(a, _iz(a, SAG_BACAK), sure, func(f: float) -> Vector3:
		return Vector3(sin(f + PI) * bacak, 0.0, 0.0))
	_cevrim(a, _iz(a, SOL_KOL), sure, func(f: float) -> Vector3:
		return Vector3(sin(f + PI) * kol, 0.0, 0.09))
	_cevrim(a, _iz(a, SAG_KOL), sure, func(f: float) -> Vector3:
		return Vector3(sin(f) * kol, 0.0, -0.09))
	# Gövde adım frekansının iki katında zıplar: her ayak basışında bir kez.
	_cevrim(a, _iz(a, GOVDE_KONUM), sure, func(f: float) -> Vector3:
		return Vector3(0.0, absf(sin(f)) * zipzip - zipzip * 0.5, 0.0))
	_cevrim(a, _iz(a, GOVDE_DONUS), sure, func(_f: float) -> Vector3:
		return Vector3(egim, 0.0, 0.0))
	return a

func _zipla() -> Animation:
	var a := Animation.new()
	a.length = 0.45
	var bacak := _iz(a, SOL_BACAK)
	a.track_insert_key(bacak, 0.0, Vector3(0.0, 0.0, 0.0))
	a.track_insert_key(bacak, 0.18, Vector3(-0.9, 0.0, 0.0))
	a.track_insert_key(bacak, 0.45, Vector3(-0.5, 0.0, 0.0))
	var bacak2 := _iz(a, SAG_BACAK)
	a.track_insert_key(bacak2, 0.0, Vector3(0.0, 0.0, 0.0))
	a.track_insert_key(bacak2, 0.18, Vector3(0.5, 0.0, 0.0))
	a.track_insert_key(bacak2, 0.45, Vector3(0.25, 0.0, 0.0))
	for yol in [SOL_KOL, SAG_KOL]:
		var kol := _iz(a, yol)
		var yan := 0.09 if yol == SOL_KOL else -0.09
		a.track_insert_key(kol, 0.0, Vector3(0.0, 0.0, yan))
		a.track_insert_key(kol, 0.2, Vector3(-1.9, 0.0, yan * 3.0))
		a.track_insert_key(kol, 0.45, Vector3(-1.4, 0.0, yan * 3.0))
	var govde := _iz(a, GOVDE_DONUS)
	a.track_insert_key(govde, 0.0, Vector3(0.0, 0.0, 0.0))
	a.track_insert_key(govde, 0.45, Vector3(-0.12, 0.0, 0.0))
	var konum := _iz(a, GOVDE_KONUM)
	a.track_insert_key(konum, 0.0, Vector3.ZERO)
	a.track_insert_key(konum, 0.45, Vector3.ZERO)
	return a

func _dusme() -> Animation:
	var a := Animation.new()
	a.length = 0.9
	a.loop_mode = Animation.LOOP_LINEAR
	_cevrim(a, _iz(a, SOL_BACAK), a.length, func(f: float) -> Vector3:
		return Vector3(-0.35 + sin(f) * 0.12, 0.0, 0.0))
	_cevrim(a, _iz(a, SAG_BACAK), a.length, func(f: float) -> Vector3:
		return Vector3(0.3 + sin(f + PI) * 0.12, 0.0, 0.0))
	_cevrim(a, _iz(a, SOL_KOL), a.length, func(f: float) -> Vector3:
		return Vector3(-2.2, 0.0, 0.3 + sin(f) * 0.1))
	_cevrim(a, _iz(a, SAG_KOL), a.length, func(f: float) -> Vector3:
		return Vector3(-2.2, 0.0, -0.3 - sin(f) * 0.1))
	_cevrim(a, _iz(a, GOVDE_DONUS), a.length, func(_f: float) -> Vector3:
		return Vector3(0.18, 0.0, 0.0))
	_cevrim(a, _iz(a, GOVDE_KONUM), a.length, func(_f: float) -> Vector3: return Vector3.ZERO)
	return a

## Durum makinesi: yerde tek bir blend space (bosta -> yürüme -> koşma),
## havada zıplama ve düşme. Geçişleri kod travel() ile sürüyor.
func _agac() -> AnimationNodeStateMachine:
	var yer := AnimationNodeBlendSpace1D.new()
	yer.min_space = 0.0
	yer.max_space = 1.0
	yer.add_blend_point(_oynat("bosta"), 0.0, -1, "bosta")
	yer.add_blend_point(_oynat("yurume"), 0.45, -1, "yurume")
	yer.add_blend_point(_oynat("kosma"), 1.0, -1, "kosma")

	var sm := AnimationNodeStateMachine.new()
	sm.add_node("yer", yer, Vector2(340, 120))
	sm.add_node("zipla", _oynat("zipla"), Vector2(560, 40))
	sm.add_node("dusme", _oynat("dusme"), Vector2(560, 200))
	sm.add_transition("Start", "yer", _gecis(0.0))
	sm.add_transition("yer", "zipla", _gecis(0.08))
	sm.add_transition("yer", "dusme", _gecis(0.16))
	sm.add_transition("zipla", "dusme", _gecis(0.18))
	sm.add_transition("zipla", "yer", _gecis(0.12))
	sm.add_transition("dusme", "yer", _gecis(0.1))
	return sm

func _oynat(ad: String) -> AnimationNodeAnimation:
	var d := AnimationNodeAnimation.new()
	d.animation = ad
	return d

func _gecis(sure: float) -> AnimationNodeStateMachineTransition:
	var g := AnimationNodeStateMachineTransition.new()
	g.switch_mode = AnimationNodeStateMachineTransition.SWITCH_MODE_IMMEDIATE
	g.xfade_time = sure
	return g
