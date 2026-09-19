class_name BolumGrafi
extends RefCounted
## Bölümün "nereden nereye zıplanabilir" grafı.
##
## İKİ MÜŞTERİSİ VAR ve tek uygulama olması şart:
##  - `testler/bolum_hatti_testi` — bölüm bitirilebilir mi (hesapla);
##  - `betikler/bot/otomatik_oyuncu.gd` — bölümü gerçekten oyna (uygula).
##
## Aynı geometriyi iki yerde ayrı hesaplamak, testin "geçilebilir" dediği bir
## boşluğu botun geçememesi demekti; o zaman hangisinin haklı olduğunu
## anlamanın yolu yok. Tek kaynak: burası.
##
## DURAK = üstünde durulabilen kutu (platform, zemin, hareketli platformun bir
## duruşu). Hareketli platform İKİ durak üretir (alt uç / üst uç) ve ikisi aynı
## "binek grubu"nda: aralarındaki geçiş zıplamak değil beklemektir.

## Havada yatay hıza tam hâkim olunamıyor (hava ivmesi 22 m/sn²): teorik menzil
## gerçekte yakalanmıyor. Zor ama mümkün sayılan pay bu.
const HAVA_VERIMI := 0.8
## Çiçek toplama yarıçapı 0,85; karakter ~1,6 m. Durağın üstünden bu kadar
## yukarısı zıplayarak alınıyor.
const CICEK_ERISIM := 2.6
const CICEK_YANAL := 1.4

var duraklar: Array[Dictionary] = []
var tuzaklar: Array[AABB] = []
var bitis: Node3D = null
var oyuncu: Node3D = null
var cicekler: Array[Node3D] = []
var kontrol_noktalari: Array[Vector3] = []

var _oyuncu_degerleri := {}
## Kalkış noktası taraması pahalı (yüzeyi 0,5 m ızgarayla tarıyor) ve bot onu
## HER KARE soruyordu. Duraklar sabit olduğu için cevap da sabit: önbellek.
var _kalkis_onbellek := {}

static func kur(kok: Node3D) -> BolumGrafi:
	var g := BolumGrafi.new()
	g._tara(kok)
	return g

func _tara(kok: Node3D) -> void:
	var grup := 0
	for dugum: Node in _tum_dugumler(kok):
		if dugum is StaticBody3D or dugum is AnimatableBody3D:
			var kutular := _kutular(dugum as Node3D)
			if kutular.is_empty():
				continue
			var kutu := kutular[0]
			if dugum is AnimatableBody3D and "uc" in dugum:
				var uc: Vector3 = dugum.uc
				# TUZAK: platform ölçüm anında çoktan hareket etmiş oluyor.
				# `baslangic_fazi` sıfırdan farklıysa düğüm daha ilk fizik
				# karesinde turun ortasına kayıyor; oradan +uc kadar süpürmek
				# yanlış alan veriyor. Turun BAŞLANGIÇ konumuna geri çekiliyor.
				var kayma := Vector3.ZERO
				var baslangic: Variant = dugum.get("_baslangic")
				if baslangic is Vector3 and (baslangic as Vector3) != Vector3.ZERO:
					kayma = (baslangic as Vector3) - (dugum as Node3D).position
				kutu = AABB(kutu.position + kayma, kutu.size)
				var son := AABB(kutu.position + uc, kutu.size)
				var supurulen := kutu.merge(son)
				for durus: AABB in [kutu, son]:
					duraklar.append(_durak(String(dugum.name), durus, supurulen,
						grup, dugum as Node3D))
				grup += 1
			else:
				for i in kutular.size():
					var ad := String(dugum.name)
					if kutular.size() > 1:
						ad = "%s#%d" % [ad, i + 1]
					duraklar.append(_durak(ad, kutular[i], kutular[i], -1, null))
		elif dugum is Area3D:
			match _betik_yolu(dugum):
				"res://betikler/tuzak.gd":
					for kutu in _kutular(dugum as Node3D):
						tuzaklar.append(kutu)
				"res://betikler/bitis.gd":
					bitis = dugum as Node3D
				"res://betikler/toplanabilir.gd":
					cicekler.append(dugum as Node3D)

	_olumcul_duraklari_at()
	oyuncu = kok.get_node_or_null("Oyuncu")
	var kap := kok.get_node_or_null("KontrolNoktalari")
	if kap != null:
		for c: Node in kap.get_children():
			kontrol_noktalari.append((c as Node3D).global_position)

