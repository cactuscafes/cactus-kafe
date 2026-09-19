extends Node
## Bölümleri bota oynatır ve denge sayılarını çıkarır.
##
##   godot --headless --path oyun3d res://araclar/denge_olc.tscn
##   godot --headless --path oyun3d res://araclar/denge_olc.tscn -- bolum3
##   godot --headless --path oyun3d res://araclar/denge_olc.tscn -- --par
##
## Çıktı: her bölüm için bitirme süresi, ölüm, zıplama sayısı ve zorlanılan
## geçişler; ayrıca `user://denge.json`. Bunlar DENGE bilgisidir, başarı ölçütü
## değil: botun 40 saniyede bitirdiği bölümü insan 2 dakikada bitirir, ama
## botun 9 kez öldüğü yer insanın da öldüğü yerdir.
##
## `--par` ile botun turu `res://hayaletler/` altına yazılıyor: oyunla birlikte
## gelen "par turu". İlk kez oynayan birinin de yarışacak biri oluyor — kendi
## hayaletin ancak bölümü bir kez bitirdikten sonra oluşuyor.

const BOT := preload("res://betikler/bot/otomatik_oyuncu.gd")
const RAPOR_YOLU := "user://denge.json"
const BUTCE_YOLU := "res://denge_butce.json"

var _ayrintili := false
var _par_yaz := false

func _ready() -> void:
	await get_tree().process_frame
	var istenen := ""
	var ayrintili := false
	for arg in OS.get_cmdline_user_args():
		if arg == "-v":
			ayrintili = true
		elif arg == "--par":
			_par_yaz = true
		else:
			istenen = arg
	_ayrintili = ayrintili
	var rapor := {}
	for bilgi: Dictionary in Bolumler.LISTE:
		if not istenen.is_empty() and bilgi["kimlik"] != istenen:
			continue
		rapor[bilgi["kimlik"]] = await _oyna(bilgi)
	_yaz(rapor)
	var hatalar := _butceyi_dogrula(rapor)
	if hatalar.is_empty():
		print("DENGE: BUTCE ICINDE")
	else:
		for h in hatalar:
			printerr("  ! " + h)
		printerr("DENGE: BUTCE ASILDI (%d)" % hatalar.size())
	get_tree().quit(0 if hatalar.is_empty() else 1)

## Bütçe, botun ne kadar iyi oynadığını değil bölümün DEĞİŞİP değişmediğini
## ölçüyor: aynı bot dün 40 saniyede bitirdiği bölümü bugün 90 saniyede
## bitiriyorsa bölüm zorlaşmış demektir. Sayılar insan süresi değil.
func _butceyi_dogrula(rapor: Dictionary) -> Array[String]:
	var hatalar: Array[String] = []
	var butce := {}
	var dosya := FileAccess.open(BUTCE_YOLU, FileAccess.READ)
	if dosya != null:
		var cozum: Variant = JSON.parse_string(dosya.get_as_text())
		if cozum is Dictionary:
			butce = cozum
	for kimlik: String in rapor:
		var sonuc: Dictionary = rapor[kimlik]
		var sinir: Dictionary = butce.get(kimlik, {})
		# Başarı ölçütü "hepsini topladı" değil, BİTİŞE ULAŞTI: bot mükemmel
		# oyuncu değil, sürtünme ölçer. Alamadığı çiçek rapora "zor" diye
		# yazılıyor ve asgari oran ayrıca kontrol ediliyor.
		#
		# Botun bugün bitişe ulaşamadığı bölümlerde `bitis_bekleniyor: false`
		# yazılı — orada ölçüt "daha kötüye gitmesin"e dönüşüyor. Bölümün
		# BİTİRİLEBİLİR olduğu ayrıca `bolum_hatti_testi` ile kanıtlanıyor;
		# bot onu doğrulamıyor, sürtünmeyi ölçüyor.
		if not bool(sonuc["bitise_ulasti"]):
			if bool(sinir.get("bitis_bekleniyor", true)):
				hatalar.append("%s BİTİŞE ULAŞILAMADI: %s" % [kimlik, sonuc["takildi"]])
				continue
		if sinir.has("azami_sure") and float(sonuc["sure"]) > float(sinir["azami_sure"]):
			hatalar.append("%s: %.1f sn (bütçe %.0f) — bölüm zorlaşmış olabilir"
				% [kimlik, sonuc["sure"], sinir["azami_sure"]])
		if sinir.has("azami_olum") and int(sonuc["olum"]) > int(sinir["azami_olum"]):
			hatalar.append("%s: %d ölüm (bütçe %d)"
				% [kimlik, sonuc["olum"], sinir["azami_olum"]])
		var oran := float(sonuc["toplanan"]) / maxf(float(sonuc["hedef"]), 1.0)
		if sinir.has("asgari_cicek") and oran < float(sinir["asgari_cicek"]):
			hatalar.append("%s: çiçeklerin %%%d'i toplandı (asgari %%%d) — zor: %s"
				% [kimlik, int(oran * 100.0), int(float(sinir["asgari_cicek"]) * 100.0),
					", ".join(PackedStringArray(sonuc["zor_cicek"]))])
	return hatalar

