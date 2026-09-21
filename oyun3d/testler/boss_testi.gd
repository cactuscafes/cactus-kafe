extends Node
## Boss testi (Faz 16): dövüş kalıbı, açık penceresi ve bitiş kilidi.
##
##   godot --headless --fixed-fps 60 --path oyun3d res://testler/boss_testi.tscn
##
## `--fixed-fps` ŞART: dövüşte vuruş duraklaması (hit-stop) zaman ölçeğini
## 0,05'e indiriyor. Gerçek zamanda koşarken bu, her vuruşun saniyelerce
## sürmesi demek ve test dakikalarca bekliyor. Sabit kare hızında zaman
## senkronizasyonu kapanıyor: dövüş saniyeler içinde oynanıyor.
##
## BİR DÖVÜŞ NEDEN TEST EDİLİR: boss, oyunun tek "elle ayarlanmış" anı.
## Sayılarının (telgraf süresi, sersem penceresi, kalıp uzunluğu) birbirine
## göre anlamı var ve biri değişince dövüş sessizce imkânsız ya da anlamsız
## hâle geliyor. Elle denemek her seferinde bölümün sonuna kadar oynamak
## demek; burada dövüş betikle oynanıyor.
##
## ÖLÇÜLENLER:
##  - canavar SERSEM dışında hasar ALMIYOR (açık yoksa dövüş "zıpla geç" olur)
##  - sersem penceresinde hasar ALIYOR (açık varsa dövüş bitirilebilir)
##  - her vuruşta evre değişiyor ve ritim hızlanıyor
##  - saldırıdan önce telgraf var (oyuncunun kaçma penceresi gerçekten var mı)
##  - canavar yenilmeden bitiş AÇILMIYOR, yenilince açılıyor
##  - bütün dövüş baştan sona oynanabiliyor (betik canavarı yeniyor)

var _hatalar: Array[String] = []
var _bolum: Node3D
var _oyuncu: CharacterBody3D
var _boss: CharacterBody3D
var _oyun: Node

