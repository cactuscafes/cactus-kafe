extends CanvasLayer
## Bölüm durumu ve kare bütçesi.
##
## Ölçüm satırı Faz 0'dan beri duruyor ve durmaya devam edecek: 16.6 ms'yi
## ekranda tutmak, performansın ne zaman bozulduğunu sonradan aramaktan ucuz.

const BUTCE_MS := 16.6

@export var oyun_yolu: NodePath = ^"../Oyun"
@export var oyuncu_yolu: NodePath = ^"../Oyuncu"
@export var hayalet_yolu: NodePath = ^"../HayaletKaydedici"

@onready var _durum: Label = $Durum
@onready var _mesaj: Label = $Mesaj
@onready var _olcum: Label = $Olcum
@onready var _can: Label = %Can
@onready var _hayalet_etiketi: Label = %Hayalet
## Canavar can çubuğu — yalnızca canavarı olan bölümlerde var (Faz 16).
@onready var _boss_kutu: Control = get_node_or_null("%BossCan")
@onready var _boss_dolu: ColorRect = get_node_or_null("%Dolu")

var _boss: Node = null
var _boss_genislik := 0.0

var _oyun: Node
var _hayalet: Node
var _sayac := 0.0

func _ready() -> void:
	_oyun = get_node(oyun_yolu)
	_oyun.durum_degisti.connect(_durumu_yaz)
	_hayalet = get_node_or_null(hayalet_yolu)
	_hayalet_etiketi.visible = false
	var oyuncu := get_node(oyuncu_yolu)
	oyuncu.can_degisti.connect(_cani_yaz)
	_cani_yaz(oyuncu.can, oyuncu.can_max)
	_boss_kur()
	_durumu_yaz()
	_olcumu_yaz()

## Canavar varsa çubuğu bağlar. Çubuk bölüm başında GÖRÜNMÜYOR: dövüş
## başlamadan ekranda duran bir can çubuğu, oyuncuya olmayan bir tehdidi
## işaret ediyor.
func _boss_kur() -> void:
	if _boss_kutu == null or not _oyun.has_method("boss"):
		return
	_boss = _oyun.boss()
	if _boss == null:
		return
	_boss_genislik = _boss_dolu.offset_right - _boss_dolu.offset_left
	_boss.can_degisti.connect(_boss_cani_yaz)

func _boss_cani_yaz(can: int, en_fazla: int) -> void:
	if _boss_dolu == null:
		return
	var oran := clampf(float(can) / maxf(float(en_fazla), 1.0), 0.0, 1.0)
	_boss_dolu.offset_right = _boss_dolu.offset_left + _boss_genislik * oran

func _process(delta: float) -> void:
	_durum.text = tr("HUD_DURUM") % [
		_oyun.toplanan, _oyun.hedef_toplanabilir, _oyun.sure, _oyun.olum,
	]
	# Görünürlüğe HER KARE karar veriyoruz. _ready'de bir kez bakmak işe
	# yaramıyor: HUD sahnede kaydediciden önce geldiği için onun _ready'si
	# henüz çalışmamış oluyor ve hayalet_var daima false görünüyor.
	_hayalet_etiketi.visible = (_hayalet != null and _hayalet.hayalet_var
		and not _oyun.bitti)
	if _hayalet_etiketi.visible:
		# Eksi = hayaletin önündesin. Renk, sayıyı okumadan önce bilgi versin.
		var f: float = _hayalet.fark
		# Kimle yarıştığını bilmek gerekiyor: kendi turun mu, oyunla gelen
		# par turu mu?
		var etiket := "HUD_PAR" if _hayalet.par_mi else "HUD_HAYALET"
		_hayalet_etiketi.text = "%s %+.2f" % [tr(etiket), f]
		_hayalet_etiketi.add_theme_color_override("font_color",
			Color(0.42, 0.9, 0.55) if f <= 0.0 else Color(1.0, 0.55, 0.45))

	# Çubuk dövüş başlayınca görünüyor: canavar oyuncuyu fark ettiğinde.
	if _boss_kutu != null:
		_boss_kutu.visible = (is_instance_valid(_boss)
			and _boss.get("durum") in [1, 2, 3] and not _oyun.bitti)

	_sayac -= delta
	if _sayac <= 0.0:
		_sayac = 0.25
		_olcumu_yaz()

func _cani_yaz(can: int, en_fazla: int) -> void:
	_can.text = tr("HUD_CAN") % [can, en_fazla]
	# Son can farklı renkte: sayıyı okumadan da durum anlaşılsın.
	_can.add_theme_color_override("font_color",
		Color(1.0, 0.35, 0.3) if can <= 1 else Color(0.898, 0.6, 0.35))

func _durumu_yaz() -> void:
	_mesaj.text = _oyun.mesaj

func _olcumu_yaz() -> void:
	var fps := Engine.get_frames_per_second()
	var ms := 1000.0 / maxf(float(fps), 1.0)
	var cizim := RenderingServer.get_rendering_info(
		RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME
	)
	_olcum.text = "%d FPS · %.1f ms (bütçe %.1f) · %d draw call · %s\n%s" % [
		fps, ms, BUTCE_MS, cizim, OS.get_name(),
		tr("HUD_TUSLAR_DOKUNMA") if Girdi.dokunmatik else tr("HUD_TUSLAR"),
	]
