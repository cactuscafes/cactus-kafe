extends Node
## Düşman yapay zekâsı, hasar ve navigasyon testleri.
##
##   godot --headless --path oyun3d res://testler/dusman_testi.tscn
##
## Yapay zekâ elle test edilmesi en pahalı şey: durumu görmek için oyunu açıp
## düşmanın yanına gitmek, beklemek, arkasından dolaşmak gerekiyor. Burada
## oyuncu ışınlanıp durum makinesinin ne yaptığı okunuyor.

var _hatalar: Array[String] = []
var _bolum: Node3D
var _oyuncu: CharacterBody3D
var _dusman: CharacterBody3D

func _ready() -> void:
	await get_tree().process_frame
	_calis()

func _dogrula(kosul: bool, mesaj: String) -> void:
	if not kosul:
		_hatalar.append(mesaj)

func _bekle(kare: int) -> void:
	for i in kare:
		await get_tree().physics_frame

func _calis() -> void:
	_bolum = (load("res://sahneler/bolum1.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(_bolum)
	await _bekle(30)
	_oyuncu = _bolum.get_node("Oyuncu")
	_dusman = _bolum.get_node("Dusmanlar/Dusman3")

	_navigasyon_testi()
	await _ezme_testi()
	await _devriye_testi()
	await _farketme_testi()
	await _saldiri_testi()
	await _dokunulmazlik_testi()
	await _olum_testi()

	if _hatalar.is_empty():
		print("DUSMAN TESTI: GECTI")
		get_tree().quit(0)
	else:
		for h: String in _hatalar:
			printerr("  ! " + h)
		print("DUSMAN TESTI: KALDI (%d)" % _hatalar.size())
		get_tree().quit(1)

## Bayat navigasyon örgüsünün en sık belirtisi: düşman kovalayamıyor çünkü
## iki nokta arasında yol yok. Örgüyü yeniden pişirmeyi unutmak buradan
## anlaşılıyor.
func _navigasyon_testi() -> void:
	var bolge: NavigationRegion3D = _bolum.get_node("Navigasyon")
	var harita := bolge.get_navigation_map()
	var bas := NavigationServer3D.map_get_closest_point(harita, Vector3(-4, 0.2, -18))
	var son := NavigationServer3D.map_get_closest_point(harita, Vector3(6, 0.2, -16))
	var yol := NavigationServer3D.map_get_path(harita, bas, son, true)
	print("navigasyon: %d nokta, %.1f m yol" % [yol.size(), _uzunluk(yol)])
	_dogrula(yol.size() >= 2, "Kum alanında iki nokta arasında yol bulunamadı")
	_dogrula(bas.distance_to(Vector3(-4, 0.2, -18)) < 2.0,
		"Devriye noktası örgünün dışında (%.1f m uzakta)" % bas.distance_to(Vector3(-4, 0.2, -18)))

func _uzunluk(yol: PackedVector3Array) -> float:
	var t := 0.0
	for i in range(1, yol.size()):
		t += yol[i].distance_to(yol[i - 1])
	return t

## Ezme: düşmanın üstüne düşünce hasar verip sıçramalı; yandan çarpınca
## ezme sayılmamalı. İkisini ayırmak "yandan değdim ama ezdim sayıldı"
## hatasını yakalıyor.
func _ezme_testi() -> void:
	var kurban: CharacterBody3D = _bolum.get_node("Dusmanlar/Dusman1")
	var can_once: int = kurban.can

	# Yandan çarp: ezme olmamalı.
	_oyuncu.global_position = kurban.global_position + Vector3(1.0, 0.0, 0.0)
	_oyuncu.velocity = Vector3(-4.0, 0.0, 0.0)
	await _bekle(10)
	_dogrula(kurban.can == can_once,
		"Yandan çarpma ezme sayıldı (can %d -> %d)" % [can_once, kurban.can])

	# Üstüne düş: ezme olmalı ve sıçramalı.
	_oyuncu.global_position = kurban.global_position + Vector3(0.0, 2.6, 0.0)
	_oyuncu.velocity = Vector3(0.0, -6.0, 0.0)
	var kare := 0
	while kurban.can == can_once and kare < 120:
		await get_tree().physics_frame
		kare += 1
	print("ezme: %d karede can %d -> %d, sıçrama hızı %.2f" % [
		kare, can_once, kurban.can, _oyuncu.velocity.y])
	_dogrula(kurban.can == can_once - 1, "Üstüne düşmek düşmana hasar vermedi")
	_dogrula(_oyuncu.velocity.y > 1.0, "Ezmeden sonra sıçrama olmadı (%.2f)" % _oyuncu.velocity.y)

	# Kalan canı bitir: yenilmeli ve sahneden kalkmalı.
	while is_instance_valid(kurban) and kurban.can > 0 and kare < 400:
		_oyuncu.global_position = kurban.global_position + Vector3(0.0, 2.6, 0.0)
		_oyuncu.velocity = Vector3(0.0, -6.0, 0.0)
		await _bekle(12)
		kare += 12
	await _bekle(50)
	print("yenilme: düşman sahnede mi? %s" % is_instance_valid(kurban))
	_dogrula(not is_instance_valid(kurban), "Canı biten düşman sahneden kalkmadı")

func _devriye_testi() -> void:
	# Oyuncuyu uzağa al ki düşman devriyede kalsın.
	_oyuncu.global_position = Vector3(0, 1.0, 40)
	await _bekle(20)
	_dusman.durum = _dusman.Durum.DEVRIYE
	# YER DEĞİŞTİRME değil KAT EDİLEN YOL ölçülüyor: devriye ileri geri gidiyor,
	# tur ortasında başladığı yere dönebiliyor ve "hiç kımıldamadı" gibi
	# görünüyor. Ölçtüğün şey, ölçmek istediğin şey olmayabilir.
	var onceki := _dusman.global_position
	var yol := 0.0
	for i in 120:
		await get_tree().physics_frame
		yol += onceki.distance_to(_dusman.global_position)
		onceki = _dusman.global_position
	print("devriye: %.2f m yol aldı, durum=%d" % [yol, _dusman.durum])
	_dogrula(yol > 2.0, "Düşman devriyede hareket etmiyor (%.2f m)" % yol)
	_dogrula(_dusman.durum == _dusman.Durum.DEVRIYE,
		"Oyuncu 40 m uzaktayken düşman devriyeden çıktı")

func _farketme_testi() -> void:
	# Görüş mesafesinin dışında ama yakın: hâlâ fark etmemeli.
	_oyuncu.global_position = _dusman.global_position + Vector3(0, 0.9, -20)
	await _bekle(15)
	_dogrula(_dusman.durum == _dusman.Durum.DEVRIYE,
		"20 m uzaktaki oyuncu fark edildi (görüş mesafesi %.0f m)" % _dusman.gorus_mesafesi)

	# Düşmanın tam önüne koy: fark etmeli.
	var model: Node3D = _dusman.get_node("Model")
	var onu := -model.global_transform.basis.z
	_oyuncu.global_position = _dusman.global_position + onu * 6.0 + Vector3(0, 0.9, 0)
	await _bekle(30)
	print("farketme: durum=%d (2=KOVALA bekleniyor)" % _dusman.durum)
	_dogrula(_dusman.durum != _dusman.Durum.DEVRIYE,
		"Düşman 6 m önündeki oyuncuyu fark etmedi")

func _saldiri_testi() -> void:
	var can_once: int = _oyuncu.can
	_oyuncu.global_position = _dusman.global_position + Vector3(1.2, 0.9, 0)
	# Hazırlık + vuruş için yeterli süre.
	await _bekle(90)
	print("saldırı: can %d -> %d, durum=%d" % [can_once, _oyuncu.can, _dusman.durum])
	_dogrula(_oyuncu.can < can_once, "Düşman menzilde saldırmadı ya da hasar vermedi")
	_dogrula(_oyuncu.can == can_once - _dusman.hasar,
		"Tek saldırıda %d can gitti, %d olmalıydı" % [can_once - _oyuncu.can, _dusman.hasar])

func _dokunulmazlik_testi() -> void:
	# Düşmandan uzaklaş. Yanı başında beklersen düşmanın bir sonraki vuruşu
	# dokunulmazlığı tazeler ve test "süre dolmadı" sanır — testin kendisi
	# yanılır, kod değil.
	_oyuncu.global_position = Vector3(0.0, 1.0, 40.0)
	_oyuncu.dokunulmazligi_bitir()
	await _bekle(10)

	_dogrula(_oyuncu.hasar_al(1, Vector3.FORWARD), "Kontrollü hasar uygulanamadı")
	_dogrula(not _oyuncu.hasar_al(1, Vector3.FORWARD),
		"Dokunulmazlık sırasında ikinci hasar alındı")

	# Kare sayısıyla değil, durumla bekle: vuruş duraklaması (hit-stop) fizik
	# karelerini gerçek zamanda seyrelttiği için "75 kare" burada 30 saniye
	# sürebiliyor.
	var kare := 0
	while _oyuncu.dokunulmaz_mi() and kare < 400:
		await get_tree().physics_frame
		kare += 1
	var alindi: bool = _oyuncu.hasar_al(1, Vector3.FORWARD)
	print("dokunulmazlık: %d karede bitti, sonrasında hasar %s" % [
		kare, "alındı" if alindi else "ALINMADI"])
	_dogrula(kare < 400, "Dokunulmazlık hiç bitmedi")
	_dogrula(alindi, "Dokunulmazlık bittiği hâlde hasar alınmadı")

func _olum_testi() -> void:
	var dogum := Vector3(2.0, 1.5, 12.0)
	_oyuncu.dogum_noktasi_ayarla(dogum)
	# Canı tam olarak bitirecek kadar vur. `while can > 0` yazmak sonsuz
	# döngü: ölüm canı yeniden dolduruyor.
	var vurus: int = _oyuncu.can
	for i in vurus:
		_oyuncu.dokunulmazligi_bitir()
		_oyuncu.hasar_al(1, Vector3.FORWARD)
		await _bekle(2)
	await _bekle(10)
	print("ölüm: can %d/%d, doğuma uzaklık %.2f m" % [
		_oyuncu.can, _oyuncu.can_max, _oyuncu.global_position.distance_to(dogum)])
	_dogrula(_oyuncu.can == _oyuncu.can_max, "Ölümden sonra can dolmadı")
	_dogrula(_oyuncu.global_position.distance_to(dogum) < 2.0,
		"Ölümden sonra doğum noktasına dönülmedi")
	# Doğar doğmaz kısa dokunulmazlık: üstünde duran düşman anında vurmasın.
	_dogrula(_oyuncu.dokunulmaz_mi(), "Doğumda kısa dokunulmazlık verilmedi")
