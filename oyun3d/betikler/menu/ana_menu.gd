extends Control
## Ana menü.

@onready var _rekor: Label = %Rekor
@onready var _bolum_kutusu: GridContainer = %BolumKutusu
@onready var _ayarlar: Control = %AyarlarPaneli
@onready var _krediler: Control = %KredilerPaneli
@onready var _ag: Control = %AgPaneli

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = false
	Ses.muzik_baslat()
	_bolumleri_kur()
	%Ayarlar.pressed.connect(func() -> void: _panel(_ayarlar, true))
	%Krediler.pressed.connect(func() -> void: _panel(_krediler, true))
	%Yaris.pressed.connect(func() -> void: _panel(_ag, true))
	_ag.kapandi.connect(func() -> void: _panel(_ag, false))
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
	var bolumler := Bolumler.liste()
	# Altı bölüm tek sütunda 720p ekrana sığmıyor: en alttaki "Çık" düğmesi
	# ekranın dışında kalıyordu. Üçten fazlası iki sütuna geçiyor; demoda
	# (tek bölüm) tek sütun daha derli toplu duruyor.
	_bolum_kutusu.columns = 2 if bolumler.size() > 3 else 1
	for i in bolumler.size():
		var bilgi: Dictionary = bolumler[i]
		var kimlik: String = bilgi["kimlik"]
		var kayit := Ayarlar.kayit(kimlik)
		toplam += int(kayit["oynanma"])

		var buton := Button.new()
		buton.custom_minimum_size = Vector2(250 if _bolum_kutusu.columns > 1 else 340, 0)
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
	%AltBaslik.text = tr("MENU_DEMO") if Urun.demo else tr("MENU_ALTBASLIK")

func _panel(panel: Control, ac: bool) -> void:
	panel.visible = ac
	%Kutu.visible = not ac
	if ac:
		MenuYardimci.ilk_butona_odaklan(panel)
	else:
		MenuYardimci.ilk_butona_odaklan(%Kutu)
