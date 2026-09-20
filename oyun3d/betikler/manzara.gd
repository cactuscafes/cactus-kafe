class_name Manzara
extends Node3D
## Uzak manzara: ufuk çizgisi, tepeler ve serpiştirilen süsleme (Faz 13).
##
## SORUN: bölümün zemini 120-140 metrelik bir düzlem ve orada BİTİYOR. Kamera
## ufka baktığında düzlemin kenarı keskin bir çizgi olarak görünüyor, arkası
## boş gökyüzü. Oyun "bir masanın üstünde" geçiyormuş gibi duruyor.
##
## ÇÖZÜM ÜÇ KATMAN:
##   1. uzak zemin — oyun zemininin bittiği yeri kapatan geniş düzlem
##   2. tepeler    — ufukta tabakalı mesa siluetleri, sisle yıkanmış
##   3. serpinti   — kaya ve kaktüsler; dünyanın oyun alanında bitmediği hissi
##
## ÜÇÜ DE ÇARPIŞMASIZ. Bu bir süs değil kural: bölümün ulaşılabilirlik grafı
## (`betikler/bolum_grafi.gd`) çarpışma kutularından çıkıyor. Buraya çarpışma
## eklemek bölüm doğrulayıcısını ve botu sessizce yanıltırdı — "şuraya
## zıplanabiliyor" diyen bir kaya. `testler/manzara_testi` bunu doğruluyor.
##
## HER ÇALIŞTIRMADA AYNI: yerleşim tohumdan üretiliyor. Rastgele bir manzara
## her açılışta farklı görünürdü; ekran görüntüsü ve görsel testi de anlamını
## yitirirdi.
##
## SAHNEDE DEĞİL ÇALIŞMA ANINDA: 130 süsleme düğümünü .tscn'e yazmak dosyayı
## üçe katlardı ve kalite ön ayarına göre seyreltilemezdi.

## Yerleşimin tohumu — bölüm kimliğinden türetiliyor.
@export var tohum := 1
## Oyun alanının çevresinde boş bırakılan pay (metre): süsleme oyuncunun
## gittiği yere değil, ARKASINA konuyor.
@export var pay := 7.0
## Tepelerin halkası.
@export var tepe_ic := 115.0
@export var tepe_dis := 265.0
@export var tepe_sayisi := 24
## Serpiştirilen kaya/kaktüs sayısı (yüksek kalitede).
@export var kaya_sayisi := 90
@export var kaktus_sayisi := 40
## Serpintinin yarıçapı; oyun zemininin kenarını aşmamalı.
@export var serpinti_yaricap := 62.0
## Zemin baştan sona dikenliyse serpinti KAPALI: ölümcül zemine kaktüs
## dikmek "buraya basılabilir" diyor. Görsel süs, oynanış işaretini bozamaz.
@export var serpinti := true
@export var zemin_y := 0.0
@export var zemin_renk := Color(0.514, 0.545, 0.494)
## Tepeler zemin renginden biraz koyu ve sıcak: uzaklık zaten sisle geliyor.
@export var tepe_renk := Color(0.46, 0.42, 0.36)

const DUNYA_GOLGE := preload("res://golgeler/dunya.gdshader")
const KAYA := preload("res://varliklar/kaya.gltf")
const KAKTUS := preload("res://varliklar/kaktus.gltf")

func _ready() -> void:
	# Ayarlar panelinden gelen kalite değişikliği bu grubu geziyor.
	add_to_group("manzara")
	kalite_uygula()

## Manzarayı kalite ön ayarına göre yeniden kurar. Yerleşim tohumdan
## geldiği için aynı kalitede her zaman aynı manzara çıkıyor.
func kalite_uygula() -> void:
	# Başsız kipte hiçbir şey çizilmiyor. Bot (`araclar/denge_olc.gd`) altı
	# bölümü onlarca kez yeniden yüklüyor; her seferinde çizilmeyecek 130
	# süslemeyi kurmak denge ölçümünü kat kat yavaşlatıyordu. Manzaranın
	# DOĞRULANDIĞI yer pencereli koşan `testler/gorsel_testi`.
	if DisplayServer.get_name() == "headless":
		return
	for cocuk in get_children():
		cocuk.queue_free()
	var rng := RandomNumberGenerator.new()
	rng.seed = tohum
	var kalite: int = Ayarlar.grafik
	_uzak_zemin()
	_tepeler(rng, kalite)
	if kalite <= 0 or not serpinti:
		return   # düşük kalitede serpinti yok: en ucuz kalem burası
	var oran := 0.5 if kalite == 1 else 1.0
	var alan := _oyun_alani()
	_serpistir(rng, _mesh(KAYA), int(kaya_sayisi * oran), alan, 0.5, 1.9, "Kayalar")
	_serpistir(rng, _mesh(KAKTUS), int(kaktus_sayisi * oran), alan, 0.6, 1.3, "Kaktusler")

