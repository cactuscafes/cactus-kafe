extends Node
## Bölümün navigasyon örgüsünü üretip kaydeder.
##
##   godot --headless --path oyun3d res://araclar/navmesh_uret.tscn
##
## Örgü çalışma anında da pişirilebilir ama bölüm açılışını geciktirir ve her
## oyuncunun makinesinde yeniden hesaplanır. Bir kez pişirip kaynağı depoya
## koymak, "üret ve doğrula" hattının navigasyon ayağı.
##
## SEVİYE DEĞİŞTİYSE BUNU YENİDEN ÇALIŞTIR. Bayat örgü sessizce bozulur:
## düşman görünmez duvarlara çarpar ya da boşlukta yürür. dusman_testi
## içindeki yol testi bunu yakalamak için var.

const CIKTI := "res://navigasyon/bolum1.tres"

func _ready() -> void:
	await get_tree().process_frame
	var bolum: Node3D = (load("res://sahneler/ana.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(bolum)
	await get_tree().process_frame

	var orgu := NavigationMesh.new()
	orgu.cell_size = 0.2
	orgu.cell_height = 0.2
	orgu.agent_radius = 0.5
	orgu.agent_height = 1.6
	orgu.agent_max_climb = 0.45
	orgu.agent_max_slope = 46.0
	orgu.region_min_size = 2.0
	# Çarpışma şekillerinden pişir: oyuncunun üstünde yürüdüğü şey bu.
	orgu.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	orgu.geometry_collision_mask = 1   # yalnızca "zemin" katmanı
	# Zemin 140x140; parkurun dışını pişirmenin anlamı yok.
	orgu.filter_baking_aabb = AABB(Vector3(-26.0, -4.0, -60.0), Vector3(52.0, 24.0, 82.0))

	var kaynak := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(orgu, kaynak, bolum)
	NavigationServer3D.bake_from_source_geometry_data(orgu, kaynak)

	var poligon := orgu.get_polygon_count()
	print("navigasyon örgüsü: %d poligon, %d köşe" % [poligon, orgu.get_vertices().size()])
	if poligon == 0:
		printerr("  ! Örgü boş — çarpışma katmanı ya da AABB yanlış olabilir")
		get_tree().quit(1)
		return
	var hata := ResourceSaver.save(orgu, CIKTI)
	if hata != OK:
		printerr("  ! Kaydedilemedi: %d" % hata)
		get_tree().quit(1)
		return
	print("kaydedildi -> %s" % CIKTI)
	get_tree().quit(0)
