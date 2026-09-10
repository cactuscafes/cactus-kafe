extends CanvasLayer
## Bölüm bitiş ekranı: süre, ölüm, rekor.

@export var oyun_yolu: NodePath = ^"../Oyun"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	var oyun := get_node(oyun_yolu)
	oyun.bolum_bitti.connect(_goster.bind(oyun))
	%Tekrar.pressed.connect(func() -> void:
		get_tree().paused = false
		get_tree().reload_current_scene())
	%AnaMenu.pressed.connect(func() -> void:
		get_tree().paused = false
		get_tree().change_scene_to_file("res://sahneler/ana_menu.tscn"))
	MenuYardimci.butonlari_seslendir(self)

func _goster(rekor: bool, oyun: Node) -> void:
	%Sure.text = "Süre   %s" % Ayarlar.sure_metni(oyun.sure)
	%Olum.text = "Ölüm   %d" % oyun.olum
	%EnIyi.text = "En iyi   %s" % Ayarlar.sure_metni(Ayarlar.en_iyi_sure)
	%Rekor.visible = rekor
	visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	MenuYardimci.ilk_butona_odaklan(self)
