extends Node
## Düşman yapay zekâsı, hasar ve navigasyon testleri.
##
##   godot --headless --path oyun3d res://testler/dusman_testi.tscn
##
## Yapay zekâ elle test edilmesi en pahalı şey: durumu görmek için oyunu açıp
## düşmanın yanına gitmek, beklemek, arkasından dolaşmak gerekiyor. Burada
## oyuncu ışınlanıp durum makinesinin ne yaptığı okunuyor.
##
## FAZ 14: düşman rig'lendi ve iki alt tür geldi. Eklenen üç soru:
##  - model gerçekten iskeletli mi, animasyonları yerinde mi, hızları
##    animasyonun ölçüldüğü hızlarla aynı mı (ikisi ayrı dosyada duruyor);
##  - hoplayan gerçekten YERDEN KESİLİYOR mu ve indikten sonra savunmasız
##    bir penceresi var mı (adil olmasının şartı);
##  - atıcının dikeni DUVARDAN geçiyor mu (siper gerçekten siper mi).

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

	_rig_dogrula()
	_navigasyon_testi()
	await _ezme_testi()
	await _devriye_testi()
	await _farketme_testi()
	await _saldiri_testi()
	await _dokunulmazlik_testi()
	await _olum_testi()
	await _hoplayan_testi()
	await _atici_testi()
	await _diken_duvar_testi()

	if _hatalar.is_empty():
		print("DUSMAN TESTI: GECTI")
		get_tree().quit(0)
	else:
		for h: String in _hatalar:
			printerr("  ! " + h)
		print("DUSMAN TESTI: KALDI (%d)" % _hatalar.size())
		get_tree().quit(1)

# ------------------------------------------------------------- rig (Faz 14)

const OLCUM := "res://varliklar/dusman_olcum.json"
## Ayak kayması bütçesi (araclar/dusman_karakter.py::KAYMA_HEDEFI = 2,5).
const KAYMA_BUTCESI := 2.8

func _rig_dogrula() -> void:
	var dosya := FileAccess.open(OLCUM, FileAccess.READ)
	if dosya == null:
		_hatalar.append("%s yok — araclar/dusman_karakter.py çalıştırılmalı" % OLCUM)
		return
	var olcum: Dictionary = JSON.parse_string(dosya.get_as_text())
	var model := _dusman.get_node_or_null("Model/Gorsel")
	var iskelet := _bul(model, "Skeleton3D") as Skeleton3D
	_dogrula(iskelet != null, "Düşmanda iskelet (Skeleton3D) yok")
	if iskelet != null:
		_dogrula(iskelet.get_bone_count() == int(olcum["kemik"]),
			"Düşman kemik sayısı %d, ölçümde %d" % [
				iskelet.get_bone_count(), olcum["kemik"]])
	var mesh := _bul(model, "MeshInstance3D") as MeshInstance3D
	_dogrula(mesh != null and mesh.skin != null,
		"Düşman mesh'i iskelete bağlı değil (skin yok) — poz donar")
	if mesh != null:
		var mat := mesh.mesh.surface_get_material(0) as BaseMaterial3D
		_dogrula(mat != null and mat.albedo_texture != null,
			"Düşmanın dokusu yok — oyunda bembeyaz görünür")

	var oynatici := _bul(model, "AnimationPlayer") as AnimationPlayer
	_dogrula(oynatici != null, "Düşmanda AnimationPlayer yok")
	if oynatici != null:
		var beklenen: Dictionary = olcum["animasyon"]
		for ad: String in beklenen:
			if not oynatici.has_animation(ad):
				_hatalar.append("Düşman animasyonu yok: %s (gelen: %s)" % [
					ad, ", ".join(oynatici.get_animation_list())])
				continue
			var sure := oynatici.get_animation(ad).length
			_dogrula(absf(sure - float(beklenen[ad])) < 0.08,
				"'%s' süresi %.2f sn, ölçümde %.2f sn" % [ad, sure, beklenen[ad]])
		# Durum makinesindeki her durumun animasyonu gerçekten var mı?
		for durum: int in _dusman.ANIMASYON:
			var ad: String = _dusman.ANIMASYON[durum]
			_dogrula(oynatici.has_animation(ad),
				"Durum %d için '%s' animasyonu yok" % [durum, ad])

	# Animasyonun ölçüldüğü hızlar ile oyundaki hızlar aynı mı? İkisi ayrı
	# dosyada; biri değişip diğeri unutulursa ayak kayması sessizce büyür.
	var hizlar: Dictionary = olcum.get("hiz", {})
	_dogrula(absf(float(hizlar.get("yurume", 0.0)) - _dusman.ANIM_YURUME_HIZI) < 0.01,
		"yürüme hızı ölçümde %.2f, dusman.gd'de %.2f" % [
			hizlar.get("yurume", 0.0), _dusman.ANIM_YURUME_HIZI])
	_dogrula(absf(float(hizlar.get("kosma", 0.0)) - _dusman.ANIM_KOSMA_HIZI) < 0.01,
		"koşma hızı ölçümde %.2f, dusman.gd'de %.2f" % [
			hizlar.get("kosma", 0.0), _dusman.ANIM_KOSMA_HIZI])
	var kayma: Dictionary = olcum.get("kayma", {})
	for ad: String in kayma:
		_dogrula(float(kayma[ad]) <= KAYMA_BUTCESI,
			"düşman '%s' ayağı %.2f kat kayıyor (bütçe %.2f)" % [
				ad, kayma[ad], KAYMA_BUTCESI])
	print("düşman rig: %d kemik, %d animasyon, kayma %s" % [
		iskelet.get_bone_count() if iskelet else -1,
		(olcum["animasyon"] as Dictionary).size(), str(kayma)])

