extends Control
## Ses, fare ve ekran ayarları. Hem ana menüde hem duraklatmada aynı panel.

signal kapandi

@onready var _master: HSlider = %Master
@onready var _sfx: HSlider = %SFX
@onready var _muzik: HSlider = %Muzik
@onready var _hassasiyet: HSlider = %Hassasiyet
@onready var _tam_ekran: CheckButton = %TamEkran
@onready var _sarsinti: CheckButton = %Sarsinti
@onready var _telemetri: CheckButton = %Telemetri
@onready var _dil: OptionButton = %Dil
@onready var _grafik: OptionButton = %Grafik

const DILLER := [["tr", "Türkçe"], ["en", "English"]]
## Grafik ön ayarları (Faz 13). Ne açıp kapattıkları `betikler/ortam.gd`de:
## düşük = gölgesiz ve serpintisiz, orta = gölge + dolgu ışığı + serpinti,
## yüksek = ayrıca parlama ve SSAO (SSAO yalnızca masaüstü render yolunda).
const GRAFIKLER := ["AYAR_GRAFIK_DUSUK", "AYAR_GRAFIK_ORTA", "AYAR_GRAFIK_YUKSEK"]

func _ready() -> void:
	_master.value = Ayarlar.master
	_sfx.value = Ayarlar.sfx
	_muzik.value = Ayarlar.muzik
	# Hassasiyet kullanıcıya 1-10 arası gösteriliyor; içeride radyan/piksel.
	_hassasiyet.value = Ayarlar.hassasiyet * 2000.0
	_tam_ekran.button_pressed = Ayarlar.tam_ekran
	_sarsinti.button_pressed = Ayarlar.sarsinti
	_telemetri.button_pressed = Ayarlar.telemetri
	# Sunucu kurulmadıysa seçeneği hiç gösterme: çalışmayan ayar, olmayan
	# ayardan kötüdür.
	_telemetri.visible = not Urun.TELEMETRI_URL.is_empty()
	_grafik_etiketle()
	# Dil değişince OptionButton öğeleri kendiliğinden çevrilmiyor: Godot
	# yalnızca Control'ün `text` alanını çeviriyor, koddan eklenen öğeleri
	# değil. Etiketler yeniden yazılmazsa dil Türkçeden İngilizceye geçince
	# bu kutu Türkçe kalıyor.
	Ayarlar.degisti.connect(_grafik_etiketle)
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
	_telemetri.toggled.connect(func(a: bool) -> void: _degisti("telemetri", 1.0 if a else 0.0))
	# Grafik ayarı YÜRÜRLÜKTEKİ bölüme hemen uygulanıyor: oyuncu duraklatma
	# menüsünde seçeneği değiştirip farkı görmeli, yeniden başlatmamalı.
	_grafik.item_selected.connect(func(i: int) -> void:
		Ayarlar.grafik = i
		Ayarlar.kaydet()
		for dugum in get_tree().get_nodes_in_group("ortam"):
			dugum.kalite_uygula()
		for dugum in get_tree().get_nodes_in_group("manzara"):
			dugum.kalite_uygula())
	_dil.item_selected.connect(func(i: int) -> void:
		Ayarlar.dil = DILLER[i][0]
		Ayarlar.uygula()
		Ayarlar.kaydet())
	%TusAtama.pressed.connect(_tus_atamayi_ac)
	# Telefonda klavye yok; çalışmayan ayarı göstermiyoruz (telemetri ile aynı
	# kural).
	%TusAtama.visible = not OS.has_feature("mobile")
	%Kapat.pressed.connect(func() -> void: kapandi.emit())
	MenuYardimci.butonlari_seslendir(self)

func _grafik_etiketle() -> void:
	_grafik.clear()
	for i in GRAFIKLER.size():
		_grafik.add_item(tr(GRAFIKLER[i]), i)
	_grafik.select(clampi(Ayarlar.grafik, 0, GRAFIKLER.size() - 1))

const TUS_ATAMA := preload("res://sahneler/tus_atama.tscn")

func _tus_atamayi_ac() -> void:
	var ekran: Control = TUS_ATAMA.instantiate()
	add_child(ekran)
	$Panel.visible = false
	ekran.kapandi.connect(func() -> void:
		ekran.queue_free()
		$Panel.visible = true)

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
		"telemetri": Ayarlar.telemetri = deger > 0.5
	Ayarlar.uygula()
	Ayarlar.kaydet()