## Üstü baştan sona dikenle kaplı yüzey DURAK DEĞİLDİR: orada durulmuyor,
## ölünüyor. Bölüm 2, 3, 4 ve 6'da zeminin tamamı dikenli; onu durak saymak
## hem grafta olmayan bir yol açıyor hem de botu "zemindeyim, buradan yol yok"
## diye kilitliyordu (ölüm anında bir kare zemine değiyor).
func _olumcul_duraklari_at() -> void:
	var kalan: Array[Dictionary] = []
	for d in duraklar:
		var aabb: AABB = d["aabb"]
		var y: float = float(d["ust"]) + 0.4
		var guvenli := false
		for oran_x in [0.15, 0.5, 0.85]:
			for oran_z in [0.15, 0.5, 0.85]:
				var nokta := Vector3(aabb.position.x + aabb.size.x * oran_x, y,
					aabb.position.z + aabb.size.z * oran_z)
				if not tuzakta_mi(nokta):
					guvenli = true
		if guvenli:
			kalan.append(d)
	duraklar = kalan

func _durak(ad: String, durus: AABB, supurulen: AABB, grup: int,
		dugum: Node3D) -> Dictionary:
	return {
		"ad": ad,
		"aabb": durus,
		"supurulen": supurulen,
		"ust": durus.position.y + durus.size.y,
		"ust_min": supurulen.position.y + durus.size.y,
		"ust_max": supurulen.position.y + supurulen.size.y,
		"grup": grup,
		"dugum": dugum,   # hareketli platform düğümü (bot bekleyeceği için)
	}

# ------------------------------------------------------------------ menziller

## Zıplamayla kat edilebilen yatay mesafe; `dy` hedefin kaç metre yukarıda
## olduğu (eksi = aşağıda). Değerler oyuncunun KENDİ dışa aktarım
## değerlerinden: sabit yazılsaydı zıplama ayarı değişince yalan söylerdi.
func menzil(dy: float) -> float:
	var g := float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
	var h := oyuncu_degeri("ziplama_yuksekligi", 1.65)
	if dy > h:
		return -1.0
	var hiz := oyuncu_degeri("kosma_hizi", 7.4) * HAVA_VERIMI
	var dusme := oyuncu_degeri("dusme_carpani", 1.35)
	var v0 := sqrt(2.0 * g * h)
	return hiz * (v0 / g + sqrt(maxf(2.0 * (h - dy) / (g * dusme), 0.0)))

func oyuncu_degeri(ad: String, varsayilan: float) -> float:
	if _oyuncu_degerleri.is_empty():
		var o: Node = (load("res://sahneler/oyuncu.tscn") as PackedScene).instantiate()
		for alan in ["ziplama_yuksekligi", "kosma_hizi", "yurume_hizi", "dusme_carpani"]:
			_oyuncu_degerleri[alan] = o.get(alan)
		o.free()
	return _oyuncu_degerleri.get(ad, varsayilan)

func ayni_binek(a: int, b: int) -> bool:
	return int(duraklar[a]["grup"]) >= 0 and duraklar[a]["grup"] == duraklar[b]["grup"]

func ziplanabilir_mi(a: int, b: int) -> bool:
	var ustten: float = float(duraklar[b]["ust"]) - float(duraklar[a]["ust"])
	var m := menzil(ustten)
	if m < 0.0:
		return false
	if yatay_mesafe(duraklar[a]["aabb"], duraklar[b]["aabb"]) > m:
		return false
	return kalkis_noktasi(a, b, m) != null

