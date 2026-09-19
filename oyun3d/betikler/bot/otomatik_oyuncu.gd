class_name OtomatikOyuncu
extends Node
## Bölümü gerçekten oynayan bot.
##
## NEDEN VAR: Faz 9'un bıraktığı tek açık madde "bölümler oynanarak
## dengelenmedi"ydi. `bolum_hatti_testi` bölümün bitirilebilir olduğunu
## HESAPLIYOR; bu bot OYNUYOR. İkisi farklı sorular:
##
##   hesap  → "bu boşluk 4,2 m, menzil 6,4 m, geçilir"
##   oyun   → "bu boşluğu geçmek üç denemede bir tutuyor"
##
## İkincisi denge bilgisidir ve ancak oynayarak çıkar. Bot insan oyun testinin
## yerini TUTMAZ (eğlence ölçmüyor), ama sayıları üretir: bitirme süresi, ölüm
## sayısı, hangi geçişte kaç kez denendi.
##
## BOT MÜKEMMEL OYNAMAZ, ÖLÇER. Her çiçek için sınırlı bir bütçesi var; o süre
## içinde alamadığı çiçeği "zor" diye işaretleyip yoluna devam ediyor. Amaç
## bölümü %100 bitirmek değil, NERENİN zor olduğunu söylemek — botun beş kez
## deneyip alamadığı çiçek, insanın da zorlanacağı yerdir. Bu yüzden başarı
## ölçütü "hepsini topladı" değil, "bitişe ulaştı + kaç çiçek".
##
## NASIL OYNUYOR: gerçek girdiyle. `Input.action_press("ileri")` basıyor ve
## kamerayı hedefe çeviriyor — oyuncu kodu, girdinin bottan mı klavyeden mi
## geldiğini bilmiyor. Karakteri doğrudan ışınlayan bir "bot" hiçbir şey
## kanıtlamazdı: zıplama hissi, coyote süresi, hava kontrolü ölçülmemiş olurdu.

signal bitti(rapor: Dictionary)

## Bölüm başına en fazla oyun-içi süre. Aşılırsa bot pes ediyor ve nerede
## takıldığını yazıyor — sonsuza kadar denemesi CI'ı kilitler.
const AZAMI_SURE := 110.0
## Bir geçiş için en fazla deneme. Fazlası "bu geçiş bota göre çok zor".
const AZAMI_DENEME := 6
## Geçiş başına süre sınırı (saniye).
const GECIS_SURESI := 12.0
## Hedefe bu kadar yaklaşınca varılmış sayılıyor.
const VARIS_YARICAPI := 0.7

var _oyuncu: CharacterBody3D
var _oyun: Node
var _kol: SpringArm3D
var graf: BolumGrafi

var _sira: Array[int] = []        ## sırayla uğranacak duraklar
var _su_durak := -1
var _hedef_sira := 0
var _yol: Array[int] = []         ## şu anki durağa göre hesaplanmış yol
var _gecis_suresi := 0.0
var _deneme := 0
var _ziplama_kalan := 0.0
var _cicek_hedefi: Node3D = null
var _son_konum := Vector3.ZERO
var _plan_sayisi := 0
## Bu geçiş için hızlanma mesafesine gidildi mi?
var _hizlandi := false
var _duraganlik := 0.0

## Ayrıntılı kütük: bot nerede ne yapıyor? Bölüm tasarlarken açılıyor.
var ayrintili := false
var _sayac := 0

var _rapor := {
	"bitti": false, "bitise_ulasti": false, "sure": 0.0, "olum": 0,
	"ziplama": 0, "toplanan": 0, "hedef": 0, "zorlanan": [], "zor_cicek": [],
	"takildi": "",
}

