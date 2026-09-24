extends Node
## Görsel test (Faz 13): aydınlatma ve manzara yerinde mi?
##
##   xvfb-run -a godot --path oyun3d --rendering-driver opengl3 \
##     --audio-driver Dummy res://testler/gorsel_testi.tscn
##
## İKİ AYRI SORU SORUYOR:
##
## 1) YAPI — bölümde ortam düğümü var mı, sis açık mı, güneş gölge üretiyor
##    mu, manzara ÇARPIŞMASIZ mı? Sonuncusu en önemlisi: manzara süslemesi
##    çarpışma kazanırsa bölümün ulaşılabilirlik grafı (`bolum_grafi.gd`)
##    onu basılabilir bir yüzey sanır; bölüm doğrulayıcısı ve bot sessizce
##    yanlış cevap verir. Görsel bir katman oynanışı bozamaz.
##
## 2) ÖLÇÜM — bölüm gerçekten ÇİZİLDİĞİNDE kare ne kadar aydınlık ve ne kadar
##    karşıtlık taşıyor? Aydınlatma sessizce bozulabiliyor: ortam kaynağı
##    yanlış, gölge mesafesi sıfır, ton eşlemesi kapanmış — oyun açılıyor,
##    hata yok, sahne düpedüz gri. Bütçe `gorsel_butce.json` içinde ve
##    bantları geniş: amaç piksel eşitliği değil, "bu bölüm karardı /
##    patladı / düzleşti" demek.
##
## PENCERE ŞART: başsız kipte kare boyutu (0,0) ve okunan görüntü boş çıkıyor.
## CI'da dokunmatik ve performans adımları gibi Xvfb altında koşuyor.

const BUTCE := "res://gorsel_butce.json"
const BOLUMLER := ["bolum1", "bolum2", "bolum3", "bolum4", "bolum5", "bolum6",
	"bolum7", "bolum8"]
## Ölçümden önce beklenen kare: ışık, gölge atlası ve gökyüzü ışıması oturuyor.
const BEKLE := 45

var _hatalar: Array[String] = []
var _olculen := {}

func _ready() -> void:
	await get_tree().process_frame
	var butce := _butce_oku()
	for ad: String in BOLUMLER:
		await _bolumu_dogrula(ad, butce.get(ad, {}))

	# Ölçümler her koşuda yazdırılıyor: bütçeyi güncellemek gerektiğinde
	# sayıyı aramaya gerek kalmasın.
	for ad: String in _olculen:
		var o: Dictionary = _olculen[ad]
		print("%-8s parlaklık %.3f  karşıtlık %.3f" % [ad, o["parlaklik"], o["karsitlik"]])

	if _hatalar.is_empty():
		print("GORSEL TESTI: GECTI")
		get_tree().quit(0)
	else:
		for h in _hatalar:
			printerr("  ! " + h)
		print("GORSEL TESTI: KALDI (%d)" % _hatalar.size())
		get_tree().quit(1)

func _dogrula(kosul: bool, mesaj: String) -> void:
	if not kosul:
		_hatalar.append(mesaj)

func _butce_oku() -> Dictionary:
	var dosya := FileAccess.open(BUTCE, FileAccess.READ)
	if dosya == null:
		_hatalar.append("%s yok" % BUTCE)
		return {}
	var veri: Variant = JSON.parse_string(dosya.get_as_text())
	return veri if veri is Dictionary else {}

