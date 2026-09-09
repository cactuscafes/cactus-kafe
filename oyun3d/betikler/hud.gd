extends CanvasLayer
## Kare bütçesini ekranda tutar.
##
## 60 FPS = kare başına 16.6 ms. Bu sayıyı ilk günden görmek, sonradan
## "yavaşlamış ama ne zaman yavaşladı?" sorusunu tamamen ortadan kaldırır.

const BUTCE_MS := 16.6

@onready var _etiket: Label = $Bilgi

var _sayac := 0.0

func _ready() -> void:
	_yaz()

func _process(delta: float) -> void:
	_sayac -= delta
	if _sayac <= 0.0:
		_sayac = 0.25
		_yaz()

func _yaz() -> void:
	var fps := Engine.get_frames_per_second()
	var ms := 1000.0 / maxf(float(fps), 1.0)
	var cizim := RenderingServer.get_rendering_info(
		RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME
	)
	_etiket.text = "%d FPS · %.1f ms (bütçe %.1f ms)\n%d draw call · %s\n%s\nWASD hareket · Shift koş · Space zıpla · Esc fare" % [
		fps, ms, BUTCE_MS, cizim, OS.get_name(),
		RenderingServer.get_video_adapter_name(),
	]
