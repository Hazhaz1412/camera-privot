class_name BuildGrid
extends Node

signal build_mode_changed(enabled: bool)
signal build_selection_changed(item_id: String)
signal build_status_changed(message: String, success: bool)

@export var grid_map_path: NodePath = ^"../GridMap"
@export var terrain_generator_path: NodePath = ^"TerrainGenerator"
@export var placement_rules_path: NodePath = ^"PlacementRules"
@export var targeter_path: NodePath = ^"Targeting"
@export var preview_path: NodePath = ^"Preview"
@export var player_path: NodePath = ^"../Player"
@export var tree_spawner_path: NodePath = ^"../TreeContainer/TreeSpawner"
@export var animal_spawner_path: NodePath = ^"../AnimalContainer/AnimalSpawner"
@export var build_mode_enabled := false
@export var build_mode_toggle_key := KEY_B

@onready var tree_spawner: TreeSpawner = get_node(tree_spawner_path)
@onready var animal_spawner: AnimalSpawner = get_node(animal_spawner_path)
@onready var grid_map: GridMap = get_node(grid_map_path)
@onready var terrain_generator: GridTerrainGenerator = get_node(terrain_generator_path)
@onready var placement_rules: GridPlacementRules = get_node(placement_rules_path)
@onready var targeter: GridTargeting = get_node(targeter_path)
@onready var preview: GridBuildPreview = get_node(preview_path)
@onready var player: Node = get_node_or_null(player_path)

var inventory: InventoryData
var selected_item_id := ""
var _placed_grid_items: Dictionary = {}
var _placed_objects_by_cell: Dictionary = {}
var _placed_objects: Array[PlacedBuildObject] = []
var _object_container: Node3D


func _ready() -> void:
	grid_map.cell_size = Vector3.ONE
	preview.setup(grid_map.cell_size)
	if player != null:
		inventory = player.get_node_or_null("Inventory") as InventoryData
		if player.has_method("set_grid_map"):
			player.set_grid_map(grid_map)
	if not is_instance_valid(terrain_generator):
		push_error("Không tìm thấy TerrainGenerator")
		return
	_object_container = Node3D.new()
	_object_container.name = "PlacedBuildObjects"
	add_child(_object_container)
	terrain_generator.set_tree_spawner(tree_spawner)
	terrain_generator.set_animal_spawner(animal_spawner)
	terrain_generator.generate(grid_map)


func _process(delta: float) -> void:
	if is_instance_valid(terrain_generator):
		terrain_generator.update_stream(grid_map, delta)
	if build_mode_enabled:
		_update_preview()
	else:
		preview.hide_preview()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == build_mode_toggle_key:
			set_build_mode_enabled(not build_mode_enabled)
			get_viewport().set_input_as_handled()
			return
	if not build_mode_enabled:
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MouseButton.MOUSE_BUTTON_LEFT:
			place_selected_at_mouse(event.position)
			get_viewport().set_input_as_handled()
		elif event.button_index == MouseButton.MOUSE_BUTTON_MIDDLE:
			reclaim_at_mouse(event.position)
			get_viewport().set_input_as_handled()
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_X or event.keycode == KEY_DELETE:
			reclaim_at_mouse()
			get_viewport().set_input_as_handled()


func set_build_mode_enabled(enabled: bool) -> void:
	if build_mode_enabled == enabled:
		return
	build_mode_enabled = enabled
	if not build_mode_enabled:
		preview.hide_preview()
	build_mode_changed.emit(build_mode_enabled)


func is_build_mode_enabled() -> bool:
	return build_mode_enabled


func select_placeable(item_id: String) -> void:
	if not item_id.is_empty() and not PlaceableCatalog.is_placeable(item_id):
		return
	if selected_item_id == item_id:
		return
	selected_item_id = item_id
	build_selection_changed.emit(selected_item_id)


func place_selected_at_mouse(mouse_position: Vector2 = Vector2(-1.0, -1.0)) -> bool:
	var target := targeter.get_mouse_target(grid_map, placement_rules, mouse_position)
	if target.is_empty():
		_set_status("Không tìm thấy vị trí đặt hợp lệ.", false)
		return false
	return place_selected_at_cell(target["place_cell"])


func place_selected_at_cell(anchor_cell: Vector3i) -> bool:
	if selected_item_id.is_empty() or inventory == null:
		_set_status("Hãy chọn một vật phẩm có trong túi.", false)
		return false
	if inventory.count_item(selected_item_id) <= 0:
		_set_status("Vật phẩm đã hết trong túi.", false)
		select_placeable("")
		return false

	var data := PlaceableCatalog.get_placeable(selected_item_id)
	if not _can_place(anchor_cell, data):
		_set_status("Vị trí bị chặn hoặc không đủ mặt đỡ.", false)
		return false

	var placed := false
	if String(data.get("kind", "")) == "grid_block":
		placed = _place_grid_block(anchor_cell, selected_item_id, data)
	else:
		placed = _place_object(anchor_cell, selected_item_id, data)
	if not placed:
		return false

	var placed_name := String(data.get("display_name", selected_item_id))
	_set_status("Đã đặt %s." % placed_name, true)
	if inventory.count_item(selected_item_id) <= 0:
		select_placeable("")
	else:
		build_selection_changed.emit(selected_item_id)
	return true


