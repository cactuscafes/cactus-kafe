extends Node
## Ses testi (Faz 15): kayıt, havuz, 3B, kısma, katmanlı müzik ve çevre.
##
##   godot --headless --path oyun3d res://testler/ses_testi.tscn
##
## SESİ TEST ETMEK GARİP GÖRÜNÜYOR ama ses, sessizce bozulan şeylerin başında
## geliyor: bir ses adı yanlış yazılınca oyun çalışmaya devam ediyor, yalnızca
## o olay sessiz kalıyor. Kimse fark etmiyor, çünkü "ses çıkmadı" bir hata
## mesajı üretmiyor. Burada ölçülenler:
##
##  - KAYIT: koddaki her `Ses.cal("...")` adı kütüphanede var mı? (yazım hatası)
##  - ÖKSÜZ: `ses/` altında üretilip hiç kullanılmayan dosya var mı?
##  - HAVUZ: yüzlerce ses çalınca düğüm sayısı sabit kalıyor mu? (sızıntı)
##  - 3B: ses verilen konumdan mı çalıyor?
##  - KISMA: müzik kısılıyor ve ESKİ SEVİYESİNE dönüyor mu?
##  - KATMAN: iki müzik katmanı eşzamanlı mı? (kayarsa akort tutmaz)
##  - GERİLİM: düşman kovalayınca gerilim katmanı gerçekten açılıyor mu?

const TARANAN := ["res://betikler", "res://araclar", "res://testler"]

var _hatalar: Array[String] = []

func _ready() -> void:
	await get_tree().process_frame
	_kaydi_dogrula()
	_oksuz_dosya_var_mi()
	await _havuzu_dogrula()
	await _uc_boyutu_dogrula()
	await _muzigi_dogrula()
	await _kismayi_dogrula()
	await _ortami_dogrula()
	await _gerilimi_dogrula()

	if _hatalar.is_empty():
		print("SES TESTI: GECTI")
		get_tree().quit(0)
	else:
		for h in _hatalar:
			printerr("  ! " + h)
		print("SES TESTI: KALDI (%d)" % _hatalar.size())
		get_tree().quit(1)

func _dogrula(kosul: bool, mesaj: String) -> void:
	if not kosul:
		_hatalar.append(mesaj)

func _bekle(kare: int) -> void:
	for i in kare:
		await get_tree().process_frame

# ------------------------------------------------------------------ kayıt

## Koddaki bütün ses adlarını toplayıp kütüphaneyle karşılaştırır.
##
## Bu testin en çok işe yarayan parçası: `Ses.cal("dusman_olum")` yazmak
## (dosyanın adı `dusman_oldu`) oyunu bozmuyor, yalnızca o ses hiç çıkmıyor.
## Godot bunu çalışma anında `push_warning` ile söylüyor — yani ancak o olay
## gerçekleşirse ve biri günlüğe bakarsa.
func _kaydi_dogrula() -> void:
	var adlar := _kodda_gecen_sesler()
	_dogrula(adlar.size() > 10,
		"Kodda ses çağrısı bulunamadı (%d) — tarayıcı bozulmuş olabilir" % adlar.size())
	for ad: String in adlar:
		_dogrula(Ses.EFEKTLER.has(ad) or Ses.ORTAMLAR.has(ad),
			"Kodda çalınan '%s' sesi kütüphanede yok (yazım hatası?)" % ad)
	print("kayıt: kodda %d ayrı ses adı, kütüphanede %d efekt + %d çevre" % [
		adlar.size(), Ses.EFEKTLER.size(), Ses.ORTAMLAR.size()])

