extends Node
## Ayak IK testi (Faz 12): ayaklar gerçekten zemine oturuyor mu?
##
##   godot --headless --path oyun3d res://testler/ayak_ik_testi.tscn
##
## NEDEN AYRI BİR TEST: ayak IK'sı sessizce bozulan türden bir özellik.
## Modifiye edici iskelete eklenmemişse, kemik adları değişmişse, ışın
## maskesi yanlışsa ya da `_process_modification` hiç çağrılmıyorsa oyun
## eskisi gibi çalışır — karakter yalnızca yokuşta bir ayağı havada durur.
## Ekran görüntüsüne bakan bir insan bunu fark eder, hiçbir birim testi etmez.
##
## ÖLÇÜ: her ayak bileğinin ALTINA ışın atılıyor ve bileğin zeminden
## yüksekliği ölçülüyor. Doğru değer `bilek_m` (0,10 m): ayak tabanı yere
## değiyor demek. Test, IK KAPALIYKEN aynı ölçümü de alıyor — böylece
## "zaten öyleydi" ile "IK düzeltti" birbirinden ayrılıyor.
##
## POZ NEREDEN OKUNUYOR: bir modifiye edicinin yazdığı poz DIŞARIDAN
## görünmüyor. Godot iskeletin pozunu modifiye ediciler çalışmadan önce
## yedekliyor ve sonra geri yüklüyor; sonuç yalnızca deri (skinning)
## dönüşümlerine gidiyor, `get_bone_global_pose()` ise eski değeri veriyor.
## Bu yüzden test iskelete İKİNCİ bir modifiye edici ekliyor: modifiye
## ediciler çocuk sırasına göre zincirleniyor, dolayısıyla "prob" kendi
## sırası geldiğinde IK'nın çıktısını okuyor. Bu, deriye giden pozun ta
## kendisi — testin ölçtüğü şeyle oyunda görünen şey aynı.

const OLCUM := "res://varliklar/oyuncu_olcum.json"
const AYAKLAR := ["AyakSol", "AyakSag"]
## Rampa eğimi: karakterin `floor_max_angle`ının (55°) altında kalmalı,
## yoksa oyuncu kayar ve ölçüm zemini değil düşüşü ölçer.
const RAMPA_ACI := 0.35   # ~20°

var _hatalar: Array[String] = []
var _bilek := 0.10

## IK'dan SONRA çalışan, hiçbir şey yazmayan modifiye edici: sırası geldiğinde
## iskelette ne varsa onu kaydediyor.
class Prob extends SkeletonModifier3D:
	var adlar: Array[String] = []
	var gorulen: Array[Vector3] = []

	func _process_modification() -> void:
		var isk := get_skeleton()
		if isk == null:
			return
		gorulen.clear()
		for ad in adlar:
			var k := isk.find_bone(ad)
			gorulen.append(isk.global_transform * isk.get_bone_global_pose(k).origin
				if k >= 0 else Vector3.ZERO)

func _ready() -> void:
	var dosya := FileAccess.open(OLCUM, FileAccess.READ)
	if dosya != null:
		var olcum: Dictionary = JSON.parse_string(dosya.get_as_text())
		_bilek = float(olcum.get("bilek_m", 0.1))

	await _zeminde("düz zemin", 0.0)
	await _zeminde("rampa", RAMPA_ACI)
	await _basamakta()
	await _havada()

	if _hatalar.is_empty():
		print("AYAK IK TESTI: GECTI")
		get_tree().quit(0)
	else:
		for h in _hatalar:
			printerr("  ! " + h)
		print("AYAK IK TESTI: KALDI (%d)" % _hatalar.size())
		get_tree().quit(1)

func _dogrula(kosul: bool, mesaj: String) -> void:
	if not kosul:
		_hatalar.append(mesaj)