func reclaim_at_mouse(mouse_position: Vector2 = Vector2(-1.0, -1.0)) -> bool:
	var target := targeter.get_mouse_target(grid_map, placement_rules, mouse_position)
	if target.is_empty():
		_set_status("Không có vật Player đã đặt tại đây.", false)
		return false
	for cell in [target.get("delete_cell", Vector3i.ZERO), target.get("place_cell", Vector3i.ZERO)]:
		for candidate in [Vector3i(cell), Vector3i(cell) + Vector3i.UP, Vector3i(cell) + Vector3i.DOWN]:
			if _placed_objects_by_cell.has(candidate):
				return _reclaim_object(_placed_objects_by_cell[candidate])
			if _placed_grid_items.has(candidate):
				return _reclaim_grid_block(candidate)
	_set_status("Chỉ có thể thu hồi vật do Player đã đặt.", false)
	return false


func _place_grid_block(cell: Vector3i, item_id: String, data: Dictionary) -> bool:
	var mesh_item := int(data.get("mesh_library_item", placement_rules.block_item))
	terrain_generator.set_runtime_cell(grid_map, cell, mesh_item)
	if not inventory.try_remove_item(item_id):
		terrain_generator.set_runtime_cell(grid_map, cell, GridMap.INVALID_CELL_ITEM)
		return false
	_placed_grid_items[cell] = item_id
	return true


func _place_object(anchor_cell: Vector3i, item_id: String, data: Dictionary) -> bool:
	var footprint: Vector2i = data.get("footprint", Vector2i.ONE)
	var placed := PlacedBuildObject.new()
	placed.setup(item_id, anchor_cell, footprint)
	_object_container.add_child(placed)
	var anchor_world := grid_map.to_global(grid_map.map_to_local(anchor_cell))
	anchor_world.y -= grid_map.cell_size.y
	placed.global_position = anchor_world
	placed.activate_obstacle(maxf(0.45, Vector2(footprint).length() * 0.32))
	if not inventory.try_remove_item(item_id):
		placed.queue_free()
		return false
	for occupied_cell in placed.occupied_cells:
		_placed_objects_by_cell[occupied_cell] = placed
		_placed_objects_by_cell[occupied_cell + Vector3i.DOWN] = placed
	_placed_objects.append(placed)
	return true


func _reclaim_grid_block(cell: Vector3i) -> bool:
	var item_id := String(_placed_grid_items[cell])
	if not inventory.try_add_item(item_id):
		_set_status("Túi không đủ chỗ để thu hồi.", false)
		return false
	terrain_generator.set_runtime_cell(grid_map, cell, GridMap.INVALID_CELL_ITEM)
	_placed_grid_items.erase(cell)
	_set_status("Đã thu hồi %s." % ItemCatalog.get_display_name(item_id), true)
	return true


func _reclaim_object(placed: PlacedBuildObject) -> bool:
	if not is_instance_valid(placed):
		return false
	var reclaimed_items := placed.get_reclaim_items()
	if not inventory.try_add_items(reclaimed_items):
		_set_status("Túi không đủ chỗ để thu hồi.", false)
		return false
	placed.clear_stored_items()
	for cell in placed.occupied_cells:
		_placed_objects_by_cell.erase(cell)
		_placed_objects_by_cell.erase(cell + Vector3i.DOWN)
	_placed_objects.erase(placed)
	_set_status("Đã thu hồi %s." % ItemCatalog.get_display_name(placed.item_id), true)
	placed.queue_free()
	return true


func _update_preview() -> void:
	if selected_item_id.is_empty() or inventory == null or inventory.count_item(selected_item_id) <= 0:
		preview.hide_preview()
		return
	var target := targeter.get_mouse_target(grid_map, placement_rules)
	if target.is_empty():
		preview.hide_preview()
		return
	var cell: Vector3i = target["place_cell"]
	var data := PlaceableCatalog.get_placeable(selected_item_id)
	preview.show_placeable(grid_map, placement_rules, cell, data, _can_place(cell, data))


func _can_place(anchor_cell: Vector3i, data: Dictionary) -> bool:
	var footprint: Vector2i = data.get("footprint", Vector2i.ONE)
	for cell in _get_footprint_cells(anchor_cell, footprint):
		if not placement_rules.can_place_block(grid_map, cell):
			return false
		if grid_map.get_cell_item(cell + Vector3i.DOWN) == GridMap.INVALID_CELL_ITEM:
			return false
		if _placed_objects_by_cell.has(cell) or _placed_objects_by_cell.has(cell + Vector3i.DOWN):
			return false
		if _cell_overlaps_player_body(cell):
			return false
	return true


func _get_footprint_cells(anchor_cell: Vector3i, footprint: Vector2i) -> Array[Vector3i]:
	var cells: Array[Vector3i] = []
	for z_offset in range(footprint.y):
		for x_offset in range(footprint.x):
			cells.append(anchor_cell + Vector3i(x_offset, 0, z_offset))
	return cells


func _cell_overlaps_player_body(cell: Vector3i) -> bool:
	if player == null:
		player = get_node_or_null(player_path)
	if player == null or not player.has_method("would_block_body_cell"):
		return false
	return player.would_block_body_cell(cell)


func _set_status(message: String, success: bool) -> void:
	build_status_changed.emit(message, success)
