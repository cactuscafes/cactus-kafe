extends Control
## Ana menü.

@onready var _rekor: Label = %Rekor
@onready var _bolum_kutusu: VBoxContainer = %BolumKutusu
@onready var _ayarlar: Control = %AyarlarPaneli
@onready var _krediler: Control = %KredilerPaneli

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = false
	Ses.muzik_baslat()
	_bolumleri_kur()
	%Ayarlar.pressed.connect(func() -> void: _panel(_ayarlar, true))
	%Krediler.pressed.connect(func() -> void: _panel(_krediler, true))
	%Cik.pressed.connect(func() -> void: get_tree().quit())
	%Cik.visible = not OS.has_feature("web")  # tarayıcıda sekmeyi oyun kapatmaz
	%KredilerKapat.pressed.connect(func() -> void: _panel(_krediler, false))
	_ayarlar.kapandi.connect(func() -> void: _panel(_ayarlar, false))
	MenuYardimci.butonlari_seslendir(self)
	MenuYardimci.ilk_butona_odaklan(%Kutu)

## Bölüm düğmeleri kütükten üretiliyor: yeni bölüm eklemek için menüye
## dokunmak gerekmiyor, `bolumler.gd`'ye bir satır yetiyor.
func _bolumleri_kur() -> void:
	var toplam := 0
	for i in Bolumler.LISTE.size():
		var bilgi: Dictionary = Bolumler.LISTE[i]
		var kimlik: String = bilgi["kimlik"]
		var kayit := Ayarlar.kayit(kimlik)
		toplam += int(kayit["oynanma"])

		var buton := Button.new()
		buton.custom_minimum_size = Vector2(340, 0)
		var sure: float = kayit["sure"]
		buton.text = "%d. %s%s" % [
			i + 1, tr(bilgi["ad"]),
			"" if sure <= 0.0 else "   ·   %s" % Ayarlar.sure_metni(sure),
		]
		buton.pressed.connect(
			func() -> void: get_tree().change_scene_to_file(bilgi["sahne"]))
		_bolum_kutusu.add_child(buton)

	_rekor.text = (tr("MENU_REKOR_YOK") if toplam == 0
		else tr("MENU_OZET") % [Bolumler.sayi(), toplam])

func _panel(panel: Control, ac: bool) -> void:
	panel.visible = ac
	%Kutu.visible = not ac
	if ac:
		MenuYardimci.ilk_butona_odaklan(panel)
	else:
		MenuYardimci.ilk_butona_odaklan(%Kutu)