## Uğrak başına bütçe. Aşılınca oradaki çiçekler "zor" diye işaretlenip
## geçiliyor. Bütçe ÇİÇEK başına değil UĞRAK başına, çünkü kaybedilen zamanın
## çoğu çiçeğin başında değil oraya giderken (düşüp geri tırmanırken) harcanıyor
## — çiçek başına saysaydık sayaç her düşüşte sıfırlanır ve bot sonsuza kadar
## denerdi.
const UGRAK_SURESI := 16.0
## Bitiş ayağı daha cömert: oradaki tek soru "bölüm bitirilebiliyor mu".
const BITIS_SURESI := 50.0
var _ugrak_butce := {}
var _atlanan := {}
var _bitis_duragi := -1

func kur(bolum: Node3D) -> void:
	graf = BolumGrafi.kur(bolum)
	_oyuncu = graf.oyuncu as CharacterBody3D
	_oyun = bolum.get_node_or_null("Oyun")
	_kol = _oyuncu.get_node_or_null("KameraKolu")
	_oyuncu.olduruldu.connect(_olunce)
	_su_durak = graf.altindaki_durak(_oyuncu.global_position)
	_bitis_duragi = graf.altindaki_durak(graf.bitis.global_position)
	_sirayi_kur()
	_rapor["hedef"] = graf.cicekler.size()

## Uğrak sırası: çiçekler doğuşa uzaklığına göre, sonra bitiş. Çiçeklerin hepsi
## toplanmadan bitiş açılmıyor, yani hepsi rotanın parçası.
func _sirayi_kur() -> void:
	var derinlik := _derinlikler(maxi(_su_durak, 0))
	var cicek_duraklari: Array[int] = []
	for cicek in graf.cicekler:
		if not is_instance_valid(cicek) or _atlanan.has(cicek):
			continue   # toplanmış ya da "zor" diye geçilmiş
		var d := graf.cicek_duragi(cicek.global_position)
		if d >= 0 and not cicek_duraklari.has(d):
			cicek_duraklari.append(d)
	cicek_duraklari.sort_custom(func(a: int, b: int) -> bool:
		return int(derinlik.get(a, 999)) < int(derinlik.get(b, 999)))
	_sira = cicek_duraklari
	var son := graf.altindaki_durak(graf.bitis.global_position)
	if son >= 0:
		_sira.append(son)

## Hâlâ hedeflenebilir çiçek sayısı (toplanmamış ve "zor" diye geçilmemiş).
func _kalan_cicek() -> int:
	var sayi := 0
	for cicek in graf.cicekler:
		if is_instance_valid(cicek) and not _atlanan.has(cicek):
			sayi += 1
	return sayi

func _derinlikler(baslangic: int) -> Dictionary:
	var sonuc := {baslangic: 0}
	var kuyruk: Array[int] = [baslangic]
	while not kuyruk.is_empty():
		var su: int = kuyruk.pop_front()
		for hedef in graf.duraklar.size():
			if sonuc.has(hedef):
				continue
			if graf.ayni_binek(su, hedef) or graf.ziplanabilir_mi(su, hedef):
				sonuc[hedef] = int(sonuc[su]) + 1
				kuyruk.append(hedef)
	return sonuc