func _kodda_gecen_sesler() -> Array[String]:
	var desen := RegEx.new()
	desen.compile('(?:cal|cal_3b|ortam_baslat)\\("([a-z0-9_]+)"')
	var adlar: Array[String] = []
	for klasor: String in TARANAN:
		for yol: String in _gd_dosyalari(klasor):
			var dosya := FileAccess.open(yol, FileAccess.READ)
			if dosya == null:
				continue
			# `ses.gd`in kendisi kütüphaneyi tanımlıyor; orada geçen adlar
			# çağrı değil tanım.
			if yol.ends_with("/ses.gd"):
				continue
			# YORUM SATIRLARI ATILIYOR: bu dosyanın kendi açıklamasında örnek
			# olarak geçen `Ses.cal("dusman_olum")` gerçek bir çağrı değil.
			# Tarayıcı onu da toplayınca test kendi belgesinden şikâyet etti.
			var satirlar := PackedStringArray()
			for satir in dosya.get_as_text().split("\n"):
				if not satir.strip_edges().begins_with("#"):
					satirlar.append(satir)
			var metin := "\n".join(satirlar)
			for eslesme in desen.search_all(metin):
				var ad := eslesme.get_string(1)
				if not adlar.has(ad):
					adlar.append(ad)
	return adlar

func _gd_dosyalari(klasor: String) -> Array[String]:
	var sonuc: Array[String] = []
	var d := DirAccess.open(klasor)
	if d == null:
		return sonuc
	d.list_dir_begin()
	var ad := d.get_next()
	while ad != "":
		var tam := klasor.path_join(ad)
		if d.current_is_dir():
			sonuc.append_array(_gd_dosyalari(tam))
		elif ad.ends_with(".gd"):
			sonuc.append(tam)
		ad = d.get_next()
	d.list_dir_end()
	return sonuc

## Üretilip kullanılmayan ses dosyası: ya bağlanmayı unuttuk ya da artık
## gereksiz. İkisi de sessizce duruyor ve paketin içinde yer kaplıyor.
func _oksuz_dosya_var_mi() -> void:
	var kullanilan := {}
	for ad: String in Ses.EFEKTLER:
		kullanilan[(Ses.EFEKTLER[ad] as AudioStream).resource_path.get_file()] = true
	for ad: String in Ses.ORTAMLAR:
		kullanilan[(Ses.ORTAMLAR[ad] as AudioStream).resource_path.get_file()] = true
	kullanilan["muzik.wav"] = true
	kullanilan["muzik_gerilim.wav"] = true
	var d := DirAccess.open("res://ses")
	if d == null:
		_hatalar.append("res://ses açılamadı")
		return
	var oksuz: Array[String] = []
	d.list_dir_begin()
	var ad := d.get_next()
	while ad != "":
		if ad.ends_with(".wav") and not kullanilan.has(ad):
			oksuz.append(ad)
		ad = d.get_next()
	d.list_dir_end()
	_dogrula(oksuz.is_empty(), "Kullanılmayan ses dosyası: %s" % ", ".join(oksuz))

# ------------------------------------------------------------------ havuz

## Havuz sınırlı olmalı: her ses için düğüm yaratan bir sistem, uzun bir
## bölümde yüzlerce düğüm biriktirir ve kimse fark etmez.
func _havuzu_dogrula() -> void:
	var once := Ses.get_child_count()
	for i in 200:
		Ses.cal("tik")
		Ses.cal_3b("tik", Vector3(randf() * 10.0, 0, 0))
	await _bekle(2)
	_dogrula(Ses.get_child_count() == once,
		"Ses havuzu büyüyor: %d -> %d düğüm" % [once, Ses.get_child_count()])
	print("havuz: 400 çağrıdan sonra düğüm sayısı %d (sabit)" % Ses.get_child_count())

# --------------------------------------------------------------------- 3B

func _uc_boyutu_dogrula() -> void:
	var konum := Vector3(12.0, 3.0, -7.0)
	Ses.cal_3b("toplama", konum)
	await _bekle(1)
	var havuz: Array = Ses.get("_havuz_3b")
	var bulundu := false
	for dugum in havuz:
		var o := dugum as AudioStreamPlayer3D
		if o.playing and o.global_position.distance_to(konum) < 0.01:
			bulundu = true
			_dogrula(o.max_distance > 10.0,
				"3B sesin menzili çok kısa (%.1f m)" % o.max_distance)
			_dogrula(o.bus == &"SFX", "3B ses SFX bus'ında değil: %s" % o.bus)
	_dogrula(bulundu, "3B ses verilen konumdan çalmadı")
	await _dinleyiciyi_dogrula()
	print("3B: ses %s konumundan çalıyor, menzil %.0f m" % [
		konum, (havuz[0] as AudioStreamPlayer3D).max_distance])

