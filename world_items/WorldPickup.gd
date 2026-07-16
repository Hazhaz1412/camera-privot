class_name WorldPickup
extends Node3D

signal collected(spawn_key: String)

var item_id := ""
var spawn_key := ""
var _visual_root: Node3D
var _time_offset := 0.0


func setup(new_item_id: String, new_spawn_key: String) -> void:
	item_id = new_item_id
	spawn_key = new_spawn_key
	name = "Pickup_%s_%s" % [item_id, spawn_key.replace(":", "_")]
	_time_offset = float(abs(hash(spawn_key)) % 1000) * 0.01
	add_to_group("world_pickup")
	_build_visual()


func _process(_delta: float) -> void:
	if _visual_root == null:
		return
	_visual_root.position.y = 0.10 + sin(Time.get_ticks_msec() * 0.0025 + _time_offset) * 0.045
	_visual_root.rotation.y += 0.003


func collect() -> void:
	collected.emit(spawn_key)
	queue_free()


func _build_visual() -> void:
	_visual_root = Node3D.new()
	_visual_root.name = "Visual"
	add_child(_visual_root)

	match item_id:
		"stick":
			_add_stick_visual()
		"vine":
			_add_vine_visual()
		"stone":
			_add_stone_visual()
		"wood":
			_add_wood_visual()
		"coal":
			_add_rock_visual(Color("30343a"), Vector3(0.95, 0.72, 1.12))
		"iron_ore":
			_add_rock_visual(Color("9b6753"), Vector3(1.15, 0.82, 0.92))
		_:
			_add_generic_visual()


func _add_stick_visual() -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.045
	mesh.bottom_radius = 0.06
	mesh.height = 0.9
	mesh.radial_segments = 7
	var instance := _make_mesh_instance(mesh, Color("a06b3f"))
	instance.rotation.z = PI * 0.5
	instance.rotation.y = 0.25

	var twig := CylinderMesh.new()
	twig.top_radius = 0.025
	twig.bottom_radius = 0.035
	twig.height = 0.32
	twig.radial_segments = 6
	var twig_instance := _make_mesh_instance(twig, Color("8b5938"))
	twig_instance.position = Vector3(0.2, 0.08, 0.0)
	twig_instance.rotation.z = 0.85


func _add_vine_visual() -> void:
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.24
	mesh.outer_radius = 0.33
	mesh.rings = 12
	mesh.ring_segments = 6
	var instance := _make_mesh_instance(mesh, Color("4f9a4c"))
	instance.scale = Vector3(1.25, 0.35, 0.85)
	instance.rotation.x = PI * 0.5


func _add_stone_visual() -> void:
	var mesh := SphereMesh.new()
	mesh.radius = 0.30
	mesh.height = 0.45
	mesh.radial_segments = 7
	mesh.rings = 4
	var instance := _make_mesh_instance(mesh, Color("7c858d"))
	instance.scale = Vector3(1.2, 0.75, 0.95)
	instance.rotation = Vector3(0.15, 0.4, -0.08)


func _add_rock_visual(color: Color, scale_value: Vector3) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = 0.30
	mesh.height = 0.48
	mesh.radial_segments = 7
	mesh.rings = 4
	var instance := _make_mesh_instance(mesh, color)
	instance.scale = scale_value
	instance.rotation = Vector3(0.18, 0.55, -0.10)


func _add_wood_visual() -> void:
	var log_mesh := CylinderMesh.new()
	log_mesh.top_radius = 0.24
	log_mesh.bottom_radius = 0.27
	log_mesh.height = 0.85
	log_mesh.radial_segments = 9
	var log_instance := _make_mesh_instance(log_mesh, Color("805033"))
	log_instance.rotation.z = PI * 0.5

	for end_x in [-0.43, 0.43]:
		var end_mesh := CylinderMesh.new()
		end_mesh.top_radius = 0.205
		end_mesh.bottom_radius = 0.205
		end_mesh.height = 0.018
		end_mesh.radial_segments = 9
		var end_instance := _make_mesh_instance(end_mesh, Color("c28b58"))
		end_instance.rotation.z = PI * 0.5
		end_instance.position.x = end_x


func _add_generic_visual() -> void:
	var data := ItemCatalog.get_item(item_id)
	var color: Color = data.get("color", Color("8a9298"))
	var size: Vector2i = data.get("size", Vector2i.ONE)
	var mesh := BoxMesh.new()
	mesh.size = Vector3(
		clampf(0.28 + float(size.x) * 0.09, 0.36, 0.68),
		clampf(0.18 + float(size.y) * 0.07, 0.28, 0.55),
		clampf(0.28 + float(size.x + size.y) * 0.035, 0.36, 0.62)
	)
	var instance := _make_mesh_instance(mesh, color)
	instance.rotation = Vector3(0.12, 0.45, -0.08)


func _make_mesh_instance(mesh: PrimitiveMesh, color: Color) -> MeshInstance3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.92
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	_visual_root.add_child(instance)
	return instance
