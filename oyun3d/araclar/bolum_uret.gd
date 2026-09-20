extends Node
## Bölüm sahnelerini veriden üretir.
##
##   godot --headless --path oyun3d res://araclar/bolum_uret.tscn
##
## NEDEN VAR: Faz 9'un hedefi "iki bölüm bir demo, altı bölüm bir oyun". Elle
## yazılmış her .tscn 350 satır ve bunların ~250 satırı her bölümde AYNI: HUD,
## duraklatma, bitiş ekranı, hayalet kaydedici, birleştirici, ortam. Altı bölüm
## demek, aynı 250 satırın altı kopyası demek — HUD'a bir etiket eklemek altı
## dosyayı elle düzeltmek olurdu. Burada tekrar eden kısım KOD, bölüme özgü
## kısım VERİ (`bolum_tasarimi/bolumN.gd`).
##
## Bölüm 1 ve 2 bilerek elle kalmaya devam ediyor: yayınlanmış, testleri olan
## ve elle ayarlanmış iki bölümü yeniden üretmenin kazancı yok, riski var.
## Yeni bölümler bu hattan geçiyor.
##
## ÜRETİLEN SAHNELER ELLE DÜZENLENMEZ: bir dahaki çalıştırmada üzerine yazılır.
## Kök düğüme `uretildi` üst verisi yazılıyor ki dosyayı açan bunu bilsin. Bir
## bölümü elden geçirmek isterseniz veri dosyasını silin, .tscn artık sizindir.

const CIKTI_KLASOR := "res://sahneler"
const TASARIM_KLASOR := "res://bolum_tasarimi"
const NAV_KLASOR := "res://navigasyon"

const PLATFORM := preload("res://sahneler/platform.tscn")
const HAREKETLI := preload("res://sahneler/hareketli_platform.tscn")
const TOPLANABILIR := preload("res://sahneler/toplanabilir.tscn")
const KONTROL := preload("res://sahneler/kontrol_noktasi.tscn")
const DUSMAN := preload("res://sahneler/dusman.tscn")
const OYUNCU := preload("res://sahneler/oyuncu.tscn")
const DURAKLAT := preload("res://sahneler/duraklat.tscn")
const BITIS_EKRANI := preload("res://sahneler/bitis_ekrani.tscn")
const DOKUNMATIK := preload("res://sahneler/dokunmatik.tscn")

const TUZAK_BETIK := preload("res://betikler/tuzak.gd")
const BITIS_BETIK := preload("res://betikler/bitis.gd")
const OYUN_BETIK := preload("res://betikler/oyun.gd")
const HUD_BETIK := preload("res://betikler/hud.gd")
const BIRLESTIRICI_BETIK := preload("res://betikler/birlestirici.gd")
const HAYALET_BETIK := preload("res://betikler/ag/hayalet_kaydedici.gd")
const UZAK_BETIK := preload("res://betikler/ag/uzak_oyuncular.gd")
const TUZAK_MALZEME := preload("res://golgeler/tuzak_malzeme.tres")
const ORTAM_SAHNE := preload("res://sahneler/ortam.tscn")
const DUNYA_GOLGE := preload("res://golgeler/dunya.gdshader")
const MANZARA_BETIK := preload("res://betikler/manzara.gd")

## Süsleme adı -> model. Veride "tur" alanı bunlardan biri olmalı.
const SUSLER := {
	"kaya": "res://varliklar/kaya.gltf",
	"kaktus": "res://varliklar/kaktus.gltf",
	"tabela": "res://varliklar/tabela.gltf",
	"sandik": "res://varliklar/sandik.gltf",
}

var _hatalar: Array[String] = []

func _ready() -> void:
	await get_tree().process_frame
	var dosyalar := _tasarim_dosyalari()
	if dosyalar.is_empty():
		printerr("  ! %s altında bölüm verisi yok" % TASARIM_KLASOR)
		get_tree().quit(1)
		return
	for yol: String in dosyalar:
		_uret(yol)
	if _hatalar.is_empty():
		print("BOLUM URETIMI: %d bölüm yazıldı" % dosyalar.size())
		get_tree().quit(0)
	else:
		for h in _hatalar:
			printerr("  ! " + h)
		printerr("BOLUM URETIMI: KALDI (%d)" % _hatalar.size())
		get_tree().quit(1)

