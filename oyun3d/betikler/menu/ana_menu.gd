extends Control
## Ana menü.

const BOLUM := "res://sahneler/ana.tscn"

@onready var _rekor: Label = %Rekor
@onready var _ayarlar: Control = %AyarlarPaneli
@onready var _krediler: Control = %KredilerPaneli

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = false
	Ses.muzik_baslat()
	_rekor.text = "En iyi süre: %s   ·   %d kez oynandı" % [
		Ayarlar.sure_metni(Ayarlar.en_iyi_sure), Ayarlar.oynanma,
	]
	%Basla.pressed.connect(func() -> void: get_tree().change_scene_to_file(BOLUM))
	%Ayarlar.pressed.connect(func() -> void: _panel(_ayarlar, true))
	%Krediler.pressed.connect(func() -> void: _panel(_krediler, true))
	%Cik.pressed.connect(func() -> void: get_tree().quit())
	%Cik.visible = not OS.has_feature("web")  # tarayıcıda sekmeyi oyun kapatmaz
	%KredilerKapat.pressed.connect(func() -> void: _panel(_krediler, false))
	_ayarlar.kapandi.connect(func() -> void: _panel(_ayarlar, false))
	MenuYardimci.butonlari_seslendir(self)
	MenuYardimci.ilk_butona_odaklan(%Kutu)

func _panel(panel: Control, ac: bool) -> void:
	panel.visible = ac
	%Kutu.visible = not ac
	if ac:
		MenuYardimci.ilk_butona_odaklan(panel)
	else:
		MenuYardimci.ilk_butona_odaklan(%Kutu)
