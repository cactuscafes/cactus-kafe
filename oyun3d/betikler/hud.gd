extends CanvasLayer
## Bölüm durumu ve kare bütçesi.
##
## Ölçüm satırı Faz 0'dan beri duruyor ve durmaya devam edecek: 16.6 ms'yi
## ekranda tutmak, performansın ne zaman bozulduğunu sonradan aramaktan ucuz.

const BUTCE_MS := 16.6

@export var oyun_yolu: NodePath = ^"../Oyun"
@export var oyuncu_yolu: NodePath = ^"../Oyuncu"

@onready var _durum: Label = $Durum
@onready var _mesaj: Label = $Mesaj
@onready var _olcum: Label = $Olcum
@onready var _can: Label = %Can

var _oyun: Node
var _sayac := 0.0

func _ready() -> void:
	_oyun = get_node(oyun_yolu)
	_oyun.durum_degisti.connect(_durumu_yaz)
	var oyuncu := get_node(oyuncu_yolu)
	oyuncu.can_degisti.connect(_cani_yaz)
	_cani_yaz(oyuncu.can, oyuncu.can_max)
	_durumu_yaz()
	_olcumu_yaz()

func _process(delta: float) -> void:
	_durum.text = tr("HUD_DURUM") % [
		_oyun.toplanan, _oyun.hedef_toplanabilir, _oyun.sure, _oyun.olum,
	]
	_sayac -= delta
	if _sayac <= 0.0:
		_sayac = 0.25
		_olcumu_yaz()

func _cani_yaz(can: int, en_fazla: int) -> void:
	_can.text = tr("HUD_CAN") % [can, en_fazla]
	# Son can farklı renkte: sayıyı okumadan da durum anlaşılsın.
	_can.add_theme_color_override("font_color",
		Color(1.0, 0.35, 0.3) if can <= 1 else Color(0.898, 0.6, 0.35))

func _durumu_yaz() -> void:
	_mesaj.text = _oyun.mesaj

func _olcumu_yaz() -> void:
	var fps := Engine.get_frames_per_second()
	var ms := 1000.0 / maxf(float(fps), 1.0)
	var cizim := RenderingServer.get_rendering_info(
		RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME
	)
	_olcum.text = "%d FPS · %.1f ms (bütçe %.1f) · %d draw call · %s\n%s" % [
		fps, ms, BUTCE_MS, cizim, OS.get_name(),
		tr("HUD_TUSLAR_DOKUNMA") if Girdi.dokunmatik else tr("HUD_TUSLAR"),
	]