func _tasarim_dosyalari() -> Array[String]:
	var sonuc: Array[String] = []
	var dir := DirAccess.open(TASARIM_KLASOR)
	if dir == null:
		return sonuc
	for ad in dir.get_files():
		# Dışa aktarımda .gd dosyaları .gdc olarak paketlenebiliyor; üretim
		# aracı zaten yalnızca geliştirme sırasında çalışıyor.
		if ad.ends_with(".gd"):
			sonuc.append("%s/%s" % [TASARIM_KLASOR, ad])
	sonuc.sort()
	return sonuc

func _uret(tasarim_yolu: String) -> void:
	var betik: GDScript = load(tasarim_yolu)
	if betik == null or not ("VERI" in betik):
		_hatalar.append("%s: VERI sabiti yok" % tasarim_yolu)
		return
	var veri: Dictionary = betik.VERI
	var eksik := _eksik_alanlar(veri)
	if not eksik.is_empty():
		_hatalar.append("%s: eksik alan %s" % [tasarim_yolu, ", ".join(eksik)])
		return

	var kimlik: String = veri["kimlik"]
	var kok := _sahne_kur(veri)
	var paket := PackedScene.new()
	var hata := paket.pack(kok)
	if hata != OK:
		_hatalar.append("%s paketlenemedi: %d" % [kimlik, hata])
		kok.free()
		return
	var cikti := "%s/%s.tscn" % [CIKTI_KLASOR, kimlik]
	hata = ResourceSaver.save(paket, cikti)
	kok.free()
	if hata != OK:
		_hatalar.append("%s kaydedilemedi: %d" % [kimlik, hata])
		return
	print("%-8s %2d platform, %2d çiçek, %d düşman -> %s" % [
		kimlik, (veri["platformlar"] as Array).size(),
		(veri["cicekler"] as Array).size(),
		(veri.get("dusmanlar", []) as Array).size(), cikti])

func _eksik_alanlar(veri: Dictionary) -> Array[String]:
	var eksik: Array[String] = []
	for alan in ["kimlik", "ad", "oyuncu", "platformlar", "cicekler", "bitis"]:
		if not veri.has(alan):
			eksik.append(alan)
	return eksik

# ---------------------------------------------------------------- sahne kurma

func _sahne_kur(veri: Dictionary) -> Node3D:
	var kimlik: String = veri["kimlik"]
	var kok := Node3D.new()
	kok.name = kimlik.capitalize().replace(" ", "")
	kok.set_meta("uretildi", "araclar/bolum_uret.gd — elle düzenlemeyin")
	kok.set_meta("tasarim", "%s/%s.gd" % [TASARIM_KLASOR, kimlik])

	_ortam_ekle(kok, veri)
	_zemin_ekle(kok, veri)
	_tuzaklari_ekle(kok, veri)
	_navigasyon_ekle(kok, kimlik)
	_parkur_ekle(kok, veri)
	_hareketlileri_ekle(kok, veri)
	_toplananlari_ekle(kok, veri)
	_kontrol_noktalari_ekle(kok, veri)
	_bitis_ekle(kok, veri)
	_susleme_ekle(kok, veri)
	_manzara_ekle(kok, veri)
	_dusmanlari_ekle(kok, veri)
	_birlestirici_ekle(kok)
	_oyuncu_ekle(kok, veri)
	_oyun_ekle(kok, veri)
	_hud_ekle(kok)
	_arayuz_ekle(kok)
	return kok

## Her düğümün sahibi kök olmalı, yoksa `PackedScene.pack()` onu yazmıyor.
## Örneklenen alt sahnelerin İÇ düğümlerine sahip atanmıyor: onlar zaten
## kendi sahnelerinde kayıtlı, üzerine yazılan dışa aktarım değerleri ise
## örnek kökünde saklanıyor.
func _ekle(ebeveyn: Node, dugum: Node, kok: Node) -> Node:
	ebeveyn.add_child(dugum)
	dugum.owner = kok
	return dugum