func _physics_process(delta: float) -> void:
	if _oyuncu == null or _rapor["bitti"] or not _rapor["takildi"].is_empty():
		return
	_rapor["sure"] = float(_oyun.sure) if _oyun != null else 0.0
	if _oyun != null and _oyun.bitti:
		_rapor["bitise_ulasti"] = true
		_bitir(true)
		return
	# Bitiş alanına varmak, bölümü bitirmekten ayrı ölçülüyor: çiçeklerin hepsi
	# alınmadan bitiş açılmıyor ama "buraya kadar gelebildim" yine de bilgi.
	if graf.bitis != null and _oyuncu.is_on_floor():
		var b := graf.bitis.global_position
		if Vector2(b.x - _oyuncu.global_position.x,
				b.z - _oyuncu.global_position.z).length() < 2.5 \
				and absf(b.y - _oyuncu.global_position.y) < 3.0:
			_rapor["bitise_ulasti"] = true
			if _kalan_cicek() == 0 or _atlanan.size() > 0:
				_bitir(_oyun != null and _oyun.bitti)
				return
	if float(_rapor["sure"]) > AZAMI_SURE:
		_pes_et("süre doldu")
		return
	if _hedef_sira >= _sira.size():
		# Rota bitti ama bölüm bitmedi: kalan çiçek varsa rotayı yeniden kur.
		# İlk rota doğuş noktasına göre kurulmuştu; bot artık başka yerde ve
		# atlanan çiçek başka bir sırayla toplanabilir.
		if _kalan_cicek() > 0 and _plan_sayisi < 3:
			_plan_sayisi += 1
			_sirayi_kur()
			_hedef_sira = 0
			return
		# Rota tükendi: kalan çiçek yoksa bitişe yönel, varsa zor işaretle.
		var son := graf.altindaki_durak(graf.bitis.global_position)
		if son >= 0 and _su_durak != son:
			_sira = [son] as Array[int]
			_hedef_sira = 0
			return
		_pes_et("%d çiçek kaldı, rota tükendi" % _kalan_cicek())
		return

	if _ziplama_kalan > 0.0:
		_ziplama_kalan -= delta
		if _ziplama_kalan <= 0.0:
			Input.action_release("ziplama")

	_konumu_tazele()
	_takilmayi_izle(delta)
	_sayac += 1
	if ayrintili and _sayac % 60 == 0:
		var ad: String = graf.duraklar[_su_durak]["ad"] if _su_durak >= 0 else "havada"
		var hedef_ad := "-"
		if _hedef_sira < _sira.size():
			hedef_ad = graf.duraklar[_sira[_hedef_sira]]["ad"]
		print("  %5.1f sn  durak=%-12s hedef=%-12s cicek=%d/%d konum=%s" % [
			_rapor["sure"], ad, hedef_ad, _oyun.toplanan if _oyun else 0,
			graf.cicekler.size(), _kisa(_oyuncu.global_position)])
	# TUZAK: ölümden sonra oyuncu havada doğuyor ve hangi durakta olduğu
	# bilinmiyor. Eksi indeksle devam etmek sessizce yanlış cevap veriyordu —
	# GDScript'te `duraklar[-1]` son elemanı döndürüyor, yani bot kendini
	# listedeki SON durakta sanıp "yol yok" diyordu. Yere değene kadar bekle.
	if _su_durak < 0:
		_dur()
		return
	var hedef_durak: int = _sira[_hedef_sira]
	_ugrak_butce[hedef_durak] = float(_ugrak_butce.get(hedef_durak, 0.0)) + delta
	var butce := BITIS_SURESI if hedef_durak == _bitis_duragi else UGRAK_SURESI
	if float(_ugrak_butce[hedef_durak]) > butce:
		_ugragi_birak(hedef_durak)
		return

	# ÖNCE BURADAKİNİ TOPLA. Rota "hangi durağa uğranacak" sırası veriyor ama
	# bot yolda başka durakların üstünden geçiyor; oradaki çiçeği almadan
	# geçerse sonradan geri dönmek zorunda kalıyor ve bölüm iki katı sürüyordu.
	# İnsan da öyle oynar: ayağının altındakini alır.
	#
	# Aynı hareketli platformun iki duruşu tek yer sayılıyor: platform seni
	# taşırken "hedef duruş geride kaldı" deyip geri dönmek, botun çiçeği
	# alamadan platformdan inmesi demekti.
	if _su_durak == hedef_durak or graf.ayni_binek(_su_durak, hedef_durak) \
			or _duraktaki_cicek(_su_durak) != null:
		_ugrakta_calis(delta)
		return

	_gecis_suresi += delta
	if _gecis_suresi > GECIS_SURESI:
		_gecis_basarisiz("süre")
		return
	_gecise_calis(hedef_durak)

