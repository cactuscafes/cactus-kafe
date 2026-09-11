extends CanvasLayer
## Ekran kontrolleri: sol altta hareket çubuğu, sağda kamera, sağ altta düğmeler.
##
## Hiçbiri oyuncu koduna dokunmuyor: çubuk `Input.action_press(eylem, guc)` ile
## aynı eylemleri basıyor, kamera sürüklemesi `Girdi.bakis_kaydi` sinyalinden
## geçiyor. Oyuncu ve kamera, girdinin klavyeden mi parmaktan mı geldiğini
## bilmiyor.
##
## PARMAK BOYUTU: düğmeler 120 px (1280x720 tasarımında). Telefonda ~9 mm'ye
## denk gelir; bundan küçük düğmelere basılamıyor, bu bir estetik tercih değil.

const CUBUK_YARICAP := 110.0
const OLU_BOLGE := 0.18

@onready var _cubuk: Control = %Cubuk

var _cubuk_parmak := -1
var _cubuk_merkez := Vector2.ZERO
var _cubuk_yon := Vector2.ZERO
var _bakis_parmak := -1
var _basili: Array[String] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	visible = Girdi.dokunmatik
	Girdi.dokunmatik_degisti.connect(_gorunurluk)
	%Zipla.button_down.connect(func() -> void: Input.action_press("ziplama"))
	%Zipla.button_up.connect(func() -> void: Input.action_release("ziplama"))
	%Kos.toggled.connect(func(acik: bool) -> void:
		if acik: Input.action_press("kosma")
		else: Input.action_release("kosma"))
	%Duraklat.pressed.connect(func() -> void:
		var menu := get_parent().get_node_or_null("Duraklat")
		if menu != null:
			menu.duraklat(true))

func _gorunurluk(aktif: bool) -> void:
	visible = aktif
	if not aktif:
		_birak()

func _unhandled_input(olay: InputEvent) -> void:
	# Düğmelerin üstündeki dokunuşlar buraya hiç gelmiyor: Control'ler onları
	# _gui_input'ta tüketiyor. Bölme bu yüzden güvenli.
	var ekran := get_viewport().get_visible_rect().size
	if olay is InputEventScreenTouch:
		var dokunus := olay as InputEventScreenTouch
		if dokunus.pressed:
			if dokunus.position.x < ekran.x * 0.5 and _cubuk_parmak < 0:
				_cubuk_parmak = dokunus.index
				_cubuk_merkez = dokunus.position
				_cubuk.position = _cubuk_merkez
				_cubuk.yon = Vector2.ZERO
				_cubuk.visible = true
			elif _bakis_parmak < 0:
				_bakis_parmak = dokunus.index
		else:
			if dokunus.index == _cubuk_parmak:
				_cubuk_parmak = -1
				_cubuk_yon = Vector2.ZERO
				_cubuk.visible = false
				_birak()
			elif dokunus.index == _bakis_parmak:
				_bakis_parmak = -1
	elif olay is InputEventScreenDrag:
		var surukle := olay as InputEventScreenDrag
		if surukle.index == _cubuk_parmak:
			var fark := surukle.position - _cubuk_merkez
			_cubuk_yon = fark / CUBUK_YARICAP
			if _cubuk_yon.length() > 1.0:
				_cubuk_yon = _cubuk_yon.normalized()
			_cubuk.yon = _cubuk_yon
		elif surukle.index == _bakis_parmak:
			Girdi.bakis_kaydi.emit(surukle.relative)

func _process(_delta: float) -> void:
	if _cubuk_parmak < 0:
		return
	# Çubuğun gücü eylemlere aktarılıyor: hafif itince yürüme, sonuna kadar
	# itince koşma hızına yaklaşma — analog çubuk gibi.
	_bas("sag", _cubuk_yon.x)
	_bas("sol", -_cubuk_yon.x)
	_bas("geri", _cubuk_yon.y)
	_bas("ileri", -_cubuk_yon.y)

func _bas(eylem: String, guc: float) -> void:
	if guc > OLU_BOLGE:
		Input.action_press(eylem, minf(guc, 1.0))
		if not _basili.has(eylem):
			_basili.append(eylem)
	elif _basili.has(eylem):
		Input.action_release(eylem)
		_basili.erase(eylem)

func _birak() -> void:
	for eylem in _basili:
		Input.action_release(eylem)
	_basili.clear()
