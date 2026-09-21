extends Node
## Bölüm akışı: toplananlar, süre, ölüm, bitiş, yeniden başlama.
##
## Oyun durumu tek bir yerde duruyor; karakter ve nesneler sadece sinyal
## gönderiyor. Faz 4'te bölüm sayısı artınca burası bir sahne yükleyicisine
## dönüşecek, ama arayüz aynı kalacak.

signal durum_degisti
signal bolum_bitti(rekor: bool)

@export var bolum_kimligi := "bolum1"
@export var oyuncu_yolu: NodePath = ^"../Oyuncu"
@export var hedef_toplanabilir := 0
## Bölümün çevre sesi (`Ses.ORTAMLAR`). Boş bırakılırsa çevre sesi yok.
@export var ortam_sesi := "ruzgar"

var toplanan := 0
var yenilen := 0
var olum := 0
var sure := 0.0
var bitti := false
var mesaj := ""

var _oyuncu: CharacterBody3D
## Bölümün düşmanları, bir kez toplanıyor. Her karede gruptan yeniden
## süzmek (gerilim hesabı için) kare başına bir dizi ayırıyordu; düşman
## sayısı sabit, liste de sabit olabilir.
var _dusmanlar: Array[Node] = []

func _ready() -> void:
	_oyuncu = get_node(oyuncu_yolu)
	_oyuncu.olduruldu.connect(_olunce)

	# YALNIZCA bu bölümün içindekiler. Global grubu doğrudan saymak, aynı anda
	# iki bölüm ağaçtayken (geçiş animasyonu, önizleme, test) diğer bölümün
	# çiçeklerini de sayıyordu: bölüm 8 yerine 16 çiçek istiyordu.
	var cicekler := _bolumdekiler("toplanabilir")
	for dugum in cicekler:
		dugum.alindi.connect(_toplayinca)
	_dusmanlar = _bolumdekiler("dusman")
	for dugum in _dusmanlar:
		dugum.yenildi.connect(_dusman_yenilince)
	hedef_toplanabilir = cicekler.size()
	Telemetri.olay("bolum_basladi", {"bolum": bolum_kimligi})
	Ses.ortam_baslat(ortam_sesi)
	durum_degisti.emit()

func _exit_tree() -> void:
	# Bölüm kapanınca rüzgâr da kapanmalı: menüye dönüldüğünde çölün sesi
	# ana menüde çalmaya devam ediyordu.
	Ses.ortam_durdur()
	Ses.gerilim_ayarla(0.0)

## Verilen gruptaki düğümlerden yalnızca bu bölümün ağacında olanlar.
func _bolumdekiler(grup: String) -> Array[Node]:
	var kok := get_parent()
	var sonuc: Array[Node] = []
	for dugum in get_tree().get_nodes_in_group(grup):
		if kok != null and kok.is_ancestor_of(dugum):
			sonuc.append(dugum)
	return sonuc

func _process(delta: float) -> void:
	if not bitti:
		sure += delta
	_gerilimi_guncelle()
	if not bitti and Input.is_action_just_pressed("yeniden"):
		get_tree().reload_current_scene()

## Müziğin gerilim katmanı OYUNUN DURUMUNDAN besleniyor: kaç düşman peşinde?
##
## Tehlikeyi mesafeyle ölçmek ilk akla gelen yol ama yanlış cevap veriyor —
## uyuyan bir düşmanın iki adım ötesinden geçmek gergin değil, fark edilmiş
## olmak gergin. Bu yüzden ölçü DURUM: kovalayan ya da saldıran her düşman
## gerilimi artırıyor, ikisi tavana çıkarıyor.
func _gerilimi_guncelle() -> void:
	if bitti:
		Ses.gerilim_ayarla(0.0)
		return
	var pesimde := 0
	for d in _dusmanlar:
		# Yenilen düşman sahneden kalkıyor; listeden değil. Geçersiz olanı
		# atlamak, listeyi her karede yeniden kurmaktan ucuz.
		if is_instance_valid(d) and d.get("durum") in [1, 2, 3]:
			pesimde += 1   # FARKETTI, KOVALA, SALDIRI
	Ses.gerilim_ayarla(minf(float(pesimde) / 2.0, 1.0))

func _toplayinca() -> void:
	toplanan += 1
	mesaj = ""
	durum_degisti.emit()

func _dusman_yenilince() -> void:
	yenilen += 1
	durum_degisti.emit()

func _olunce() -> void:
	olum += 1
	# Ölüm konumu: hangi zıplamada takılındığı ancak böyle görülüyor.
	var k: Vector3 = _oyuncu.global_position
	Telemetri.olay("olum", {"bolum": bolum_kimligi, "sure": snappedf(sure, 0.1),
		"x": snappedf(k.x, 0.5), "y": snappedf(k.y, 0.5), "z": snappedf(k.z, 0.5)})
	mesaj = tr("OYUN_OLDUN")
	# Ölüm anında müzik geri çekiliyor: olayın duyulması için yer açmak.
	Ses.kis()
	durum_degisti.emit()

## Bitiş alanı çağırır. Hepsi toplanmadan bölüm bitmez.
func bitirmeyi_dene() -> void:
	if bitti:
		return
	if toplanan < hedef_toplanabilir:
		mesaj = tr("OYUN_EKSIK_CICEK") % [
			hedef_toplanabilir, hedef_toplanabilir - toplanan,
		]
	else:
		bitti = true
		mesaj = ""
		Telemetri.olay("bolum_bitti", {"bolum": bolum_kimligi,
			"sure": snappedf(sure, 0.1), "olum": olum, "yenilen": yenilen})
		Telemetri.gonder()
		Ses.cal("bitis")
		Ses.kis()
		var rekor := Ayarlar.sonuc_kaydet(bolum_kimligi, sure, olum)
		bolum_bitti.emit(rekor)
	durum_degisti.emit()

func kontrol_noktasi(nokta: Vector3) -> void:
	_oyuncu.dogum_noktasi_ayarla(nokta)
	mesaj = tr("OYUN_KONTROL")
	durum_degisti.emit()
