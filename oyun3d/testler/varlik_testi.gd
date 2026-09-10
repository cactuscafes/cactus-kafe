extends Node
## Varlık hattı testleri — Blender'ın ürettiği ölçüler Godot'ya aynı mı geliyor?
##
##   godot --headless --path oyun3d res://testler/varlik_testi.tscn
##
## İçe aktarımda en sık kaybedilen üç şey: ölçek (santimetre/metre karışması),
## eksen (Blender Z-up, Godot Y-up) ve UV. Üçü de sessizce bozulur: sahne açılır,
## hata çıkmaz, model 100 kat büyük ya da yan yatmış olur. Blender tarafındaki
## `varliklar/olcum.json` bu testin sözleşmesi.

const OLCUM := "res://varliklar/olcum.json"
const ATLAS := "res://varliklar/atlas.png"

var _hatalar: Array[String] = []

func _ready() -> void:
	var dosya := FileAccess.open(OLCUM, FileAccess.READ)
	if dosya == null:
		printerr("  ! %s okunamadı — önce araclar/modeller.py çalıştırılmalı" % OLCUM)
		get_tree().quit(1)
		return
	var rapor: Dictionary = JSON.parse_string(dosya.get_as_text())
	var bant: Dictionary = rapor["_bant"]

	for ad: String in rapor:
		if ad.begins_with("_"):
			continue
		_varligi_dogrula(ad, rapor[ad], bant)

	if _hatalar.is_empty():
		print("VARLIK TESTI: GECTI")
		get_tree().quit(0)
	else:
		for h: String in _hatalar:
			printerr("  ! " + h)
		print("VARLIK TESTI: KALDI (%d)" % _hatalar.size())
		get_tree().quit(1)

func _dogrula(kosul: bool, mesaj: String) -> void:
	if not kosul:
		_hatalar.append(mesaj)