## Oyun zemininin bittiği yeri kapatan geniş düzlem. Tek parça, iki üçgen:
## ufku kapatmanın en ucuz yolu, arkasına da tepeler oturuyor.
func _uzak_zemin() -> void:
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(tepe_dis * 2.6, tepe_dis * 2.6)
	var dugum := MeshInstance3D.new()
	dugum.name = "UzakZemin"
	dugum.mesh = mesh
	# Oyun zemininin ALTINDA: aynı yükseklikte olsaydı z-çakışması (z-fighting)
	# titreşen çizgiler çıkarırdı.
	dugum.position = Vector3(0, zemin_y - 0.06, 0)
	dugum.material_override = _malzeme(zemin_renk.darkened(0.06), 0.15, 0.0, 0.0)
	dugum.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(dugum)

func _tepeler(rng: RandomNumberGenerator, kalite: int) -> void:
	var sayi := tepe_sayisi if kalite >= 1 else int(tepe_sayisi * 0.6)
	var coklu := MultiMesh.new()
	coklu.transform_format = MultiMesh.TRANSFORM_3D
	coklu.mesh = _mesa_mesh()
	coklu.instance_count = sayi
	for i in sayi:
		# Halka üzerinde eşit aralık + gürültü: tam rastgele açı seçilince
		# tepeler kümeleniyor ve ufkun bir yanı boş kalıyor.
		var aci := TAU * (float(i) + rng.randf_range(-0.35, 0.35)) / float(sayi)
		var uzaklik := rng.randf_range(tepe_ic, tepe_dis)
		# Yükseklik uzaklıkla artıyor: uzaktaki tepe aynı açısal büyüklüğü
		# koruyor, yakındaki ufku kapatmıyor. Üstel dağılım (karesi) birkaç
		# büyük, çok sayıda küçük tepe veriyor — düzgün dağılım ufku aynı
		# boyda kesilmiş bir duvara çeviriyordu.
		var t := rng.randf()
		var yukseklik := (4.0 + t * t * 15.0) * (uzaklik / tepe_ic)
		var genislik := rng.randf_range(12.0, 40.0)
		var temel := Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(
			Vector3(genislik, yukseklik, genislik))
		coklu.set_instance_transform(i, Transform3D(temel, Vector3(
			cos(aci) * uzaklik, zemin_y - 0.5, sin(aci) * uzaklik)))
	var dugum := MultiMeshInstance3D.new()
	dugum.name = "Tepeler"
	dugum.multimesh = coklu
	# Tabakalar açık: uzaktaki mesaya karakterini veren yatay çizgiler.
	dugum.material_override = _malzeme(tepe_renk, 0.12, 0.09, 0.16)
	dugum.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(dugum)

func _serpistir(rng: RandomNumberGenerator, mesh: Mesh, sayi: int, alan: AABB,
		en_kucuk: float, en_buyuk: float, ad: String) -> void:
	if mesh == null or sayi <= 0:
		return
	var genis := alan.grow(pay)
	var yerler: Array[Transform3D] = []
	# Reddetme örneklemesi: nokta oyun alanına düşerse atılıyor. Deneme sayısı
	# sınırlı — dar bölümlerde alan diski neredeyse doldurabiliyor.
	var deneme := 0
	while yerler.size() < sayi and deneme < sayi * 12:
		deneme += 1
		var a := rng.randf_range(0.0, TAU)
		# sqrt: düzgün dağılım. Doğrudan yarıçap seçilirse merkez kalabalıklaşır.
		var r := sqrt(rng.randf()) * serpinti_yaricap
		var nokta := Vector3(cos(a) * r, zemin_y, sin(a) * r)
		if genis.has_point(Vector3(nokta.x, genis.position.y + genis.size.y * 0.5, nokta.z)):
			continue
		var olcek := rng.randf_range(en_kucuk, en_buyuk)
		yerler.append(Transform3D(
			Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(Vector3.ONE * olcek),
			nokta))
	if yerler.is_empty():
		return
	var coklu := MultiMesh.new()
	coklu.transform_format = MultiMesh.TRANSFORM_3D
	coklu.mesh = mesh
	coklu.instance_count = yerler.size()
	for i in yerler.size():
		coklu.set_instance_transform(i, yerler[i])
	var dugum := MultiMeshInstance3D.new()
	dugum.name = ad
	dugum.multimesh = coklu
	# Gölge KAPALI: 130 küçük nesnenin gölgesi, gölge atlasının çözünürlüğünü
	# oyuncunun bastığı yerden çalıyor. Kazanç görünmüyor, bedeli görünüyor.
	dugum.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(dugum)

