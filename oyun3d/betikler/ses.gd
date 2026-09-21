extends Node
## Ses çalma (autoload: Ses).
##
## Tek bir AudioStreamPlayer'ı tekrar tekrar çalmak yerine küçük bir havuz
## tutuyoruz: aynı anda birkaç ses çakışabilsin (çiçek toplarken zıplamak gibi).
## Havuz dolduğunda en eskisi kesilir — sessiz kalmaktansa kesmek iyidir.
##
## FAZ 15 — DÖRT KATMAN:
##   1. 2B efektler   — oyuncunun kendi sesleri ve arayüz (mesafesi yok)
##   2. 3B efektler   — dünyadaki olaylar; nereden geldiği duyuluyor
##   3. çevre (ortam) — rüzgâr döngüsü + seyrek kuş ötüşleri
##   4. müzik         — iki katman: sakin taban + gerilim; ikisi aynı anda
##                      çalıyor, gerilim kovalanırken açılıyor
##
## NEDEN HER SES 3B DEĞİL: oyuncunun kendi ayak sesi, zıplaması ve hasarı
## kulağının dibinde olmalı — onları konumlandırmak, kamera döndüğünde kendi
## sesini sağdan solda duymaya yol açıyor. 3B olan şey DÜNYADA olup biten:
## düşmanın saldırısı, dikenin çarpması, uzaktaki bir ölüm.

const HAVUZ_BOYU := 8
const HAVUZ_3B_BOYU := 10

## 3B sesin tam gürlükte duyulduğu mesafe ve tamamen sustuğu mesafe.
## Oyunun ölçeğine göre seçildi: kamera 5 m arkada, bölümler ~60 m uzun.
## `unit_size` küçük olursa düşman iki adım ötede susuyor, büyük olursa
## bölümün öbür ucundaki kavga kulağının dibinde patlıyor.
const BIRIM_MESAFE := 6.0
const AZAMI_MESAFE := 45.0

## Müziğin kısılma (ducking) derinliği ve süresi. Ölüm, kontrol noktası ve
## bitiş gibi anlarda müzik geri çekiliyor ki olay duyulsun.
const KISMA_DB := -9.0
const KISMA_SURESI := 0.5

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
	"ezme": preload("res://ses/ezme.wav"),
	"dusman_oldu": preload("res://ses/dusman_oldu.wav"),
	"tik": preload("res://ses/tik.wav"),
	# Faz 15
	"diken_at": preload("res://ses/diken_at.wav"),
	"diken_carp": preload("res://ses/diken_carp.wav"),
	"hop": preload("res://ses/hop.wav"),
	"kus": preload("res://ses/kus.wav"),
}

## Çevre döngüleri — bölüm verisinden seçiliyor ("ortam_sesi").
const ORTAMLAR := {
	"ruzgar": preload("res://ses/ruzgar.wav"),
}

var _havuz: Array[AudioStreamPlayer] = []
var _havuz_3b: Array[AudioStreamPlayer3D] = []
var _sira := 0
var _sira_3b := 0
var _muzik: AudioStreamPlayer
var _gerilim: AudioStreamPlayer
var _ortam: AudioStreamPlayer
var _gerilim_hedefi := 0.0
var _gerilim_suanki := 0.0
var _kisma := 0.0
var _kus_sayaci := 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # duraklatmada da UI sesi çıksın
	for i in HAVUZ_BOYU:
		var oynatici := AudioStreamPlayer.new()
		oynatici.bus = &"SFX"
		add_child(oynatici)
		_havuz.append(oynatici)

	for i in HAVUZ_3B_BOYU:
		var uc_boyutlu := AudioStreamPlayer3D.new()
		uc_boyutlu.bus = &"SFX"
		uc_boyutlu.unit_size = BIRIM_MESAFE
		uc_boyutlu.max_distance = AZAMI_MESAFE
		# Ters kare sönüm, oyunun ölçeğinde çok hızlı susuyor; logaritmik
		# sönüm uzaktaki olayı "uzakta ama var" seviyesinde tutuyor.
		uc_boyutlu.attenuation_model = AudioStreamPlayer3D.ATTENUATION_LOGARITHMIC
		add_child(uc_boyutlu)
		_havuz_3b.append(uc_boyutlu)

	_muzik = _muzik_oynatici(preload("res://ses/muzik.wav"))
	_gerilim = _muzik_oynatici(preload("res://ses/muzik_gerilim.wav"))
	_gerilim.volume_db = -60.0

	_ortam = AudioStreamPlayer.new()
	_ortam.bus = &"Ortam"
	add_child(_ortam)

## Müzik katmanı: WAV döngüsü elle işaretleniyor, yoksa parça bir kez çalıp
## susuyor.
func _muzik_oynatici(parca: AudioStreamWAV) -> AudioStreamPlayer:
	parca.loop_mode = AudioStreamWAV.LOOP_FORWARD
	parca.loop_begin = 0
	parca.loop_end = int(parca.get_length() * parca.mix_rate)
	var oynatici := AudioStreamPlayer.new()
	oynatici.bus = &"Muzik"
	oynatici.stream = parca
	add_child(oynatici)
	return oynatici

func _process(delta: float) -> void:
	_gerilimi_isle(delta)
	_kismayi_isle(delta)
	_kuslari_isle(delta)

# --- efektler --------------------------------------------------------------

