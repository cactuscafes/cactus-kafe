extends Control
## Ses, fare ve ekran ayarları. Hem ana menüde hem duraklatmada aynı panel.

signal kapandi

@onready var _master: HSlider = %Master
@onready var _sfx: HSlider = %SFX
@onready var _muzik: HSlider = %Muzik
@onready var _hassasiyet: HSlider = %Hassasiyet
@onready var _tam_ekran: CheckButton = %TamEkran

func _ready() -> void:
	_master.value = Ayarlar.master
	_sfx.value = Ayarlar.sfx
	_muzik.value = Ayarlar.muzik
	# Hassasiyet kullanıcıya 1-10 arası gösteriliyor; içeride radyan/piksel.
	_hassasiyet.value = Ayarlar.hassasiyet * 2000.0
	_tam_ekran.button_pressed = Ayarlar.tam_ekran
	_tam_ekran.visible = not OS.has_feature("web")  # tarayıcıda F11 kullanıcının işi

	_master.value_changed.connect(func(d: float) -> void: _degisti("master", d))
	_sfx.value_changed.connect(func(d: float) -> void: _degisti("sfx", d))
	_muzik.value_changed.connect(func(d: float) -> void: _degisti("muzik", d))
	_hassasiyet.value_changed.connect(func(d: float) -> void: _degisti("hassasiyet", d))
	_tam_ekran.toggled.connect(func(a: bool) -> void: _degisti("tam_ekran", 1.0 if a else 0.0))
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
	Ayarlar.uygula()
	Ayarlar.kaydet()
