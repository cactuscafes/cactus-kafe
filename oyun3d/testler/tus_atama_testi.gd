extends Node
## Tuş atama testi.
##
##   godot --headless --path oyun3d res://testler/tus_atama_testi.tscn
##
## Tuş ataması, elle denemesi en sıkıcı özelliklerden biri: her seferinde
## menüyü aç, tıkla, tuşa bas, oyuna dön, dene. Buradaki asıl soru "düğme
## çalışıyor mu" değil, ŞU ÜÇÜ:
##
##  1. Atama gerçekten INPUTMAP'e işliyor mu (yoksa ekranda yazı değişip
##     oyunda hiçbir şey olmaz);
##  2. Oyuncu kendini oyundan kilitleyebiliyor mu (çakışan atama, kaybolan
##     oyun kolu bağlaması, geri dönüşü olmayan hata);
##  3. Ayar diske yazılıyor ve geri okunuyor mu.

var _hatalar: Array[String] = []

func _ready() -> void:
	await get_tree().process_frame
	var onceki: Dictionary = Ayarlar.tuslar.duplicate()

	_varsayilan_testi()
	_atama_testi()
	_cakisma_testi()
	_kilitlenme_testi()
	_kayit_testi()
	await _ekran_testi()

	# Test ortamı temiz bırakılıyor: bu makinede oyun da oynanabilir.
	Girdi.tuslari_uygula(onceki)
	Ayarlar.tuslar = onceki
	Ayarlar.kaydet()

	if _hatalar.is_empty():
		print("TUS ATAMA TESTI: GECTI")
		get_tree().quit(0)
	else:
		for h in _hatalar:
			printerr("  ! " + h)
		print("TUS ATAMA TESTI: KALDI (%d)" % _hatalar.size())
		get_tree().quit(1)

func _dogrula(kosul: bool, mesaj: String) -> void:
	if not kosul:
		_hatalar.append(mesaj)

func _tus_olayi(kod: Key, basili := true) -> InputEventKey:
	var tus := InputEventKey.new()
	tus.physical_keycode = kod
	tus.pressed = basili
	return tus

func _varsayilan_testi() -> void:
	Girdi.varsayilana_don()
	_dogrula(Girdi.tus_kodu("ziplama") == KEY_SPACE,
		"Varsayılan zıplama tuşu Space değil: %s" % Girdi.tus_adi("ziplama"))
	_dogrula(InputMap.event_is_action(_tus_olayi(KEY_SPACE), "ziplama"),
		"Space InputMap'te 'ziplama' değil")
	_dogrula(Girdi.ATANABILIR.size() >= 8,
		"Atanabilir eylem sayısı az: %d" % Girdi.ATANABILIR.size())

func _atama_testi() -> void:
	var engel := Girdi.tus_ata("ziplama", KEY_J)
	_dogrula(engel.is_empty(), "Boştaki tuş reddedildi: %s" % engel)
	# Asıl ölçüm: ekrandaki yazı değil, InputMap.
	_dogrula(InputMap.event_is_action(_tus_olayi(KEY_J), "ziplama"),
		"Yeni tuş (J) InputMap'e işlemedi")
	_dogrula(not InputMap.event_is_action(_tus_olayi(KEY_SPACE), "ziplama"),
		"Eski tuş (Space) hâlâ zıplatıyor")
	_dogrula(Girdi.tus_adi("ziplama") == "J",
		"Ekranda gösterilecek ad yanlış: %s" % Girdi.tus_adi("ziplama"))
	print("atama: ziplama -> %s" % Girdi.tus_adi("ziplama"))

func _cakisma_testi() -> void:
	var engel := Girdi.tus_ata("kosma", KEY_J)
	_dogrula(engel == "ziplama", "Çakışma bildirilmedi (dönen: '%s')" % engel)
	# Çakışma reddedildiyse İKİ eylem de bozulmamış olmalı.
	_dogrula(InputMap.event_is_action(_tus_olayi(KEY_J), "ziplama"),
		"Reddedilen atama zıplamayı bozdu")
	_dogrula(InputMap.event_is_action(_tus_olayi(KEY_SHIFT), "kosma"),
		"Reddedilen atama koşmayı bozdu")

## Oyuncu kendini oyundan kilitleyebilmemeli.
func _kilitlenme_testi() -> void:
	# 1) İkincil tuşlar duruyor: ileri'yi I'ya alsan da ok tuşu çalışıyor.
	Girdi.tus_ata("ileri", KEY_I)
	_dogrula(InputMap.event_is_action(_tus_olayi(KEY_UP), "ileri"),
		"Atama sonrası ok tuşu kayboldu — geri dönüşü olmayan durum")
	# 2) Oyun kolu bağlamaları duruyor.
	var kol_var := false
	for olay: InputEvent in InputMap.action_get_events("ziplama"):
		if olay is InputEventJoypadButton:
			kol_var = true
	_dogrula(kol_var, "Tuş ataması oyun kolu bağlamasını sildi")
	# 3) Duraklatma tuşu atanabilir olsa bile menüye ulaşmak mümkün kalmalı.
	Girdi.tus_ata("duraklat", KEY_P)
	_dogrula(InputMap.event_is_action(_tus_olayi(KEY_P), "duraklat"),
		"Duraklatma tuşu atanamadı")

