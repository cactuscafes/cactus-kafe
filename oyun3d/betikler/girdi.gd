extends Node
## Girdi eylemlerini çalışma zamanında kurar (autoload: Girdi).
##
## Klavye + oyun kolu birlikte tanımlı: aynı eylem iki girdiden de gelir, oyun
## kodu hangisinin bastığını bilmez. Girdiyi soyutlamanın bütün amacı bu.
##
## TUŞ ATAMA (Faz 9): oyuncu birincil tuşları değiştirebiliyor. İkincil tuşlar
## (ok tuşları) ve oyun kolu bağlamaları DEĞİŞMİYOR — böylece kimse kendini
## oyundan kilitleyemiyor. Özel atamalar `Ayarlar.tuslar` içinde saklanıyor ve
## `Ayarlar.uygula()` tarafından buraya veriliyor; Girdi otomatik yüklemeden
## okumuyor, çünkü autoload sırasında Girdi, Ayarlar'dan ÖNCE hazırlanıyor.
##
## DOKUNMATİK: ekrandaki çubuk ve düğmeler de aynı eylemleri basıyor
## (`Input.action_press`), yani oyuncu ve kamera kodu girdinin nereden geldiğini
## bilmiyor. Girdiyi soyutlamanın bütün karşılığı bu: telefon desteği eklemek
## `oyuncu.gd`'ye tek satır dokunmadan yapılabildi.

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

## Dokunmatik sürükleme kameraya buradan geçiyor: ekrandaki katman kamerayı
## tanımıyor, kamera da ekranı tanımıyor.
signal bakis_kaydi(delta: Vector2)
## Oyuncu son olarak hangi girdiyi kullandı? Ekran kontrolleri buna göre
## görünüyor/gizleniyor — aynı derleme hem telefonda hem masaüstünde doğru.
signal dokunmatik_degisti(aktif: bool)

var dokunmatik := false:
	set(deger):
		if dokunmatik != deger:
			dokunmatik = deger
			dokunmatik_degisti.emit(deger)

const DUGMELER := {
	"ziplama": JOY_BUTTON_A,
	"kosma": JOY_BUTTON_LEFT_SHOULDER,
	"yeniden": JOY_BUTTON_Y,
	"duraklat": JOY_BUTTON_START,
}

## Oyuncuya gösterilen ve değiştirilebilen eylemler; sıra ekranda da bu.
## Bakış eylemleri listede yok: onlar fare/çubuk işi.
const ATANABILIR := ["ileri", "geri", "sol", "sag", "ziplama", "kosma",
	"duraklat", "yeniden"]

## eylem -> özel birincil tuş (physical keycode). Ayarlar veriyor.
var _ozel := {}

func _ready() -> void:
	tuslari_uygula({})

	for eylem: String in EKSENLER:
		var eksen := InputEventJoypadMotion.new()
		eksen.axis = EKSENLER[eylem][0]
		eksen.axis_value = EKSENLER[eylem][1]
		_ekle(eylem, eksen)

	for eylem: String in DUGMELER:
		var dugme := InputEventJoypadButton.new()
		dugme.button_index = DUGMELER[eylem]
		_ekle(eylem, dugme)

func _input(olay: InputEvent) -> void:
	if olay is InputEventScreenTouch or olay is InputEventScreenDrag:
		dokunmatik = true
	elif olay is InputEventKey or olay is InputEventMouseMotion \
			or olay is InputEventJoypadButton:
		dokunmatik = false

func _ekle(eylem: String, olay: InputEvent) -> void:
	if not InputMap.action_has_event(eylem, olay):
		InputMap.action_add_event(eylem, olay)

# ------------------------------------------------------------------ tuş atama

## Klavye bağlamalarını yeniden kurar. Yalnızca klavye olayları siliniyor:
## oyun kolu bağlamaları elle temizlenirse, kumandayla oynayan oyuncu tuş
## atama ekranını açtığı an kumandasını kaybederdi.
func tuslari_uygula(ozel: Dictionary) -> void:
	_ozel = ozel.duplicate()
	for eylem: String in TUSLAR:
		if not InputMap.has_action(eylem):
			InputMap.add_action(eylem, OLU_BOLGE)
		for olay: InputEvent in InputMap.action_get_events(eylem):
			if olay is InputEventKey:
				InputMap.action_erase_event(eylem, olay)
		for kod: int in kodlar(eylem):
			var tus := InputEventKey.new()
			tus.physical_keycode = kod
			_ekle(eylem, tus)

## Eylemin şu anki klavye kodları. Özel atama BİRİNCİL tuşun yerine geçiyor,
## ikincil (ok tuşları) yerinde kalıyor.
func kodlar(eylem: String) -> Array:
	var varsayilan: Array = TUSLAR.get(eylem, [])
	if not _ozel.has(eylem):
		return varsayilan
	var liste := varsayilan.duplicate()
	if liste.is_empty():
		return [int(_ozel[eylem])]
	liste[0] = int(_ozel[eylem])
	return liste

func tus_kodu(eylem: String) -> int:
	var liste := kodlar(eylem)
	return int(liste[0]) if not liste.is_empty() else 0

func tus_adi(eylem: String) -> String:
	var kod := tus_kodu(eylem)
	return OS.get_keycode_string(kod) if kod != 0 else "—"

## Bu tuş başka bir eylemde kullanılıyor mu? Kullanılıyorsa o eylemin adı.
## Çakışmayı sessizce çözmek (diğerini boşaltmak) yerine reddediyoruz: oyuncu
## hangi tuşu kaybettiğini fark etmeden kaybetmemeli.
func cakisma(eylem: String, kod: int) -> String:
	for diger: String in TUSLAR:
		if diger == eylem:
			continue
		if kodlar(diger).has(kod):
			return diger
	return ""

## Yeni birincil tuş. Çakışma varsa atama YAPILMIYOR, çakışan eylem dönüyor.
func tus_ata(eylem: String, kod: int) -> String:
	var engel := cakisma(eylem, kod)
	if not engel.is_empty():
		return engel
	var yeni := _ozel.duplicate()
	yeni[eylem] = kod
	tuslari_uygula(yeni)
	Ayarlar.tuslar = yeni
	Ayarlar.kaydet()
	return ""

func varsayilana_don() -> void:
	tuslari_uygula({})
	Ayarlar.tuslar = {}
	Ayarlar.kaydet()
