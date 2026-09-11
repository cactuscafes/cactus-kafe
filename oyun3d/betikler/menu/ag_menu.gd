extends Control
## Yarış lobisi: barındır ya da katıl, oyuncuları gör, yarışı başlat.

signal kapandi

@onready var _durum: Label = %Durum
@onready var _liste: Label = %Liste
@onready var _adres: LineEdit = %Adres
@onready var _ad: LineEdit = %Ad

func _ready() -> void:
	_ad.text = Ayarlar.oyuncu_adi
	%Barindir.pressed.connect(_barindir)
	%Katil.pressed.connect(_katil)
	%Baslat.pressed.connect(func() -> void: Ag.yarisi_baslat())
	%Ayril.pressed.connect(func() -> void:
		Ag.ayril()
		_yenile())
	%Kapat.pressed.connect(func() -> void: kapandi.emit())
	Ag.durum_degisti.connect(func(m: String) -> void: _durum.text = m)
	Ag.siralama_degisti.connect(func(_s: Array) -> void: _yenile())
	Ag.oyuncu_ayrildi.connect(func(_k: int) -> void: _yenile())
	Ag.yaris_basladi.connect(func() -> void:
		get_tree().change_scene_to_file(Bolumler.sahne("bolum1")))
	MenuYardimci.butonlari_seslendir(self)
	_yenile()

func _adi_kaydet() -> void:
	Ayarlar.oyuncu_adi = _ad.text.strip_edges().substr(0, 16)
	if Ayarlar.oyuncu_adi.is_empty():
		Ayarlar.oyuncu_adi = "Oyuncu"
	Ayarlar.kaydet()
	Ag.kendi_adim = Ayarlar.oyuncu_adi

func _barindir() -> void:
	_adi_kaydet()
	Ag.sunucu_baslat()
	_yenile()

func _katil() -> void:
	_adi_kaydet()
	Ag.katil(_adres.text.strip_edges())
	_yenile()

func _yenile() -> void:
	%Barindir.disabled = Ag.bagli
	%Katil.disabled = Ag.bagli
	%Adres.editable = not Ag.bagli
	%Ad.editable = not Ag.bagli
	%Baslat.visible = Ag.barindiriyor
	%Ayril.visible = Ag.bagli
	if not Ag.bagli:
		_liste.text = tr("AG_BAGLI_DEGIL")
		return
	var satirlar: Array[String] = []
	for o: Dictionary in Ag.siralama():
		satirlar.append("%s%s" % [o["ad"],
			"  —  %s" % Ayarlar.sure_metni(o["sure"]) if o["bitti"] else ""])
	_liste.text = "\n".join(satirlar)
