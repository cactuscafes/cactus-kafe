extends Node
## Ağ katmanı (autoload: Ag) — barındır / katıl, durum dağıtımı, doğrulama.
##
## TASARIM KARARI: Godot'nun MultiplayerSynchronizer'ı yerine durum paketleri
## elle gönderiliyor. Sebebi öğrenme değil, denetim: burada kimin neye yetkili
## olduğu, paketin hangi sıklıkta gittiği ve geç gelen paketin ne olacağı
## okunabiliyor. Synchronizer bunları gizler; gizlenen şeyi hata ayıklayamazsın.
##
## OTORİTE MODELİ: Her oyuncu KENDİ karakterini simüle ediyor (istemci
## otoritesi). Sunucu gelen konumu doğruluyor: iki paket arasında fiziğin izin
## verdiğinden hızlı gidilmişse paket reddediliyor. Bu tam bir hile koruması
## DEĞİL — sunucunun kendi simülasyonunu koşturduğu otorite modeli daha
## güçlüdür; ama ışınlanma ve hız hilesinin en kaba biçimlerini keser ve
## yarış oyununda kabul edilebilir bir denge.
##
## GECİKME: Uzak oyuncular ~GECIKME_TAMPONU kadar GERİDEN oynatılıyor. Paket
## geç gelirse elimizde hâlâ aradeğerlenecek iki örnek olur; tampon olmadan
## her kayıp pakette karakter zıplar.

signal durum_degisti(mesaj: String)
signal oyuncu_katildi(kimlik: int)
signal oyuncu_ayrildi(kimlik: int)
signal yaris_basladi()
signal siralama_degisti(siralama: Array)

const PORT := 8910
const GONDERIM_HZ := 20.0
const GECIKME_TAMPONU := 0.12     # saniye
## Karakterin ulaşabileceği en yüksek hız + pay. Bunun üstü reddediliyor.
const AZAMI_HIZ := 12.0

var kendi_adim := "Oyuncu"
var barindiriyor := false
var bagli := false
## kimlik -> {"ad": String, "sure": float, "bitti": bool}
var oyuncular := {}
## kimlik -> [{"t": float, "konum": Vector3, "yon": float, "hiz": float}, ...]
var _tamponlar := {}
var _reddedilen := 0
## kimlik -> son meşru ışınlanmanın zamanı (hız sınırı için)
var _son_isinlanma := {}
var _sayac := 0.0
var _yerel_oyuncu: Node3D

func _ready() -> void:
	multiplayer.peer_connected.connect(_peer_katildi)
	multiplayer.peer_disconnected.connect(_peer_ayrildi)
	multiplayer.connected_to_server.connect(_sunucuya_baglandim)
	multiplayer.connection_failed.connect(func() -> void: _durum("Bağlanılamadı"))
	multiplayer.server_disconnected.connect(func() -> void:
		_durum("Sunucu kapandı")
		ayril())

func _durum(mesaj: String) -> void:
	durum_degisti.emit(mesaj)

# --- bağlantı ---------------------------------------------------------------

func sunucu_baslat(port := PORT) -> Error:
	var akran := ENetMultiplayerPeer.new()
	var hata := akran.create_server(port, 8)
	if hata != OK:
		_durum("Sunucu açılamadı: %d" % hata)
		return hata
	multiplayer.multiplayer_peer = akran
	barindiriyor = true
	bagli = true
	oyuncular = {1: {"ad": kendi_adim, "sure": 0.0, "bitti": false}}
	_durum("Sunucu açık (port %d)" % port)
	return OK

func katil(adres: String, port := PORT) -> Error:
	var akran := ENetMultiplayerPeer.new()
	var hata := akran.create_client(adres, port)
	if hata != OK:
		_durum("Bağlanılamadı: %d" % hata)
		return hata
	multiplayer.multiplayer_peer = akran
	barindiriyor = false
	_durum("Bağlanılıyor: %s:%d" % [adres, port])
	return OK

func ayril() -> void:
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null
	barindiriyor = false
	bagli = false
	oyuncular.clear()
	_tamponlar.clear()

func _sunucuya_baglandim() -> void:
	bagli = true
	_durum("Bağlandı")
	_katilimi_bildir.rpc_id(1, kendi_adim)

func _peer_katildi(kimlik: int) -> void:
	if barindiriyor:
		_durum("Oyuncu katıldı: %d" % kimlik)

func _peer_ayrildi(kimlik: int) -> void:
	oyuncular.erase(kimlik)
	_tamponlar.erase(kimlik)
	oyuncu_ayrildi.emit(kimlik)
	if barindiriyor:
		_listeyi_dagit.rpc(oyuncular)