## Oyuncunun hangi durakta olduğunu takip ediyor. Hareketli platformun üstünde
## duruyorsa durak, o platformun ŞU ANKİ konumuna en yakın duruş.
func _konumu_tazele() -> void:
	if not _oyuncu.is_on_floor():
		return
	var zemin := _zemin_dugumu()
	if zemin != null and zemin is AnimatableBody3D:
		var en_iyi := -1
		var en_iyi_mesafe := 1e9
		for i in graf.duraklar.size():
			if graf.duraklar[i]["dugum"] != zemin:
				continue
			var m: float = graf.merkez(i).distance_to(zemin.global_position)
			if m < en_iyi_mesafe:
				en_iyi_mesafe = m
				en_iyi = i
		if en_iyi >= 0:
			_durak_degisti(en_iyi)
		return
	var durak := graf.altindaki_durak(_oyuncu.global_position, 0.2)
	if durak >= 0:
		_durak_degisti(durak)

## TAKILMA: bot ileri basıyor ama yerinden oynamıyorsa önünde bir şey var
## (rampanın yan duvarı, platform kenarı). Gerçek oyuncu ne yaparsa onu yap —
## önce zıpla, geçmiyorsa başka yol dene. Bu olmadan bot duvara bakıp
## süre dolana kadar bekliyordu.
func _takilmayi_izle(delta: float) -> void:
	var yol_alindi := _oyuncu.global_position.distance_to(_son_konum)
	_son_konum = _oyuncu.global_position
	if yol_alindi > 0.04 or not _oyuncu.is_on_floor():
		_duraganlik = 0.0
		return
	_duraganlik += delta
	if _duraganlik > 0.8:
		_zipla(0.6)
	if _duraganlik > 3.0:
		_duraganlik = 0.0
		_gecis_basarisiz("takıldı")

func _durak_degisti(yeni: int) -> void:
	if yeni == _su_durak:
		return
	_su_durak = yeni
	_gecis_suresi = 0.0
	_deneme = 0
	_yol = []
	_hizlandi = false

func _zemin_dugumu() -> Node:
	for i in _oyuncu.get_slide_collision_count():
		var carpisma := _oyuncu.get_slide_collision(i)
		if carpisma.get_normal().y > 0.7:
			return carpisma.get_collider()
	return null

# ---------------------------------------------------------------- uğrakta iş