func _ortam_ekle(kok: Node3D, veri: Dictionary) -> void:
	# Aydınlatmanın TEKNİK kurulumu `sahneler/ortam.tscn` içinde (Faz 13);
	# burada yalnızca bölümün sanat yönü veriliyor. Altı bölüm aynı sahneyi
	# örnekliyor: gölge kademesini değiştirmek tek dosyada bir satır.
	var ortam := ORTAM_SAHNE.instantiate()
	ortam.name = "Ortam"
	ortam.gok_ufuk = veri.get("gok_ufuk", Color(0.72, 0.75, 0.71))
	ortam.gok_yer = veri.get("gok_yer", Color(0.35, 0.37, 0.34))
	if veri.has("gok_ust"):
		ortam.gok_ust = veri["gok_ust"]
	else:
		# Üst rengi verilmemişse ufuktan türetiliyor. Yalnızca koyulaştırmak
		# yetmiyor: kum rengi bir ufkun koyusu KAHVE oluyor ve tepede kahve
		# bir gökyüzü çıkıyor. Gökyüzü yukarı doğru hem koyulaşır hem MAVİYE
		# kayar — atmosferin kendisi böyle davranıyor.
		ortam.gok_ust = ortam.gok_ufuk.lerp(Color(0.28, 0.44, 0.68), 0.55)
	ortam.bulut = veri.get("bulut", 0.45)
	ortam.sis_renk = veri.get("sis_renk", Color(0.702, 0.741, 0.729))
	ortam.sis = veri.get("sis", 0.0035)
	ortam.gunes_aci = veri.get("gunes_aci", Vector3(-52, -38, 0))
	ortam.gunes_gucu = veri.get("gunes_gucu", 0.85)
	if veri.has("gunes_renk"):
		ortam.gunes_renk = veri["gunes_renk"]
	_ekle(kok, ortam, kok)

func _zemin_ekle(kok: Node3D, veri: Dictionary) -> void:
	var olcu: float = veri.get("zemin_olcu", 140.0)
	var govde := StaticBody3D.new()
	govde.name = "Zemin"
	govde.collision_layer = 1
	govde.collision_mask = 0
	govde.position = Vector3(0, veri.get("zemin_y", 0.0), 0)
	_ekle(kok, govde, kok)

	var mesh := PlaneMesh.new()
	mesh.size = Vector2(olcu, olcu)
	var gorsel := MeshInstance3D.new()
	gorsel.name = "Gorsel"
	gorsel.mesh = mesh
	# Zeminin tamamı dikenliyse ÖYLE GÖRÜNMELİ. Oyuncu "buraya basılmaz"ı
	# metinden değil renkten öğreniyor; bölüm 2 de aynı çizgili gölgelendiriciyi
	# zemin malzemesi olarak kullanıyor.
	if veri.get("zemin_tuzakli", false):
		gorsel.material_override = TUZAK_MALZEME
		gorsel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	else:
		gorsel.material_override = zemin_malzemesi(
			veri.get("zemin_renk", Color(0.514, 0.545, 0.494)))
	_ekle(govde, gorsel, kok)

	var sekil := BoxShape3D.new()
	sekil.size = Vector3(olcu, 1.0, olcu)
	var carpisma := CollisionShape3D.new()
	carpisma.name = "Carpisma"
	carpisma.position = Vector3(0, -0.5, 0)
	carpisma.shape = sekil
	_ekle(govde, carpisma, kok)

## Zemin malzemesi — dünya gölgelendiricisi, zemine göre ayarlanmış (Faz 13).
##
## Zemin 140 metrelik tek bir düzlem: aynı desen ölçeğiyle boyanırsa desen
## uzakta titreşiyor, yakında ise kutulardan daha ince duruyor. Ölçek
## büyütülüyor (daha geniş lekeler) ve dip karartması kapatılıyor — düzlemin
## "dibi" yok, kapatılmazsa bütün zemin tek tonda koyulaşıyor.
static func zemin_malzemesi(renk: Color) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = DUNYA_GOLGE
	mat.set_shader_parameter("renk", renk)
	mat.set_shader_parameter("puruzluluk", 0.95)
	mat.set_shader_parameter("desen_olcek", 0.42)
	mat.set_shader_parameter("desen_gucu", 0.16)
	mat.set_shader_parameter("ust_agarma", 0.0)
	mat.set_shader_parameter("tabaka_gucu", 0.0)
	mat.set_shader_parameter("dip_gucu", 0.0)
	return mat