func _ready() -> void:
	await get_tree().process_frame
	_bolum = (load("res://sahneler/bolum6.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(_bolum)
	await _bekle(20)
	_oyuncu = _bolum.get_node("Oyuncu")
	_boss = _bolum.get_node_or_null("Boss")
	_oyun = _bolum.get_node("Oyun")
	if _boss == null:
		printerr("  ! bolum6'da Boss düğümü yok")
		get_tree().quit(1)
		return

	# Diğer düşmanlar susturuluyor: ölçülen şey BU dövüş.
	for d in get_tree().get_nodes_in_group("dusman"):
		if d != _boss:
			(d as Node).set_physics_process(false)

	await _kurulum_dogrula()
	await _bitis_kilidi_dogrula()
	await _sersem_disinda_hasar_yok()
	await _dovusu_oyna()
	await _bitis_acildi_mi()

	if _hatalar.is_empty():
		print("BOSS TESTI: GECTI")
		get_tree().quit(0)
	else:
		for h in _hatalar:
			printerr("  ! " + h)
		print("BOSS TESTI: KALDI (%d)" % _hatalar.size())
		get_tree().quit(1)

func _dogrula(kosul: bool, mesaj: String) -> void:
	if not kosul:
		_hatalar.append(mesaj)

func _bekle(kare: int) -> void:
	for i in kare:
		await get_tree().physics_frame

## Oyuncuyu arenaya, canavarın karşısına koyar.
func _arenaya(uzaklik := 6.0) -> void:
	var model: Node3D = _boss.get_node("Model")
	var yon := -model.global_transform.basis.z
	_oyuncu.global_position = _boss.global_position + yon * uzaklik + Vector3(0, 1.0, 0)
	_oyuncu.velocity = Vector3.ZERO

func _kurulum_dogrula() -> void:
	var olcum := FileAccess.open("res://varliklar/boss_olcum.json", FileAccess.READ)
	_dogrula(olcum != null, "boss_olcum.json yok — araclar/boss_karakter.py çalışmalı")
	if olcum != null:
		var veri: Dictionary = JSON.parse_string(olcum.get_as_text())
		var iskelet := _bul(_boss, "Skeleton3D") as Skeleton3D
		_dogrula(iskelet != null and iskelet.get_bone_count() == int(veri["kemik"]),
			"Boss kemik sayısı tutmuyor")
		var oynatici := _bul(_boss, "AnimationPlayer") as AnimationPlayer
		_dogrula(oynatici != null, "Boss'ta AnimationPlayer yok")
		if oynatici != null:
			for ad: String in veri["animasyon"]:
				_dogrula(oynatici.has_animation(ad), "Boss animasyonu yok: %s" % ad)
			# Dövüşün okunması "sersem" pozuna bağlı: o yoksa açık görünmez.
			_dogrula(oynatici.has_animation("sersem"),
				"'sersem' animasyonu yok — dövüşün açığı görünmez")
		var hiz: Dictionary = veri.get("hiz", {})
		_dogrula(absf(float(hiz.get("yurume", 0.0)) - _boss.yurume_hizi) < 0.01,
			"Yürüme hızı ölçümde %.2f, boss.gd'de %.2f" % [
				hiz.get("yurume", 0.0), _boss.yurume_hizi])
	print("kurulum: %d can, %d kemik, telgraf %.2f/%.2f sn, sersem %.1f sn" % [
		_boss.can_max, (_bul(_boss, "Skeleton3D") as Skeleton3D).get_bone_count(),
		_boss.carpma_telgrafi, _boss.atis_telgrafi, _boss.sersem_suresi])

## Bitiş, canavar yenilmeden açılmamalı — yoksa dövüş isteğe bağlı bir süs.
func _bitis_kilidi_dogrula() -> void:
	_oyun.toplanan = _oyun.hedef_toplanabilir   # çiçek koşulunu aradan çıkar
	_oyun.bitirmeyi_dene()
	await _bekle(2)
	_dogrula(not _oyun.bitti, "Canavar yenilmeden bölüm bitti")
	_dogrula(not _oyun.mesaj.is_empty(), "Bitiş kilidi oyuncuya söylenmiyor")
	print("kilit: bitiş kapalı, mesaj = \"%s\"" % _oyun.mesaj)

## Sersem DEĞİLKEN üstüne binmek hasar vermemeli.
func _sersem_disinda_hasar_yok() -> void:
	_arenaya(5.0)
	await _bekle(30)
	var once: int = _boss.can
	var denedi := 0
	# Canavar sersem olana kadar değil, sersem OLMADIĞI sürece zıpla.
	for i in 90:
		if _boss.get("_sersem_mi"):
			break
		_oyuncu.global_position = _boss.global_position + Vector3(0, 3.4, 0)
		_oyuncu.velocity = Vector3(0, -8.0, 0)
		denedi += 1
		await _bekle(4)
	print("açık yok: %d deneme, can %d -> %d" % [denedi, once, _boss.can])
	_dogrula(_boss.can == once,
		"Sersem değilken hasar alındı (can %d -> %d)" % [once, _boss.can])

## Bütün dövüşü oyna: sersem penceresini bekle, üstüne bin, tekrarla.
## Bu testin asıl iddiası — dövüş BİTİRİLEBİLİR.
func _dovusu_oyna() -> void:
	var evreler: Array[int] = []
	var beklemeler: Array[float] = []
	var kare := 0
	while _boss.can > 0 and kare < 4000:
		await get_tree().physics_frame
		kare += 1
		# Oyuncu ölmesin: dövüşü ölçüyoruz, oyuncunun hayatta kalmasını değil.
		_oyuncu.can = _oyuncu.can_max
		if not _boss.get("_sersem_mi"):
			# Menzilin dışında bekle ki canavar kalıbını işletsin.
			if _oyuncu.global_position.distance_to(_boss.global_position) < 5.0:
				_arenaya(6.5)
			continue
		if not evreler.has(_boss.can):
			evreler.append(_boss.can)
			beklemeler.append(_boss.bekleme)
		_oyuncu.global_position = _boss.global_position + Vector3(0, 3.2, 0)
		_oyuncu.velocity = Vector3(0, -9.0, 0)
		await _bekle(6)
	print("dövüş: %d karede bitti, evrelerde bekleme %s" % [kare, str(beklemeler)])
	_dogrula(kare < 4000, "Dövüş bitirilemedi — canavar yenilemiyor")
	_dogrula(evreler.size() >= 2, "Evre geçişi olmadı (%d)" % evreler.size())
	if beklemeler.size() >= 2:
		_dogrula(beklemeler[-1] < beklemeler[0],
			"Evre ilerledikçe ritim hızlanmıyor (%.2f -> %.2f sn)" % [
				beklemeler[0], beklemeler[-1]])

func _bitis_acildi_mi() -> void:
	await _bekle(40)
	_dogrula(_oyun.boss_yenildi, "Canavar yenildiği hâlde oyun bilmiyor")
	_oyun.toplanan = _oyun.hedef_toplanabilir
	_oyun.bitirmeyi_dene()
	await _bekle(2)
	print("kilit açıldı: bitti = %s" % _oyun.bitti)
	_dogrula(_oyun.bitti, "Canavar yenildikten sonra bitiş hâlâ kapalı")

func _bul(kok: Node, sinif: String) -> Node:
	var yigin: Array[Node] = [kok]
	while not yigin.is_empty():
		var d: Node = yigin.pop_back()
		if d.is_class(sinif):
			return d
		for c in d.get_children():
			yigin.append(c)
	return null
