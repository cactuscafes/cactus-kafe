extends Node
## Oyun hissi efektleri (autoload: Efekt).
##
## Sarsıntı ve zaman durması, onları *isteyen* koddan (hasar, patlama) onları
## *uygulayan* koddan (kamera, motor) ayrı durmalı. Düşman, oyuncuya vurduğunda
## kameranın nerede olduğunu bilmek zorunda kalmasın diye buradan sinyal
## yayınlıyoruz.

signal sarsildi(guc: float)

var _zaman_geri_alma := 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _process(delta: float) -> void:
	if _zaman_geri_alma > 0.0:
		# Gerçek zamanla say: zaman ölçeği yavaşken delta de yavaşlar,
		# yoksa "0.08 saniyelik" duraklama 1.6 saniye sürer.
		_zaman_geri_alma -= delta / maxf(Engine.time_scale, 0.01)
		if _zaman_geri_alma <= 0.0:
			Engine.time_scale = 1.0

## Kameraya sarsıntı yollar. guc ~ 0.1 hafif, 0.5 sert.
func sarsint(guc: float) -> void:
	if not Ayarlar.sarsinti:
		return
	sarsildi.emit(guc)

## Vuruş anında zamanı kısa süre neredeyse durdurur (hit-stop). Darbeye
## ağırlık veren en ucuz numara; süre 0.05-0.12 sn dışına çıkarsa oyun
## takılıyor gibi hissettirir.
func vurus_duraklamasi(sure := 0.08, olcek := 0.05) -> void:
	Engine.time_scale = olcek
	_zaman_geri_alma = sure
