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
## bir durağın üstünde olmalı — yoksa bölüm bitirilemez, çünkü çiçeklerin hepsi
## toplanmadan bitiş açılmıyor.
##
## MENZİL NEREDEN GELİYOR: oyuncu sahnesinin kendi dışa aktarım değerlerinden
## (zıplama yüksekliği, koşu hızı) ve projenin yerçekiminden. Sabit yazsaydım
## zıplama ayarı değiştiğinde test yalan söylemeye başlardı.
##
## Bu test tasarım hatası bulmak için, oyun hatası için değil: "buraya
## zıplanamıyor" diyorsa veri dosyasındaki sayı yanlıştır.

## Havada yatay hıza tam hâkim olunamıyor (hava ivmesi 22 m/sn²): teorik menzil
## gerçekte yakalanmıyor. Zor ama mümkün sayılan pay bu.
const HAVA_VERIMI := 0.8
## Yatayda pay var, dikeyde yok. Sebebi: zıplama yüksekliği deterministik
## (v0 = sqrt(2gh) tam olarak h metre yükseltiyor), yatay menzil ise hava
## ivmesine ve oyuncunun zıplamaya kaç m/sn ile girdiğine bağlı. Dikeye de pay
## koyunca bölüm 1'in ilk basamağı (1,55 m) "zıplanamaz" çıkıyordu — oysa oyun
## yayında ve o basamak geçiliyor. Testin gerçeğe uyması gerekiyor, tersi değil.
## Çiçek toplama yarıçapı 0,85; karakter ~1,6 m. Durağın üstünden bu kadar
## yukarısı zıplayarak alınıyor.
const CICEK_ERISIM := 2.6
const CICEK_YANAL := 1.4

var _hatalar: Array[String] = []
var _uyarilar: Array[String] = []

func _ready() -> void:
	await get_tree().process_frame
	for bilgi: Dictionary in Bolumler.LISTE:
		await _bolumu_dogrula(bilgi)
	for u in _uyarilar:
		print("  ~ " + u)
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

	var duraklar := _duraklari_bul(kok)
	var tuzaklar := _tuzaklari_bul(kok)
	var oyuncu: Node3D = kok.get_node_or_null("Oyuncu")
	var bitis: Node3D = _bitisi_bul(kok)

	if duraklar.is_empty() or oyuncu == null or bitis == null:
		_hatalar.append("%s: durak/oyuncu/bitiş bulunamadı" % kimlik)
		kok.queue_free()
		await get_tree().process_frame
		return

	var baslangic := _altindaki_durak(oyuncu.global_position, duraklar)
	_dogrula(baslangic >= 0, "%s: doğuş noktasının altında durak yok" % kimlik)
	var hedef := _altindaki_durak(bitis.global_position, duraklar)
	_dogrula(hedef >= 0, "%s: bitiş alanının altında durak yok" % kimlik)

	if baslangic >= 0 and hedef >= 0:
		var ulasilan := _erisim_kumesi(baslangic, duraklar, tuzaklar)
		if not ulasilan.has(hedef):
			_hatalar.append("%s: bitişe zıplayarak ulaşılamıyor (doğuş '%s' -> bitiş '%s'); ulaşılan: %s"
				% [kimlik, duraklar[baslangic]["ad"], duraklar[hedef]["ad"],
					_adlar(ulasilan, duraklar)])

		# Çiçeklerin hepsi toplanmadan bitiş açılmıyor: biri ulaşılamazsa bölüm
		# bitirilemez. Bu, elle test edilirken en geç fark edilen hata.
		var cicekler := _grup_konumlari(kok, "toplanabilir")
		_dogrula(cicekler.size() >= 6,
			"%s: %d çiçek — bölüm için az" % [kimlik, cicekler.size()])
		for i in cicekler.size():
			var durak := _cicek_duragi(cicekler[i], duraklar)
			if durak < 0:
				_hatalar.append("%s: %d. çiçek hiçbir durağın erişiminde değil (%s)"
					% [kimlik, i + 1, _kisa(cicekler[i])])
			elif not ulasilan.has(durak):
				_hatalar.append("%s: %d. çiçeğin durağı '%s' erişilemez"
					% [kimlik, i + 1, duraklar[durak]["ad"]])

		var kn := _kontrol_noktalari(kok)
		for i in kn.size():
			var durak := _altindaki_durak(kn[i], duraklar)
			if durak < 0 or not ulasilan.has(durak):
				_hatalar.append("%s: %d. kontrol noktası erişilemez (%s)"
					% [kimlik, i + 1, _kisa(kn[i])])

		print("%-8s %2d durak, %2d ulaşılan, %2d çiçek, menzil %.1f m (düz)" % [
			kimlik, duraklar.size(), ulasilan.size(), cicekler.size(),
			_menzil(0.0)])

	# Düşmanlar boşlukta durmamalı: navigasyon örgüsü onları yürütemez.
	for dusman: Node3D in _grup_dugumleri(kok, "dusman"):
		if _altindaki_durak(dusman.global_position, duraklar) < 0:
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

