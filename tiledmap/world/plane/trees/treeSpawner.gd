class_name TreeSpawner
extends Node3D

@export var oak_scene: PackedScene
@export var oak2_scene: PackedScene
@export var oak3_scene: PackedScene
@export var tree_block_radius := 0.42
@export var visibility_end := 42.0
@export var visibility_fade_margin := 8.0
@export var cast_tree_shadows := false

# chunk -> {"renderers": Array[MultiMeshInstance3D], "obstacle_ids": Array[int]}
var _trees_by_chunk: Dictionary = {}
var _tree_visuals: Dictionary = {}


func _ready() -> void:
	_build_visual_library()


func spawn_trees_for_chunk(chunk_coord: Vector2i, trees: Array, grid_map: GridMap) -> void:
	if trees.is_empty() or _trees_by_chunk.has(chunk_coord):
		return
	if _tree_visuals.is_empty():
		_build_visual_library()

	var trees_by_type: Dictionary = {}
	for tree_data: Dictionary in trees:
		var tree_type := int(tree_data["type"])
		if not trees_by_type.has(tree_type):
			trees_by_type[tree_type] = []
		trees_by_type[tree_type].append(tree_data)

	var renderers: Array[MultiMeshInstance3D] = []
	var obstacle_ids: Array[int] = []
	for tree_type: int in trees_by_type.keys():
		var visual: Dictionary = _tree_visuals.get(tree_type, {})
		if visual.is_empty():
			continue
		var typed_trees: Array = trees_by_type[tree_type]
		var renderer := _create_multimesh_renderer(tree_type, visual, typed_trees.size())
		add_child(renderer)
		for index in range(typed_trees.size()):
			var tree_data: Dictionary = typed_trees[index]
			var cell: Vector3i = tree_data["cell"]
			var placement := _make_tree_transform(cell, tree_type, grid_map)
			renderer.multimesh.set_instance_transform(index, placement * visual["transform"])

			var world_position := to_global(placement.origin)
			var obstacle_id := _tree_obstacle_id(chunk_coord, cell)
			ObstacleRegistry.register(obstacle_id, world_position, tree_block_radius)
			obstacle_ids.append(obstacle_id)
		renderers.append(renderer)

	_trees_by_chunk[chunk_coord] = {
		"renderers": renderers,
		"obstacle_ids": obstacle_ids,
		"tree_count": trees.size(),
	}


func despawn_trees_for_chunk(chunk_coord: Vector2i) -> void:
	if not _trees_by_chunk.has(chunk_coord):
		return
	var chunk_data: Dictionary = _trees_by_chunk[chunk_coord]
	for obstacle_id: int in chunk_data["obstacle_ids"]:
		ObstacleRegistry.unregister(obstacle_id)
	for renderer: MultiMeshInstance3D in chunk_data["renderers"]:
		if is_instance_valid(renderer):
			renderer.queue_free()
	_trees_by_chunk.erase(chunk_coord)


func clear_all() -> void:
	for chunk_coord: Vector2i in _trees_by_chunk.keys().duplicate():
		despawn_trees_for_chunk(chunk_coord)


func get_tree_count() -> int:
	var count := 0
	for chunk_data: Dictionary in _trees_by_chunk.values():
		count += int(chunk_data.get("tree_count", 0))
	return count


func get_renderer_count() -> int:
	var count := 0
	for chunk_data: Dictionary in _trees_by_chunk.values():
		count += chunk_data["renderers"].size()
	return count


func _build_visual_library() -> void:
	_tree_visuals.clear()
	for tree_type in [TerrainSampler.TreeType.OAK, TerrainSampler.TreeType.OAK2, TerrainSampler.TreeType.OAK3]:
		var scene := _get_scene(tree_type)
		if scene == null:
			continue
		var prototype := scene.instantiate() as Node3D
		prototype.visible = false
		add_child(prototype)
		var mesh_instance := _find_mesh_instance(prototype)
		if mesh_instance != null and mesh_instance.mesh != null:
			_tree_visuals[tree_type] = {
				"mesh": mesh_instance.mesh,
				"material": mesh_instance.get_active_material(0),
				"transform": prototype.global_transform.affine_inverse() * mesh_instance.global_transform,
			}
		prototype.queue_free()


func _create_multimesh_renderer(tree_type: int, visual: Dictionary, count: int) -> MultiMeshInstance3D:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = visual["mesh"]
	multimesh.instance_count = count

	var renderer := MultiMeshInstance3D.new()
	renderer.name = "TreeBatch_%d" % tree_type
	renderer.multimesh = multimesh
	renderer.material_override = visual["material"]
	renderer.cast_shadow = (
		GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		if cast_tree_shadows
		else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	)
	renderer.visibility_range_end = visibility_end
	renderer.visibility_range_end_margin = visibility_fade_margin
	renderer.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	return renderer


func _make_tree_transform(cell: Vector3i, tree_type: int, grid_map: GridMap) -> Transform3D:
	var world_position := grid_map.to_global(grid_map.map_to_local(cell))
	var local_position := to_local(world_position)
	var seed_offset := tree_type * 97
	local_position.x += (TerrainUtils.random_01(cell.x, cell.z, 931 + seed_offset, 8127) - 0.5) * 0.42
	local_position.z += (TerrainUtils.random_01(cell.x, cell.z, 932 + seed_offset, 8127) - 0.5) * 0.42
	var yaw := TerrainUtils.random_01(cell.x, cell.z, 933 + seed_offset, 8127) * TAU
	var scale_factor := lerpf(0.86, 1.10, TerrainUtils.random_01(cell.x, cell.z, 934 + seed_offset, 8127))
	return Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * scale_factor), local_position)


func _find_mesh_instance(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node
	for child in node.get_children():
		var found := _find_mesh_instance(child)
		if found != null:
			return found
	return null


func _tree_obstacle_id(chunk_coord: Vector2i, cell: Vector3i) -> int:
	return int(hash("tree:%d:%d:%d:%d" % [chunk_coord.x, chunk_coord.y, cell.x, cell.z]))


func _get_scene(tree_type: int) -> PackedScene:
	match tree_type:
		TerrainSampler.TreeType.OAK:
			return oak_scene
		TerrainSampler.TreeType.OAK2:
			return oak2_scene
		TerrainSampler.TreeType.OAK3:
			return oak3_scene
	return null
