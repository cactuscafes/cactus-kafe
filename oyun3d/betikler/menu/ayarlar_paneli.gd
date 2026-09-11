extends Control
## Ses, fare ve ekran ayarları. Hem ana menüde hem duraklatmada aynı panel.

signal kapandi

@onready var _master: HSlider = %Master
@onready var _sfx: HSlider = %SFX
@onready var _muzik: HSlider = %Muzik
@onready var _hassasiyet: HSlider = %Hassasiyet
@onready var _tam_ekran: CheckButton = %TamEkran
@onready var _sarsinti: CheckButton = %Sarsinti
@onready var _dil: OptionButton = %Dil

const DILLER := [["tr", "Türkçe"], ["en", "English"]]

func _ready() -> void:
	_master.value = Ayarlar.master
	_sfx.value = Ayarlar.sfx
	_muzik.value = Ayarlar.muzik
	# Hassasiyet kullanıcıya 1-10 arası gösteriliyor; içeride radyan/piksel.
	_hassasiyet.value = Ayarlar.hassasiyet * 2000.0
	_tam_ekran.button_pressed = Ayarlar.tam_ekran
	_sarsinti.button_pressed = Ayarlar.sarsinti
	for i in DILLER.size():
		_dil.add_item(DILLER[i][1], i)
		if DILLER[i][0] == Ayarlar.dil:
			_dil.select(i)
	_tam_ekran.visible = not OS.has_feature("web")  # tarayıcıda F11 kullanıcının işi

	_master.value_changed.connect(func(d: float) -> void: _degisti("master", d))
	_sfx.value_changed.connect(func(d: float) -> void: _degisti("sfx", d))
	_muzik.value_changed.connect(func(d: float) -> void: _degisti("muzik", d))
	_hassasiyet.value_changed.connect(func(d: float) -> void: _degisti("hassasiyet", d))
	_tam_ekran.toggled.connect(func(a: bool) -> void: _degisti("tam_ekran", 1.0 if a else 0.0))
	_sarsinti.toggled.connect(func(a: bool) -> void: _degisti("sarsinti", 1.0 if a else 0.0))
	_dil.item_selected.connect(func(i: int) -> void:
		Ayarlar.dil = DILLER[i][0]
		Ayarlar.uygula()
		Ayarlar.kaydet())
	%Kapat.pressed.connect(func() -> void: kapandi.emit())
	MenuYardimci.butonlari_seslendir(self)

func _degisti(alan: String, deger: float) -> void:
	match alan:
		"master": Ayarlar.master = deger
		"sfx":
			Ayarlar.sfx = deger
			Ses.cal("tik")   # seviyeyi duyarak ayarlamak gerekir
		"muzik": Ayarlar.muzik = deger
		"hassasiyet": Ayarlar.hassasiyet = deger / 2000.0
		"tam_ekran": Ayarlar.tam_ekran = deger > 0.5
		"sarsinti": Ayarlar.sarsinti = deger > 0.5
	Ayarlar.uygula()
	Ayarlar.kaydet()
