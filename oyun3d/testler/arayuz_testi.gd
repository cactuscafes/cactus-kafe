extends Node
## Menü, ayar kalıcılığı, kayıt ve duraklatma testleri.
##
##   godot --headless --path oyun3d res://testler/arayuz_testi.tscn
##
## Bu fazın işleri "görünür ama denenmesi sıkıcı" türden: ayar kaydediliyor mu,
## rekor doğru mu güncelleniyor, Esc gerçekten duraklatıyor mu, bölüm bitince
## ekran çıkıyor mu. Elle her seferinde bölümü baştan oynamak yerine burada
## ölçülüyor.

var _hatalar: Array[String] = []

func _ready() -> void:
	# Ağaç kurulurken add_child yapılamaz ("parent is busy setting up
	# children"): bir kare bekleyip öyle başla.
	await get_tree().process_frame
	_calis()

func _dogrula(kosul: bool, mesaj: String) -> void:
	if not kosul:
		_hatalar.append(mesaj)

func _bekle(kare: int) -> void:
	for i in kare:
		await get_tree().process_frame

func _calis() -> void:
	_autoload_testi()
	_ses_testi()
	await _ayar_kaliciligi_testi()
	_kayit_testi()
	await _menu_testi()
	await _duraklatma_testi()
	await _bitis_testi()

	if _hatalar.is_empty():
		print("ARAYUZ TESTI: GECTI")
		get_tree().quit(0)
	else:
		for h: String in _hatalar:
			printerr("  ! " + h)
		print("ARAYUZ TESTI: KALDI (%d)" % _hatalar.size())
		get_tree().quit(1)

func _autoload_testi() -> void:
	for ad in ["Girdi", "Ses", "Ayarlar"]:
		_dogrula(get_tree().root.get_node_or_null(NodePath(ad)) != null,
			"%s autoload'u yüklenmemiş" % ad)

func _ses_testi() -> void:
	for bus in ["Master", "SFX", "Muzik"]:
		_dogrula(AudioServer.get_bus_index(bus) >= 0, "Ses bus'ı yok: %s" % bus)
	for ad: String in Ses.EFEKTLER:
		_dogrula(Ses.EFEKTLER[ad] != null, "Ses yüklenemedi: %s" % ad)
	var muzik: AudioStreamWAV = preload("res://ses/muzik.wav")
	print("ses: %d efekt, müzik %.1f sn" % [Ses.EFEKTLER.size(), muzik.get_length()])

func _ayar_kaliciligi_testi() -> void:
	var eski := Ayarlar.muzik
	Ayarlar.muzik = 0.33
	Ayarlar.hassasiyet = 0.004
	Ayarlar.kaydet()
	# Diskten taze oku: bellekteki değeri değil, dosyaya yazılanı sınıyoruz.
	var c := ConfigFile.new()
	var sonuc := c.load(Ayarlar.AYAR_YOLU)
	_dogrula(sonuc == OK, "Ayar dosyası yazılmamış (%s)" % Ayarlar.AYAR_YOLU)
	_dogrula(is_equal_approx(c.get_value("ses", "muzik", -1.0), 0.33),
		"Müzik seviyesi diske yazılmamış")
	_dogrula(is_equal_approx(c.get_value("kontrol", "hassasiyet", -1.0), 0.004),
		"Hassasiyet diske yazılmamış")

	# Uygulanan seviye gerçekten bus'a düşüyor mu?
	Ayarlar.muzik = 0.5
	Ayarlar.uygula()
	var db := AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Muzik"))
	_dogrula(absf(db - linear_to_db(0.5)) < 0.01,
		"Müzik bus seviyesi ayarla uyuşmuyor (%.2f dB)" % db)
	print("ayarlar: diske yazılıyor, bus %.1f dB" % db)
	Ayarlar.muzik = eski
	Ayarlar.kaydet()
	await _bekle(1)

func _kayit_testi() -> void:
	# Temiz başlangıç: kayıt dosyasını sil.
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Ayarlar.KAYIT_YOLU))
	Ayarlar.kayitlar = {}

	_dogrula(Ayarlar.sonuc_kaydet("bolum1", 90.0, 3), "İlk sonuç rekor sayılmadı")
	_dogrula(is_equal_approx(Ayarlar.en_iyi_sure("bolum1"), 90.0), "İlk rekor kaydedilmedi")
	_dogrula(not Ayarlar.sonuc_kaydet("bolum1", 120.0, 0), "Daha kötü süre rekor sayıldı")
	_dogrula(is_equal_approx(Ayarlar.en_iyi_sure("bolum1"), 90.0), "Kötü süre rekoru bozdu")
	_dogrula(Ayarlar.sonuc_kaydet("bolum1", 75.5, 1), "Daha iyi süre rekor sayılmadı")
	_dogrula(is_equal_approx(Ayarlar.en_iyi_sure("bolum1"), 75.5), "Yeni rekor kaydedilmedi")
	_dogrula(Ayarlar.oynanma("bolum1") == 3,
		"Oynanma sayacı %d, 3 olmalı" % Ayarlar.oynanma("bolum1"))

	# Bölümler birbirinin kaydını ezmemeli — tek sayı tutulsa fark edilmezdi.
	_dogrula(Ayarlar.sonuc_kaydet("bolum2", 200.0, 5), "İkinci bölümün ilk sonucu rekor sayılmadı")
	_dogrula(is_equal_approx(Ayarlar.en_iyi_sure("bolum1"), 75.5),
		"Bölüm 2'nin sonucu bölüm 1'in rekorunu bozdu")
	_dogrula(is_equal_approx(Ayarlar.en_iyi_sure("bolum2"), 200.0), "Bölüm 2 rekoru tutulmadı")

	var k := ConfigFile.new()
	_dogrula(k.load(Ayarlar.KAYIT_YOLU) == OK, "Kayıt dosyası yazılmamış")
	_dogrula(is_equal_approx(k.get_value("bolum1", "en_iyi_sure", -1.0), 75.5),
		"Rekor diske yazılmamış")
	_dogrula(is_equal_approx(k.get_value("bolum2", "en_iyi_sure", -1.0), 200.0),
		"Bölüm 2 rekoru diske yazılmamış")
	_dogrula(Ayarlar.sure_metni(75.5) == "1:15.50",
		"Süre biçimi yanlış: %s" % Ayarlar.sure_metni(75.5))
	print("kayıt: bölüm1 %s / bölüm2 %s, biçim %s" % [
		Ayarlar.sure_metni(Ayarlar.en_iyi_sure("bolum1")),
		Ayarlar.sure_metni(Ayarlar.en_iyi_sure("bolum2")),
		Ayarlar.sure_metni(75.5)])

