extends Node
## Ses çalma (autoload: Ses).
##
## Tek bir AudioStreamPlayer'ı tekrar tekrar çalmak yerine küçük bir havuz
## tutuyoruz: aynı anda birkaç ses çakışabilsin (çiçek toplarken zıplamak gibi).
## Havuz dolduğunda en eskisi kesilir — sessiz kalmaktansa kesmek iyidir.

const HAVUZ_BOYU := 8

const EFEKTLER := {
	"adim1": preload("res://ses/adim1.wav"),
	"adim2": preload("res://ses/adim2.wav"),
	"zipla": preload("res://ses/zipla.wav"),
	"inis": preload("res://ses/inis.wav"),
	"toplama": preload("res://ses/toplama.wav"),
	"olum": preload("res://ses/olum.wav"),
	"kontrol": preload("res://ses/kontrol.wav"),
	"bitis": preload("res://ses/bitis.wav"),
	"hasar": preload("res://ses/hasar.wav"),
	"dusman_farketti": preload("res://ses/dusman_farketti.wav"),
	"dusman_saldiri": preload("res://ses/dusman_saldiri.wav"),
	"tik": preload("res://ses/tik.wav"),
}

var _havuz: Array[AudioStreamPlayer] = []
var _sira := 0
var _muzik: AudioStreamPlayer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # duraklatmada da UI sesi çıksın
	for i in HAVUZ_BOYU:
		var oynatici := AudioStreamPlayer.new()
		oynatici.bus = &"SFX"
		add_child(oynatici)
		_havuz.append(oynatici)

	_muzik = AudioStreamPlayer.new()
	_muzik.bus = &"Muzik"
	var parca: AudioStreamWAV = preload("res://ses/muzik.wav")
	# WAV döngüsü: bitiş karesi elle veriliyor, yoksa parça bir kez çalıp susar.
	parca.loop_mode = AudioStreamWAV.LOOP_FORWARD
	parca.loop_begin = 0
	parca.loop_end = int(parca.get_length() * parca.mix_rate)
	_muzik.stream = parca
	add_child(_muzik)

## perde: yarım ton cinsinden rastgelelik payı. Aynı sesin arka arkaya
## tıpatıp aynı çalması kulağa yapay gelir; adım seslerinde şart.
func cal(ad: String, perde := 0.0, ses_db := 0.0) -> void:
	if not EFEKTLER.has(ad):
		push_warning("Bilinmeyen ses: %s" % ad)
		return
	var oynatici := _havuz[_sira]
	_sira = (_sira + 1) % HAVUZ_BOYU
	oynatici.stream = EFEKTLER[ad]
	oynatici.pitch_scale = 1.0 if is_zero_approx(perde) else pow(2.0, randf_range(-perde, perde) / 12.0)
	oynatici.volume_db = ses_db
	oynatici.play()

func adim_cal() -> void:
	cal("adim1" if randf() < 0.5 else "adim2", 2.0, -2.0)

func muzik_baslat() -> void:
	if not _muzik.playing:
		_muzik.play()

func muzik_durdur() -> void:
	_muzik.stop()

## Doğrusal 0-1 değerini bus'a desibel olarak yazar.
static func seviye_ayarla(bus_adi: StringName, deger: float) -> void:
	var indeks := AudioServer.get_bus_index(bus_adi)
	if indeks < 0:
		return
	if deger <= 0.001:
		AudioServer.set_bus_mute(indeks, true)
	else:
		AudioServer.set_bus_mute(indeks, false)
		AudioServer.set_bus_volume_db(indeks, linear_to_db(deger))
