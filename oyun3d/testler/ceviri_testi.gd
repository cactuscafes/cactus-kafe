extends Node
## Çeviri testi: kullanılan her anahtarın iki dilde de karşılığı var mı?
##
##   godot --headless --path oyun3d res://testler/ceviri_testi.tscn
##
## Lokalizasyonda hata "çökme" olarak gelmiyor: eksik anahtar ekranda ham
## hâliyle (AYAR_GERI gibi) görünüyor ve çoğu zaman kimse fark etmiyor.
## Bu yüzden anahtarlar koddan ve sahnelerden TARANIP tabloyla karşılaştırılıyor.

const CSV := "res://arayuz/ceviriler.csv"
const DILLER := ["tr", "en"]

var _hatalar: Array[String] = []

func _ready() -> void:
	await get_tree().process_frame
	var anahtarlar := _csv_anahtarlari()
	_dogrula(anahtarlar.size() > 20, "Çeviri tablosu şüpheli derecede küçük (%d)" % anahtarlar.size())

	# 1) Her anahtarın her dilde karşılığı var ve boş değil.
	var onceki := TranslationServer.get_locale()
	for dil: String in DILLER:
		TranslationServer.set_locale(dil)
		var eksik := 0
		for anahtar: String in anahtarlar:
			var karsilik := TranslationServer.translate(anahtar)
			if karsilik == anahtar or karsilik.strip_edges().is_empty():
				eksik += 1
				if eksik <= 3:
					_hatalar.append("%s dilinde karşılığı yok: %s" % [dil, anahtar])
		print("%s: %d anahtar, %d eksik" % [dil, anahtarlar.size(), eksik])

	# 2) Kodda ve sahnelerde kullanılan anahtarlar tabloda var mı?
	var kullanilan := _kullanilan_anahtarlar()
	for anahtar: String in kullanilan:
		if not anahtarlar.has(anahtar):
			_hatalar.append("Kullanılıyor ama tabloda yok: %s" % anahtar)
	print("kodda/sahnede kullanılan anahtar: %d" % kullanilan.size())

	# 3) Dil değişince metin gerçekten değişiyor mu?
	TranslationServer.set_locale("tr")
	var turkce := TranslationServer.translate("DURAKLAT_DEVAM")
	TranslationServer.set_locale("en")
	var ingilizce := TranslationServer.translate("DURAKLAT_DEVAM")
	_dogrula(turkce != ingilizce,
		"Dil değişince metin değişmiyor (%s / %s)" % [turkce, ingilizce])
	print("örnek: tr='%s' en='%s'" % [turkce, ingilizce])
	TranslationServer.set_locale(onceki)

	if _hatalar.is_empty():
		print("CEVIRI TESTI: GECTI")
		get_tree().quit(0)
	else:
		for h: String in _hatalar:
			printerr("  ! " + h)
		print("CEVIRI TESTI: KALDI (%d)" % _hatalar.size())
		get_tree().quit(1)

func _dogrula(kosul: bool, mesaj: String) -> void:
	if not kosul:
		_hatalar.append(mesaj)

func _csv_anahtarlari() -> PackedStringArray:
	var dosya := FileAccess.open(CSV, FileAccess.READ)
	var anahtarlar := PackedStringArray()
	dosya.get_csv_line()   # başlık
	while not dosya.eof_reached():
		var satir := dosya.get_csv_line()
		if satir.size() >= 3 and not satir[0].strip_edges().is_empty():
			anahtarlar.append(satir[0])
	return anahtarlar

## .gd dosyalarında tr("X"), .tscn dosyalarında text = "X" biçimindeki
## BÜYÜK_HARFLI anahtarları toplar.
func _kullanilan_anahtarlar() -> PackedStringArray:
	var bulunan := PackedStringArray()
	var kod := RegEx.create_from_string('tr\\("([A-Z][A-Z0-9_]+)"\\)')
	var sahne := RegEx.create_from_string('text = "([A-Z][A-Z0-9_]+)"')
	for klasor in ["res://betikler", "res://sahneler"]:
		_tara(klasor, kod, sahne, bulunan)
	return bulunan

func _tara(klasor: String, kod: RegEx, sahne: RegEx, bulunan: PackedStringArray) -> void:
	for ad in DirAccess.get_directories_at(klasor):
		_tara("%s/%s" % [klasor, ad], kod, sahne, bulunan)
	for ad in DirAccess.get_files_at(klasor):
		var uzanti := ad.get_extension()
		if uzanti != "gd" and uzanti != "tscn":
			continue
		var metin := FileAccess.get_file_as_string("%s/%s" % [klasor, ad])
		for eslesme in (kod if uzanti == "gd" else sahne).search_all(metin):
			var anahtar := eslesme.get_string(1)
			if not bulunan.has(anahtar):
				bulunan.append(anahtar)