func _menu_testi() -> void:
	var menu: Control = (load("res://sahneler/ana_menu.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(menu)
	await _bekle(3)
	for ad in ["BolumKutusu", "Ayarlar", "Krediler", "Rekor"]:
		_dogrula(menu.get_node_or_null("%%%s" % ad) != null, "Ana menüde %s yok" % ad)
	# Her bölüm için bir düğme ve her düğme için geçerli bir sahne.
	var kutu: VBoxContainer = menu.get_node("%BolumKutusu")
	_dogrula(kutu.get_child_count() == Bolumler.sayi(),
		"Menüde %d bölüm düğmesi var, %d olmalı" % [kutu.get_child_count(), Bolumler.sayi()])
	for bilgi: Dictionary in Bolumler.LISTE:
		_dogrula(ResourceLoader.exists(bilgi["sahne"]),
			"Bölüm sahnesi yok: %s" % bilgi["sahne"])
		_dogrula(ResourceLoader.exists("res://navigasyon/%s.tres" % bilgi["kimlik"]),
			"Bölümün navigasyon örgüsü yok: %s" % bilgi["kimlik"])
	# Ayarlar paneli açılıp kapanıyor mu?
	var panel: Control = menu.get_node("%AyarlarPaneli")
	_dogrula(not panel.visible, "Ayarlar paneli açılışta görünür olmamalı")
	(menu.get_node("%Ayarlar") as Button).pressed.emit()
	await _bekle(2)
	_dogrula(panel.visible, "Ayarlar butonu paneli açmadı")
	panel.kapandi.emit()
	await _bekle(2)
	_dogrula(not panel.visible, "Geri butonu paneli kapatmadı")
	print("menü: butonlar ve ayar paneli çalışıyor")
	menu.queue_free()
	await _bekle(2)

func _duraklatma_testi() -> void:
	var bolum: Node3D = (load("res://sahneler/bolum1.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(bolum)
	await _bekle(5)
	var duraklat: CanvasLayer = bolum.get_node("Duraklat")
	_dogrula(not duraklat.visible, "Duraklatma menüsü açılışta görünmemeli")

	duraklat.duraklat(true)
	await _bekle(2)
	_dogrula(get_tree().paused, "Duraklatma ağacı durdurmadı")
	_dogrula(duraklat.visible, "Duraklatma menüsü görünmedi")
	# Menü ağaç duraklatılmışken de işlemeli, yoksa bir daha açılamaz.
	_dogrula(duraklat.process_mode == Node.PROCESS_MODE_ALWAYS,
		"Duraklatma menüsü PROCESS_MODE_ALWAYS değil — kendisi de donar")

	duraklat.duraklat(false)
	await _bekle(2)
	_dogrula(not get_tree().paused, "Devam et ağacı çalıştırmadı")
	print("duraklatma: aç/kapa çalışıyor")
	bolum.queue_free()
	await _bekle(2)

func _bitis_testi() -> void:
	var bolum: Node3D = (load("res://sahneler/bolum1.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(bolum)
	await _bekle(5)
	var oyun := bolum.get_node("Oyun")
	var bitis: CanvasLayer = bolum.get_node("BitisEkrani")
	_dogrula(not bitis.visible, "Bitiş ekranı açılışta görünmemeli")

	# Çiçekler toplanmadan bitiş kabul edilmemeli.
	oyun.bitirmeyi_dene()
	await _bekle(2)
	_dogrula(not oyun.bitti, "Çiçekler toplanmadan bölüm bitti")
	_dogrula(not bitis.visible, "Eksik çiçekle bitiş ekranı açıldı")
	_dogrula(oyun.mesaj != "", "Eksik çiçek uyarısı verilmedi")

	oyun.toplanan = oyun.hedef_toplanabilir
	oyun.sure = 42.0
	oyun.bitirmeyi_dene()
	await _bekle(3)
	_dogrula(oyun.bitti, "Bölüm bitmedi")
	_dogrula(bitis.visible, "Bitiş ekranı açılmadı")
	_dogrula(get_tree().paused, "Bitişte ağaç duraklatılmadı")
	_dogrula(is_equal_approx(Ayarlar.en_iyi_sure("bolum1"), 42.0),
		"Bitişte rekor kaydedilmedi (%.1f)" % Ayarlar.en_iyi_sure("bolum1"))
	print("bitiş: ekran açıldı, rekor %s olarak kaydedildi" % Ayarlar.sure_metni(42.0))
	get_tree().paused = false
	bolum.queue_free()
	await _bekle(2)
