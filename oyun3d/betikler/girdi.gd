extends Node
## Girdi eylemlerini çalışma zamanında kurar (autoload: Girdi).
##
## Klavye + oyun kolu birlikte tanımlı: aynı eylem iki girdiden de gelir, oyun
## kodu hangisinin bastığını bilmez. Girdiyi soyutlamanın bütün amacı bu.
##
## Faz 2'de bunlar Proje Ayarları > Girdi Haritası paneline taşınacak; oyuncuya
## tuş atama ekranı yazılacağı gün zaten oraya ihtiyaç olacak.

const OLU_BOLGE := 0.2

const TUSLAR := {
	"ileri": [KEY_W, KEY_UP],
	"geri": [KEY_S, KEY_DOWN],
	"sol": [KEY_A, KEY_LEFT],
	"sag": [KEY_D, KEY_RIGHT],
	"ziplama": [KEY_SPACE],
	"kosma": [KEY_SHIFT],
	"duraklat": [KEY_ESCAPE],
	"yeniden": [KEY_R],
	"bak_sol": [],
	"bak_sag": [],
	"bak_yukari": [],
	"bak_asagi": [],
}

## eylem -> [eksen, yön]
const EKSENLER := {
	"sol": [JOY_AXIS_LEFT_X, -1.0],
	"sag": [JOY_AXIS_LEFT_X, 1.0],
	"ileri": [JOY_AXIS_LEFT_Y, -1.0],
	"geri": [JOY_AXIS_LEFT_Y, 1.0],
	"bak_sol": [JOY_AXIS_RIGHT_X, -1.0],
	"bak_sag": [JOY_AXIS_RIGHT_X, 1.0],
	"bak_yukari": [JOY_AXIS_RIGHT_Y, -1.0],
	"bak_asagi": [JOY_AXIS_RIGHT_Y, 1.0],
}

const DUGMELER := {
	"ziplama": JOY_BUTTON_A,
	"kosma": JOY_BUTTON_LEFT_SHOULDER,
	"yeniden": JOY_BUTTON_Y,
	"duraklat": JOY_BUTTON_START,
}

func _ready() -> void:
	for eylem: String in TUSLAR:
		if not InputMap.has_action(eylem):
			InputMap.add_action(eylem, OLU_BOLGE)
		for kod: int in TUSLAR[eylem]:
			var tus := InputEventKey.new()
			tus.physical_keycode = kod
			_ekle(eylem, tus)

	for eylem: String in EKSENLER:
		var eksen := InputEventJoypadMotion.new()
		eksen.axis = EKSENLER[eylem][0]
		eksen.axis_value = EKSENLER[eylem][1]
		_ekle(eylem, eksen)

	for eylem: String in DUGMELER:
		var dugme := InputEventJoypadButton.new()
		dugme.button_index = DUGMELER[eylem]
		_ekle(eylem, dugme)

func _ekle(eylem: String, olay: InputEvent) -> void:
	if not InputMap.action_has_event(eylem, olay):
		InputMap.action_add_event(eylem, olay)
