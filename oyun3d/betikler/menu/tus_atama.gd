extends Control
## Tuş atama ekranı.
##
## NEDEN VAR: erişilebilirlikte en çok istenen madde bu. WASD herkes için
## uygun değil — sol elini kullananlar, tek elle oynayanlar, farklı klavye
## düzenleri. "Ok tuşları da çalışıyor" cevabı yeterli değil, çünkü zıplama
## ok tuşlarında yok.
##
## İKİ KİLİT: (1) ikincil tuşlar ve oyun kolu bağlamaları hiç değişmiyor,
## (2) çakışan atama reddediliyor. Oyuncunun kendini oyundan kilitlemesi
## mümkün olmamalı; "ayarları sıfırlamak için dosya silin" bir çözüm değildir.

signal kapandi

## Eylem -> çeviri anahtarı. Sıra ekranda göründüğü sıra.
const ETIKETLER := {
	"ileri": "EYLEM_ILERI",
	"geri": "EYLEM_GERI",
	"sol": "EYLEM_SOL",
	"sag": "EYLEM_SAG",
	"ziplama": "EYLEM_ZIPLAMA",
	"kosma": "EYLEM_KOSMA",
	"duraklat": "EYLEM_DURAKLAT",
	"yeniden": "EYLEM_YENIDEN",
}

@onready var _liste: GridContainer = %Liste
@onready var _uyari: Label = %Uyari

var _bekleyen := ""
var _butonlar := {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # duraklatmada da çalışmalı
	_satirlari_kur()
	%Varsayilan.pressed.connect(func() -> void:
		Girdi.varsayilana_don()
		_bekleyen = ""
		_tazele()
		_uyari.text = "")
	%Kapat.pressed.connect(func() -> void:
		_bekleyen = ""
		kapandi.emit())
	MenuYardimci.butonlari_seslendir(self)

## Sekiz eylem tek sütunda 720p ekrana sığmıyordu (son satır panelin dışına
## taşıyordu). İki sütunlu ızgara: etiket, düğme, etiket, düğme.
func _satirlari_kur() -> void:
	for eylem: String in Girdi.ATANABILIR:
		var etiket := Label.new()
		etiket.custom_minimum_size = Vector2(140, 0)
		etiket.text = ETIKETLER.get(eylem, eylem)
		_liste.add_child(etiket)

		var buton := Button.new()
		buton.custom_minimum_size = Vector2(130, 0)
		buton.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		buton.pressed.connect(_atamayi_basla.bind(eylem))
		_liste.add_child(buton)
		_butonlar[eylem] = buton
	_tazele()

func _tazele() -> void:
	for eylem: String in _butonlar:
		var buton: Button = _butonlar[eylem]
		buton.text = tr("TUS_BEKLENIYOR") if eylem == _bekleyen else Girdi.tus_adi(eylem)

func _atamayi_basla(eylem: String) -> void:
	_bekleyen = eylem
	_uyari.text = tr("TUS_IPUCU")
	_tazele()

## Bir sonraki tuşa basışı yakalıyoruz. `_input` (yalnızca `_unhandled_input`
## değil): atanacak tuş bir menü kısayolu olabilir ve düğmeye gitmeden önce
## bize gelmeli.
func _input(olay: InputEvent) -> void:
	if _bekleyen.is_empty():
		return
	var tus := olay as InputEventKey
	if tus == null or not tus.pressed or tus.echo:
		return
	get_viewport().set_input_as_handled()
	var eylem := _bekleyen
	_bekleyen = ""

	if tus.physical_keycode == KEY_ESCAPE:
		_uyari.text = ""   # vazgeçildi
		_tazele()
		return

	var engel := Girdi.tus_ata(eylem, tus.physical_keycode)
	if engel.is_empty():
		_uyari.text = ""
		Ses.cal("tik")
	else:
		# Çakışma: atama yapılmadı, eski tuş duruyor.
		_uyari.text = tr("TUS_CAKISMA") % [
			OS.get_keycode_string(tus.physical_keycode),
			tr(ETIKETLER.get(engel, engel))]
	_tazele()