## Bir zemin kurar, oyuncuyu üstüne oturtur, IK açık ve kapalıyken hatayı ölçer.
func _zeminde(ad: String, egim: float) -> void:
	var sahne := Node3D.new()
	add_child(sahne)
	sahne.add_child(_zemin(egim))
	var oyuncu: CharacterBody3D = (load("res://sahneler/oyuncu.tscn") as PackedScene).instantiate()
	sahne.add_child(oyuncu)
	oyuncu.global_position = Vector3(0.0, 1.2, 0.0)
	# Oyuncunun kendi sürücüsü kapalı değil: düşüp zemine oturması, IK'nın
	# "yerde" sayılması ve etkinin açılması için fizik gerekiyor.
	var ik: Node = oyuncu.get_node_or_null("Yon/Model/iskelet/Skeleton3D/AyakIK")
	_dogrula(ik != null, "%s: AyakIK iskelete eklenmemiş" % ad)
	if ik == null:
		sahne.queue_free()
		await get_tree().process_frame
		return
	var prob := _prob_tak(oyuncu)

	await _bekle(90)
	await get_tree().process_frame
	_dogrula(oyuncu.is_on_floor(), "%s: oyuncu zemine oturmadı" % ad)
	_dogrula(ik.influence > 0.9,
		"%s: yerde IK etkisi açılmadı (%.2f)" % [ad, ik.influence])
	var acik := _bilek_hatasi(oyuncu, prob)

	# Aynı poz, yalnızca IK kapalı. Kalan farkı IK yaratıyor.
	ik.influence = 0.0
	oyuncu.set_physics_process(false)   # etki yeniden açılmasın
	await _bekle(6)
	await get_tree().process_frame
	var kapali := _bilek_hatasi(oyuncu, prob)

	print("%s: bilek hatası IK açık %.3f m, kapalı %.3f m" % [ad, acik, kapali])
	_dogrula(acik < 0.06, "%s: IK açıkken ayak zeminden %.3f m sapıyor" % [ad, acik])
	if egim > 0.05:
		# Düz zeminde animasyon zaten yaklaşık doğru; farkı ancak eğim gösterir.
		_dogrula(acik < kapali * 0.6,
			"%s: IK hatayı azaltmıyor (açık %.3f, kapalı %.3f)" % [ad, acik, kapali])
	sahne.queue_free()
	await get_tree().process_frame

## Bir ayak basamakta, diğeri zeminde. Gövde yatırmanın ÇÖZEMEYECEĞİ durum:
## iki zemin de yatay, eğim yok, yatırılacak bir şey yok. Fark yalnızca ayak
## ayak çözülerek kapanabiliyor — Faz 11'in ucuz numarasının sınırı tam burası.
func _basamakta() -> void:
	var sahne := Node3D.new()
	add_child(sahne)
	sahne.add_child(_zemin(0.0))
	# Sağ ayağın (x > 0) altına basamak. Yükseklik bacağın menzilinde:
	# daha yükseği "uçurum kenarı" durumu olur, IK bilerek uzanmaz.
	# Kutunun kenarı tam x = 0'da: oyuncunun sağ ayağı üstünde, sol ayağı
	# yanındaki alçak zeminde kalıyor.
	sahne.add_child(_kutu(Vector3(4.0, 1.0, 6.0), Vector3(2.0, -0.38, 0.0)))
	var oyuncu: CharacterBody3D = (load("res://sahneler/oyuncu.tscn") as PackedScene).instantiate()
	sahne.add_child(oyuncu)
	oyuncu.global_position = Vector3(0.0, 1.2, 0.0)
	var prob := _prob_tak(oyuncu)
	var ik: Node = oyuncu.get_node_or_null("Yon/Model/iskelet/Skeleton3D/AyakIK")
	await _bekle(100)
	await get_tree().process_frame
	var acik := _bilek_hatasi(oyuncu, prob)
	if ik != null:
		ik.influence = 0.0
		oyuncu.set_physics_process(false)
	await _bekle(6)
	await get_tree().process_frame
	var kapali := _bilek_hatasi(oyuncu, prob)
	print("basamak: bilek hatası IK açık %.3f m, kapalı %.3f m" % [acik, kapali])
	_dogrula(acik < 0.06, "basamak: IK açıkken ayak zeminden %.3f m sapıyor" % acik)
	_dogrula(acik < kapali * 0.6,
		"basamak: IK hatayı azaltmıyor (açık %.3f, kapalı %.3f)" % [acik, kapali])
	sahne.queue_free()
	await get_tree().process_frame

