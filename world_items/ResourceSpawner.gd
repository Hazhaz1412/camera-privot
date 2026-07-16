class_name ResourceSpawner
extends Node3D

@export var player_path: NodePath = ^"../Player"
@export var grid_map_path: NodePath = ^"../GridMap"
@export var terrain_generator_path: NodePath = ^"../BuildGrid/TerrainGenerator"
@export var scan_radius := 22
@export var despawn_margin := 10
@export var spawn_chance := 0.038
@export var max_active_pickups := 90
@export var scan_interval := 0.65
@export var rescan_cell_distance := 2
@export var max_checked_empty_cells := 32768
@export var generation_seed := 9127

var player: Node3D
var grid_map: GridMap
var terrain_generator: GridTerrainGenerator
var _active_by_key: Dictionary = {}
var _collected_keys: Dictionary = {}
var _checked_empty_keys: Dictionary = {}
var _scan_time := 0.0
var _last_scan_center := Vector2i(2147483647, 2147483647)


func _ready() -> void:
	_resolve_nodes()


func _process(delta: float) -> void:
	_scan_time += delta
	if _scan_time < scan_interval:
		return
	_scan_time = 0.0
	_resolve_nodes()
	if player == null or grid_map == null or terrain_generator == null:
		return
	var center_cell := grid_map.local_to_map(grid_map.to_local(player.global_position))
	var center := Vector2i(center_cell.x, center_cell.z)
	if _last_scan_center.x != 2147483647:
		var moved := center - _last_scan_center
		if maxi(absi(moved.x), absi(moved.y)) < rescan_cell_distance:
			return
	_despawn_distant_pickups()
	_spawn_near_player_at(center)
	if terrain_generator.get_pending_chunk_count() == 0:
		_last_scan_center = center


func _resolve_nodes() -> void:
	if player == null:
		player = get_node_or_null(player_path) as Node3D
	if grid_map == null:
		grid_map = get_node_or_null(grid_map_path) as GridMap
	if terrain_generator == null:
		terrain_generator = get_node_or_null(terrain_generator_path) as GridTerrainGenerator


func _spawn_near_player() -> void:
	var center_cell := grid_map.local_to_map(grid_map.to_local(player.global_position))
	_spawn_near_player_at(Vector2i(center_cell.x, center_cell.z))


func _spawn_near_player_at(center: Vector2i) -> void:
	for z in range(center.y - scan_radius, center.y + scan_radius + 1):
		for x in range(center.x - scan_radius, center.x + scan_radius + 1):
			if _active_by_key.size() >= max_active_pickups:
				return
			if Vector2i(x - center.x, z - center.y).length_squared() > scan_radius * scan_radius:
				continue
			_try_spawn_at(x, z)


func _try_spawn_at(world_x: int, world_z: int) -> void:
	var key := "%d:%d" % [world_x, world_z]
	if _active_by_key.has(key) or _collected_keys.has(key) or _checked_empty_keys.has(key):
		return
	if TerrainUtils.random_01(world_x, world_z, 601, generation_seed) > spawn_chance:
		_mark_checked_empty(key)
		return

	var surface_cell := terrain_generator.get_surface_cell(world_x, world_z)
	if grid_map.get_cell_item(surface_cell) == GridMap.INVALID_CELL_ITEM:
		return
	var cell_above := surface_cell + Vector3i.UP
	if grid_map.get_cell_item(cell_above) != GridMap.INVALID_CELL_ITEM:
		_mark_checked_empty(key)
		return

	var world_position := grid_map.to_global(grid_map.map_to_local(surface_cell))
	world_position.x += (TerrainUtils.random_01(world_x, world_z, 603, generation_seed) - 0.5) * 0.46
	world_position.z += (TerrainUtils.random_01(world_x, world_z, 604, generation_seed) - 0.5) * 0.46
	world_position.y += 0.08
	if ObstacleRegistry.get_blocking_obstacle(world_position, 0.28, 0):
		_mark_checked_empty(key)
		return

	var item_id := _pick_resource_type(world_x, world_z)
	var pickup := WorldPickup.new()
	add_child(pickup)
	pickup.setup(item_id, key)
	pickup.collected.connect(_on_pickup_collected)
	pickup.global_position = world_position
	pickup.rotation.y = TerrainUtils.random_01(world_x, world_z, 605, generation_seed) * TAU
	_active_by_key[key] = pickup


func _pick_resource_type(world_x: int, world_z: int) -> String:
	var roll := TerrainUtils.random_01(world_x, world_z, 602, generation_seed)
	if roll < 0.26:
		return "stick"
	if roll < 0.44:
		return "vine"
	if roll < 0.66:
		return "stone"
	if roll < 0.81:
		return "wood"
	if roll < 0.91:
		return "coal"
	return "iron_ore"


func _despawn_distant_pickups() -> void:
	var max_distance := float(scan_radius + despawn_margin)
	for key: String in _active_by_key.keys().duplicate():
		var pickup: Node3D = _active_by_key[key]
		if not is_instance_valid(pickup):
			_active_by_key.erase(key)
			continue
		var flat_delta := Vector2(
			pickup.global_position.x - player.global_position.x,
			pickup.global_position.z - player.global_position.z
		)
		if flat_delta.length() <= max_distance:
			continue
		_active_by_key.erase(key)
		pickup.queue_free()


func _on_pickup_collected(spawn_key: String) -> void:
	_active_by_key.erase(spawn_key)
	_collected_keys[spawn_key] = true


func _mark_checked_empty(key: String) -> void:
	if _checked_empty_keys.size() >= max_checked_empty_cells:
		_checked_empty_keys.clear()
	_checked_empty_keys[key] = true
