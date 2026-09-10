extends CanvasLayer
## Duraklatma menüsü. Esc ile açılır/kapanır.
##
## Ağacı duraklatıyoruz (get_tree().paused), bu yüzden bu düğüm ve altındakiler
## PROCESS_MODE_ALWAYS olmak zorunda; yoksa menü kendisi de donar ve oyun bir
## daha açılmaz.

@onready var _ayarlar: Control = %AyarlarPaneli
@onready var _kutu: Control = %Kutu

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	%Devam.pressed.connect(func() -> void: duraklat(false))
	%AyarlarButonu.pressed.connect(func() -> void: _panel(true))
	%Yeniden.pressed.connect(func() -> void:
		get_tree().paused = false
		get_tree().reload_current_scene())
	%AnaMenu.pressed.connect(func() -> void:
		get_tree().paused = false
		get_tree().change_scene_to_file("res://sahneler/ana_menu.tscn"))
	_ayarlar.kapandi.connect(func() -> void: _panel(false))
	MenuYardimci.butonlari_seslendir(self)

func _unhandled_input(olay: InputEvent) -> void:
	if olay.is_action_pressed("duraklat"):
		# Bölüm bitmişse duraklatma anlamsız: bitiş ekranı zaten açık.
		var oyun := get_parent().get_node_or_null("Oyun")
		if oyun != null and oyun.bitti:
			return
		duraklat(not visible)
		get_viewport().set_input_as_handled()

func duraklat(ac: bool) -> void:
	visible = ac
	get_tree().paused = ac
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if ac else Input.MOUSE_MODE_CAPTURED
	if ac:
		_panel(false)
		MenuYardimci.ilk_butona_odaklan(_kutu)

func _panel(ac: bool) -> void:
	_ayarlar.visible = ac
	_kutu.visible = not ac
	if ac:
		MenuYardimci.ilk_butona_odaklan(_ayarlar)
	else:
		MenuYardimci.ilk_butona_odaklan(_kutu)