# ------------------------------------------------------------------ geometri

## Durak = üstünde durulabilen kutu: platformlar, zemin, hareketli platformlar.
##
## HAREKETLİ PLATFORM İKİ DURAK: süpürdüğü alanı tek kutu saymak yanlış cevap
## veriyordu. Asansöre ALT ucunda biniliyor, ÜST ucunda iniliyor; tek kutunun
## "üst"ü en yüksek nokta olduğu için "oraya zıplanamıyor" çıkıyor ve bölüm 2
## bitirilemez görünüyordu. İki durus ayrı durak, aralarında bedava kenar var
## (binmek = beklemek).
func _duraklari_bul(kok: Node3D) -> Array[Dictionary]:
	var sonuc: Array[Dictionary] = []
	var grup := 0
	for dugum in _tum_dugumler(kok):
		if not (dugum is StaticBody3D or dugum is AnimatableBody3D):
			continue
		var kutu := _carpisma_kutusu(dugum as Node3D)
		if not _kutu_var_mi(kutu):
			continue
		if dugum is AnimatableBody3D and "uc" in dugum:
			var uc: Vector3 = dugum.uc
			# TUZAK: platform ölçüm anında çoktan hareket etmiş oluyor.
			# `baslangic_fazi` sıfırdan farklıysa düğüm daha ilk fizik karesinde
			# turun ortasına kayıyor; oradan +uc kadar süpürmek yanlış bir alan
			# veriyor ve "çiçeğe ulaşılamıyor" gibi hayalet hatalar çıkıyor.
			# Bu yüzden turun BAŞLANGIÇ konumuna geri çekiliyor.
			var kayma: Vector3 = Vector3.ZERO
			var baslangic: Variant = dugum.get("_baslangic")
			if baslangic is Vector3 and (baslangic as Vector3) != Vector3.ZERO:
				kayma = (baslangic as Vector3) - dugum.position
			kutu = AABB(kutu.position + kayma, kutu.size)
			var bitis := AABB(kutu.position + uc, kutu.size)
			var supurulen := kutu.merge(bitis)
			for durus: AABB in [kutu, bitis]:
				sonuc.append(_durak(String(dugum.name), durus, supurulen, grup))
			grup += 1
		else:
			sonuc.append(_durak(String(dugum.name), kutu, kutu, -1))
	return sonuc

func _durak(ad: String, durus: AABB, supurulen: AABB, grup: int) -> Dictionary:
	return {
		"ad": ad,
		"aabb": durus,
		"supurulen": supurulen,
		"ust": durus.position.y + durus.size.y,
		"ust_min": supurulen.position.y + durus.size.y,
		"ust_max": supurulen.position.y + supurulen.size.y,
		"grup": grup,
	}

