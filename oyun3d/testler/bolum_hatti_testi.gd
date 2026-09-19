extends Node
## Bölüm hattı testi: üretilen bölüm bitirilebilir mi?
##
##   godot --headless --path oyun3d res://testler/bolum_hatti_testi.tscn
##
## NEDEN VAR: bir bölümü elle oynayıp "geçilebiliyor" demek, o bölümü her
## değiştirdiğinde baştan oynamak demek. Dördüncü bölümden sonra kimse yapmıyor.
## Burada bitirilebilirlik OYNANARAK değil, HESAPLANARAK doğrulanıyor: duraklar
## (platform üstleri, hareketli platformun süpürdüğü alan) çıkarılıyor, aralarında
## "buradan şuraya zıplanabilir mi" kenarları kuruluyor ve doğuş noktasından
## bitişe yol var mı diye bakılıyor. Çiçekler ve kontrol noktaları da erişilebilir
## bir durağın üstünde olmalı — çiçeklerin hepsi toplanmadan bitiş açılmıyor,
## yani ulaşılamayan tek çiçek bölümü bitirilemez yapıyor.
##
## Geometri ve menzil hesabı `betikler/bolum_grafi.gd` içinde; aynı graf botun
## (Faz 10) yol bulmasında da kullanılıyor. İki ayrı uygulama, testin
## "geçilebilir" dediği bir boşluğu botun geçememesi demek olurdu.
##
## Bu test TASARIM hatası bulmak için, oyun hatası için değil: "buraya
## zıplanamıyor" diyorsa veri dosyasındaki sayı yanlıştır.

var _hatalar: Array[String] = []

func _ready() -> void:
	await get_tree().process_frame
	for bilgi: Dictionary in Bolumler.LISTE:
		await _bolumu_dogrula(bilgi)
	if _hatalar.is_empty():
		print("BOLUM HATTI TESTI: GECTI")
		get_tree().quit(0)
	else:
		for h in _hatalar:
			printerr("  ! " + h)
		print("BOLUM HATTI TESTI: KALDI (%d)" % _hatalar.size())
		get_tree().quit(1)

func _dogrula(kosul: bool, mesaj: String) -> void:
	if not kosul:
		_hatalar.append(mesaj)

func _bolumu_dogrula(bilgi: Dictionary) -> void:
	var kimlik: String = bilgi["kimlik"]
	var sahne: PackedScene = load(bilgi["sahne"])
	if sahne == null:
		_hatalar.append("%s: sahne yüklenemedi" % kimlik)
		return
	var kok: Node3D = sahne.instantiate()
	get_tree().root.add_child(kok)
	await get_tree().physics_frame
	await get_tree().physics_frame

	_yapiyi_dogrula(kimlik, kok)

	var graf := BolumGrafi.kur(kok)
	if graf.duraklar.is_empty() or graf.oyuncu == null or graf.bitis == null:
		_hatalar.append("%s: durak/oyuncu/bitiş bulunamadı" % kimlik)
		kok.queue_free()
		await get_tree().process_frame
		return

	var baslangic := graf.altindaki_durak(graf.oyuncu.global_position)
	_dogrula(baslangic >= 0, "%s: doğuş noktasının altında durak yok" % kimlik)
	var hedef := graf.altindaki_durak(graf.bitis.global_position)
	_dogrula(hedef >= 0, "%s: bitiş alanının altında durak yok" % kimlik)

	if baslangic >= 0 and hedef >= 0:
		var ulasilan := graf.erisim_kumesi(baslangic)
		if not ulasilan.has(hedef):
			_hatalar.append("%s: bitişe zıplayarak ulaşılamıyor (doğuş '%s' -> bitiş '%s'); ulaşılan: %s"
				% [kimlik, graf.duraklar[baslangic]["ad"], graf.duraklar[hedef]["ad"],
					_adlar(ulasilan, graf)])

		_dogrula(graf.cicekler.size() >= 6,
			"%s: %d çiçek — bölüm için az" % [kimlik, graf.cicekler.size()])
		for i in graf.cicekler.size():
			var konum: Vector3 = graf.cicekler[i].global_position
			var durak := graf.cicek_duragi(konum)
			if durak < 0:
				_hatalar.append("%s: %d. çiçek hiçbir durağın erişiminde değil (%s)"
					% [kimlik, i + 1, _kisa(konum)])
			elif not ulasilan.has(durak):
				_hatalar.append("%s: %d. çiçeğin durağı '%s' erişilemez"
					% [kimlik, i + 1, graf.duraklar[durak]["ad"]])

		for i in graf.kontrol_noktalari.size():
			var durak := graf.altindaki_durak(graf.kontrol_noktalari[i])
			if durak < 0 or not ulasilan.has(durak):
				_hatalar.append("%s: %d. kontrol noktası erişilemez (%s)"
					% [kimlik, i + 1, _kisa(graf.kontrol_noktalari[i])])

		print("%-8s %2d durak, %2d ulaşılan, %2d çiçek, menzil %.1f m (düz)" % [
			kimlik, graf.duraklar.size(), ulasilan.size(), graf.cicekler.size(),
			graf.menzil(0.0)])

	# Düşmanlar boşlukta durmamalı: navigasyon örgüsü onları yürütemez.
	for dusman: Node in get_tree().get_nodes_in_group("dusman"):
		if not kok.is_ancestor_of(dusman):
			continue
		if graf.altindaki_durak((dusman as Node3D).global_position) < 0:
			_hatalar.append("%s: '%s' hiçbir platformun üstünde değil" % [
				kimlik, dusman.name])

	kok.queue_free()
	await get_tree().process_frame

## Üretilen bölümlerde de elle yazılanlarda da aynı iskelet olmalı: bir bölümü
## kopyalarken unutulan düğüm, oyunun ortasında çöküyor.
func _yapiyi_dogrula(kimlik: String, kok: Node3D) -> void:
	for yol in ["Oyuncu", "Oyun", "HUD", "Duraklat", "BitisEkrani", "Dokunmatik",
			"HayaletKaydedici", "UzakOyuncular", "Navigasyon", "Toplananlar"]:
		_dogrula(kok.has_node(yol), "%s: '%s' düğümü yok" % [kimlik, yol])
	var oyun := kok.get_node_or_null("Oyun")
	if oyun != null:
		_dogrula(oyun.bolum_kimligi == kimlik,
			"%s: Oyun.bolum_kimligi '%s' — kütükteki kimlikle aynı olmalı" % [
				kimlik, oyun.bolum_kimligi])
	var hud := kok.get_node_or_null("HUD")
	if hud != null:
		for benzersiz in ["Can", "Hayalet"]:
			_dogrula(hud.get_node_or_null("%%%s" % benzersiz) != null,
				"%s: HUD'da %%%s yok" % [kimlik, benzersiz])
	# Bölüm adı çeviri tablosunda var mı? Yoksa menüde ham anahtar görünür.
	var ad: String = Bolumler.bilgi(kimlik).get("ad", "")
	_dogrula(not ad.is_empty() and tr(ad) != ad,
		"%s: '%s' çeviri anahtarının karşılığı yok" % [kimlik, ad])

func _adlar(kume: Dictionary, graf: BolumGrafi) -> String:
	var adlar: Array[String] = []
	for i: int in kume:
		adlar.append("%s@%.1f" % [graf.duraklar[i]["ad"], graf.duraklar[i]["ust"]])
	adlar.sort()
	return ", ".join(adlar)

func _kisa(v: Vector3) -> String:
	return "%.1f, %.1f, %.1f" % [v.x, v.y, v.z]
