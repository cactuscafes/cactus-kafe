extends Node3D
## Statik görselleri MultiMesh'e birleştirir (draw call düşürücü).
##
## Editörde her platformu ve süslemeyi ayrı düğüm olarak yerleştirmek doğru:
## taşıyorsun, ölçüsünü değiştiriyorsun, görüyorsun. Ama her düğüm en az bir
## draw call, gölge açıksa iki. Oyun çalışırken bunları mesh'e göre gruplayıp
## tek MultiMesh'e indiriyoruz — görüntü aynı, çizim sayısı bölünüyor.
##
## Renk farkı korunuyor: MultiMesh örnek renkleri (use_colors) ve malzemede
## `vertex_color_use_as_albedo`. Bu olmadan bütün platformlar aynı renk olurdu.
##
## Çarpışma şekillerine dokunulmuyor; yalnızca MeshInstance3D'ler kalkıyor.

## Hangi alt ağaçlar birleştirilecek (bu düğüme göre).
@export var hedefler: Array[NodePath] = []
## Birleştirilen görseller gölge yapsın mı?
@export var golge := true

func _ready() -> void:
	for yol in hedefler:
		var kok := get_node_or_null(yol)
		if kok != null:
			_birlestir(kok)

func _birlestir(kok: Node) -> void:
	var gruplar := {}    # Mesh -> {"donusumler": [...], "renkler": [...], "malzeme": ...}
	for dugum in kok.find_children("*", "MeshInstance3D", true, false):
		var mi := dugum as MeshInstance3D
		if mi.mesh == null or mi.visible == false:
			continue
		var anahtar := mi.mesh
		if not gruplar.has(anahtar):
			gruplar[anahtar] = {"donusumler": [], "renkler": [], "malzeme": _malzeme(mi)}
		gruplar[anahtar]["donusumler"].append(
			global_transform.affine_inverse() * mi.global_transform)
		gruplar[anahtar]["renkler"].append(_renk(mi))
		mi.queue_free()

	for mesh: Mesh in gruplar:
		var veri: Dictionary = gruplar[mesh]
		var coklu := MultiMesh.new()
		coklu.transform_format = MultiMesh.TRANSFORM_3D
		coklu.use_colors = true
		coklu.mesh = mesh
		coklu.instance_count = veri["donusumler"].size()
		for i in coklu.instance_count:
			coklu.set_instance_transform(i, veri["donusumler"][i])
			coklu.set_instance_color(i, veri["renkler"][i])

		var dugum := MultiMeshInstance3D.new()
		dugum.multimesh = coklu
		dugum.material_override = veri["malzeme"]
		dugum.cast_shadow = (GeometryInstance3D.SHADOW_CASTING_SETTING_ON if golge
			else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
		add_child(dugum)

## Örnek renklerinin işe yaraması için malzemede vertex_color_use_as_albedo
## açık olmalı; kopyalıyoruz ki kaynak malzeme bozulmasın.
func _malzeme(mi: MeshInstance3D) -> Material:
	var kaynak := mi.material_override
	if kaynak == null and mi.mesh.get_surface_count() > 0:
		kaynak = mi.mesh.surface_get_material(0)
	if kaynak == null:
		kaynak = StandardMaterial3D.new()
	var kopya := kaynak.duplicate() as BaseMaterial3D
	if kopya != null:
		kopya.vertex_color_use_as_albedo = true
		# Renk artık örnek renginden geliyor; taban beyaz olmalı ki çarpım
		# sonucu istenen rengi versin.
		kopya.albedo_color = Color.WHITE
	return kopya

func _renk(mi: MeshInstance3D) -> Color:
	var mat := mi.material_override as BaseMaterial3D
	if mat == null and mi.mesh.get_surface_count() > 0:
		mat = mi.mesh.surface_get_material(0) as BaseMaterial3D
	return mat.albedo_color if mat != null else Color.WHITE
