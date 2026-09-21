extends Dusman
## Atıcı düşman: yaklaşmaz, uzaktan diken atar (Faz 14).
##
## NEDEN VAR: temel düşman tek bir soru soruyor — "üstüne nasıl çıkarım?".
## Altı bölüm boyunca aynı soru. Atıcı ikinci bir soru ekliyor: "araya nasıl
## girerim?". Oyuncu artık siperi, mesafeyi ve zamanlamayı düşünmek zorunda;
## düz koşmak cezalandırılıyor.
##
## ADİL OLMASI İÇİN ÜÇ KURAL:
##   1. Atıştan önce görünür bir hazırlık var (saldırı animasyonu + ses).
##   2. Diken duvardan geçmiyor — siper gerçekten siper.
##   3. Atıcı yerinden kıpırdamıyor; yaklaşmak HER ZAMAN işe yarıyor.
##      Kovalayan bir atıcı, oyuncuya hiçbir kazanma yolu bırakmazdı.

const DIKEN := preload("res://sahneler/diken.tscn")

@export_group("Atış")
## İki atış arasındaki en kısa süre. Kısaltmak "bariyer", uzatmak "süs" yapar.
@export var atis_araligi := 2.2
## Bu mesafeden uzağa atmıyor: görüş menzili içinde ama atış menzili dışında
## kalan bir bölge bırakmak, oyuncuya yaklaşma kararını veriyor.
@export var atis_menzili := 16.0
## Dikenin namludan çıktığı yükseklik (düşmanın gövde hizası).
@export var namlu_yuksekligi := 0.55

var _atis_sayaci := 0.0

func _ready() -> void:
	super()
	# Atıcı yerinde durur. Devriye ucunu sıfırlamak YETMİYOR: temel sınıfın
	# `_ready`i devriye hedefini ZATEN eski uca göre hesapladı, düşman bir kez
	# oraya yürürdü. Hedef de başlangıca çekiliyor.
	devriye_ucu = Vector3.ZERO
	_devriye_hedefi = _baslangic
	# Menzili uzun, yakın dövüşü yok: yanına varan oyuncu güvende olmalı ki
	# yaklaşmanın karşılığı olsun.
	saldiri_menzili = 0.0
	_atis_sayaci = atis_araligi * 0.5
	# İri ve sarımsı: yerinden kıpırdamayan şey ağır görünmeli.
	_gorunum(Color(1.35, 1.12, 0.52), 1.16)
	# Uzaktan iş gördüğü için görüşü de uzun; yoksa oyuncu menzilde olup
	# fark edilmeden duruyor ve atıcı "bozuk" görünüyor.
	gorus_mesafesi = 18.0

## Kovalama yerine nişan alma: yerinde durup oyuncuya dönüyor ve atıyor.
func _kovala(delta: float) -> void:
	if _oyuncu == null:
		_gec(Durum.DEVRIYE)
		return
	_yurut(Vector3.ZERO, 0.0)
	_oynat("bosta")
	var fark := _oyuncu.global_position - global_position
	_bak(fark)

	var mesafe := fark.length()
	_kayip = 0.0 if _goruyor_mu() else _kayip + delta
	if _kayip > unutma_suresi or mesafe > unutma_mesafesi:
		_gec(Durum.DEVRIYE)
		return

	_atis_sayaci -= delta
	if _atis_sayaci <= 0.0 and mesafe <= atis_menzili and _goruyor_mu():
		_atis_sayaci = atis_araligi
		_gec(Durum.SALDIRI)

## Saldırı durumu: hazırlık bitince diken çıkıyor. Temel sınıfta burada
## yakın dövüş hasarı vardı; atıcıda yerini mermiye bırakıyor.
func _saldiri() -> void:
	_yurut(Vector3.ZERO, 0.0)
	if _oyuncu != null:
		_bak(_oyuncu.global_position - global_position)
	if _zaman > 0.0:
		return
	_at()
	_gec(Durum.KOVALA)

func _at() -> void:
	if _oyuncu == null:
		return
	var baslangic := global_position + Vector3.UP * namlu_yuksekligi
	# Nişan oyuncunun gövde ortasına: ayağına nişan almak dikeni zemine
	# gömüyor, kafasına almak üstünden geçiriyor.
	var hedef: Vector3 = _oyuncu.global_position + Vector3.UP * 0.9
	var mermi: Area3D = DIKEN.instantiate()
	# Sahneye düşmanın ALTINA değil, bölümün köküne ekleniyor: düşman ölünce
	# havadaki diken onunla birlikte silinmemeli.
	var kap := get_parent()
	if kap != null:
		kap.add_child(mermi)
	else:
		get_tree().current_scene.add_child(mermi)
	mermi.global_position = baslangic
	mermi.hasar = hasar
	mermi.kur(hedef - baslangic, self)
	Ses.cal("dusman_saldiri", 1.2)