## Durağa varıldı: buradaki çiçekleri topla, sonra sıradaki durağa geç.
func _ugrakta_calis(delta: float) -> void:
	_gecis_suresi += delta
	if _cicek_hedefi == null or not is_instance_valid(_cicek_hedefi) \
			or not _burada_mi(_cicek_hedefi):
		_cicek_hedefi = _duraktaki_cicek(_su_durak)

	if _cicek_hedefi != null:
		var hedef := _cicek_hedefi.global_position
		# Hareketli platformun taşıdığı çiçek: platformun üstünde çiçeğe doğru
		# yürümek onu platformdan indiriyor. Doğrusu, platform ÜSTÜNDE çiçeğin
		# hizasına geçip taşınmayı beklemek. Bot eskiden çiçek yaklaşınca
		# koşmaya başlıyor ve pencereyi kaçırıyordu; şimdi hizaya baştan
		# giriyor ve platform onu çiçeğin altından geçiriyor.
		var platform: Node3D = graf.duraklar[_su_durak]["dugum"]
		if platform != null:
			var hiza := Vector3(hedef.x, _oyuncu.global_position.y,
				platform.global_position.z)
			# Platformun dışına taşma: kutunun içinde kal.
			var kutu: AABB = graf.duraklar[_su_durak]["aabb"]
			hiza.x = clampf(hiza.x, platform.global_position.x - kutu.size.x * 0.5 + 0.35,
				platform.global_position.x + kutu.size.x * 0.5 - 0.35)
			hiza.z = clampf(hiza.z, platform.global_position.z - kutu.size.z * 0.5 + 0.35,
				platform.global_position.z + kutu.size.z * 0.5 - 0.35)
			if Vector2(hiza.x - _oyuncu.global_position.x,
					hiza.z - _oyuncu.global_position.z).length() > 0.25:
				_yuru(hiza, false)
			else:
				_dur()
			return
		_yuru(hedef, false)
		# Yüksekteki çiçek için zıplamak gerekiyor.
		var yatay := Vector2(hedef.x - _oyuncu.global_position.x,
			hedef.z - _oyuncu.global_position.z).length()
		if yatay < 1.6 and hedef.y - _oyuncu.global_position.y > 1.1:
			_zipla(0.6)
		if _gecis_suresi > GECIS_SURESI:
			# Çiçek alınamıyor: bölüm bitirilemez ama nerede takıldığı yazılsın.
			_pes_et("çiçek alınamadı: %s" % _kisa(hedef))
		return

	# Bitiş durağındayız ve çiçek kalmadı: bitiş alanına kadar yürü. Platformun
	# kenarında durup "geldim" saymak, bitişe ulaşıldığını kanıtlamıyor.
	if _su_durak == _bitis_duragi and graf.bitis != null:
		var b := graf.bitis.global_position
		if Vector2(b.x - _oyuncu.global_position.x,
				b.z - _oyuncu.global_position.z).length() > 1.0:
			_yuru(Vector3(b.x, _oyuncu.global_position.y, b.z), false)
			return

	# Bu durakta iş kalmadı. Rotadaki bir sonraki durağın çiçeği çoktan
	# toplanmış olabilir (yoldan geçerken alınmıştır): boş uğrakları atla.
	while _hedef_sira < _sira.size() - 1 \
			and _duraktaki_cicek(_sira[_hedef_sira]) == null \
			and _sira[_hedef_sira] != _sira[_sira.size() - 1]:
		_hedef_sira += 1
	_hedef_sira += 1
	_gecis_suresi = 0.0
	_deneme = 0
	_yol = []
	if _hedef_sira < _sira.size() and _sira[_hedef_sira] == _su_durak:
		_hedef_sira += 1

## Çiçek şu an bulunduğumuz durağın (ya da aynı hareketli platformun öbür
## duruşunun) erişiminde mi? Duruşları ayrı saymak, platformun taşıdığı çiçeği
## "başka durakta" gösterip botun onu atlamasına yol açıyordu.
func _burada_mi(cicek: Node3D) -> bool:
	if not is_instance_valid(cicek):
		return false
	var d := graf.cicek_duragi(cicek.global_position)
	return d >= 0 and (d == _su_durak or graf.ayni_binek(d, _su_durak))

## Uğrak bütçesi doldu: oradaki çiçekler bota göre çok zor. İşaretle, rapora
## yaz, sıradakine geç. Bu liste insan oyun testinde ilk bakılacak yerler.
func _ugragi_birak(durak: int) -> void:
	var isaretlenen := 0
	for cicek in graf.cicekler:
		if not is_instance_valid(cicek) or _atlanan.has(cicek):
			continue
		var d := graf.cicek_duragi(cicek.global_position)
		if d == durak or graf.ayni_binek(d, durak):
			_atlanan[cicek] = true
			isaretlenen += 1
			(_rapor["zor_cicek"] as Array).append("%s@%s" % [
				graf.duraklar[durak]["ad"], _kisa(cicek.global_position)])
	# Çiçeği olmayan uğrağın bütçesi dolduysa orası bitiş ayağıdır: bot oraya
	# ulaşamıyor demektir, sonsuza kadar denemesin.
	if isaretlenen == 0:
		_pes_et("'%s' durağına ulaşılamadı" % graf.duraklar[durak]["ad"])
		return
	_cicek_hedefi = null
	_hedef_sira += 1
	_yol = []
	_hizlandi = false

