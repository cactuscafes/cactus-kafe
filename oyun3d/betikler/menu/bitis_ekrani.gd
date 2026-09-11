extends CanvasLayer
## Bölüm bitiş ekranı: süre, ölüm, rekor.

@export var oyun_yolu: NodePath = ^"../Oyun"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	var oyun := get_node(oyun_yolu)
	oyun.bolum_bitti.connect(_goster.bind(oyun))
	%Sonraki.visible = false
	%Tekrar.pressed.connect(func() -> void:
		get_tree().paused = false
		get_tree().reload_current_scene())
	%AnaMenu.pressed.connect(func() -> void:
		get_tree().paused = false
		get_tree().change_scene_to_file("res://sahneler/ana_menu.tscn"))
	MenuYardimci.butonlari_seslendir(self)

func _goster(rekor: bool, oyun: Node) -> void:
	var sonraki := Bolumler.sonraki(oyun.bolum_kimligi)
	%Sonraki.visible = sonraki != ""
	if sonraki != "":
		%Sonraki.text = "Sonraki: %s" % Bolumler.ad(sonraki)
		if not %Sonraki.pressed.is_connected(_sonrakine_gec):
			%Sonraki.pressed.connect(_sonrakine_gec.bind(sonraki))
	%Sure.text = "Süre   %s" % Ayarlar.sure_metni(oyun.sure)
	%Olum.text = "Ölüm   %d     Yenilen düşman   %d" % [oyun.olum, oyun.yenilen]
	%EnIyi.text = "En iyi   %s" % Ayarlar.sure_metni(Ayarlar.en_iyi_sure(oyun.bolum_kimligi))
	%Rekor.visible = rekor
	visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	MenuYardimci.butonlari_seslendir(self)
	MenuYardimci.ilk_butona_odaklan(self)

func _sonrakine_gec(kimlik: String) -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(Bolumler.sahne(kimlik))
