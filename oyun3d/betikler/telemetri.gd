extends Node
## Anonim oynanış verisi (autoload: Telemetri).
##
## NEDEN VAR: Faz 8'in sorusu "demo nerede kopuyor?". Bunu ancak oyuncuların
## nerede bıraktığını ve nerede öldüğünü görerek yanıtlayabilirsin. Yirmi
## kişiyi izlemek en iyisidir ama ölçeklenmez; ölüm haritası ölçeklenir.
##
## GİZLİLİK — üç kural, üçü de kodda:
##  1. VARSAYILAN KAPALI. Ayarlardan açık rıza gerekiyor.
##  2. Sunucu adresi boşken hiçbir şey gönderilmiyor; depoda adres boş.
##  3. Kimlik yok: oturum numarası her açılışta yeniden üretiliyor ve diske
##     YAZILMIYOR, yani iki oturum birbirine bağlanamıyor. Ad, e-posta, cihaz
##     kimliği, konum yok.
##
## Gönderilemeyen veri sessizce düşüyor: telemetri oyunu bekletmemeli, hata
## penceresi açmamalı, oyuncunun umurunda olmamalı.

const AZAMI_KUYRUK := 60
const GONDERIM_ARALIGI := 20.0

var _kuyruk: Array[Dictionary] = []
var _oturum := ""
var _istek: HTTPRequest
var _sayac := GONDERIM_ARALIGI
## Test için: gerçekten ağa çıkmadan davranışı ölçebilmek.
var son_govde := ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_oturum = "%d-%d" % [Time.get_unix_time_from_system(), randi() % 1000000]
	_istek = HTTPRequest.new()
	add_child(_istek)

func etkin_mi() -> bool:
	return Ayarlar.telemetri and not Urun.TELEMETRI_URL.is_empty()

## Olay kuyruğa alınır; kapalıysa hiç alınmaz (sonradan açılınca geçmiş
## gönderilmesin diye).
func olay(ad: String, veri := {}) -> void:
	if not etkin_mi():
		return
	var kayit := veri.duplicate()
	kayit["ad"] = ad
	kayit["t"] = int(Time.get_unix_time_from_system())
	kayit["surum"] = Urun.SURUM
	kayit["demo"] = Urun.demo
	_kuyruk.append(kayit)
	if _kuyruk.size() > AZAMI_KUYRUK:
		_kuyruk.pop_front()

func _process(delta: float) -> void:
	if _kuyruk.is_empty() or not etkin_mi():
		return
	_sayac -= delta
	if _sayac <= 0.0:
		_sayac = GONDERIM_ARALIGI
		gonder()

## Kuyruğu sunucunun beklediği gövdeye çevirir. Ayrı işlev olması test
## içindir: gövdenin biçimini ağa çıkmadan doğrulayabilmek gerekiyor —
## `sunucu/` gövdeyi katı doğruluyor ve tek bir alan adı kayması tüm partiyi
## sessizce çöpe atar.
func govde_yap() -> String:
	return JSON.stringify({"oturum": _oturum, "olaylar": _kuyruk})

func gonder() -> void:
	if _kuyruk.is_empty() or not etkin_mi():
		return
	son_govde = govde_yap()
	_kuyruk.clear()
	if _istek.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		return   # önceki istek sürüyor; bu partiyi atlıyoruz
	_istek.request(Urun.TELEMETRI_URL, ["Content-Type: application/json"],
		HTTPClient.METHOD_POST, son_govde)

func kuyruk_boyu() -> int:
	return _kuyruk.size()
