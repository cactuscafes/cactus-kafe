extends Node
## Karakter testi (Faz 11-12): model, iskelet, skinning, animasyon ve adım.
##
##   godot --headless --path oyun3d res://testler/karakter_testi.tscn
##
## Rig'li bir karakterde sessizce bozulabilecek şeyler kutu karakterdekinden
## fazla ve hepsi "oyun açılıyor, hata yok" diye geçiyor:
##
##  - doku bağlanmamış (karakter bembeyaz) — bir kez oldu: Blender'da
##    `img.filepath = "//atlas.png"` yazılınca dışa aktarıcı dokuyu sessizce
##    atlıyor;
##  - iskelet geldi ama mesh ona BAĞLI değil (skin yok) — karakter T-pozunda
##    donuyor;
##  - AnimationTree yanlış AnimationPlayer'a bakıyor — animasyon çalışıyor
##    görünüyor ama kemikler kıpırdamıyor;
##  - kemik adları değişmiş — durum makinesi animasyonu bulamıyor;
##  - adım temposu oyunun hızıyla uyumsuz (Faz 12) — karakter yürümüyor,
##    buz üstünde kayıyor gibi görünüyor.
##
## Bu yüzden test yalnızca "dosya var mı" demiyor, karakteri OYNATIP kemiğin
## kıpırdadığını ölçüyor.

const MODEL := "res://varliklar/oyuncu.gltf"
const OLCUM := "res://varliklar/oyuncu_olcum.json"
const KEMIKLER := ["Kalca", "Govde", "Kafa", "KolSol", "KolSag",
	"BacakSol", "BacakSag", "DizSol", "DizSag", "AyakSol", "AyakSag"]
## Kayma bütçesi: ayak bir çevrimde yerde en fazla bu kadar katı kayabilir.
## Hedef 2,0 (araclar/karakter.py::KAYMA_HEDEFI); pay yuvarlamalar için.
const KAYMA_BUTCESI := 2.2

var _hatalar: Array[String] = []

func _ready() -> void:
	await get_tree().process_frame
	var dosya := FileAccess.open(OLCUM, FileAccess.READ)
	if dosya == null:
		printerr("  ! %s yok — önce araclar/karakter.py çalıştırılmalı" % OLCUM)
		get_tree().quit(1)
		return
	var olcum: Dictionary = JSON.parse_string(dosya.get_as_text())

	_modeli_dogrula(olcum)
	_adimi_dogrula(olcum)
	await _oyuncuyu_dogrula(olcum)

	if _hatalar.is_empty():
		print("KARAKTER TESTI: GECTI")
		get_tree().quit(0)
	else:
		for h in _hatalar:
			printerr("  ! " + h)
		print("KARAKTER TESTI: KALDI (%d)" % _hatalar.size())
		get_tree().quit(1)

func _dogrula(kosul: bool, mesaj: String) -> void:
	if not kosul:
		_hatalar.append(mesaj)

# ------------------------------------------------------------------- model