## Dikenli alanlar. Görsel, Faz 6'daki dünya uzayında çizgili gölgelendirici.
func _tuzaklari_ekle(kok: Node3D, veri: Dictionary) -> void:
	var tuzaklar: Array = veri.get("tuzaklar", [])
	for i in tuzaklar.size():
		var t: Dictionary = tuzaklar[i]
		var alan := Area3D.new()
		alan.name = "Tuzak" if tuzaklar.size() == 1 else "Tuzak%d" % (i + 1)
		alan.position = t["konum"]
		alan.collision_layer = 4
		alan.collision_mask = 2
		alan.set_script(TUZAK_BETIK)
		_ekle(kok, alan, kok)

		var olcu: Vector3 = t["olcu"]
		if t.get("gorsel", true):
			var mesh := BoxMesh.new()
			mesh.size = olcu
			var gorsel := MeshInstance3D.new()
			gorsel.name = "Gorsel"
			gorsel.mesh = mesh
			gorsel.material_override = TUZAK_MALZEME
			gorsel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_ekle(alan, gorsel, kok)

		var sekil := BoxShape3D.new()
		sekil.size = olcu
		var carpisma := CollisionShape3D.new()
		carpisma.name = "Carpisma"
		carpisma.shape = sekil
		_ekle(alan, carpisma, kok)

## Navigasyon örgüsü ayrı bir araçla pişiriliyor (`navmesh_uret.gd`) ama sahne
## ona şimdiden bağlanmalı. Yoksa "önce sahne mi örgü mü" kısır döngüsü çıkıyor:
## dosya yoksa boş bir örgü yazılıyor, pişirme onun üzerine yazıyor.
func _navigasyon_ekle(kok: Node3D, kimlik: String) -> void:
	var yol := "%s/%s.tres" % [NAV_KLASOR, kimlik]
	if not ResourceLoader.exists(yol):
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(NAV_KLASOR))
		ResourceSaver.save(NavigationMesh.new(), yol)
	var bolge := NavigationRegion3D.new()
	bolge.name = "Navigasyon"
	bolge.navigation_mesh = load(yol)
	_ekle(kok, bolge, kok)

func _parkur_ekle(kok: Node3D, veri: Dictionary) -> void:
	var parkur := Node3D.new()
	parkur.name = "Parkur"
	_ekle(kok, parkur, kok)
	for i in (veri["platformlar"] as Array).size():
		var p: Dictionary = veri["platformlar"][i]
		var dugum := PLATFORM.instantiate()
		dugum.name = p.get("ad", "Platform%d" % (i + 1))
		dugum.position = p["konum"]
		if p.has("donus"):
			dugum.rotation_degrees = p["donus"]
		dugum.olcu = p.get("olcu", Vector3(4, 0.5, 4))
		dugum.renk = p.get("renk", Color(0.55, 0.47, 0.34))
		_ekle(parkur, dugum, kok)

func _hareketlileri_ekle(kok: Node3D, veri: Dictionary) -> void:
	var liste: Array = veri.get("hareketliler", [])
	for i in liste.size():
		var h: Dictionary = liste[i]
		var dugum := HAREKETLI.instantiate()
		dugum.name = h.get("ad", "Hareketli%d" % (i + 1))
		dugum.position = h["konum"]
		dugum.uc = h["uc"]
		dugum.tur_suresi = h.get("sure", 5.0)
		dugum.baslangic_fazi = h.get("faz", 0.0)
		_ekle(kok, dugum, kok)

func _toplananlari_ekle(kok: Node3D, veri: Dictionary) -> void:
	var kap := Node3D.new()
	kap.name = "Toplananlar"
	_ekle(kok, kap, kok)
	for i in (veri["cicekler"] as Array).size():
		var dugum := TOPLANABILIR.instantiate()
		dugum.name = "Cicek%d" % (i + 1)
		dugum.position = veri["cicekler"][i]
		_ekle(kap, dugum, kok)

func _kontrol_noktalari_ekle(kok: Node3D, veri: Dictionary) -> void:
	var liste: Array = veri.get("kontrol_noktalari", [])
	var kap := Node3D.new()
	kap.name = "KontrolNoktalari"
	_ekle(kok, kap, kok)
	for i in liste.size():
		var dugum := KONTROL.instantiate()
		dugum.name = "KN%d" % (i + 1)
		dugum.position = liste[i]
		_ekle(kap, dugum, kok)

