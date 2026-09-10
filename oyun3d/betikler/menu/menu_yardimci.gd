class_name MenuYardimci
extends Object
## Menülerde tekrar eden iki iş.

## Ağaçtaki bütün butonlara tıklama sesi bağlar. Her butona tek tek
## bağlamak yerine: eklenen yeni buton da kendiliğinden sesli olur.
static func butonlari_seslendir(kok: Node) -> void:
	for dugum in kok.find_children("*", "Button", true, false):
		var buton := dugum as Button
		if not buton.pressed.is_connected(_tik):
			buton.pressed.connect(_tik)

static func _tik() -> void:
	Ses.cal("tik")

## Klavye ve oyun kolu için odak: menü açılınca ilk buton seçili olsun.
static func ilk_butona_odaklan(kok: Node) -> void:
	var butonlar := kok.find_children("*", "Button", true, false)
	if not butonlar.is_empty():
		(butonlar[0] as Button).grab_focus()
