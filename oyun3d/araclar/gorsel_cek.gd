extends Node
## Mağaza ve belge görsellerini çeker.
##
##   xvfb-run -a godot --path oyun3d --rendering-driver opengl3 \
##     --audio-driver Dummy res://araclar/gorsel_cek.tscn
##
## Çıktı: `user://gorseller/` altına 1280x720 PNG'ler. Mağaza sayfası için
## gereken 1920x1080'i almak istersen pencere boyutunu büyüt:
## `--resolution 1920x1080`.
##
## Elle ekran görüntüsü almakla arasındaki fark: bu liste tekrarlanabilir.
## Bölüm değişince aynı komut aynı kadrajları yeniden üretir.

const KLASOR := "user://gorseller"

## ad, bölüm, oyuncunun konumu, kameranın y dönüşü (derece), bekleme (kare)
const KADRAJLAR := [
	["01_baslangic", "res://sahneler/bolum1.tscn", Vector3(0, 1.2, 6), 0.0, 40],
	["02_tuzak", "res://sahneler/bolum1.tscn", Vector3(0, 3.4, -7), 10.0, 40],
	["03_rampa", "res://sahneler/bolum1.tscn", Vector3(4, 3.0, -17), 0.0, 40],
	["04_dusman", "res://sahneler/bolum1.tscn", Vector3(2, 4.6, -24), 0.0, 60],
	["05_kule", "res://sahneler/bolum2.tscn", Vector3(0, 2.2, 9), 0.0, 40],
	["06_tirmanis", "res://sahneler/bolum2.tscn", Vector3(4.6, 6.5, -9.5), 120.0, 60],
	# Son kare mobil kontrolleri gösteriyor: mağaza sayfasında "telefonda da
	# oynanır" iddiasının kanıtı ekran görüntüsüdür, cümle değil.
	["07_mobil", "res://sahneler/bolum1.tscn", Vector3(0, 1.2, 4), 0.0, 40, true],
]

## Ekran kontrolleri ancak dokunma olduktan sonra görünüyor; görsel için
## parmağı taklit ediyoruz.
func _dokunmatigi_goster(bolum: Node3D) -> void:
	var basla := Vector2(250, 520)
	var dokunus := InputEventScreenTouch.new()
	dokunus.index = 0
	dokunus.position = basla
	dokunus.pressed = true
	Input.parse_input_event(dokunus)
	await get_tree().process_frame
	var surukle := InputEventScreenDrag.new()
	surukle.index = 0
	surukle.position = basla + Vector2(62, -78)
	surukle.relative = Vector2(62, -78)
	Input.parse_input_event(surukle)
	for i in 20:
		await get_tree().process_frame

func _ready() -> void:
	await get_tree().process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(KLASOR))
	var acik_sahne := ""
	var bolum: Node3D = null

	for kadraj: Array in KADRAJLAR:
		if kadraj[1] != acik_sahne:
			if bolum != null:
				bolum.queue_free()
				await get_tree().process_frame
			bolum = (load(kadraj[1]) as PackedScene).instantiate()
			get_tree().root.add_child(bolum)
			acik_sahne = kadraj[1]
			# HUD kalsın ama ölçüm satırı mağaza görselinde olmaz.
			var hud := bolum.get_node_or_null("HUD")
			if hud != null:
				hud.get_node("Olcum").visible = false
			await get_tree().process_frame

		var oyuncu: CharacterBody3D = bolum.get_node("Oyuncu")
		var kol: SpringArm3D = oyuncu.get_node("KameraKolu")
		oyuncu.global_position = kadraj[2]
		oyuncu.velocity = Vector3.ZERO
		kol.rotation.y = deg_to_rad(kadraj[3])
		kol.rotation.x = deg_to_rad(-14.0)
		for i in int(kadraj[4]):
			await get_tree().process_frame

		if kadraj.size() > 5 and bool(kadraj[5]):
			await _dokunmatigi_goster(bolum)

		var goruntu := get_viewport().get_texture().get_image()
		var yol := "%s/%s.png" % [KLASOR, kadraj[0]]
		goruntu.save_png(yol)
		print("  %s  (%dx%d)" % [kadraj[0], goruntu.get_width(), goruntu.get_height()])

	print("görseller -> %s" % ProjectSettings.globalize_path(KLASOR))
	get_tree().quit(0)