## Oyunun oynandığı hacim: bütün çarpışma kutularının sardığı kutu. Zemin
## hariç — zemin bütün bölümü kaplıyor, hesaba katılsa serpinti için yer
## kalmazdı.
func _oyun_alani() -> AABB:
	var kok := get_parent()
	var alan := AABB(global_position, Vector3.ZERO)
	var ilk := true
	if kok == null:
		return alan
	for dugum in kok.find_children("*", "CollisionShape3D", true, false):
		var sekil := dugum as CollisionShape3D
		if sekil.shape == null or _zeminin_mi(sekil):
			continue
		var kutu := sekil.shape as BoxShape3D
		var yari := (kutu.size * 0.5) if kutu != null else Vector3.ONE
		var merkez := sekil.global_position
		var parca := AABB(merkez - yari, yari * 2.0)
		alan = parca if ilk else alan.merge(parca)
		ilk = false
	return alan

## Şekil zeminin (ya da tuzak zemininin) parçası mı? Onlar bütün bölümü
## kaplıyor; oyun alanına dahil edilirse alan bütün dünya olur.
func _zeminin_mi(sekil: Node) -> bool:
	var d: Node = sekil
	while d != null and d != get_parent():
		if d.name == "Zemin" or d.name == "Tuzaklar":
			return true
		d = d.get_parent()
	return false

func _mesh(sahne: PackedScene) -> Mesh:
	var kok := sahne.instantiate()
	var bulunan: Mesh = null
	for dugum in kok.find_children("*", "MeshInstance3D", true, false):
		bulunan = (dugum as MeshInstance3D).mesh
		break
	kok.queue_free()
	return bulunan

## Mesa: tepesi düz, yanları hafif içe eğimli sekizgen prizma. Kutu kullanmak
## ufku dikdörtgenlerle doldururdu; sekizgen uzaktan "kaya" okunuyor.
func _mesa_mesh() -> ArrayMesh:
	var koseler := PackedVector3Array()
	var normaller := PackedVector3Array()
	const N := 8
	for i in N:
		var a0 := TAU * float(i) / float(N)
		var a1 := TAU * float(i + 1) / float(N)
		var alt0 := Vector3(cos(a0) * 0.5, 0.0, sin(a0) * 0.5)
		var alt1 := Vector3(cos(a1) * 0.5, 0.0, sin(a1) * 0.5)
		var ust0 := Vector3(cos(a0) * 0.34, 1.0, sin(a0) * 0.34)
		var ust1 := Vector3(cos(a1) * 0.34, 1.0, sin(a1) * 0.34)
		var n := (alt1 - alt0).cross(ust0 - alt0).normalized()
		for v in [alt0, alt1, ust1, alt0, ust1, ust0]:
			koseler.append(v)
			normaller.append(n)
		# Üst kapak: tepeden bakılmıyor ama güneş açısı alçakken siluette
		# eksikliği görünüyor.
		for v in [ust0, ust1, Vector3(0.0, 1.0, 0.0)]:
			koseler.append(v)
			normaller.append(Vector3.UP)
	var diziler := []
	diziler.resize(Mesh.ARRAY_MAX)
	diziler[Mesh.ARRAY_VERTEX] = koseler
	diziler[Mesh.ARRAY_NORMAL] = normaller
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, diziler)
	return mesh

func _malzeme(renk: Color, desen: float, tabaka: float, dip: float) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = DUNYA_GOLGE
	mat.set_shader_parameter("renk", renk)
	mat.set_shader_parameter("puruzluluk", 1.0)
	mat.set_shader_parameter("desen_olcek", 0.12)
	mat.set_shader_parameter("desen_gucu", desen)
	mat.set_shader_parameter("ust_agarma", 0.08)
	mat.set_shader_parameter("tabaka_gucu", tabaka)
	mat.set_shader_parameter("tabaka_sikligi", 0.55)
	mat.set_shader_parameter("dip_gucu", dip)
	mat.set_shader_parameter("dip_yukseklik", 6.0)
	return mat
