extends Node
## Girdi eylemlerini çalışma zamanında kurar (autoload: Girdi).
##
## Faz 0'da eylemler kodda tanımlı; böylece proje dosyası sürümden bağımsız
## kalıyor ve tuş listesi tek yerden okunuyor. Faz 1'de bunları
## Proje > Proje Ayarları > Girdi Haritası paneline taşı: editörde tuş
## atamak, kod değiştirmekten hızlıdır ve oyuncuya tuş atama ekranı
## yazacaksan zaten oraya ihtiyacın olacak.

const EYLEMLER := {
	"ileri": [KEY_W, KEY_UP],
	"geri": [KEY_S, KEY_DOWN],
	"sol": [KEY_A, KEY_LEFT],
	"sag": [KEY_D, KEY_RIGHT],
	"ziplama": [KEY_SPACE],
	"kosma": [KEY_SHIFT],
	"fare_birak": [KEY_ESCAPE],
}

func _ready() -> void:
	for eylem: String in EYLEMLER:
		if not InputMap.has_action(eylem):
			InputMap.add_action(eylem)
		for kod: int in EYLEMLER[eylem]:
			var olay := InputEventKey.new()
			olay.physical_keycode = kod
			if not InputMap.action_has_event(eylem, olay):
				InputMap.action_add_event(eylem, olay)