func _tuzaklari_bul(kok: Node3D) -> Array[AABB]:
	var sonuc: Array[AABB] = []
	for dugum in _tum_dugumler(kok):
		if dugum is Area3D and _betik_yolu(dugum) == "res://betikler/tuzak.gd":
			var kutu := _carpisma_kutusu(dugum as Node3D)
			if _kutu_var_mi(kutu):
				sonuc.append(kutu)
	return sonuc

func _bitisi_bul(kok: Node3D) -> Node3D:
	for dugum in _tum_dugumler(kok):
		if dugum is Area3D and _betik_yolu(dugum) == "res://betikler/bitis.gd":
			return dugum
	return null

func _betik_yolu(dugum: Node) -> String:
	var betik: Script = dugum.get_script() as Script
	return betik.resource_path if betik != null else ""

## Gövdenin kutu çarpışmasının dünya uzayındaki eksen hizalı sınırı.
## Şekil yoksa ölçüsü sıfır bir AABB döner (`_kutu_var_mi`).
func _carpisma_kutusu(govde: Node3D) -> AABB:
	for cocuk: Node in govde.get_children():
		var sekil := cocuk as CollisionShape3D
		if sekil == null or not (sekil.shape is BoxShape3D):
			continue
		var olcu: Vector3 = (sekil.shape as BoxShape3D).size
		# Dönmüş platformların eksen hizalı kutusu alınıyor: eğik rampayı biraz
		# büyük gösteriyor, ama testin işi "ulaşılabilir mi", milimetre değil.
		var d: Transform3D = govde.global_transform * sekil.transform
		var b: Basis = d.basis
		var yari := Vector3(
			absf(b.x.x) * olcu.x + absf(b.y.x) * olcu.y + absf(b.z.x) * olcu.z,
			absf(b.x.y) * olcu.x + absf(b.y.y) * olcu.y + absf(b.z.y) * olcu.z,
			absf(b.x.z) * olcu.x + absf(b.y.z) * olcu.y + absf(b.z.z) * olcu.z) * 0.5
		return AABB(d.origin - yari, yari * 2.0)
	return AABB()

func _kutu_var_mi(kutu: AABB) -> bool:
	return kutu.size.length_squared() > 0.0

## Zıplamayla kat edilebilen yatay mesafe; `dy` hedefin kaç metre yukarıda
## olduğu (eksi = aşağıda).
func _menzil(dy: float) -> float:
	var g := float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
	var h := _oyuncu_degeri("ziplama_yuksekligi", 1.65)
	if dy > h:
		return -1.0   # bu yüksekliğe zıplanamıyor
	var hiz := _oyuncu_degeri("kosma_hizi", 7.4) * HAVA_VERIMI
	var dusme := _oyuncu_degeri("dusme_carpani", 1.35)
	var v0 := sqrt(2.0 * g * h)
	var t_yukari := v0 / g
	var t_asagi := sqrt(maxf(2.0 * (h - dy) / (g * dusme), 0.0))
	return hiz * (t_yukari + t_asagi)

var _oyuncu_degerleri := {}

func _oyuncu_degeri(ad: String, varsayilan: float) -> float:
	if _oyuncu_degerleri.is_empty():
		var o: Node = (load("res://sahneler/oyuncu.tscn") as PackedScene).instantiate()
		for alan in ["ziplama_yuksekligi", "kosma_hizi", "dusme_carpani"]:
			_oyuncu_degerleri[alan] = o.get(alan)
		o.free()
	return _oyuncu_degerleri.get(ad, varsayilan)

## Doğuş noktasından zıplayarak ulaşılabilen durakların kümesi (genişlik-öncelikli).
func _erisim_kumesi(baslangic: int, duraklar: Array[Dictionary],
		tuzaklar: Array[AABB]) -> Dictionary:
	var ulasilan := {baslangic: true}
	var kuyruk: Array[int] = [baslangic]
	while not kuyruk.is_empty():
		var su: int = kuyruk.pop_front()
		for hedef in duraklar.size():
			if ulasilan.has(hedef):
				continue
			var ayni_binek: bool = int(duraklar[su]["grup"]) >= 0 \
				and duraklar[su]["grup"] == duraklar[hedef]["grup"]
			if ayni_binek or _ziplanabilir_mi(duraklar[su], duraklar[hedef], tuzaklar):
				ulasilan[hedef] = true
				kuyruk.append(hedef)
	return ulasilan