func _duraktaki_cicek(durak: int) -> Node3D:
	var en_iyi: Node3D = null
	var en_iyi_mesafe := 1e9
	for cicek in graf.cicekler:
		if not is_instance_valid(cicek) or not cicek.visible or _atlanan.has(cicek):
			continue
		var d := graf.cicek_duragi(cicek.global_position)
		if d < 0 or (d != durak and not graf.ayni_binek(d, durak)):
			continue
		var m: float = cicek.global_position.distance_to(_oyuncu.global_position)
		if m < en_iyi_mesafe:
			en_iyi_mesafe = m
			en_iyi = cicek
	return en_iyi

# ------------------------------------------------------------------- geçişler

func _gecise_calis(hedef_durak: int) -> void:
	if _yol.is_empty():
		_yol = graf.yol(_su_durak, hedef_durak)
		if _yol.size() < 2:
			_pes_et("'%s'(#%d) durağından '%s'(#%d) durağına yol yok — oyuncu %s" % [
				graf.duraklar[_su_durak]["ad"], _su_durak,
				graf.duraklar[hedef_durak]["ad"], hedef_durak,
				_kisa(_oyuncu.global_position)])
			return
	var sonraki: int = _yol[1]

	# Hareketli platforma binmek: zıplamak değil BEKLEMEK. Platform hedef
	# duruşa yaklaşana kadar duruyoruz — botun öğrendiği tek "sabır".
	if graf.ayni_binek(_su_durak, sonraki):
		_dur()
		return

	# ÜSTÜNDE DURDUĞUMUZ PLATFORM HAREKETLİYSE, İNMEK DE BEKLEMEK İSTER.
	# Kalkış noktası dünyada sabit bir nokta; platform başka yerdeyken oraya
	# yürümek platformdan inmek demek. Bot bölüm 3'ün sonunda tam bunu yapıyor,
	# asansörden düşüp ölüyor ve baştan tırmanıyordu.
	var bindigimiz: Node3D = graf.duraklar[_su_durak]["dugum"]
	if bindigimiz != null:
		var kendi_durus := graf.merkez(_su_durak)
		var sapma := Vector2(bindigimiz.global_position.x - kendi_durus.x,
			bindigimiz.global_position.z - kendi_durus.z).length()
		if sapma > 1.0:
			_dur()
			return

	var kalkis: Variant = graf.kalkis_noktasi(_su_durak, sonraki)
	if kalkis == null:
		_gecis_basarisiz("kalkış noktası yok")
		return
	var nokta: Vector3 = kalkis
	var varis := graf.en_yakin_ust(sonraki, _oyuncu.global_position)
	var yatay := Vector2(nokta.x - _oyuncu.global_position.x,
		nokta.z - _oyuncu.global_position.z).length()
	var bosluk := graf.yatay_mesafe(graf.duraklar[_su_durak]["aabb"],
		graf.duraklar[sonraki]["aabb"])
	var ustten: float = float(graf.duraklar[sonraki]["ust"]) - float(graf.duraklar[_su_durak]["ust"])

	# HAVADAYKEN HEDEFE YÖNEL. Burada eskiden kalkış noktasına yöneliyordu:
	# zıpladıktan sonra kalkış noktası ARKADA kalıyor, bot havada geri
	# dönüyor ve her seferinde dikene düşüyordu. Zıplamanın yarısı havada
	# yönlendirmektir (hava ivmesi 22 m/sn²) — bot da onu kullanmalı.
	if not _oyuncu.is_on_floor():
		_yuru(varis, bosluk > 2.5)
		return

	# Hareketli platforma atlıyorsak platform o duruşa gelene kadar bekle.
	# Platform o duruşa gelmeden atlamak boşluğa atlamaktır. İki koşul birden
	# aranıyor: platform duruşa YAKIN ve ona doğru YAKLAŞIYOR olmalı.
	#
	# Yalnızca "yakın" bakmak yetmiyordu: zıplama ~1 saniye sürüyor, platform o
	# sırada uzaklaşıyorsa bot platformun BULUNDUĞU yere değil BULUNDUĞU yerin
	# arkasına düşüyor ve her turda aşağı uçuyordu. Yaklaşırken zıplayınca
	# platform, bot inerken duruşa varmış oluyor.
	if graf.duraklar[sonraki]["dugum"] != null and yatay < VARIS_YARICAPI + 0.5:
		var platform: Node3D = graf.duraklar[sonraki]["dugum"]
		var durus := graf.merkez(sonraki)
		var uzaklik := Vector2(platform.global_position.x - durus.x,
			platform.global_position.z - durus.z).length()
		if uzaklik > 1.6 or not _yaklasiyor(platform, durus):
			_dur()
			return

	# HIZLANMA MESAFESİ. Bot eskiden kalkış noktasına gelip orada duruyor,
	# sonra hedefe dönüp zıplıyordu: yatay hız neredeyse sıfırken zıplamak,
	# boşluğun yarısına düşmek demek. Gerçek oyuncu koşarak gelir ve kenarı
	# hızla terk eder. Bu yüzden kalkış noktasının ARKASINDA bir hazırlık
	# noktası seçiliyor; bot önce oraya gidiyor, sonra hedefe doğru koşup
	# kenarda zıplıyor.
	var yon := (varis - nokta)
	yon.y = 0.0
	if yon.length_squared() > 0.0001:
		yon = yon.normalized()
	var kaynak_kutu: AABB = graf.duraklar[_su_durak]["aabb"]
	var hazirlik := nokta - yon * minf(2.4, maxf(bosluk, 1.2))
	hazirlik.x = clampf(hazirlik.x, kaynak_kutu.position.x + 0.3,
		kaynak_kutu.position.x + kaynak_kutu.size.x - 0.3)
	hazirlik.z = clampf(hazirlik.z, kaynak_kutu.position.z + 0.3,
		kaynak_kutu.position.z + kaynak_kutu.size.z - 0.3)

	if not _hizlandi:
		var hazir_uzaklik := Vector2(hazirlik.x - _oyuncu.global_position.x,
			hazirlik.z - _oyuncu.global_position.z).length()
		# Hazırlık noktası dikenin içindeyse (dar taşta olabilir) atla.
		if hazir_uzaklik > 0.6 and not graf.tuzakta_mi(hazirlik + Vector3(0, 0.3, 0)):
			_yuru(hazirlik, false)
			return
		_hizlandi = true

	if yatay > VARIS_YARICAPI:
		# Artık doğru yönden ve koşarak geliyoruz.
		_yuru(varis, true)
		return

	# Kenardayız ve hızlıyız: zıpla.
	_yuru(varis, bosluk > 2.0)
	if _oyuncu.is_on_floor():
		_zipla(0.6 if (ustten > 0.5 or bosluk > 2.0) else 0.18)