## perde: yarım ton cinsinden rastgelelik payı. Aynı sesin arka arkaya
## tıpatıp aynı çalması kulağa yapay gelir; adım seslerinde şart.
func cal(ad: String, perde := 0.0, ses_db := 0.0) -> void:
	if not EFEKTLER.has(ad):
		push_warning("Bilinmeyen ses: %s" % ad)
		return
	var oynatici := _havuz[_sira]
	_sira = (_sira + 1) % HAVUZ_BOYU
	oynatici.stream = EFEKTLER[ad]
	oynatici.pitch_scale = _perde(perde)
	oynatici.volume_db = ses_db
	oynatici.play()

## Dünyadaki bir noktadan gelen ses. Havuz düğümü oyuncunun/ağacın altına
## TAŞINMIYOR, konuma ışınlanıyor: düşman ölüp sahneden kalkınca sesi de
## onunla birlikte kesilirdi — oysa ölüm sesi ölümden sonra duyulur.
func cal_3b(ad: String, konum: Vector3, perde := 0.0, ses_db := 0.0) -> void:
	if not EFEKTLER.has(ad):
		push_warning("Bilinmeyen ses: %s" % ad)
		return
	var oynatici := _havuz_3b[_sira_3b]
	_sira_3b = (_sira_3b + 1) % HAVUZ_3B_BOYU
	oynatici.stream = EFEKTLER[ad]
	oynatici.pitch_scale = _perde(perde)
	oynatici.volume_db = ses_db
	oynatici.global_position = konum
	oynatici.play()

func adim_cal() -> void:
	cal("adim1" if randf() < 0.5 else "adim2", 2.0, -2.0)

func _perde(perde: float) -> float:
	return 1.0 if is_zero_approx(perde) else pow(2.0, randf_range(-perde, perde) / 12.0)

# --- çevre -----------------------------------------------------------------

## Bölümün çevre sesini başlatır. Bilinmeyen ad sessizce yok sayılmıyor:
## çevre sesi yoksa bölüm "ölü" duyuluyor ve sebebi aranırken vakit gidiyor.
func ortam_baslat(ad: String) -> void:
	if ad.is_empty():
		ortam_durdur()
		return
	if not ORTAMLAR.has(ad):
		push_warning("Bilinmeyen çevre sesi: %s" % ad)
		return
	var parca: AudioStreamWAV = ORTAMLAR[ad]
	parca.loop_mode = AudioStreamWAV.LOOP_FORWARD
	parca.loop_begin = 0
	parca.loop_end = int(parca.get_length() * parca.mix_rate)
	if _ortam.stream != parca or not _ortam.playing:
		_ortam.stream = parca
		_ortam.play()
	_kus_sayaci = randf_range(4.0, 9.0)

func ortam_durdur() -> void:
	_ortam.stop()
	_kus_sayaci = 0.0

## Kuşlar döngünün İÇİNDE değil: 8 saniyelik bir döngüye gömülü kuş, üçüncü
## tekrarda sahte duyuluyor. Rastgele aralıkla ayrı çalınca döngü duyulmuyor.
func _kuslari_isle(delta: float) -> void:
	if not _ortam.playing:
		return
	_kus_sayaci -= delta
	if _kus_sayaci > 0.0:
		return
	_kus_sayaci = randf_range(7.0, 16.0)
	cal("kus", 1.5, -14.0)

# --- müzik -----------------------------------------------------------------

## İki katman AYNI ANDA başlıyor. Gerilim katmanını sonradan başlatmak,
## döngünün ortasından girmesi demek — iki parça kayar ve akort tutmaz.
func muzik_baslat() -> void:
	if _muzik.playing:
		return
	_muzik.play()
	_gerilim.play()
	_gerilim_suanki = 0.0
	_gerilim.volume_db = -60.0

func muzik_durdur() -> void:
	_muzik.stop()
	_gerilim.stop()

## 0 = sakin, 1 = tam gerilim. Oyun durumu buradan besliyor (bkz. oyun.gd).
func gerilim_ayarla(oran: float) -> void:
	_gerilim_hedefi = clampf(oran, 0.0, 1.0)

func gerilim_orani() -> float:
	return _gerilim_suanki

## Gerilim katmanı ANİ değil: düşman fark edince müziğin bir anda değişmesi
## "düğmeye basıldı" gibi duyuluyor. Açılış hızlı (tehlike hemen duyulmalı),
## kapanış yavaş (tehlike geçti hissi yavaş oturur).
func _gerilimi_isle(delta: float) -> void:
	var hiz := 1.6 if _gerilim_hedefi > _gerilim_suanki else 0.5
	_gerilim_suanki = move_toward(_gerilim_suanki, _gerilim_hedefi, delta * hiz)
	if not _gerilim.playing:
		return
	_gerilim.volume_db = (-60.0 if _gerilim_suanki < 0.02
		else linear_to_db(_gerilim_suanki)) + _kisma_db()

# --- kısma (ducking) -------------------------------------------------------

## Müziği kısa süre geri çeker. BUS'a değil OYNATICIYA uygulanıyor: bus'ın
## seviyesi oyuncunun ayarı (`Ayarlar.seviye_ayarla`), oraya yazmak oyuncunun
## müzik ayarını kalıcı olarak bozardı.
func kis() -> void:
	_kisma = KISMA_SURESI

func _kisma_db() -> float:
	return KISMA_DB * clampf(_kisma / KISMA_SURESI, 0.0, 1.0)

func _kismayi_isle(delta: float) -> void:
	if _kisma <= 0.0:
		_muzik.volume_db = 0.0
		return
	_kisma = maxf(_kisma - delta, 0.0)
	_muzik.volume_db = _kisma_db()

# --- ayarlar ---------------------------------------------------------------

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
