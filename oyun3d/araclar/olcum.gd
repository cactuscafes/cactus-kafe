extends Node
## Performans ölçümü ve bütçe denetimi.
##
##   xvfb-run -a godot --path oyun3d --rendering-driver opengl3 \
##     --audio-driver Dummy res://araclar/olcum.tscn
##
## NEDEN FPS ÖLÇMÜYORUZ: bu makinenin GPU'su yok (yazılımsal llvmpipe), ölçülen
## kare süresi kimsenin donanımını temsil etmez. Ölçülen şeyler donanımdan
## bağımsız: draw call, üçgen sayısı, doku belleği. Bunlar düşerse her
## donanımda düşer.
##
## Bütçeler `performans_butce.json` dosyasında. Aşılırsa çıkış kodu 1 —
## CI'da "şu değişiklik draw call'u iki katına çıkardı" kendiliğinden görünür.

const BUTCE_YOLU := "res://performans_butce.json"
const CIKTI := "user://performans.json"
const ISINMA := 45      # ilk karelerde gölge haritası vs. oturuyor
const ORNEK := 90

var _rapor := {}

func _ready() -> void:
	await get_tree().process_frame
	var butce := _butce_oku()
	var asilan: Array[String] = []

	# Taban: hiçbir bölüm yokken ne harcanıyor? Gölge atlası, gökyüzü ve yazı
	# tipi buraya düşer; bölümlerin sayısından çıkarınca gerçek maliyet görünür.
	var taban := await _olc()
	_rapor["_taban"] = taban
	print("%-7s  %4d draw call                       %5.1f MB doku (gölge + gökyüzü + yazı tipi)"
		% ["taban", taban["draw_call"], taban["doku_mb"]])

	for bilgi: Dictionary in Bolumler.LISTE:
		var kimlik: String = bilgi["kimlik"]
		var olcum := await _bolumu_olc(bilgi["sahne"])
		_rapor[kimlik] = olcum
		var sinir: Dictionary = butce.get(kimlik, {})
		print("%-7s  %4d draw call (tepe %4d)  %7d üçgen  %5.1f MB doku" % [
			kimlik, olcum["draw_call"], olcum["draw_call_tepe"],
			olcum["ucgen"], olcum["doku_mb"]])
		for alan: String in sinir:
			if float(olcum.get(alan, 0.0)) > float(sinir[alan]):
				asilan.append("%s: %s = %s, bütçe %s" % [
					kimlik, alan, olcum[alan], sinir[alan]])

	var dosya := FileAccess.open(CIKTI, FileAccess.WRITE)
	dosya.store_string(JSON.stringify(_rapor, "  ", true))
	dosya.close()
	print("rapor -> %s" % ProjectSettings.globalize_path(CIKTI))

	if asilan.is_empty():
		print("PERFORMANS: BUTCE ICINDE")
		get_tree().quit(0)
	else:
		for a: String in asilan:
			printerr("  ! " + a)
		print("PERFORMANS: BUTCE ASILDI (%d)" % asilan.size())
		get_tree().quit(1)

func _butce_oku() -> Dictionary:
	var d := FileAccess.open(BUTCE_YOLU, FileAccess.READ)
	if d == null:
		return {}
	return JSON.parse_string(d.get_as_text())

func _bolumu_olc(sahne_yolu: String) -> Dictionary:
	var bolum: Node3D = (load(sahne_yolu) as PackedScene).instantiate()
	get_tree().root.add_child(bolum)
	var sonuc := await _olc()
	bolum.queue_free()
	await get_tree().process_frame
	return sonuc

func _olc() -> Dictionary:
	for i in ISINMA:
		await get_tree().process_frame

	var toplam_cizim := 0
	var tepe_cizim := 0
	var toplam_ucgen := 0
	for i in ORNEK:
		await get_tree().process_frame
		var cizim := RenderingServer.get_rendering_info(
			RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
		toplam_cizim += cizim
		tepe_cizim = maxi(tepe_cizim, cizim)
		toplam_ucgen += RenderingServer.get_rendering_info(
			RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)

	return {
		"draw_call": int(round(float(toplam_cizim) / ORNEK)),
		"draw_call_tepe": tepe_cizim,
		"ucgen": int(round(float(toplam_ucgen) / ORNEK)),
		"doku_mb": snappedf(float(RenderingServer.get_rendering_info(
			RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED)) / 1048576.0, 0.1),
		"tampon_mb": snappedf(float(RenderingServer.get_rendering_info(
			RenderingServer.RENDERING_INFO_BUFFER_MEM_USED)) / 1048576.0, 0.1),
	}