## Platform hedef duruşa doğru mu gidiyor? Bir kare öncesine göre bakıyoruz;
## platformun hızını dışarıdan okumak (AnimatableBody3D) güvenilir değil.
var _platform_onceki := {}

func _yaklasiyor(platform: Node3D, durus: Vector3) -> bool:
	var su := platform.global_position
	var onceki: Vector3 = _platform_onceki.get(platform, su)
	_platform_onceki[platform] = su
	var yon := su - onceki
	if yon.length_squared() < 1e-8:
		return true   # duruyor: beklemenin anlamı yok
	return yon.dot(durus - su) > 0.0

func _gecis_basarisiz(neden: String) -> void:
	_deneme += 1
	_gecis_suresi = 0.0
	_yol = []
	_hizlandi = false
	var ad: String = graf.duraklar[_su_durak]["ad"] if _su_durak >= 0 else "?"
	if _deneme >= AZAMI_DENEME:
		_pes_et("'%s' durağından ilerlenemedi (%s)" % [ad, neden])
		return
	# Zorlanma denge bilgisi: hangi geçiş kaç denemede tuttu?
	var zorlanan: Array = _rapor["zorlanan"]
	for kayit in zorlanan:
		if kayit["durak"] == ad:
			kayit["deneme"] = _deneme
			return
	zorlanan.append({"durak": ad, "deneme": _deneme})