func _kayit_testi() -> void:
	Ayarlar.kaydet()
	var c := ConfigFile.new()
	_dogrula(c.load(Ayarlar.AYAR_YOLU) == OK, "Ayar dosyası okunamadı")
	var diskten: Dictionary = c.get_value("kontrol", "tuslar", {})
	_dogrula(int(diskten.get("ziplama", 0)) == KEY_J,
		"Atama diske yazılmadı: %s" % diskten)

	# Oyunu yeniden başlatmış gibi: ayarları uygula, atamalar geri gelmeli.
	Girdi.tuslari_uygula({})
	_dogrula(Girdi.tus_kodu("ziplama") == KEY_SPACE, "Sıfırlama çalışmadı")
	Ayarlar.tuslar = diskten
	Ayarlar.uygula()
	_dogrula(Girdi.tus_kodu("ziplama") == KEY_J,
		"Kaydedilen atama yeniden yüklenmedi")
	print("kayıt: %d özel atama diske yazıldı ve geri okundu" % diskten.size())

## Ekranın kendisi: tıkla, tuşa bas, yazı değişsin.
func _ekran_testi() -> void:
	var ekran: Control = (load("res://sahneler/tus_atama.tscn") as PackedScene).instantiate()
	add_child(ekran)
	await get_tree().process_frame

	var satirlar: Array[Button] = []
	for dugum: Node in ekran.get_node("%Liste").get_children():
		var buton := dugum as Button
		if buton != null:
			satirlar.append(buton)
	_dogrula(satirlar.size() == Girdi.ATANABILIR.size(),
		"Ekranda %d düğme var, %d olmalı" % [satirlar.size(), Girdi.ATANABILIR.size()])

	var ziplama_butonu: Button = null
	for i in mini(satirlar.size(), Girdi.ATANABILIR.size()):
		if Girdi.ATANABILIR[i] == "ziplama":
			ziplama_butonu = satirlar[i]
	_dogrula(ziplama_butonu != null, "Zıplama satırı bulunamadı")
	if ziplama_butonu == null:
		ekran.queue_free()
		return

	# 1) Tıkla -> "tuşa bas" durumuna geçmeli.
	ziplama_butonu.pressed.emit()
	await get_tree().process_frame
	_dogrula(ziplama_butonu.text == tr("TUS_BEKLENIYOR"),
		"Tıklayınca bekleme yazısı çıkmadı: '%s'" % ziplama_butonu.text)

	# 2) Yeni tuşa bas.
	get_viewport().push_input(_tus_olayi(KEY_K))
	await get_tree().process_frame
	_dogrula(Girdi.tus_kodu("ziplama") == KEY_K, "Ekrandan atama işlemedi")
	_dogrula(ziplama_butonu.text == "K", "Düğme yazısı güncellenmedi: '%s'" % ziplama_butonu.text)

	# 3) Esc vazgeçmeli, eski tuş kalmalı.
	ziplama_butonu.pressed.emit()
	await get_tree().process_frame
	get_viewport().push_input(_tus_olayi(KEY_ESCAPE))
	await get_tree().process_frame
	_dogrula(Girdi.tus_kodu("ziplama") == KEY_K, "Esc atamayı geri almadı")
	_dogrula(ziplama_butonu.text == "K", "Esc'ten sonra düğme bekleme yazısında kaldı")

	# 4) Çakışan tuş: uyarı çıkmalı, atama değişmemeli.
	var uyari: Label = ekran.get_node("%Uyari")
	ziplama_butonu.pressed.emit()
	await get_tree().process_frame
	get_viewport().push_input(_tus_olayi(KEY_SHIFT))   # koşma tuşu
	await get_tree().process_frame
	_dogrula(Girdi.tus_kodu("ziplama") == KEY_K, "Çakışan tuş atandı")
	_dogrula(not uyari.text.strip_edges().is_empty(), "Çakışmada uyarı gösterilmedi")
	print("ekran: %d satır, çakışma uyarısı: %s" % [satirlar.size(), uyari.text])

	# 5) Varsayılana dön.
	ekran.get_node("%Varsayilan").pressed.emit()
	await get_tree().process_frame
	_dogrula(Girdi.tus_kodu("ziplama") == KEY_SPACE, "Varsayılana dönülmedi")
	_dogrula(ziplama_butonu.text == "Space", "Varsayılan sonrası yazı: '%s'" % ziplama_butonu.text)

	ekran.queue_free()
	await get_tree().process_frame
