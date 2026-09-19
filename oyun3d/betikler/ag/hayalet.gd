extends Node3D
## Kayıttan oynatılan hayalet.
##
## Fizik yok, çarpışma yok, yalnızca aradeğerlenmiş konum ve yön. Hayaletin
## oyuncuyu itmesi ya da ona takılması yarışı bozar; hayalet bir GÖRÜNTÜdür.
##
## Faz 11'den beri oyuncuyla AYNI modeli kullanıyor (saydam malzeme ile):
## silueti farklı olan hayalet, yarıştığın şeyin sen olmadığını söylüyordu.
## Animasyonu kayıttaki HIZ sürüyor — durum makinesi yok, iki animasyon yeter.

const YURUME_ESIGI := 0.6
const KOSMA_HIZI := 7.4

@onready var _yon: Node3D = $Yon

var _oynatici: AnimationPlayer
var _su_anki := ""

func _ready() -> void:
	var model := $Yon/Model
	_oynatici = model.get_node_or_null("AnimationPlayer")
	# Saydam malzeme mesh'e uygulanıyor: doku yerine tek renk, çünkü hayalet
	# bir görüntü; dokulu olsa oyuncuyla karışırdı.
	var malzeme := StandardMaterial3D.new()
	malzeme.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	malzeme.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	malzeme.albedo_color = Color(0.435, 0.902, 0.761, 0.32)
	malzeme.cull_mode = BaseMaterial3D.CULL_DISABLED
	for dugum in model.find_children("*", "MeshInstance3D", true, false):
		var mesh := dugum as MeshInstance3D
		mesh.material_override = malzeme
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

## Hız animasyonu seçiyor: duruyorsa boşta, yürüyorsa yürüme, koşuyorsa koşma.
func _animasyonu_sec(hiz: float) -> void:
	if _oynatici == null:
		return
	var istenen := "bosta"
	if hiz > KOSMA_HIZI * 0.75:
		istenen = "kosma"
	elif hiz > YURUME_ESIGI:
		istenen = "yurume"
	if istenen != _su_anki and _oynatici.has_animation(istenen):
		_su_anki = istenen
		_oynatici.play(istenen)
		_oynatici.get_animation(istenen).loop_mode = Animation.LOOP_LINEAR

func uygula(durum: Dictionary) -> void:
	global_position = durum["konum"]
	_yon.rotation.y = durum["yon"]
	_animasyonu_sec(float(durum.get("hiz", 0.0)))
	# GÖRÜNÜRLÜĞÜ YALNIZCA DEĞİŞİNCE YAZ. Aynı değeri her karede atamak
	# Godot'da ucuz değil: görünürlük alt ağaca yayılıyor ve bu tek satır,
	# hayalet oynarken kareyi ölçülebilir biçimde pahalılaştırıyordu (botun
	# denge ölçümü hayaletli bölümde 60 kat yavaşlayınca fark edildi —
	# gerçek cihazda da bedeli var).
	var gorunur: bool = not durum["bitti"]
	if visible != gorunur:
		visible = gorunur