func _bitis_ekle(kok: Node3D, veri: Dictionary) -> void:
	var alan := Area3D.new()
	alan.name = "Bitis"
	alan.position = veri["bitis"]
	alan.collision_layer = 16
	alan.collision_mask = 2
	alan.set_script(BITIS_BETIK)
	alan.oyun_yolu = NodePath("../Oyun")
	_ekle(kok, alan, kok)

	var sekil := BoxShape3D.new()
	sekil.size = Vector3(4, 3, 4)
	var carpisma := CollisionShape3D.new()
	carpisma.name = "Carpisma"
	carpisma.shape = sekil
	_ekle(alan, carpisma, kok)

	var mesh := BoxMesh.new()
	mesh.size = Vector3(4, 0.12, 4)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.949, 0.808, 0.404)
	mat.emission_enabled = true
	mat.emission = Color(0.949, 0.808, 0.404)
	mat.emission_energy_multiplier = 0.7
	var gorsel := MeshInstance3D.new()
	gorsel.name = "Gorsel"
	gorsel.position = Vector3(0, -1.13, 0)
	gorsel.mesh = mesh
	gorsel.material_override = mat
	_ekle(alan, gorsel, kok)

func _susleme_ekle(kok: Node3D, veri: Dictionary) -> void:
	var liste: Array = veri.get("susleme", [])
	var kap := Node3D.new()
	kap.name = "Susleme"
	_ekle(kok, kap, kok)
	for i in liste.size():
		var s: Dictionary = liste[i]
		var tur: String = s["tur"]
		if not SUSLER.has(tur):
			_hatalar.append("%s: bilinmeyen süsleme '%s'" % [veri["kimlik"], tur])
			continue
		var sahne: PackedScene = load(SUSLER[tur])
		var dugum: Node3D = sahne.instantiate()
		dugum.name = "%s%d" % [tur.capitalize(), i + 1]
		var olcek: float = s.get("olcek", 1.0)
		var temel := Basis(Vector3.UP, deg_to_rad(s.get("aci", 0.0))).scaled(Vector3.ONE * olcek)
		dugum.transform = Transform3D(temel, s["konum"])
		_ekle(kap, dugum, kok)

## Uzak manzara (Faz 13): ufku kapatan zemin, tepeler ve serpinti. Düğüm
## çalışma anında dolduruyor — .tscn'de yalnızca ayarları duruyor.
func _manzara_ekle(kok: Node3D, veri: Dictionary) -> void:
	var dugum := Node3D.new()
	dugum.name = "Manzara"
	dugum.set_script(MANZARA_BETIK)
	# Tohum bölümün kimliğinden: aynı bölüm her açılışta aynı manzarayı
	# kuruyor, farklı bölümler birbirine benzemiyor.
	dugum.tohum = abs(hash(veri["kimlik"]))
	dugum.zemin_y = veri.get("zemin_y", 0.0)
	dugum.zemin_renk = veri.get("zemin_renk", Color(0.514, 0.545, 0.494))
	dugum.tepe_renk = veri.get("tepe_renk", dugum.zemin_renk.darkened(0.3))
	dugum.serpinti = not veri.get("zemin_tuzakli", false)
	# Serpinti oyun zemininin kenarını aşmamalı: aşarsa kayalar boşlukta durur.
	dugum.serpinti_yaricap = float(veri.get("zemin_olcu", 140.0)) * 0.44
	_ekle(kok, dugum, kok)

func _dusmanlari_ekle(kok: Node3D, veri: Dictionary) -> void:
	var liste: Array = veri.get("dusmanlar", [])
	var kap := Node3D.new()
	kap.name = "Dusmanlar"
	_ekle(kok, kap, kok)
	for i in liste.size():
		var d: Dictionary = liste[i]
		var dugum: Node3D = DUSMAN.instantiate()
		dugum.name = "Dusman%d" % (i + 1)
		var temel := Basis(Vector3.UP, deg_to_rad(d.get("aci", 0.0)))
		dugum.transform = Transform3D(temel, d["konum"])
		dugum.devriye_ucu = d.get("devriye_ucu", Vector3(4, 0, 0))
		_ekle(kap, dugum, kok)