func _varligi_dogrula(ad: String, beklenen: Dictionary, bant: Dictionary) -> void:
	var yol := "res://varliklar/%s.gltf" % ad
	if not ResourceLoader.exists(yol):
		_dogrula(false, "%s: dosya yok (%s)" % [ad, yol])
		return

	var kok: Node3D = (load(yol) as PackedScene).instantiate()
	var mesh_dugumu := _mesh_bul(kok)
	if mesh_dugumu == null:
		_dogrula(false, "%s: MeshInstance3D bulunamadı" % ad)
		kok.free()
		return

	var mesh := mesh_dugumu.mesh as ArrayMesh
	var aabb := mesh_dugumu.get_aabb()

	# 1) Ölçek ve eksen: Blender Z-up -> Godot Y-up (x, z, y sırası).
	var b: Array = beklenen["boyut_m"]
	var hedef := Vector3(b[0], b[2], b[1])
	var sapma := (aabb.size - hedef).abs()
	_dogrula(sapma.x < 0.02 and sapma.y < 0.02 and sapma.z < 0.02,
		"%s: ölçü tutmuyor — Godot %s, Blender %s" % [ad, aabb.size, hedef])

	# 2) Orijin tabanda olmalı: Godot'da y = zemin yüksekliği yazınca otursun.
	_dogrula(absf(aabb.position.y) < 0.01,
		"%s: orijin tabanda değil (aabb.y=%.3f)" % [ad, aabb.position.y])

	# 3) Üçgen bütçesi
	var dizi := mesh.surface_get_arrays(0)
	var indeksler: PackedInt32Array = dizi[Mesh.ARRAY_INDEX]
	var ucgen := indeksler.size() / 3
	_dogrula(ucgen == int(beklenen["ucgen"]),
		"%s: üçgen sayısı %d, beklenen %d" % [ad, ucgen, int(beklenen["ucgen"])])
	_dogrula(ucgen <= int(bant["ucgen_ust_sinir"]),
		"%s: üçgen bütçesi aşıldı (%d)" % [ad, ucgen])

	# 4) UV ve doku
	var uvler: PackedVector2Array = dizi[Mesh.ARRAY_TEX_UV]
	_dogrula(uvler.size() > 0, "%s: UV katmanı yok" % ad)
	var mat := mesh.surface_get_material(0) as BaseMaterial3D
	_dogrula(mat != null and mat.albedo_texture != null,
		"%s: malzemede albedo dokusu yok" % ad)

	# 5) UV'ler nesneye ayrılan atlas bölgesinin içinde mi?
	#
	# Bu testi bir hata yakalattığı için ekledim: Blender UV'nin başlangıcı sol
	# alt, glTF'inki sol üst. V ekseni çevrilmeyince her nesne atlasın dikey
	# aynasındaki bölgeyi örnekliyordu — kaktüs kahverengi, tabela gri. Doku
	# yoğunluğu bu hatada bile doğru çıkıyor; sadece bölge sınaması yakalıyor.
	if uvler.size() > 0 and beklenen.has("bolge_px"):
		var b_px: Array = beklenen["bolge_px"]
		var atlas_px := float(beklenen["atlas_px"])
		var disarida := 0
		for uv: Vector2 in uvler:
			var x := uv.x * atlas_px
			var y := uv.y * atlas_px
			if x < float(b_px[0]) - 1.0 or x > float(b_px[0] + b_px[2]) + 1.0 \
					or y < float(b_px[1]) - 1.0 or y > float(b_px[1] + b_px[3]) + 1.0:
				disarida += 1
		_dogrula(disarida == 0,
			"%s: %d UV noktası '%s' bölgesinin (%s) dışında" % [
				ad, disarida, beklenen["bolge"], b_px])

	# 6) Atlastan gerçekten hangi renk okunuyor?
	#
	# Bölge sınaması UV'lerin doğru dikdörtgende olduğunu söyler; bu test
	# dokunun o dikdörtgenden okunduğunu söyler. Aradaki fark V ekseni
	# çevirmesiydi: Blender UV'nin başlangıcı sol alt, glTF'inki sol üst,
	# dışa aktarıcı çeviriyor, Godot çevirmiyor. Bir yanlış işaret kaktüsü
	# kahverengi yapıyor ve hiçbir sayısal test bunu yakalamıyordu.
	if uvler.size() > 0 and beklenen.has("taban_renk"):
		# İçe aktarılmış dokuyu kullan (ham dosyayı değil): render ne
		# görüyorsa test de onu görsün.
		var atlas := (load(ATLAS) as Texture2D).get_image()
		if atlas.is_compressed():
			atlas.decompress()
		var ort := Vector3.ZERO
		var adet := 0
		for i in range(0, uvler.size(), maxi(1, uvler.size() / 40)):
			var uv := uvler[i]
			var renk := atlas.get_pixelv(Vector2i(
				clampi(int(uv.x * atlas.get_width()), 0, atlas.get_width() - 1),
				clampi(int(uv.y * atlas.get_height()), 0, atlas.get_height() - 1)))
			ort += Vector3(renk.r, renk.g, renk.b)
			adet += 1
		ort /= float(adet)
		var t_renk: Array = beklenen["taban_renk"]
		var hedef_renk := Vector3(t_renk[0], t_renk[1], t_renk[2])
		var fark := (ort - hedef_renk).abs()
		_dogrula(fark.x < 0.15 and fark.y < 0.15 and fark.z < 0.15,
			"%s: atlastan okunan renk %v, '%s' bölgesinin rengi %v" % [
				ad, ort, beklenen["bolge"], hedef_renk])

	# 7) Doku yoğunluğu: UV'ler dışa aktarımda bozulmuşsa burada yakalanır.
	if uvler.size() > 0 and mat != null and mat.albedo_texture != null:
		var doku_px: float = float(mat.albedo_texture.get_size().x)
		var yogunluk := _teksel_yogunlugu(dizi[Mesh.ARRAY_VERTEX], uvler, indeksler, doku_px)
		var beklenen_yogunluk := float(beklenen["teksel_metre"])
		print("%-8s %4d üçgen  %5.2f×%5.2f×%5.2f m  %4.0f teksel/m (Blender: %.0f)" % [
			ad, ucgen, aabb.size.x, aabb.size.y, aabb.size.z, yogunluk, beklenen_yogunluk])
		_dogrula(absf(yogunluk - beklenen_yogunluk) / beklenen_yogunluk < 0.15,
			"%s: doku yoğunluğu %.0f, Blender %.0f dedi" % [ad, yogunluk, beklenen_yogunluk])
		_dogrula(yogunluk >= float(bant["teksel_metre_min"])
			and yogunluk <= float(bant["teksel_metre_max"]),
			"%s: doku yoğunluğu bant dışı (%.0f)" % [ad, yogunluk])

	kok.free()

## Üçgen başına (teksel alanı / dünya alanı) oranının karekökü = teksel/metre.
func _teksel_yogunlugu(noktalar: PackedVector3Array, uvler: PackedVector2Array,
		indeksler: PackedInt32Array, doku_px: float) -> float:
	var toplam := 0.0
	var sayi := 0
	for i in range(0, indeksler.size(), 3):
		var a := noktalar[indeksler[i]]
		var bb := noktalar[indeksler[i + 1]]
		var c := noktalar[indeksler[i + 2]]
		var alan := (bb - a).cross(c - a).length() * 0.5
		if alan < 1e-8:
			continue
		var ua := uvler[indeksler[i]] * doku_px
		var ub := uvler[indeksler[i + 1]] * doku_px
		var uc := uvler[indeksler[i + 2]] * doku_px
		var uv_alan := absf((ub - ua).cross(uc - ua)) * 0.5
		toplam += sqrt(uv_alan / alan)
		sayi += 1
	return toplam / maxf(float(sayi), 1.0)

func _mesh_bul(n: Node) -> MeshInstance3D:
	if n is MeshInstance3D:
		return n as MeshInstance3D
	for c in n.get_children():
		var bulunan := _mesh_bul(c)
		if bulunan != null:
			return bulunan
	return null