## Havada IK kapanmalı: ışın ya boşa gider ya altından geçen bir şeyi bulur.
func _havada() -> void:
	var sahne := Node3D.new()
	add_child(sahne)
	sahne.add_child(_zemin(0.0))
	var oyuncu: CharacterBody3D = (load("res://sahneler/oyuncu.tscn") as PackedScene).instantiate()
	sahne.add_child(oyuncu)
	oyuncu.global_position = Vector3(0.0, 1.2, 0.0)
	await _bekle(60)
	var ik: Node = oyuncu.get_node_or_null("Yon/Model/iskelet/Skeleton3D/AyakIK")
	if ik == null:
		sahne.queue_free()
		return
	# Yukarı fırlat ve zeminden uzaklaştır.
	oyuncu.global_position = Vector3(0.0, 9.0, 0.0)
	await _bekle(40)
	print("havada: IK etkisi %.2f" % ik.influence)
	_dogrula(not oyuncu.is_on_floor(), "havada: oyuncu hâlâ yerde sayılıyor")
	_dogrula(ik.influence < 0.1,
		"havada: IK kapanmadı (%.2f) — bacaklar boşluğa uzanır" % ik.influence)
	sahne.queue_free()
	await get_tree().process_frame

## Probu IK'dan sonra iskelete takar (çocuk sırası = çalışma sırası).
func _prob_tak(oyuncu: Node3D) -> Prob:
	var iskelet: Skeleton3D = oyuncu.get_node_or_null("Yon/Model/iskelet/Skeleton3D")
	if iskelet == null:
		return null
	var prob := Prob.new()
	prob.adlar.assign(AYAKLAR)
	iskelet.add_child(prob)
	return prob

## İki bileğin zeminden yüksekliğinin hedeften (bilek_m) ortalama sapması.
func _bilek_hatasi(oyuncu: Node3D, prob: Prob) -> float:
	if prob == null or prob.gorulen.size() != AYAKLAR.size():
		return 999.0
	var uzay := oyuncu.get_world_3d().direct_space_state
	var toplam := 0.0
	for poz: Vector3 in prob.gorulen:
		var sorgu := PhysicsRayQueryParameters3D.create(
			poz + Vector3.UP * 0.6, poz - Vector3.UP * 1.5, 1)
		var vurus := uzay.intersect_ray(sorgu)
		if vurus.is_empty():
			return 999.0
		var zemin: Vector3 = vurus["position"]
		toplam += absf(poz.y - zemin.y - _bilek)
	return toplam / float(prob.gorulen.size())

## Eğimli ya da düz bir zemin. Eğim X ekseninde: iki ayak yanyana durduğu
## için sol/sağ farkı doğuyor — ayak ayak çözülmesi gereken durum.
func _zemin(egim: float) -> StaticBody3D:
	var govde := _kutu(Vector3(14.0, 1.0, 14.0), Vector3(0.0, -0.5, 0.0))
	govde.rotation.z = egim
	return govde

## Çarpışma katmanı 1 = oyuncunun maskesindeki zemin katmanı.
func _kutu(olcu: Vector3, konum: Vector3) -> StaticBody3D:
	var govde := StaticBody3D.new()
	govde.collision_layer = 1
	var sekil := CollisionShape3D.new()
	var kutu := BoxShape3D.new()
	kutu.size = olcu
	sekil.shape = kutu
	govde.add_child(sekil)
	govde.position = konum
	return govde

func _bekle(kare: int) -> void:
	for i in kare:
		await get_tree().physics_frame