## Faz 6: aynı mesh'i paylaşan görselleri tek MultiMesh'te birleştiriyor.
func _birlestirici_ekle(kok: Node3D) -> void:
	var dugum := Node3D.new()
	dugum.name = "Birlestirici"
	dugum.set_script(BIRLESTIRICI_BETIK)
	dugum.hedefler = [NodePath("../Parkur"), NodePath("../Susleme")] as Array[NodePath]
	_ekle(kok, dugum, kok)

func _oyuncu_ekle(kok: Node3D, veri: Dictionary) -> void:
	var dugum: Node3D = OYUNCU.instantiate()
	dugum.name = "Oyuncu"
	dugum.position = veri["oyuncu"]
	_ekle(kok, dugum, kok)

func _oyun_ekle(kok: Node3D, veri: Dictionary) -> void:
	var dugum := Node.new()
	dugum.name = "Oyun"
	dugum.set_script(OYUN_BETIK)
	dugum.bolum_kimligi = veri["kimlik"]
	dugum.oyuncu_yolu = NodePath("../Oyuncu")
	_ekle(kok, dugum, kok)

func _hud_ekle(kok: Node3D) -> void:
	var hud := CanvasLayer.new()
	hud.name = "HUD"
	hud.set_script(HUD_BETIK)
	hud.oyun_yolu = NodePath("../Oyun")
	_ekle(kok, hud, kok)

	_etiket(hud, kok, "Durum", Vector2(18, 14), Vector2(520, 44), 20,
		Color(1, 1, 1), false)
	var can := _etiket(hud, kok, "Can", Vector2(18, 46), Vector2(320, 74), 20,
		Color(0.898, 0.365, 0.353), true)
	can.unique_name_in_owner = true
	# Hayalet etiketi ekranın ortasında: farkı okumak için göz oraya gidiyor.
	var hayalet := _etiket(hud, kok, "Hayalet", Vector2(-180, 52), Vector2(180, 84), 22,
		Color(1, 1, 1), true)
	hayalet.unique_name_in_owner = true
	hayalet.anchor_left = 0.5
	hayalet.anchor_right = 0.5
	hayalet.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var mesaj := _etiket(hud, kok, "Mesaj", Vector2(0, 96), Vector2(0, 130), 22,
		Color(1, 0.949, 0.847), false)
	mesaj.anchor_right = 1.0
	mesaj.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var olcum := _etiket(hud, kok, "Olcum", Vector2(18, -62), Vector2(720, -14), 14,
		Color(0.902, 0.925, 0.898), false)
	olcum.anchor_top = 1.0
	olcum.anchor_bottom = 1.0

func _etiket(hud: CanvasLayer, kok: Node, ad: String, sol_ust: Vector2,
		sag_alt: Vector2, boyut: int, renk: Color, anahat_koyu: bool) -> Label:
	var etiket := Label.new()
	etiket.name = ad
	etiket.offset_left = sol_ust.x
	etiket.offset_top = sol_ust.y
	etiket.offset_right = sag_alt.x
	etiket.offset_bottom = sag_alt.y
	etiket.add_theme_color_override("font_color", renk)
	etiket.add_theme_color_override("font_outline_color",
		Color(0, 0, 0, 0.85) if anahat_koyu else Color(0, 0, 0, 0.8))
	etiket.add_theme_constant_override("outline_size", 6)
	etiket.add_theme_font_size_override("font_size", boyut)
	_ekle(hud, etiket, kok)
	return etiket

func _arayuz_ekle(kok: Node3D) -> void:
	for veri in [["Duraklat", DURAKLAT], ["BitisEkrani", BITIS_EKRANI],
			["Dokunmatik", DOKUNMATIK]]:
		var dugum: Node = (veri[1] as PackedScene).instantiate()
		dugum.name = veri[0]
		_ekle(kok, dugum, kok)

	var hayalet := Node.new()
	hayalet.name = "HayaletKaydedici"
	hayalet.set_script(HAYALET_BETIK)
	_ekle(kok, hayalet, kok)

	var uzak := Node3D.new()
	uzak.name = "UzakOyuncular"
	uzak.set_script(UZAK_BETIK)
	_ekle(kok, uzak, kok)
