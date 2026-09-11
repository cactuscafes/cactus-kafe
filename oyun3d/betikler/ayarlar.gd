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
var dil := "tr"
## Erişilebilirlik: ekran sarsıntısı hareket hassasiyeti olanlarda rahatsızlık
## yapabiliyor. Kapatmak oynanışı değiştirmiyor, yalnızca kamerayı sabit
## tutuyor.
var sarsinti := true
var oyuncu_adi := "Oyuncu"

# kayıt — bölüm kimliğine göre: {"bolum1": {"sure": 42.0, "olum": 1, "oynanma": 3}}
var kayitlar := {}

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
		dil = c.get_value("genel", "dil", dil)
		sarsinti = c.get_value("erisim", "sarsinti", sarsinti)
		oyuncu_adi = c.get_value("genel", "oyuncu_adi", oyuncu_adi)
	var k := ConfigFile.new()
	kayitlar = {}
	if k.load(KAYIT_YOLU) == OK:
		for bolum in k.get_sections():
			kayitlar[bolum] = {
				"sure": k.get_value(bolum, "en_iyi_sure", 0.0),
				"olum": k.get_value(bolum, "en_iyi_olum", 0),
				"oynanma": k.get_value(bolum, "oynanma", 0),
			}

func kaydet() -> void:
	var c := ConfigFile.new()
	c.set_value("ses", "master", master)
	c.set_value("ses", "sfx", sfx)
	c.set_value("ses", "muzik", muzik)
	c.set_value("kontrol", "hassasiyet", hassasiyet)
	c.set_value("ekran", "tam_ekran", tam_ekran)
	c.set_value("genel", "dil", dil)
	c.set_value("erisim", "sarsinti", sarsinti)
	c.set_value("genel", "oyuncu_adi", oyuncu_adi)
	c.save(AYAR_YOLU)

func uygula() -> void:
	TranslationServer.set_locale(dil)
	Ag.kendi_adim = oyuncu_adi
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

## Bölümün kaydını döndürür; hiç oynanmadıysa sıfırlı sözlük.
func kayit(bolum: String) -> Dictionary:
	return kayitlar.get(bolum, {"sure": 0.0, "olum": 0, "oynanma": 0})

func en_iyi_sure(bolum: String) -> float:
	return kayit(bolum)["sure"]

func oynanma(bolum: String) -> int:
	return kayit(bolum)["oynanma"]

## Bölüm bitince çağrılır. Yeni rekor kırıldıysa true döner.
func sonuc_kaydet(bolum: String, sure: float, olum: int) -> bool:
	var mevcut: Dictionary = kayit(bolum).duplicate()
	mevcut["oynanma"] = int(mevcut["oynanma"]) + 1
	var rekor: bool = float(mevcut["sure"]) <= 0.0 or sure < float(mevcut["sure"])
	if rekor:
		mevcut["sure"] = sure
		mevcut["olum"] = olum
	kayitlar[bolum] = mevcut

	var k := ConfigFile.new()
	for kimlik: String in kayitlar:
		k.set_value(kimlik, "en_iyi_sure", kayitlar[kimlik]["sure"])
		k.set_value(kimlik, "en_iyi_olum", kayitlar[kimlik]["olum"])
		k.set_value(kimlik, "oynanma", kayitlar[kimlik]["oynanma"])
	k.save(KAYIT_YOLU)
	return rekor

static func sure_metni(saniye: float) -> String:
	if saniye <= 0.0:
		return "—"
	return "%d:%05.2f" % [int(saniye) / 60, fmod(saniye, 60.0)]