func _modeli_dogrula(olcum: Dictionary) -> void:
	var sahne: PackedScene = load(MODEL)
	_dogrula(sahne != null, "Karakter modeli yüklenemedi")
	if sahne == null:
		return
	var kok: Node3D = sahne.instantiate()
	var iskelet := _bul(kok, "Skeleton3D") as Skeleton3D
	var mesh := _bul(kok, "MeshInstance3D") as MeshInstance3D
	var oynatici := _bul(kok, "AnimationPlayer") as AnimationPlayer

	_dogrula(iskelet != null, "İskelet (Skeleton3D) yok")
	if iskelet != null:
		_dogrula(iskelet.get_bone_count() == int(olcum["kemik"]),
			"Kemik sayısı %d, %d olmalı" % [iskelet.get_bone_count(), olcum["kemik"]])
		var adlar: Array[String] = []
		for i in iskelet.get_bone_count():
			adlar.append(iskelet.get_bone_name(i))
		for beklenen: String in KEMIKLER:
			_dogrula(adlar.has(beklenen), "'%s' kemiği yok (gelen: %s)" % [
				beklenen, ", ".join(adlar)])

	_dogrula(mesh != null, "Mesh yok")
	if mesh != null:
		# Skin: mesh'in kemiklere bağlı olduğunun kanıtı. Yoksa model
		# iskeletle birlikte kıpırdamaz, T-pozunda donar.
		_dogrula(mesh.skin != null, "Mesh iskelete bağlı değil (skin yok)")
		var mat := mesh.mesh.surface_get_material(0) as BaseMaterial3D
		_dogrula(mat != null and mat.albedo_texture != null,
			"Karakterin dokusu yok — oyunda bembeyaz görünür")
		var aabb := mesh.mesh.get_aabb()
		var boy: float = aabb.size.y
		_dogrula(absf(boy - float(olcum["boy_m"])) < 0.05,
			"Boy %.2f m, ölçümde %.2f m" % [boy, olcum["boy_m"]])
		# Ayak tabanı orijinde: sahnede y = zemin yazınca karakter zemine oturur.
		_dogrula(absf(aabb.position.y) < 0.02,
			"Ayak tabanı orijinde değil (%.3f)" % aabb.position.y)
		var ucgen := mesh.mesh.get_faces().size() / 3
		_dogrula(ucgen == int(olcum["ucgen"]),
			"Üçgen sayısı %d, ölçümde %d" % [ucgen, olcum["ucgen"]])

	_dogrula(oynatici != null, "AnimationPlayer yok")
	if oynatici != null:
		var beklenen: Dictionary = olcum["animasyon"]
		for ad: String in beklenen:
			if not oynatici.has_animation(ad):
				_hatalar.append("'%s' animasyonu yok (gelen: %s)" % [
					ad, ", ".join(oynatici.get_animation_list())])
				continue
			var sure := oynatici.get_animation(ad).length
			_dogrula(absf(sure - float(beklenen[ad])) < 0.08,
				"'%s' süresi %.2f sn, ölçümde %.2f sn" % [ad, sure, beklenen[ad]])
		print("model: %d kemik, %d animasyon, %.2f m" % [
			iskelet.get_bone_count() if iskelet else -1,
			oynatici.get_animation_list().size(), float(olcum["boy_m"])])
	kok.free()

# --------------------------------------------------------- adım / kayma

## Ayak yerde ne kadar kayıyor? Gövde bir çevrimde `hiz * sure` metre gidiyor,
## bacaklar `adim` metre atabiliyor; oran ikisinin bölümü. Bu bir tercih
## meselesi ama SESSİZCE bozulabilen bir tercih: animasyonun süresi elle
## değiştirilirse ya da hareket hızı artırılırsa kayma büyür ve kimse fark
## etmez. Bütçe onu görünür kılıyor.
func _adimi_dogrula(olcum: Dictionary) -> void:
	if not olcum.has("adim_m") or not olcum.has("hiz"):
		_hatalar.append("Ölçümde adım verisi yok — araclar/karakter.py eski")
		return
	var adimlar: Dictionary = olcum["adim_m"]
	var hizlar: Dictionary = olcum["hiz"]
	var sureler: Dictionary = olcum["animasyon"]
	for ad: String in adimlar:
		var adim := float(adimlar[ad])
		_dogrula(adim > 0.2, "'%s' adım boyu ölçülememiş (%.3f m)" % [ad, adim])
		if adim <= 0.2:
			continue
		var kayma: float = float(hizlar[ad]) * float(sureler[ad]) / adim
		print("%s: adım %.2f m, çevrim %.2f sn, kayma %.2fx" % [
			ad, adim, sureler[ad], kayma])
		_dogrula(kayma <= KAYMA_BUTCESI,
			"'%s' ayağı yerde %.2f kat kayıyor (bütçe %.2f)" % [
				ad, kayma, KAYMA_BUTCESI])

# ------------------------------------------------------- oyuncu sahnesinde