## 3B sesin ANLAMI dinleyicinin yerine bağlı. Varsayılan dinleyici kameradır
## ve kamera karakterin 5 m arkasında: düşman yanı başındayken bile "uzakta"
## duyuluyor. Oyuncu sahnesinde kameranın altında, karaktere doğru kaydırılmış
## bir AudioListener3D var; bu test onun yerinde durduğunu doğruluyor.
func _dinleyiciyi_dogrula() -> void:
	var oyuncu: CharacterBody3D = (load("res://sahneler/oyuncu.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(oyuncu)
	await get_tree().process_frame
	var dinleyici := oyuncu.get_node_or_null("KameraKolu/Kamera/Dinleyici") as AudioListener3D
	_dogrula(dinleyici != null, "Oyuncuda AudioListener3D yok — sesler kameradan duyulur")
	if dinleyici != null:
		var kamera: Camera3D = oyuncu.get_node("KameraKolu/Kamera")
		var d_uzak := dinleyici.global_position.distance_to(oyuncu.global_position)
		var k_uzak := kamera.global_position.distance_to(oyuncu.global_position)
		print("dinleyici: karaktere %.2f m, kamera %.2f m" % [d_uzak, k_uzak])
		_dogrula(d_uzak < k_uzak,
			"Dinleyici kameradan daha uzakta (%.2f > %.2f m)" % [d_uzak, k_uzak])
	oyuncu.queue_free()
	await get_tree().process_frame

# ------------------------------------------------------------------ müzik

## İki katmanın eşzamanlılığı bu sistemin can damarı: kayarlarsa gerilim
## katmanı açıldığı anda akort tutmaz ve müzik "bozuk" duyulur.
func _muzigi_dogrula() -> void:
	Ses.muzik_baslat()
	await _bekle(20)
	var m: AudioStreamPlayer = Ses.get("_muzik")
	var g: AudioStreamPlayer = Ses.get("_gerilim")
	_dogrula(m.playing and g.playing, "Müzik katmanlarının ikisi birden çalmıyor")
	var fark := absf(m.get_playback_position() - g.get_playback_position())
	_dogrula(fark < 0.05, "Müzik katmanları kaymış: %.3f sn fark" % fark)
	_dogrula(absf(m.stream.get_length() - g.stream.get_length()) < 0.01,
		"Katmanların uzunluğu farklı (%.2f / %.2f sn) — döngüde kayarlar" % [
			m.stream.get_length(), g.stream.get_length()])
	_dogrula(m.bus == &"Muzik" and g.bus == &"Muzik",
		"Müzik katmanları Muzik bus'ında değil")

	# Gerilim açılıp kapanıyor mu?
	var sessiz := g.volume_db
	Ses.gerilim_ayarla(1.0)
	await _bekle(90)
	var acik := g.volume_db
	var acik_oran := Ses.gerilim_orani()
	# Kapanış bilerek yavaş (tehlike geçti hissi yavaş oturur), bu yüzden
	# kare sayısıyla değil DURUMLA bekleniyor: kare süresi makineye göre
	# değişiyor ve sabit sayı testi makineye bağlı yapıyor.
	Ses.gerilim_ayarla(0.0)
	var kare := 0
	while Ses.gerilim_orani() > 0.05 and kare < 600:
		await get_tree().process_frame
		kare += 1
	print("müzik: gerilim kapalı %.1f dB, açık %.1f dB (oran %.2f), %d karede kapandı" % [
		sessiz, acik, acik_oran, kare])
	_dogrula(acik > sessiz + 20.0,
		"Gerilim katmanı açılmıyor (%.1f -> %.1f dB)" % [sessiz, acik])
	_dogrula(acik_oran > 0.8, "Gerilim tavana çıkmadı (%.2f)" % acik_oran)
	_dogrula(kare < 600, "Gerilim katmanı kapanmıyor")

# ------------------------------------------------------------------ kısma

## Kısma OYNATICIYA uygulanıyor, bus'a değil: bus oyuncunun ayarı. Test tam
## bunu koruyor — kısma bus'a yazsaydı oyuncunun müzik ayarı her ölümde biraz
## daha düşerdi ve kimse sebebini bulamazdı.
func _kismayi_dogrula() -> void:
	var indeks := AudioServer.get_bus_index(&"Muzik")
	var bus_once := AudioServer.get_bus_volume_db(indeks)
	var m: AudioStreamPlayer = Ses.get("_muzik")
	Ses.kis()
	await _bekle(2)
	var kisik := m.volume_db
	_dogrula(kisik < -3.0, "Kısma müziği kısmadı (%.1f dB)" % kisik)
	_dogrula(is_equal_approx(AudioServer.get_bus_volume_db(indeks), bus_once),
		"Kısma BUS seviyesini değiştirdi — oyuncunun ayarı bozulur")
	await _bekle(90)
	print("kısma: %.1f dB'ye indi, sonra %.1f dB'ye döndü" % [kisik, m.volume_db])
	_dogrula(is_zero_approx(m.volume_db), "Kısma sonrası müzik eski seviyesine dönmedi")

# ------------------------------------------------------------------ çevre

func _ortami_dogrula() -> void:
	Ses.ortam_baslat("ruzgar")
	await _bekle(2)
	var o: AudioStreamPlayer = Ses.get("_ortam")
	_dogrula(o.playing, "Çevre sesi başlamadı")
	_dogrula(o.bus == &"Ortam", "Çevre sesi Ortam bus'ında değil: %s" % o.bus)
	var parca := o.stream as AudioStreamWAV
	_dogrula(parca != null and parca.loop_mode == AudioStreamWAV.LOOP_FORWARD,
		"Çevre sesi döngüye alınmamış — bir kez çalıp susar")
	Ses.ortam_durdur()
	await _bekle(2)
	_dogrula(not o.playing, "Çevre sesi durdurulamadı")
	print("çevre: rüzgâr döngüsü %.1f sn, durdurma çalışıyor" % parca.get_length())

# --------------------------------------------------------------- gerilim

## Gerilim katmanı OYUN DURUMUNDAN besleniyor mu? Bölüm yükleniyor, bir
## düşman kovalama durumuna zorlanıyor ve müziğin açılması bekleniyor.
func _gerilimi_dogrula() -> void:
	var bolum: Node3D = (load("res://sahneler/bolum1.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(bolum)
	await _bekle(5)
	Ses.gerilim_ayarla(0.0)
	await _bekle(2)

	# Düşmanın durumunu ELLE yazmak işe yaramıyor: yapay zekâ bir sonraki
	# karede "oyuncuyu göremiyorum" deyip devriyeye dönüyor. Gerçek yol,
	# oyuncuyu düşmanın önüne koymak — testin ölçtüğü şey de zaten bu:
	# oyun durumu müziği sürüyor mu?
	var dusmanlar := bolum.get_node("Dusmanlar")
	var ilk: Node3D = dusmanlar.get_child(0)
	var oyuncu: Node3D = bolum.get_node("Oyuncu")
	var model: Node3D = ilk.get_node("Model")
	oyuncu.global_position = ilk.global_position \
		- model.global_transform.basis.z * 5.0 + Vector3(0, 0.6, 0)
	var kare := 0
	while Ses.gerilim_orani() < 0.1 and kare < 300:
		await get_tree().process_frame
		kare += 1
	var gergin := Ses.gerilim_orani()
	print("gerilim: düşman kovalarken %.2f" % gergin)
	_dogrula(gergin > 0.1,
		"Düşman kovalarken müziğin gerilim katmanı açılmadı (%.2f)" % gergin)

	# Bölüm kapanınca gerilim SÖNMELİ: menüye dönüldüğünde müziğin gergin
	# katmanı açık kalıyordu. Sönüm yavaş olduğu için yine durumla bekleniyor.
	bolum.queue_free()
	kare = 0
	while Ses.gerilim_orani() > 0.05 and kare < 600:
		await get_tree().process_frame
		kare += 1
	_dogrula(kare < 600, "Bölüm kapanınca gerilim sönmedi (%.2f)" % Ses.gerilim_orani())