@rpc("any_peer", "reliable")
func _katilimi_bildir(ad: String) -> void:
	if not barindiriyor:
		return
	var kimlik := multiplayer.get_remote_sender_id()
	oyuncular[kimlik] = {"ad": ad, "sure": 0.0, "bitti": false}
	_listeyi_dagit.rpc(oyuncular)

@rpc("authority", "reliable", "call_local")
func _listeyi_dagit(liste: Dictionary) -> void:
	oyuncular = liste.duplicate(true)
	for kimlik: int in oyuncular:
		if kimlik != multiplayer.get_unique_id():
			oyuncu_katildi.emit(kimlik)
	siralama_degisti.emit(siralama())

# --- durum dağıtımı ---------------------------------------------------------

## Bölüm sahnesi yerel karakteri buraya bildiriyor; ağ katmanı sahneyi tanımak
## zorunda kalmasın diye.
func yerel_oyuncuyu_ayarla(dugum: Node3D) -> void:
	_yerel_oyuncu = dugum

func _physics_process(delta: float) -> void:
	if not bagli or _yerel_oyuncu == null:
		return
	_sayac -= delta
	if _sayac > 0.0:
		return
	_sayac = 1.0 / GONDERIM_HZ
	var yon: Node3D = _yerel_oyuncu.get_node("Yon")
	var hiz := Vector2(_yerel_oyuncu.velocity.x, _yerel_oyuncu.velocity.z).length()
	if barindiriyor:
		# Sunucu kendine RPC atamaz ("RPC on yourself is not allowed"); zaten
		# gereksiz — doğrudan işliyoruz.
		_durumu_isle(1, _yerel_oyuncu.global_position, yon.rotation.y, hiz)
	else:
		_durum_bildir.rpc_id(1, _yerel_oyuncu.global_position, yon.rotation.y, hiz)

@rpc("any_peer", "unreliable_ordered")
func _durum_bildir(konum: Vector3, yon: float, hiz: float) -> void:
	if not barindiriyor:
		return
	_durumu_isle(multiplayer.get_remote_sender_id(), konum, yon, hiz)

## Sunucudaki tek giriş noktası: doğrula, herkese dağıt, kendi tamponuna yaz.
func _durumu_isle(kimlik: int, konum: Vector3, yon: float, hiz: float) -> void:
	if kimlik == 0:
		kimlik = 1     # yerel çağrı = sunucunun kendisi
	if not _gecerli_mi(kimlik, konum, hiz):
		_reddedilen += 1
		return
	_durum_dagit.rpc(kimlik, konum, yon, hiz)
	_tamponla(kimlik, konum, yon, hiz)

@rpc("authority", "unreliable_ordered")
func _durum_dagit(kimlik: int, konum: Vector3, yon: float, hiz: float) -> void:
	if kimlik == multiplayer.get_unique_id():
		return    # kendi durumumuz geri geldiyse yok say
	_tamponla(kimlik, konum, yon, hiz)

## Sunucu doğrulaması: son bilinen konumdan buraya, geçen sürede fiziğin izin
## verdiğinden hızlı gelinmiş mi?
func _gecerli_mi(kimlik: int, konum: Vector3, _hiz: float) -> bool:
	var tampon: Array = _tamponlar.get(kimlik, [])
	if tampon.is_empty():
		return true
	var son: Dictionary = tampon[tampon.size() - 1]
	# Geçen süreyi VARIŞ zamanından hesaplıyoruz ama tabanı gönderim
	# aralığının yarısı: ağ dalgalanmasıyla iki paket aynı karede gelince
	# "0.001 saniyede 0.25 m" çıkıp masum paket reddediliyordu. Doğrulama
	# yanlış pozitif verirse kimse açık bırakmaz, kapatır — o yüzden bu tabanı
	# koymak güvenliğin kendisi.
	var gecen: float = maxf(0.5 / GONDERIM_HZ, _simdi() - son["t"])
	var mesafe: float = son["konum"].distance_to(konum)
	# Düşerken dikey hız yataydan yüksek olabiliyor; paya onu da kattık.
	return mesafe / gecen <= AZAMI_HIZ * 2.5