func _ziplanabilir_mi(a: Dictionary, b: Dictionary, tuzaklar: Array[AABB]) -> bool:
	var dy: float = b["ust"] - a["ust"]
	var menzil := _menzil(dy)
	if menzil < 0.0:
		return false
	if _yatay_mesafe(a["aabb"], b["aabb"]) > menzil:
		return false
	return _guvenli_kalkis_var_mi(a, b, menzil, tuzaklar)

## Kalkış noktası dikenin içindeyse orada durulamaz. Ama "en yakın nokta"ya
## bakmak yanlış cevap veriyor: bölüm 1'de basamak taşları dikenli tarlanın
## ÜSTÜNDE duruyor, zeminden en yakın nokta hep dikenin içinde kalıyor ve her
## kenar reddediliyordu — oysa oyuncu tarlanın kenarından atlıyor. Bu yüzden
## kaynak yüzeyin menzil içindeki GÜVENLİ noktaları taranıyor.
func _guvenli_kalkis_var_mi(a: Dictionary, b: Dictionary, menzil: float,
		tuzaklar: Array[AABB]) -> bool:
	var kaynak: AABB = a["aabb"]
	var yukseklik: float = float(a["ust"]) + 0.5
	if not _tuzak_degiyor_mu(kaynak, yukseklik, tuzaklar):
		return true   # yüzeyin tamamı güvenli; mesafe zaten ölçüldü

	var hedef: AABB = b["aabb"]
	# Yalnızca menzil içinde kalan şerit taranıyor; 140x140 zemini baştan sona
	# örneklemenin anlamı yok.
	var x0 := maxf(kaynak.position.x, hedef.position.x - menzil)
	var x1 := minf(kaynak.position.x + kaynak.size.x, hedef.position.x + hedef.size.x + menzil)
	var z0 := maxf(kaynak.position.z, hedef.position.z - menzil)
	var z1 := minf(kaynak.position.z + kaynak.size.z, hedef.position.z + hedef.size.z + menzil)
	if x1 < x0 or z1 < z0:
		return false
	const ADIM := 0.75
	var x := x0
	while x <= x1 + 0.001:
		var z := z0
		while z <= z1 + 0.001:
			var nokta := Vector3(x, yukseklik, z)
			if not _tuzakta_mi(nokta, tuzaklar) and _noktadan_mesafe(nokta, hedef) <= menzil:
				return true
			z += ADIM
		x += ADIM
	return false

func _tuzak_degiyor_mu(kutu: AABB, yukseklik: float, tuzaklar: Array[AABB]) -> bool:
	var yuzey := AABB(Vector3(kutu.position.x, yukseklik - 0.05, kutu.position.z),
		Vector3(kutu.size.x, 0.1, kutu.size.z))
	for t in tuzaklar:
		if t.intersects(yuzey):
			return true
	return false

func _tuzakta_mi(nokta: Vector3, tuzaklar: Array[AABB]) -> bool:
	for t in tuzaklar:
		if _icinde_mi(t, nokta):
			return true
	return false

func _noktadan_mesafe(nokta: Vector3, kutu: AABB) -> float:
	var dx := maxf(0.0, maxf(kutu.position.x - nokta.x, nokta.x - kutu.position.x - kutu.size.x))
	var dz := maxf(0.0, maxf(kutu.position.z - nokta.z, nokta.z - kutu.position.z - kutu.size.z))
	return sqrt(dx * dx + dz * dz)

func _yatay_mesafe(a: AABB, b: AABB) -> float:
	var dx := maxf(0.0, maxf(a.position.x - (b.position.x + b.size.x),
		b.position.x - (a.position.x + a.size.x)))
	var dz := maxf(0.0, maxf(a.position.z - (b.position.z + b.size.z),
		b.position.z - (a.position.z + a.size.z)))
	return sqrt(dx * dx + dz * dz)