## Kalkış noktası dikenin içindeyse orada durulamaz. "En yakın nokta"ya bakmak
## yanlış cevap veriyor: bölüm 1'de basamak taşları dikenli tarlanın ÜSTÜNDE
## duruyor, zeminden en yakın nokta hep dikenin içinde kalıyor ve her kenar
## reddediliyordu — oysa oyuncu tarlanın kenarından atlıyor. Bu yüzden kaynak
## yüzeyin menzil içindeki GÜVENLİ noktaları taranıyor; bulunan nokta botun
## koşacağı yer.
func kalkis_noktasi(a: int, b: int, m := -1.0) -> Variant:
	var anahtar := a * 1000 + b
	if _kalkis_onbellek.has(anahtar):
		return _kalkis_onbellek[anahtar]
	var sonuc: Variant = _kalkis_hesapla(a, b, m)
	_kalkis_onbellek[anahtar] = sonuc
	return sonuc

func _kalkis_hesapla(a: int, b: int, m: float) -> Variant:
	if m < 0.0:
		m = menzil(float(duraklar[b]["ust"]) - float(duraklar[a]["ust"]))
		if m < 0.0:
			return null
	var kaynak: AABB = duraklar[a]["aabb"]
	var hedef: AABB = duraklar[b]["aabb"]
	var y: float = float(duraklar[a]["ust"]) + 0.5

	var en_iyi: Variant = null
	var en_iyi_mesafe := 1e9
	var x0 := maxf(kaynak.position.x, hedef.position.x - m)
	var x1 := minf(kaynak.position.x + kaynak.size.x, hedef.position.x + hedef.size.x + m)
	var z0 := maxf(kaynak.position.z, hedef.position.z - m)
	var z1 := minf(kaynak.position.z + kaynak.size.z, hedef.position.z + hedef.size.z + m)
	if x1 < x0 or z1 < z0:
		return null
	const ADIM := 0.5
	var x := x0
	while x <= x1 + 0.001:
		var z := z0
		while z <= z1 + 0.001:
			var nokta := Vector3(x, y, z)
			var d := noktadan_mesafe(nokta, hedef)
			if d <= m and not tuzakta_mi(nokta) and d < en_iyi_mesafe:
				en_iyi_mesafe = d
				en_iyi = Vector3(x, float(duraklar[a]["ust"]), z)
			z += ADIM
		x += ADIM
	return en_iyi

# ---------------------------------------------------------------------- arama

## Doğuştan zıplayarak ulaşılabilen durakların kümesi.
func erisim_kumesi(baslangic: int) -> Dictionary:
	var ulasilan := {baslangic: true}
	var kuyruk: Array[int] = [baslangic]
	while not kuyruk.is_empty():
		var su: int = kuyruk.pop_front()
		for hedef in duraklar.size():
			if ulasilan.has(hedef):
				continue
			if ayni_binek(su, hedef) or ziplanabilir_mi(su, hedef):
				ulasilan[hedef] = true
				kuyruk.append(hedef)
	return ulasilan

## En az adımlı yol (durak indeksleri, başlangıç dâhil). Yol yoksa boş dizi.
func yol(baslangic: int, hedef: int) -> Array[int]:
	if baslangic == hedef:
		return [baslangic] as Array[int]
	var onceki := {baslangic: -1}
	var kuyruk: Array[int] = [baslangic]
	while not kuyruk.is_empty():
		var su: int = kuyruk.pop_front()
		for sonraki in duraklar.size():
			if onceki.has(sonraki):
				continue
			if not (ayni_binek(su, sonraki) or ziplanabilir_mi(su, sonraki)):
				continue
			onceki[sonraki] = su
			if sonraki == hedef:
				var ters: Array[int] = [hedef]
				var g: int = su
				while g != -1:
					ters.append(g)
					g = onceki[g]
				ters.reverse()
				return ters
			kuyruk.append(sonraki)
	return [] as Array[int]

# -------------------------------------------------------------------- konumlar