# --------------------------------------------------------------------- girdi

## Kamerayı hedefe çevirip "ileri" basıyor. Oyuncu kodu hareketi kameraya göre
## çözdüğü için bot da insan gibi "baktığı yöne" yürüyor.
func _yuru(hedef: Vector3, kos: bool) -> void:
	var fark := hedef - _oyuncu.global_position
	fark.y = 0.0
	if fark.length_squared() < 0.0004:
		_dur()
		return
	if _kol != null:
		_kol.rotation.y = atan2(-fark.x, -fark.z)
	# Önümüzde diken şeridi varsa KOŞARAK aş. Tek noktaya bakmak yetmiyordu:
	# bölüm 5'in şeritleri 3 m genişliğinde, bot şeridin başında zıplayıp
	# ortasına düşüyordu (41 ölüm). Şerit taranıp karşı kıyısı bulunuyor;
	# menzil içindeyse koşup zıplıyor, değilse graf zaten taşlardan geçiriyor.
	var yon := fark.normalized()
	# TUZAK: tarama noktası karakterin MERKEZİNDEN alınıyordu (y ≈ +0,9) ama
	# dikenli alanın kutusu 0–0,6 m arasında; test noktası hiçbir zaman dikenin
	# içine düşmüyor ve bot şeridin üstüne yürüyüp ölüyordu (bölüm 5'te 51
	# ölüm). Ayak hizasından bakmak gerekiyor.
	var ayak := _oyuncu.global_position - Vector3(0, 0.8, 0)
	if graf.tuzak_ayakta_mi(ayak + yon * 1.2):
		var karsi := -1.0
		var d := 1.2
		while d < 5.5:
			if not graf.tuzak_ayakta_mi(ayak + yon * d):
				karsi = d
				break
			d += 0.4
		if karsi > 0.0 and karsi < 4.6:
			kos = true
			if _oyuncu.is_on_floor() and graf.tuzak_ayakta_mi(ayak + yon * 1.7):
				_zipla(0.6)
	Input.action_press("ileri", 1.0)
	Input.action_release("geri")
	Input.action_release("sol")
	Input.action_release("sag")
	if kos:
		Input.action_press("kosma", 1.0)
	else:
		Input.action_release("kosma")

func _dur() -> void:
	for eylem in ["ileri", "geri", "sol", "sag", "kosma"]:
		Input.action_release(eylem)

func _zipla(sure: float) -> void:
	if _ziplama_kalan > 0.0 or not _oyuncu.is_on_floor():
		return
	Input.action_press("ziplama", 1.0)
	_ziplama_kalan = sure
	_rapor["ziplama"] = int(_rapor["ziplama"]) + 1

func _olunce() -> void:
	_rapor["olum"] = int(_rapor["olum"]) + 1
	_gecis_basarisiz("öldü")
	_su_durak = -1
	_cicek_hedefi = null

# --------------------------------------------------------------------- bitiş

func _bitir(basarili: bool) -> void:
	_rapor["bitti"] = basarili
	_rapor["toplanan"] = int(_oyun.toplanan) if _oyun != null else 0
	_dur()
	Input.action_release("ziplama")
	set_physics_process(false)
	bitti.emit(_rapor)

func _pes_et(neden: String) -> void:
	_rapor["takildi"] = neden
	_bitir(false)

func _kisa(v: Vector3) -> String:
	return "%.1f, %.1f, %.1f" % [v.x, v.y, v.z]