func _bolumu_dogrula(ad: String, butce: Dictionary) -> void:
	var sahne: PackedScene = load("res://sahneler/%s.tscn" % ad)
	if sahne == null:
		_hatalar.append("%s yüklenemedi" % ad)
		return
	var bolum: Node3D = sahne.instantiate()
	get_tree().root.add_child(bolum)
	await get_tree().process_frame

	_ortami_dogrula(ad, bolum)
	_manzarayi_dogrula(ad, bolum)

	# Oyuncu düşmesin: ölçülen kare her koşuda aynı olmalı.
	var oyuncu := bolum.get_node_or_null("Oyuncu") as CharacterBody3D
	if oyuncu != null:
		oyuncu.set_physics_process(false)
	for i in BEKLE:
		await get_tree().process_frame

	var goruntu := get_viewport().get_texture().get_image()
	var olcum := _parlaklik_olc(goruntu)
	_olculen[ad] = olcum
	if butce.is_empty():
		_hatalar.append("%s için görsel bütçe yok" % ad)
	else:
		var p: float = olcum["parlaklik"]
		var k: float = olcum["karsitlik"]
		_dogrula(absf(p - float(butce["parlaklik"])) <= float(butce.get("pay", 0.10)),
			"%s parlaklığı %.3f, bütçe %.3f (±%.2f) — aydınlatma değişmiş" % [
				ad, p, butce["parlaklik"], butce.get("pay", 0.10)])
		# Karşıtlık ALT sınır: sahnenin düz bir renge çökmediğinin ölçüsü.
		_dogrula(k >= float(butce.get("asgari_karsitlik", 0.06)),
			"%s karşıtlığı %.3f, en az %.3f olmalı — sahne düzleşmiş" % [
				ad, k, butce.get("asgari_karsitlik", 0.06)])

	bolum.queue_free()
	await get_tree().process_frame

func _ortami_dogrula(ad: String, bolum: Node3D) -> void:
	var ortam := bolum.get_node_or_null("Ortam")
	_dogrula(ortam != null, "%s: Ortam düğümü yok" % ad)
	if ortam == null:
		return
	var dunya := ortam.get_node_or_null("Dunya") as WorldEnvironment
	_dogrula(dunya != null and dunya.environment != null,
		"%s: WorldEnvironment kurulmamış" % ad)
	if dunya != null and dunya.environment != null:
		var e := dunya.environment
		_dogrula(e.sky != null, "%s: gökyüzü yok" % ad)
		_dogrula(e.fog_enabled, "%s: sis kapalı — uzaklık okunmaz" % ad)
		_dogrula(e.ambient_light_source == Environment.AMBIENT_SOURCE_SKY,
			"%s: ortam ışığı gökyüzünden gelmiyor, gölgeler siyaha düşer" % ad)
	var gunes := ortam.get_node_or_null("Gunes") as DirectionalLight3D
	_dogrula(gunes != null and gunes.shadow_enabled,
		"%s: güneş yok ya da gölge kapalı" % ad)
	_dogrula(ortam.get_node_or_null("Dolgu") != null, "%s: dolgu ışığı yok" % ad)

## Manzara görsel bir katman: tek bir çarpışma şekli bile taşımamalı.
func _manzarayi_dogrula(ad: String, bolum: Node3D) -> void:
	var manzara := bolum.get_node_or_null("Manzara")
	_dogrula(manzara != null, "%s: Manzara düğümü yok" % ad)
	if manzara == null:
		return
	var carpisma := manzara.find_children("*", "CollisionObject3D", true, false)
	_dogrula(carpisma.is_empty(),
		"%s: manzarada %d çarpışma gövdesi var — bölüm grafı yanılır" % [
			ad, carpisma.size()])
	var coklu := manzara.find_children("*", "MultiMeshInstance3D", true, false)
	_dogrula(not coklu.is_empty(), "%s: manzara boş kalmış" % ad)

## Karenin ortalama parlaklığı ve karşıtlığı (0-1). Her piksel değil, ızgara:
## 1280x720'yi tek tek gezmek testi gereksiz yere yavaşlatıyor, ızgara aynı
## cevabı veriyor.
func _parlaklik_olc(goruntu: Image) -> Dictionary:
	const ADIM := 4
	var toplam := 0.0
	var kare_toplam := 0.0
	var sayi := 0
	for y in range(0, goruntu.get_height(), ADIM):
		for x in range(0, goruntu.get_width(), ADIM):
			var c := goruntu.get_pixel(x, y)
			# Gözün gördüğü parlaklık: yeşil ağırlıklı (Rec. 709).
			var l := 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
			toplam += l
			kare_toplam += l * l
			sayi += 1
	if sayi == 0:
		return {"parlaklik": 0.0, "karsitlik": 0.0}
	var ort := toplam / float(sayi)
	# RMS karşıtlık: parlaklığın standart sapması.
	var varyans := maxf(kare_toplam / float(sayi) - ort * ort, 0.0)
	return {"parlaklik": ort, "karsitlik": sqrt(varyans)}