func _bul(kok: Node, sinif: String) -> Node:
	if kok == null:
		return null
	var yigin: Array[Node] = [kok]
	while not yigin.is_empty():
		var d: Node = yigin.pop_back()
		if d.is_class(sinif):
			return d
		for c in d.get_children():
			yigin.append(c)
	return null

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

# ------------------------------------------------- alt türler (Faz 14)

## Bölümün kendi düşmanlarını durdurur. Alt tür testleri TEK bir düşmanın
## davranışını ölçüyor; yakındaki başka bir düşmanın vuruşu "atıcının dikeni
## vurdu" diye okunursa test doğru sebepten değil yanlış sebepten geçer.
## Düşmanın baktığı yönde, verilen mesafede bir nokta.
func _onune(d: Node3D, mesafe: float) -> Vector3:
	var model: Node3D = d.get_node("Model")
	var onu := -model.global_transform.basis.z
	return d.global_position + onu * mesafe + Vector3(0, 0.6, 0)

func _bolumun_dusmanlarini_durdur() -> void:
	for d in get_tree().get_nodes_in_group("dusman"):
		(d as Node).set_physics_process(false)

## Hoplayan gerçekten yerden kesiliyor mu? "Zıplıyor" iddiasının tek kanıtı
## bu: kovalarken en yüksek noktası başlangıç yüksekliğinin üstünde olmalı.
## Ayrıca indikten sonra TOPARLANMA penceresi olmalı — oyuncunun üstüne
## binebileceği açık. Penceresiz bir hoplayan yenilemez olurdu.
func _hoplayan_testi() -> void:
	_bolumun_dusmanlarini_durdur()
	var sahne: PackedScene = load("res://sahneler/dusman_hoplayan.tscn")
	var h: CharacterBody3D = sahne.instantiate()
	# Konum ağaca EKLEMEDEN önce veriliyor: düşman `_ready` içinde devriye
	# başlangıcını kendi konumundan alıyor. Sonradan taşınan bir düşman
	# "başlangıç noktama döneyim" diye doğduğu yere yürüyor — testte bu,
	# "yerinden oynadı" diye okunuyordu.
	# Bölümün kendi düşmanının yanı: orada düz zemin olduğu ve görüşün açık
	# olduğu ZATEN biliniyor (devriye/farketme testleri orayı kullanıyor).
	h.position = _dusman.position + Vector3(2.0, 0.3, 0.0)
	_bolum.get_node("Dusmanlar").add_child(h)
	await _bekle(4)
	# Oyuncu düşmanın TAM ÖNÜNE konuyor: görüş açısı 120°, yanına konan
	# oyuncu fark edilmiyor ve test "zıplamıyor" diye okuyordu.
	_oyuncu.global_position = _onune(h, 5.0)
	_oyuncu.velocity = Vector3.ZERO
	await _bekle(20)

	var taban := h.global_position.y
	var en_yuksek := taban
	var havada_kare := 0
	var topar_kare := 0
	for i in 260:
		await get_tree().physics_frame
		en_yuksek = maxf(en_yuksek, h.global_position.y)
		if not h.is_on_floor():
			havada_kare += 1
		if h.get("_evre") == 3:      # Evre.TOPAR
			topar_kare += 1
	print("hoplayan: en yüksek +%.2f m, %d kare havada, %d kare toparlanma" % [
		en_yuksek - taban, havada_kare, topar_kare])
	_dogrula(en_yuksek - taban > 0.8,
		"Hoplayan zıplamıyor (en fazla +%.2f m)" % (en_yuksek - taban))
	_dogrula(havada_kare > 10, "Hoplayan havada hiç kalmıyor")
	_dogrula(topar_kare > 5,
		"Hoplayanın iniş sonrası savunmasız penceresi yok — yenilemez olur")
	h.queue_free()
	await _bekle(4)