## Verilen konumun altındaki durak. EN YÜKSEK yüzey seçiliyor, en yakını değil:
## bölüm 2'de bitiş hem kule gövdesinin hem tepe platformunun üstünde kalıyor;
## üstünde DURULAN yüzey tepe platformu.
func altindaki_durak(konum: Vector3, pay := 0.6) -> int:
	var en_iyi := -1
	var en_iyi_ust := -1e9
	for i in duraklar.size():
		var aabb: AABB = duraklar[i]["aabb"]
		if konum.x < aabb.position.x - pay or konum.x > aabb.position.x + aabb.size.x + pay:
			continue
		if konum.z < aabb.position.z - pay or konum.z > aabb.position.z + aabb.size.z + pay:
			continue
		var fark: float = konum.y - float(duraklar[i]["ust"])
		if fark < -0.6 or fark > 3.2:
			continue
		if float(duraklar[i]["ust"]) > en_iyi_ust:
			en_iyi_ust = float(duraklar[i]["ust"])
			en_iyi = i
	return en_iyi

## Çiçek hangi durağın erişiminde? Üstünde durup zıplayarak alınabiliyorsa o.
func cicek_duragi(konum: Vector3) -> int:
	for i in duraklar.size():
		var d: Dictionary = duraklar[i]
		# Hareketli platformda çiçek yol boyunca herhangi bir yerde olabilir:
		# süpürülen alana bakılıyor.
		if noktadan_mesafe(konum, d["supurulen"]) > CICEK_YANAL:
			continue
		# Alt sınır yüzeyin ÜSTÜ değil ALTI: eğik rampanın eksen hizalı
		# kutusunda "üst" en yüksek köşe oluyor, rampanın ortasındaki çiçek
		# onun 1,5 m altında kalıyor ve "erişilemez" görünüyordu.
		var alt: float = minf(float(d["ust_min"]), d["supurulen"].position.y) - 0.6
		if konum.y >= alt and konum.y <= float(d["ust_max"]) + CICEK_ERISIM:
			return i
	return -1

## Verilen noktanın AYAK hizasında diken var mı? Dikey pencere, alt kattaki
## dikenin üst kattaki yürüyüşü engellememesi için.
func tuzak_ayakta_mi(nokta: Vector3, pencere := 1.2) -> bool:
	for t in tuzaklar:
		if nokta.x < t.position.x or nokta.x > t.end.x:
			continue
		if nokta.z < t.position.z or nokta.z > t.end.z:
			continue
		if nokta.y > t.end.y + pencere or nokta.y < t.position.y - pencere:
			continue
		return true
	return false

func tuzakta_mi(nokta: Vector3) -> bool:
	for t in tuzaklar:
		if t.grow(0.01).has_point(nokta):
			return true
	return false

func noktadan_mesafe(nokta: Vector3, kutu: AABB) -> float:
	var dx := maxf(0.0, maxf(kutu.position.x - nokta.x, nokta.x - kutu.position.x - kutu.size.x))
	var dz := maxf(0.0, maxf(kutu.position.z - nokta.z, nokta.z - kutu.position.z - kutu.size.z))
	return sqrt(dx * dx + dz * dz)

func yatay_mesafe(a: AABB, b: AABB) -> float:
	var dx := maxf(0.0, maxf(a.position.x - (b.position.x + b.size.x),
		b.position.x - (a.position.x + a.size.x)))
	var dz := maxf(0.0, maxf(a.position.z - (b.position.z + b.size.z),
		b.position.z - (a.position.z + a.size.z)))
	return sqrt(dx * dx + dz * dz)

## Durağın üst yüzeyinde, verilen noktaya en yakın yer. Hedef olarak merkez
## yerine bunu kullanmak, bot geniş bir platformun ortasına değil KENARINA
## yöneldiği için hem kısa yol hem de daha az "yan duvara yürüme" demek.
func en_yakin_ust(i: int, nokta: Vector3) -> Vector3:
	var aabb: AABB = duraklar[i]["aabb"]
	return Vector3(
		clampf(nokta.x, aabb.position.x + 0.3, aabb.position.x + aabb.size.x - 0.3),
		float(duraklar[i]["ust"]),
		clampf(nokta.z, aabb.position.z + 0.3, aabb.position.z + aabb.size.z - 0.3))

