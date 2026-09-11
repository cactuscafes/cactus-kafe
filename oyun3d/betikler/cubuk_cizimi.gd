extends Control
## Sanal çubuğun çizimi: dış halka (menzil) ve içteki topuz.
##
## Doku yok, `_draw()` ile çiziliyor: iki daire için varlık üretmeye, atlasa
## yer açmaya ve ölçek ayarlamaya değmez.

const YARICAP := 110.0

## Çubuğun itilme yönü (-1..1). Dokunmatik katmanı yazıyor.
var yon := Vector2.ZERO:
	set(deger):
		yon = deger
		queue_redraw()

func _draw() -> void:
	draw_circle(Vector2.ZERO, YARICAP, Color(1, 1, 1, 0.10))
	draw_arc(Vector2.ZERO, YARICAP, 0.0, TAU, 48, Color(1, 1, 1, 0.35), 3.0, true)
	draw_circle(yon * YARICAP, 42.0, Color(0.404, 0.702, 0.529, 0.75))
	draw_arc(yon * YARICAP, 42.0, 0.0, TAU, 32, Color(1, 1, 1, 0.55), 2.5, true)