## Atıcı: (1) yerinden kıpırdamamalı — yaklaşmak her zaman işe yaramalı,
## (2) diken atmalı, (3) diken hasar vermeli.
func _atici_testi() -> void:
	_bolumun_dusmanlarini_durdur()
	var sahne: PackedScene = load("res://sahneler/dusman_atici.tscn")
	var a: CharacterBody3D = sahne.instantiate()
	a.position = _dusman.position + Vector3(2.0, 0.3, 0.0)   # bkz. hoplayan testi
	_bolum.get_node("Dusmanlar").add_child(a)
	await _bekle(10)
	var basladigi := a.global_position
	# Oyuncuyu tam karşısına, atış menziline koy.
	_oyuncu.global_position = _onune(a, 6.0)
	_oyuncu.velocity = Vector3.ZERO
	_oyuncu.dokunulmazligi_bitir()
	var can_once: int = _oyuncu.can
	var mermi_gordu := false
	for i in 300:
		await get_tree().physics_frame
		if not get_tree().get_nodes_in_group("mermi").is_empty():
			mermi_gordu = true
		if _oyuncu.can < can_once:
			break
	# YATAY yer değişimi: düşman havada doğduysa düşüşü "yürüdü" sayılmasın.
	var kayma := Vector2(a.global_position.x - basladigi.x,
		a.global_position.z - basladigi.z).length()
	print("atıcı: mermi %s, can %d -> %d, yatay yer değişimi %.2f m" % [
		"atıldı" if mermi_gordu else "ATILMADI", can_once, _oyuncu.can, kayma])
	_dogrula(mermi_gordu, "Atıcı diken atmadı")
	_dogrula(_oyuncu.can < can_once, "Atıcının dikeni hasar vermedi")
	_dogrula(kayma < 1.0,
		"Atıcı yerinden oynadı (%.2f m) — yaklaşmanın karşılığı kalmaz" % kayma)
	a.queue_free()
	await _bekle(4)

## Siper gerçekten siper mi? Diken duvara doğru atılıyor, arkasındaki
## oyuncuya ulaşmamalı. Hızlı cisim tünelleme hatası tam burada çıkar:
## kare başına 23 cm atlayan bir mermi ince duvarı delip geçebilir.
func _diken_duvar_testi() -> void:
	var duvar := StaticBody3D.new()
	duvar.collision_layer = 1
	var sekil := CollisionShape3D.new()
	var kutu := BoxShape3D.new()
	kutu.size = Vector3(4.0, 3.0, 0.3)     # İNCE duvar: tünelleme sınavı
	sekil.shape = kutu
	duvar.add_child(sekil)
	_bolum.add_child(duvar)
	duvar.global_position = Vector3(0.0, 1.5, -16.0)

	_oyuncu.global_position = Vector3(0.0, 1.0, -14.0)
	_oyuncu.velocity = Vector3.ZERO
	_oyuncu.dokunulmazligi_bitir()
	await _bekle(6)
	var can_once: int = _oyuncu.can

	var diken: Area3D = (load("res://sahneler/diken.tscn") as PackedScene).instantiate()
	_bolum.add_child(diken)
	diken.global_position = Vector3(0.0, 1.0, -20.0)
	diken.kur(Vector3(0, 0, 1), null)
	var kare := 0
	while is_instance_valid(diken) and kare < 120:
		await get_tree().physics_frame
		kare += 1
	print("diken/duvar: %d karede durdu, can %d -> %d" % [kare, can_once, _oyuncu.can])
	_dogrula(kare < 120, "Diken duvara çarpıp yok olmadı")
	_dogrula(_oyuncu.can == can_once,
		"Diken duvarın içinden geçip oyuncuya vurdu (tünelleme)")
	duvar.queue_free()
	await _bekle(4)
