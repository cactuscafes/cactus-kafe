extends Node
## Ayarlar ve kayıt (autoload: Ayarlar).
##
## İkisi de `user://` altında ConfigFile olarak duruyor. user:// yolu her
## platformda oyuna ait yazılabilir klasördür (Windows'ta AppData, tarayıcıda
## IndexedDB); proje klasörüne yazmak dışa aktarılmış oyunda çalışmaz.

const AYAR_YOLU := "user://ayarlar.cfg"
const KAYIT_YOLU := "user://kayit.cfg"

signal degisti

# ayarlar
var master := 0.85
var sfx := 0.9
var muzik := 0.55
var hassasiyet := 0.0022
var tam_ekran := false

# kayıt
var en_iyi_sure := 0.0
var en_iyi_olum := 0
var oynanma := 0

func _ready() -> void:
	yukle()
	uygula()

func yukle() -> void:
	var c := ConfigFile.new()
	if c.load(AYAR_YOLU) == OK:
		master = c.get_value("ses", "master", master)
		sfx = c.get_value("ses", "sfx", sfx)
		muzik = c.get_value("ses", "muzik", muzik)
		hassasiyet = c.get_value("kontrol", "hassasiyet", hassasiyet)
		tam_ekran = c.get_value("ekran", "tam_ekran", tam_ekran)
	var k := ConfigFile.new()
	if k.load(KAYIT_YOLU) == OK:
		en_iyi_sure = k.get_value("bolum1", "en_iyi_sure", 0.0)
		en_iyi_olum = k.get_value("bolum1", "en_iyi_olum", 0)
		oynanma = k.get_value("bolum1", "oynanma", 0)

func kaydet() -> void:
	var c := ConfigFile.new()
	c.set_value("ses", "master", master)
	c.set_value("ses", "sfx", sfx)
	c.set_value("ses", "muzik", muzik)
	c.set_value("kontrol", "hassasiyet", hassasiyet)
	c.set_value("ekran", "tam_ekran", tam_ekran)
	c.save(AYAR_YOLU)

func uygula() -> void:
	Ses.seviye_ayarla(&"Master", master)
	Ses.seviye_ayarla(&"SFX", sfx)
	Ses.seviye_ayarla(&"Muzik", muzik)
	# Tarayıcıda tam ekran ancak kullanıcı hareketiyle açılır; sessizce geçilir.
	if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
		if not tam_ekran:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	elif tam_ekran:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	degisti.emit()

## Bölüm bitince çağrılır. Yeni rekor kırıldıysa true döner.
func sonuc_kaydet(sure: float, olum: int) -> bool:
	oynanma += 1
	var rekor := en_iyi_sure <= 0.0 or sure < en_iyi_sure
	if rekor:
		en_iyi_sure = sure
		en_iyi_olum = olum
	var k := ConfigFile.new()
	k.set_value("bolum1", "en_iyi_sure", en_iyi_sure)
	k.set_value("bolum1", "en_iyi_olum", en_iyi_olum)
	k.set_value("bolum1", "oynanma", oynanma)
	k.save(KAYIT_YOLU)
	return rekor

static func sure_metni(saniye: float) -> String:
	if saniye <= 0.0:
		return "—"
	return "%d:%05.2f" % [int(saniye) / 60, fmod(saniye, 60.0)]