## MEŞRU IŞINLANMA. Doğrulayıcı "iki paket arasında bu kadar yol gidilemez"
## diyor; ama ölünce kontrol noktasına dönmek ya da bölüme doğmak tam olarak
## odur. Sunucuya haber verilmezse oyuncunun her ölümü hile sayılır ve
## paketleri düşer — karakter rakiplerin ekranında donar.
##
## Kötüye kullanıma karşı hız sınırlı: aralıktan sık gelen bildirimler yok
## sayılıyor, yani "her karede ışınlanıyorum" diyerek doğrulama kapatılamıyor.
## Tam çözüm sunucunun doğumu KENDİSİNİN kararlaştırması; bu ara çözüm ve
## sınırı burada yazılı.
const ISINLANMA_ARALIGI := 1.5

func yerel_isinlanma() -> void:
	if not bagli:
		return
	if barindiriyor:
		_isinlanmayi_isle(1)
	else:
		_isinlanma_bildir.rpc_id(1)

@rpc("any_peer", "reliable")
func _isinlanma_bildir() -> void:
	if not barindiriyor:
		return
	_isinlanmayi_isle(multiplayer.get_remote_sender_id())

func _isinlanmayi_isle(kimlik: int) -> void:
	if kimlik == 0:
		kimlik = 1
	var simdi := _simdi()
	if simdi - float(_son_isinlanma.get(kimlik, -99.0)) < ISINLANMA_ARALIGI:
		return
	_son_isinlanma[kimlik] = simdi
	# Tamponu boşaltmak = "bir sonraki konum nereye olursa olsun kabul".
	_tamponlar[kimlik] = []

func _tamponla(kimlik: int, konum: Vector3, yon: float, hiz: float) -> void:
	if not _tamponlar.has(kimlik):
		_tamponlar[kimlik] = []
	var tampon: Array = _tamponlar[kimlik]
	tampon.append({"t": _simdi(), "konum": konum, "yon": yon, "hiz": hiz})
	while tampon.size() > 24:
		tampon.pop_front()

func _simdi() -> float:
	return float(Time.get_ticks_msec()) / 1000.0

## Uzak oyuncunun ŞU AN çizilecek durumu: tampon gecikmesi kadar geriden,
## iki örnek arasında aradeğerlenmiş.
func uzak_durum(kimlik: int) -> Dictionary:
	var tampon: Array = _tamponlar.get(kimlik, [])
	if tampon.is_empty():
		return {}
	var hedef := _simdi() - GECIKME_TAMPONU
	if tampon.size() == 1 or hedef <= tampon[0]["t"]:
		return {"konum": tampon[0]["konum"], "yon": tampon[0]["yon"], "hiz": tampon[0]["hiz"]}
	for i in range(tampon.size() - 1, 0, -1):
		var b: Dictionary = tampon[i - 1]
		var s: Dictionary = tampon[i]
		if b["t"] <= hedef and hedef <= s["t"]:
			var f: float = (hedef - b["t"]) / maxf(0.001, s["t"] - b["t"])
			return {
				"konum": (b["konum"] as Vector3).lerp(s["konum"], f),
				"yon": lerp_angle(b["yon"], s["yon"], f),
				"hiz": lerpf(b["hiz"], s["hiz"], f),
			}
	var son: Dictionary = tampon[tampon.size() - 1]
	return {"konum": son["konum"], "yon": son["yon"], "hiz": son["hiz"]}

func reddedilen_paket() -> int:
	return _reddedilen

# --- yarış ------------------------------------------------------------------

func yarisi_baslat() -> void:
	if barindiriyor:
		_yarisi_baslat.rpc()

@rpc("authority", "reliable", "call_local")
func _yarisi_baslat() -> void:
	for kimlik: int in oyuncular:
		oyuncular[kimlik]["sure"] = 0.0
		oyuncular[kimlik]["bitti"] = false
	yaris_basladi.emit()

func bitirdim(sure: float) -> void:
	_bitisi_bildir.rpc_id(1, sure)

@rpc("any_peer", "reliable", "call_local")
func _bitisi_bildir(sure: float) -> void:
	if not barindiriyor:
		return
	var kimlik := multiplayer.get_remote_sender_id()
	if kimlik == 0:
		kimlik = 1
	if oyuncular.has(kimlik):
		oyuncular[kimlik]["sure"] = sure
		oyuncular[kimlik]["bitti"] = true
	_listeyi_dagit.rpc(oyuncular)

## Bitirenler süreye göre, bitirmeyenler sona.
func siralama() -> Array:
	var liste := []
	for kimlik: int in oyuncular:
		var o: Dictionary = oyuncular[kimlik]
		liste.append({"kimlik": kimlik, "ad": o["ad"], "sure": o["sure"], "bitti": o["bitti"]})
	liste.sort_custom(func(a, b):
		if a["bitti"] != b["bitti"]:
			return a["bitti"]
		return a["sure"] < b["sure"])
	return liste
