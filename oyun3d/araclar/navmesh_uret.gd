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

func _ready() -> void:
	await get_tree().process_frame
	var hatali := 0
	for bilgi: Dictionary in Bolumler.LISTE:
		if not await _pisir(bilgi["kimlik"], bilgi["sahne"]):
			hatali += 1
	get_tree().quit(1 if hatali > 0 else 0)

func _pisir(kimlik: String, sahne_yolu: String) -> bool:
	var cikti := "res://navigasyon/%s.tres" % kimlik
	var bolum: Node3D = (load(sahne_yolu) as PackedScene).instantiate()
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
	# Kutu bütün bölümü kapsamalı: bölüm 1 yatay ve uzun, bölüm 2 dikey.
	orgu.filter_baking_aabb = AABB(Vector3(-30.0, -4.0, -60.0), Vector3(60.0, 40.0, 84.0))

	var kaynak := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(orgu, kaynak, bolum)
	NavigationServer3D.bake_from_source_geometry_data(orgu, kaynak)

	var poligon := orgu.get_polygon_count()
	print("%-8s %3d poligon, %3d köşe -> %s" % [
		kimlik, poligon, orgu.get_vertices().size(), cikti])
	bolum.queue_free()
	if poligon == 0:
		printerr("  ! %s: örgü boş — çarpışma katmanı ya da AABB yanlış olabilir" % kimlik)
		return false
	var hata := ResourceSaver.save(orgu, cikti)
	if hata != OK:
		printerr("  ! %s kaydedilemedi: %d" % [kimlik, hata])
		return false
	return true