## Durağın üstündeki, kenarından `pay` kadar içeride bir nokta.
func merkez(i: int) -> Vector3:
	var aabb: AABB = duraklar[i]["aabb"]
	return Vector3(aabb.position.x + aabb.size.x * 0.5, float(duraklar[i]["ust"]),
		aabb.position.z + aabb.size.z * 0.5)

# -------------------------------------------------------------------- yardım

func _betik_yolu(dugum: Node) -> String:
	var betik: Script = dugum.get_script() as Script
	return betik.resource_path if betik != null else ""

## Gövdenin çarpışma kutusu(ları), dünya uzayında eksen hizalı.
##
## EĞİK PLATFORM PARÇALANIYOR. Bir rampanın tamamını tek eksen hizalı kutuyla
## temsil etmek, "üst"ü en yüksek köşe yapıyor: bölüm 1'in 18° eğimli rampası
## zeminden 4,1 m yukarıda görünüyor ve "zıplanamaz" çıkıyordu — oysa alçak
## ucundan yürüyerek çıkılıyor. Bot bu yüzden rampayı bulamayıp taşlara geri
## dönüyor ve dikene düşüyordu. Eğik kutu, eğim ekseni boyunca parçalara
## bölünüyor; her parçanın kendi yüksekliği oluyor.
func _kutular(govde: Node3D) -> Array[AABB]:
	var sonuc: Array[AABB] = []
	for cocuk: Node in govde.get_children():
		var sekil := cocuk as CollisionShape3D
		if sekil == null or not (sekil.shape is BoxShape3D):
			continue
		var olcu: Vector3 = (sekil.shape as BoxShape3D).size
		var d: Transform3D = govde.global_transform * sekil.transform
		var b: Basis = d.basis
		# Üst yüzü yataysa tek kutu yeter.
		if absf(b.y.normalized().dot(Vector3.UP)) > 0.999:
			sonuc.append(_kutu(d, Vector3.ZERO, olcu))
			return sonuc
		# Eğim hangi eksende? Dünya-Y'ye daha çok bulaşan yerel eksen.
		var eksen := 0 if absf(b.x.normalized().y) > absf(b.z.normalized().y) else 2
		var uzunluk: float = olcu.x if eksen == 0 else olcu.z
		var adet := clampi(int(ceil(uzunluk / 2.0)), 1, 6)
		for i in adet:
			var oran := (float(i) + 0.5) / float(adet) - 0.5
			var kayma := Vector3.ZERO
			kayma[eksen] = uzunluk * oran
			var parca := olcu
			parca[eksen] = uzunluk / float(adet)
			sonuc.append(_kutu(d, kayma, parca))
		return sonuc
	return sonuc

## Dönüşüm altındaki kutunun köşelerinden eksen hizalı sınır.
func _kutu(d: Transform3D, merkez: Vector3, olcu: Vector3) -> AABB:
	var yari := olcu * 0.5
	var en_kucuk := Vector3.INF
	var en_buyuk := -Vector3.INF
	for i in 8:
		var kose := Vector3(
			yari.x if (i & 1) else -yari.x,
			yari.y if (i & 2) else -yari.y,
			yari.z if (i & 4) else -yari.z)
		var nokta := d * (merkez + kose)
		en_kucuk = en_kucuk.min(nokta)
		en_buyuk = en_buyuk.max(nokta)
	return AABB(en_kucuk, en_buyuk - en_kucuk)

func _tum_dugumler(kok: Node) -> Array[Node]:
	var sonuc: Array[Node] = []
	var yigin: Array[Node] = [kok]
	while not yigin.is_empty():
		var d: Node = yigin.pop_back()
		sonuc.append(d)
		for c in d.get_children():
			yigin.append(c)
	return sonuc