func _icinde_mi(kutu: AABB, nokta: Vector3) -> bool:
	return kutu.grow(0.01).has_point(nokta)

## Verilen konumun altında (ya da içinde) hangi durak var?
func _altindaki_durak(konum: Vector3, duraklar: Array[Dictionary]) -> int:
	# EN YÜKSEK yüzey seçiliyor, en yakını değil: bölüm 2'de bitiş hem kule
	# gövdesinin hem tepe platformunun üstünde kalıyor; üstünde DURULAN yüzey
	# tepe platformu.
	var en_iyi := -1
	var en_iyi_ust := -1e9
	for i in duraklar.size():
		var d: Dictionary = duraklar[i]
		var aabb: AABB = d["aabb"]
		if konum.x < aabb.position.x - 0.6 or konum.x > aabb.position.x + aabb.size.x + 0.6:
			continue
		if konum.z < aabb.position.z - 0.6 or konum.z > aabb.position.z + aabb.size.z + 0.6:
			continue
		var fark: float = konum.y - float(d["ust"])
		if fark < -0.6 or fark > 3.2:
			continue
		if float(d["ust"]) > en_iyi_ust:
			en_iyi_ust = float(d["ust"])
			en_iyi = i
	return en_iyi

## Çiçek hangi durağın erişiminde? Üstünde durup zıplayarak alınabiliyorsa o durak.
func _cicek_duragi(konum: Vector3, duraklar: Array[Dictionary]) -> int:
	for i in duraklar.size():
		var d: Dictionary = duraklar[i]
		# Hareketli platformda çiçek yol boyunca herhangi bir yerde olabilir:
		# süpürülen alana bakılıyor.
		if _noktadan_mesafe(konum, d["supurulen"]) > CICEK_YANAL:
			continue
		# Alt sınır yüzeyin ÜSTÜ değil ALTI: eğik rampanın eksen hizalı kutusunda
		# "üst" en yüksek köşe oluyor, rampanın ortasındaki çiçek onun 1,5 m
		# altında kalıyor ve "erişilemez" görünüyordu.
		var alt: float = minf(float(d["ust_min"]), d["supurulen"].position.y) - 0.6
		if konum.y >= alt and konum.y <= float(d["ust_max"]) + CICEK_ERISIM:
			return i
	return -1

# -------------------------------------------------------------------- yardım

func _tum_dugumler(kok: Node) -> Array[Node]:
	var sonuc: Array[Node] = []
	var yigin: Array[Node] = [kok]
	while not yigin.is_empty():
		var d: Node = yigin.pop_back()
		sonuc.append(d)
		for c in d.get_children():
			yigin.append(c)
	return sonuc

func _grup_dugumleri(kok: Node, grup: String) -> Array[Node]:
	var sonuc: Array[Node] = []
	for d in get_tree().get_nodes_in_group(grup):
		if kok.is_ancestor_of(d):
			sonuc.append(d)
	return sonuc

func _grup_konumlari(kok: Node, grup: String) -> Array[Vector3]:
	var sonuc: Array[Vector3] = []
	for d in _grup_dugumleri(kok, grup):
		sonuc.append((d as Node3D).global_position)
	return sonuc

func _kontrol_noktalari(kok: Node) -> Array[Vector3]:
	var sonuc: Array[Vector3] = []
	var kap := kok.get_node_or_null("KontrolNoktalari")
	if kap != null:
		for c in kap.get_children():
			sonuc.append((c as Node3D).global_position)
	return sonuc

func _adlar(kume: Dictionary, duraklar: Array[Dictionary]) -> String:
	var adlar: Array[String] = []
	for i: int in kume:
		adlar.append("%s@%.1f" % [duraklar[i]["ad"], duraklar[i]["ust"]])
	adlar.sort()
	return ", ".join(adlar)

func _kisa(v: Vector3) -> String:
	return "%.1f, %.1f, %.1f" % [v.x, v.y, v.z]