## Asıl soru: AnimationTree gerçekten İSKELETİ oynatıyor mu? Ağaç yanlış
## AnimationPlayer'a bakıyorsa oyun çalışır, animasyon "geçer" ama kemikler
## kıpırdamaz — ekranda buz gibi bir karakter kayar.
func _oyuncuyu_dogrula(olcum: Dictionary) -> void:
	var oyuncu: CharacterBody3D = (load("res://sahneler/oyuncu.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(oyuncu)
	await get_tree().process_frame

	var model := oyuncu.get_node_or_null("Yon/Model")
	_dogrula(model != null, "Oyuncu sahnesinde Yon/Model yok")
	if model == null:
		oyuncu.queue_free()
		return
	# Kapsül 1,70 m ve merkezi orijinde: modelin tabanı -0,85'te olmalı.
	_dogrula(absf((model as Node3D).position.y + 0.85) < 0.02,
		"Model kapsülün tabanına oturmuyor (y=%.2f)" % (model as Node3D).position.y)

	# Animasyonun temposu bu hızlara göre hesaplandı (araclar/karakter.py).
	# İkisi ayrı dosyada duruyor; biri değişip diğeri unutulursa kayma bütçesi
	# sessizce geçersiz olur.
	var hizlar: Dictionary = olcum.get("hiz", {})
	for ad: String in hizlar:
		var alan := "%s_hizi" % ad
		var oyundaki: float = oyuncu.get(alan)
		_dogrula(absf(oyundaki - float(hizlar[ad])) < 0.01,
			"oyuncu.%s = %.2f ama ölçümde %.2f — adım kalibrasyonu eskimiş" % [
				alan, oyundaki, hizlar[ad]])

	var agac: AnimationTree = oyuncu.get_node("AnimationTree")
	_dogrula(agac.active, "AnimationTree kapalı")
	# anim_player yolu AĞACA göre çözülür, oyuncuya göre değil.
	var oynatici := agac.get_node_or_null(agac.anim_player)
	_dogrula(oynatici != null,
		"AnimationTree'nin baktığı AnimationPlayer yok: %s" % agac.anim_player)

	var iskelet := _bul(model, "Skeleton3D") as Skeleton3D
	_dogrula(iskelet != null, "Oyuncuda iskelet yok")
	# Ayak IK'sı koddan ekleniyor (bkz. oyuncu.gd::_ayak_ik_kur); gerçekten
	# eklendiğini burada, davranışını `ayak_ik_testi` doğruluyor.
	_dogrula(iskelet != null and iskelet.get_node_or_null("AyakIK") != null,
		"Ayak IK modifiye edicisi iskelete eklenmemiş")
	if iskelet == null or oynatici == null:
		oyuncu.queue_free()
		return

	# Oyuncunun KENDİ durum sürücüsü kapatılıyor: boş sahnede karakter sonsuza
	# kadar düşüyor ve `_animasyon()` her karede "dusme"ye geçiyor; testin
	# elle seçtiği durumu eziyordu. Ölçmek istediğimiz şey animasyon
	# sisteminin iskeleti sürüp sürmediği, oyuncunun durum mantığı değil.
	oyuncu.set_physics_process(false)
	var durum: AnimationNodeStateMachinePlayback = agac.get("parameters/playback")
	agac.set("parameters/yer/blend_position", 1.0)
	durum.travel("yer")
	var bacak := iskelet.find_bone("BacakSol")
	_dogrula(bacak >= 0, "BacakSol kemiği bulunamadı")
	# Dönüş büyüklüğü kuaterniyondan ölçülüyor, Euler'den değil: kemiğin yerel
	# ekseni dünya eksenine paralel olmadığı için salınım Euler'in tek
	# bileşeninde görünmüyor ve "kıpırdamıyor" gibi okunuyordu.
	var en_kucuk := 1e9
	var en_buyuk := -1e9
	for i in 90:
		await get_tree().process_frame
		var q := iskelet.get_bone_pose_rotation(bacak)
		var aci := 2.0 * acos(clampf(absf(q.w), -1.0, 1.0))
		en_kucuk = minf(en_kucuk, aci)
		en_buyuk = maxf(en_buyuk, aci)
	var genlik := en_buyuk - en_kucuk
	print("koşma: BacakSol salınımı %.2f rad" % genlik)
	_dogrula(genlik > 0.6,
		"Koşarken bacak kıpırdamıyor (%.3f rad) — ağaç iskeleti sürmüyor" % genlik)

	# Zıplama durumu da gerçekten farklı bir poz vermeli.
	durum.travel("zipla")
	for i in 40:
		await get_tree().process_frame
	_dogrula(durum.get_current_node() == "zipla",
		"Zıplama durumuna geçilmedi (%s)" % durum.get_current_node())

	oyuncu.queue_free()
	await get_tree().process_frame

func _bul(kok: Node, sinif: String) -> Node:
	var yigin: Array[Node] = [kok]
	while not yigin.is_empty():
		var d: Node = yigin.pop_back()
		if d.is_class(sinif):
			return d
		for c in d.get_children():
			yigin.append(c)
	return null