func _oyna(bilgi: Dictionary) -> Dictionary:
	var kimlik: String = bilgi["kimlik"]
	if _par_yaz:
		# Kaydedici turu yalnızca ESKİSİNDEN HIZLIYSA yazıyor; par üretirken
		# eski kaydı siliyoruz ki bu tur mutlaka kaydedilsin.
		DirAccess.remove_absolute(
			ProjectSettings.globalize_path(HayaletKayit.yol(kimlik)))
	var kok: Node3D = (load(bilgi["sahne"]) as PackedScene).instantiate()
	get_tree().root.add_child(kok)
	await get_tree().physics_frame
	await get_tree().physics_frame

	var bot: Node = BOT.new()
	bot.name = "Bot"
	get_tree().root.add_child(bot)
	bot.ayrintili = _ayrintili
	bot.kur(kok)
	var sonuc: Dictionary = await bot.bitti
	bot.queue_free()

	if _par_yaz and bool(sonuc["bitise_ulasti"]):
		_par_kaydet(kimlik, kok)
	kok.queue_free()
	await get_tree().process_frame

	var durum := "TAKILDI"
	if bool(sonuc["bitti"]):
		durum = "bitirdi"
	elif bool(sonuc["bitise_ulasti"]):
		durum = "bitişte"
	print("%-8s %-8s %6.1f sn  %2d ölüm  %3d zıplama  çiçek %d/%d  %s" % [
		bilgi["kimlik"], durum, sonuc["sure"], sonuc["olum"], sonuc["ziplama"],
		sonuc["toplanan"], sonuc["hedef"],
		sonuc["takildi"] if not sonuc["takildi"].is_empty() else _zorlananlar(sonuc)])
	var zor: Array = sonuc["zor_cicek"]
	if not zor.is_empty():
		print("         zor çiçekler: %s" % ", ".join(PackedStringArray(zor)))
	return sonuc

## Botun turunu oyunla birlikte gelen par turu olarak kaydeder.
##
## Bölümü %100 bitiren tur beklenmiyor: bot bitişe ULAŞTIYSA kaydedicinin o ana
## kadarki kaydı alınıyor. Par turu bir rekor değil, yarışacak bir yol —
## "buradan şöyle gidiliyor". Kaydedicinin kendi kaydı ancak bölüm bitince
## diske yazıldığı için düğümden doğrudan okunuyor.
func _par_kaydet(kimlik: String, kok: Node3D) -> void:
	var kayit := HayaletKayit.yukle(kimlik)
	var kaydedici := kok.get_node_or_null("HayaletKaydedici")
	if kaydedici != null:
		var canli: Variant = kaydedici.get("_kayit")
		if canli is HayaletKayit and (canli as HayaletKayit).ornek_sayisi() > 20:
			kayit = canli
	if kayit == null:
		printerr("  ! %s: par turu üretilemedi (kayıt yok)" % kimlik)
		return
	if kayit.sure <= 0.0:
		var oyun := kok.get_node_or_null("Oyun")
		kayit.sure = float(oyun.sure) if oyun != null else 0.0
	kayit.par = true
	kayit.oyuncu_adi = "bot"
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path("res://hayaletler"))
	var hata := ResourceSaver.save(kayit, HayaletKayit.par_yolu(kimlik))
	if hata != OK:
		printerr("  ! %s: par turu kaydedilemedi (%d)" % [kimlik, hata])
	else:
		print("  par turu -> %s (%.1f sn)" % [HayaletKayit.par_yolu(kimlik), kayit.sure])

func _zorlananlar(sonuc: Dictionary) -> String:
	var zorlanan: Array = sonuc["zorlanan"]
	if zorlanan.is_empty():
		return "temiz"
	var parcalar: Array[String] = []
	for kayit in zorlanan:
		parcalar.append("%s×%d" % [kayit["durak"], int(kayit["deneme"]) + 1])
	return "zorlandı: " + ", ".join(parcalar)

func _yaz(rapor: Dictionary) -> void:
	var dosya := FileAccess.open(RAPOR_YOLU, FileAccess.WRITE)
	if dosya != null:
		dosya.store_string(JSON.stringify(rapor, "  "))
		print("rapor -> %s" % ProjectSettings.globalize_path(RAPOR_YOLU))
