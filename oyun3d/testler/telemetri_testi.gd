extends Node
## Telemetri testi: gizlilik kuralları ve istemci–sunucu gövde sözleşmesi.
##
##   godot --headless --path oyun3d res://testler/telemetri_testi.tscn
##
## İki tür hata arıyoruz:
##
## 1. GİZLİLİK. "Varsayılan kapalı" bir yorum satırı değil, bir davranıştır;
##    ancak çalıştırarak doğrulanabilir. Rıza yokken kuyruğa tek olay bile
##    girmemeli — sonradan rıza verilince geçmişin gönderilmesi, rızanın
##    anlamını yok eder.
## 2. SÖZLEŞME. Sunucu gövdeyi katı doğruluyor; tek bir alan adı kayması tüm
##    partiyi sessizce çöpe atar ve bunu haftalar sonra "hiç veri gelmiyor"
##    diye fark edersin. Gövde burada basılıyor, `telemetri_testi.sh` onu
##    sunucunun kendi doğrulayıcısından geçiriyor.

var _hatalar: Array[String] = []

func _ready() -> void:
	await get_tree().process_frame

	# --- 1) Varsayılanlar -----------------------------------------------
	_dogrula(not Ayarlar.telemetri, "Telemetri varsayılan olarak AÇIK geliyor")
	_dogrula(Urun.TELEMETRI_URL.is_empty(), "Depoda telemetri adresi dolu")
	_dogrula(not Telemetri.etkin_mi(), "Varsayılan ayarlarla telemetri etkin")

	Telemetri.olay("olum", {"bolum": "bolum1"})
	_dogrula(Telemetri.kuyruk_boyu() == 0, "Rıza yokken olay kuyruğa girdi")

	# --- 2) İki koşul da gerekli ----------------------------------------
	# Rıza var, adres yok: hiçbir şey olmamalı. Bu, yayınlanmamış yapıda
	# telemetrinin kazara açılmasına karşı ikinci kilit.
	Ayarlar.telemetri = true
	_dogrula(not Telemetri.etkin_mi(), "Adres boşken telemetri etkin sayıldı")
	Telemetri.olay("olum", {"bolum": "bolum1"})
	_dogrula(Telemetri.kuyruk_boyu() == 0, "Adres boşken olay kuyruğa girdi")

	# --- 3) Açıkken: kuyruk ve gövde ------------------------------------
	Urun.TELEMETRI_URL = "http://127.0.0.1:9/olay"   # ulaşılamaz, bilerek
	_dogrula(Telemetri.etkin_mi(), "İki koşul da sağlanmışken telemetri kapalı")

	Telemetri.olay("bolum_basladi", {"bolum": "bolum1"})
	Telemetri.olay("olum", {"bolum": "bolum1", "sure": 12.3, "x": 4.5, "y": 1.0, "z": -8.0})
	Telemetri.olay("bolum_bitti", {"bolum": "bolum1", "sure": 61.2, "olum": 1, "yenilen": 2})
	_dogrula(Telemetri.kuyruk_boyu() == 3, "Kuyrukta 3 olay bekleniyordu, %d var" % Telemetri.kuyruk_boyu())

	var govde := Telemetri.govde_yap()
	var cozum: Variant = JSON.parse_string(govde)
	_dogrula(cozum is Dictionary, "Gövde geçerli JSON değil")
	if cozum is Dictionary:
		var s: Dictionary = cozum
		_dogrula(s.has("oturum") and not String(s["oturum"]).is_empty(), "Gövdede oturum yok")
		_dogrula(s.has("olaylar") and (s["olaylar"] as Array).size() == 3, "Gövdede 3 olay yok")
		var ilk: Dictionary = (s["olaylar"] as Array)[0]
		for alan: String in ["ad", "t", "surum", "demo", "bolum"]:
			_dogrula(ilk.has(alan), "Olayda '%s' alanı yok" % alan)
		# Kişisel veri sızıntısı: gövdede kullanıcı adı/ev dizini geçmemeli.
		var kullanici := OS.get_environment("USER")
		if not kullanici.is_empty():
			_dogrula(not govde.contains(kullanici), "Gövdede kullanıcı adı geçiyor")

	# --- 4) Kuyruk sınırı ------------------------------------------------
	# Ağ günlerce gitmezse bellek şişmemeli; en eskiler düşer.
	for i in 200:
		Telemetri.olay("olum", {"bolum": "bolum1", "x": float(i)})
	_dogrula(Telemetri.kuyruk_boyu() <= Telemetri.AZAMI_KUYRUK,
		"Kuyruk sınırı aşıldı: %d" % Telemetri.kuyruk_boyu())

	# --- 5) Gönderim kuyruğu boşaltıyor ---------------------------------
	# Adres ulaşılamaz; istek başarısız olacak. Önemli olan oyunun bundan
	# etkilenmemesi: kuyruk temizlenir, hata penceresi açılmaz, akış sürer.
	Telemetri.gonder()
	_dogrula(Telemetri.kuyruk_boyu() == 0, "Gönderimden sonra kuyruk boşalmadı")
	_dogrula(not Telemetri.son_govde.is_empty(), "Gönderilen gövde boş")

	# --- 6) Rıza geri alınınca --------------------------------------------
	Ayarlar.telemetri = false
	Telemetri.olay("olum", {"bolum": "bolum1"})
	_dogrula(Telemetri.kuyruk_boyu() == 0, "Rıza geri alınınca olay kuyruğa girdi")

	# --- 7) Oturum numarası diske yazılmıyor mu? -------------------------
	# İki oturumun birbirine bağlanamaması buna bağlı.
	Ayarlar.kaydet()
	var ayar_dosyasi := FileAccess.open(Ayarlar.AYAR_YOLU, FileAccess.READ)
	if ayar_dosyasi != null:
		var metin := ayar_dosyasi.get_as_text()
		_dogrula(not metin.contains("oturum"), "Oturum numarası ayarlara yazılmış")

	# Kabuk betiği bu satırı sunucunun doğrulayıcısına veriyor.
	print("GOVDE %s" % govde)

	Urun.TELEMETRI_URL = ""
	_bitir()

func _dogrula(kosul: bool, mesaj: String) -> void:
	if not kosul:
		_hatalar.append(mesaj)

func _bitir() -> void:
	if _hatalar.is_empty():
		print("TELEMETRI TESTI: GECTI")
		get_tree().quit(0)
	else:
		for h in _hatalar:
			print("  ! " + h)
		print("TELEMETRI TESTI: KALDI (%d)" % _hatalar.size())
		get_tree().quit(1)
