class_name PlacedBuildObject
extends Node3D

var item_id := ""
var anchor_cell := Vector3i.ZERO
var occupied_cells: Array[Vector3i] = []
var is_lit := true
var _obstacle_registered := false
var _fire_visual: MeshInstance3D
var factory_progress := 0.0
var factory_processing := false
var factory_inputs: Dictionary = {}
var factory_outputs: Dictionary = {}
var chest_contents: Dictionary = {}
var chest_capacity := 24
var _machine_indicator: MeshInstance3D


func setup(new_item_id: String, new_anchor_cell: Vector3i, footprint: Vector2i) -> void:
	item_id = new_item_id
	anchor_cell = new_anchor_cell
	name = "Placed_%s_%d_%d_%d" % [item_id, anchor_cell.x, anchor_cell.y, anchor_cell.z]
	add_to_group("placed_build_object")
	for z_offset in range(footprint.y):
		for x_offset in range(footprint.x):
			occupied_cells.append(anchor_cell + Vector3i(x_offset, 0, z_offset))
	_build_visual()
	set_process(FactoryRecipeCatalog.is_machine(item_id))


func _process(delta: float) -> void:
	advance_factory_time(delta)


func activate_obstacle(radius: float) -> void:
	ObstacleRegistry.register(get_instance_id(), global_position, radius)
	_obstacle_registered = true


func get_interaction_prompt() -> String:
	match item_id:
		"crafting_table":
			return "[E] Dùng Bàn chế tạo"
		"campfire":
			return "[E] %s Bếp lửa" % ("Tắt" if is_lit else "Đốt")
		"wooden_chest":
			return "[E] Gửi 1 vật phẩm  •  [Shift+E] Lấy hết  (%d/%d)" % [_get_dictionary_count(chest_contents), chest_capacity]
	if FactoryRecipeCatalog.is_machine(item_id):
		var recipe := FactoryRecipeCatalog.get_recipe(item_id)
		if not factory_outputs.is_empty():
			return "[E] Lấy %s" % FactoryRecipeCatalog.format_items(factory_outputs)
		if factory_processing:
			var duration := float(recipe.get("duration", 1.0))
			return "[E] %s — %d%%  •  Búa: tăng tốc" % [recipe.get("display_name", item_id), roundi(factory_progress / duration * 100.0)]
		return "[E] Nạp %s" % FactoryRecipeCatalog.format_items(recipe.get("inputs", {}))
	return ""


func interact(player: Node, alternate := false) -> void:
	match item_id:
		"crafting_table":
			if player.has_method("open_crafting_table"):
				player.open_crafting_table(self)
		"campfire":
			is_lit = not is_lit
			if _fire_visual != null:
				_fire_visual.visible = is_lit
			if player.has_method("show_interaction_message"):
				player.show_interaction_message("Bếp lửa đã %s." % ("được đốt" if is_lit else "tắt"))
		"wooden_chest":
			_interact_chest(player, alternate)
		_:
			if FactoryRecipeCatalog.is_machine(item_id):
				_interact_factory_machine(player)


func advance_factory_time(seconds: float) -> void:
	if not factory_processing or not FactoryRecipeCatalog.is_machine(item_id):
		return
	factory_progress += maxf(seconds, 0.0)
	var recipe := FactoryRecipeCatalog.get_recipe(item_id)
	if factory_progress < float(recipe.get("duration", 1.0)):
		_update_machine_indicator()
		return
	factory_processing = false
	factory_progress = float(recipe.get("duration", 1.0))
	factory_inputs.clear()
	factory_outputs = Dictionary(recipe.get("outputs", {})).duplicate(true)
	_update_machine_indicator()


func apply_hammer_boost(seconds := 1.25) -> bool:
	if not factory_processing:
		return false
	advance_factory_time(seconds)
	return true


func get_reclaim_items() -> Dictionary:
	var result := {item_id: 1}
	_merge_counts(result, chest_contents)
	_merge_counts(result, factory_inputs)
	_merge_counts(result, factory_outputs)
	return result


func clear_stored_items() -> void:
	chest_contents.clear()
	factory_inputs.clear()
	factory_outputs.clear()
	factory_processing = false


func _interact_factory_machine(player: Node) -> void:
	var player_inventory := _get_player_inventory(player)
	if player_inventory == null:
		return
	var recipe := FactoryRecipeCatalog.get_recipe(item_id)
	if not factory_outputs.is_empty():
		if player_inventory.try_add_items(factory_outputs):
			var collected_text := FactoryRecipeCatalog.format_items(factory_outputs)
			factory_outputs.clear()
			factory_progress = 0.0
			_update_machine_indicator()
			_show_message(player, "Đã lấy %s." % collected_text, true)
		else:
			_show_message(player, "Túi không đủ chỗ để lấy sản phẩm.", false)
		return
	if factory_processing:
		var duration := float(recipe.get("duration", 1.0))
		_show_message(player, "%s đang chạy: %d%%." % [recipe.get("display_name", item_id), roundi(factory_progress / duration * 100.0)], true)
		return
	var inputs: Dictionary = recipe.get("inputs", {})
	if not player_inventory.try_remove_items(inputs):
		_show_message(player, "Thiếu đầu vào: %s." % FactoryRecipeCatalog.format_items(inputs), false)
		return
	factory_inputs = inputs.duplicate(true)
	factory_progress = 0.0
	factory_processing = true
	_update_machine_indicator()
	_show_message(player, "Đã nạp máy — %s bắt đầu chạy." % recipe.get("display_name", item_id), true)


func _interact_chest(player: Node, alternate: bool) -> void:
	var player_inventory := _get_player_inventory(player)
	if player_inventory == null:
		return
	if alternate:
		if chest_contents.is_empty():
			_show_message(player, "Kho đang trống.", false)
			return
		if not player_inventory.try_add_items(chest_contents):
			_show_message(player, "Túi không đủ chỗ để lấy toàn bộ đồ trong kho.", false)
			return
		var withdrawn := FactoryRecipeCatalog.format_items(chest_contents)
		chest_contents.clear()
		_show_message(player, "Đã lấy khỏi kho: %s." % withdrawn, true)
		return
	if _get_dictionary_count(chest_contents) >= chest_capacity:
		_show_message(player, "Kho đã đầy.", false)
		return
	for inventory_item: Dictionary in player_inventory.get_items():
		var stored_item_id := String(inventory_item.get("item_id", ""))
		if not _can_store_item(stored_item_id):
			continue
		if player_inventory.try_remove_item_by_uid(int(inventory_item["uid"])):
			chest_contents[stored_item_id] = int(chest_contents.get(stored_item_id, 0)) + 1
			_show_message(player, "Đã gửi %s vào kho (%d/%d)." % [ItemCatalog.get_display_name(stored_item_id), _get_dictionary_count(chest_contents), chest_capacity], true)
			return
	_show_message(player, "Không có nguyên liệu/sản phẩm phù hợp để gửi vào kho.", false)


func _can_store_item(stored_item_id: String) -> bool:
	return (
		ItemCatalog.has_item(stored_item_id)
		and not PlaceableCatalog.is_placeable(stored_item_id)
		and not stored_item_id in ["stone_axe", "stone_pickaxe", "stone_hammer"]
	)


func _get_player_inventory(player: Node) -> InventoryData:
	if player == null:
		return null
	return player.get_node_or_null("Inventory") as InventoryData


func _show_message(player: Node, message: String, success: bool) -> void:
	if player.has_method("show_interaction_message"):
		player.show_interaction_message(message, success)


func _get_dictionary_count(items: Dictionary) -> int:
	var total := 0
	for count in items.values():
		total += int(count)
	return total


func _merge_counts(target: Dictionary, source: Dictionary) -> void:
	for stored_item_id: String in source.keys():
		target[stored_item_id] = int(target.get(stored_item_id, 0)) + int(source[stored_item_id])


func _build_visual() -> void:
	match item_id:
		"crafting_table":
			_build_crafting_table()
		"campfire":
			_build_campfire()
		"wooden_chest":
			_build_wooden_chest()
		"sawmill":
			_build_sawmill()
		"stone_crusher":
			_build_stone_crusher()
		"stone_furnace":
			_build_stone_furnace()


func _build_crafting_table() -> void:
	_add_box(Vector3(1.55, 0.16, 1.55), Vector3(0.5, 0.92, 0.5), Color("80583d"))
	for x in [0.12, 0.88]:
		for z in [0.12, 0.88]:
			_add_box(Vector3(0.16, 0.82, 0.16), Vector3(x, 0.43, z), Color("5d3d2c"))
	_add_box(Vector3(1.18, 0.08, 0.12), Vector3(0.5, 1.03, 0.5), Color("c99a61"), 0.55)


func _build_campfire() -> void:
	for index in range(8):
		var angle := TAU * float(index) / 8.0
		var stone := SphereMesh.new()
		stone.radius = 0.17
		stone.height = 0.25
		stone.radial_segments = 6
		stone.rings = 3
		_add_mesh(stone, Vector3(0.5 + cos(angle) * 0.48, 0.13, 0.5 + sin(angle) * 0.48), Color("777d7d"))
	for angle in [PI * 0.25, -PI * 0.25]:
		var log_mesh := CylinderMesh.new()
		log_mesh.top_radius = 0.09
		log_mesh.bottom_radius = 0.11
		log_mesh.height = 0.9
		log_mesh.radial_segments = 7
		var log := _add_mesh(log_mesh, Vector3(0.5, 0.18, 0.5), Color("70452e"))
		log.rotation = Vector3(0.0, angle, PI * 0.5)
	var flame := SphereMesh.new()
	flame.radius = 0.25
	flame.height = 0.65
	flame.radial_segments = 7
	flame.rings = 4
	_fire_visual = _add_mesh(flame, Vector3(0.5, 0.48, 0.5), Color("ff8a35"))
	var flame_material := _fire_visual.material_override as StandardMaterial3D
	flame_material.emission_enabled = true
	flame_material.emission = Color("ff662b")
	flame_material.emission_energy_multiplier = 2.2


func _build_wooden_chest() -> void:
	_add_box(Vector3(1.45, 0.72, 1.15), Vector3(0.5, 0.42, 0.5), Color("805535"))
	_add_box(Vector3(1.52, 0.18, 1.20), Vector3(0.5, 0.87, 0.5), Color("a47748"))
	_add_box(Vector3(0.14, 0.30, 0.08), Vector3(0.5, 0.66, -0.105), Color("d0a84f"))


func _build_sawmill() -> void:
	_add_box(Vector3(1.65, 0.30, 1.35), Vector3(0.5, 0.18, 0.5), Color("674b35"))
	_add_box(Vector3(1.50, 0.12, 0.48), Vector3(0.5, 0.55, 0.5), Color("a57a4d"))
	var blade := CylinderMesh.new()
	blade.top_radius = 0.46
	blade.bottom_radius = 0.46
	blade.height = 0.075
	blade.radial_segments = 12
	var blade_instance := _add_mesh(blade, Vector3(0.5, 0.88, 0.5), Color("aeb7bc"))
	blade_instance.rotation.x = PI * 0.5
	_add_machine_indicator(Vector3(1.10, 0.45, 0.5))


func _build_stone_crusher() -> void:
	_add_box(Vector3(1.58, 0.32, 1.42), Vector3(0.5, 0.18, 0.5), Color("555d62"))
	_add_box(Vector3(1.30, 0.85, 1.20), Vector3(0.5, 0.70, 0.5), Color("727d83"))
	_add_box(Vector3(0.92, 0.38, 0.92), Vector3(0.5, 1.32, 0.5), Color("4f575c"))
	_add_box(Vector3(0.48, 0.16, 0.48), Vector3(0.5, 1.58, 0.5), Color("30373b"))
	_add_machine_indicator(Vector3(1.14, 1.02, -0.02))


func _build_stone_furnace() -> void:
	_add_box(Vector3(1.55, 1.35, 1.40), Vector3(0.5, 0.72, 0.5), Color("5e5b58"))
	_add_box(Vector3(0.76, 0.62, 0.12), Vector3(0.5, 0.53, -0.205), Color("282726"))
	var ember := _add_box(Vector3(0.58, 0.34, 0.05), Vector3(0.5, 0.50, -0.275), Color("8b3822"))
	var ember_material := ember.material_override as StandardMaterial3D
	ember_material.emission_enabled = true
	ember_material.emission = Color("ff5a24")
	ember_material.emission_energy_multiplier = 1.6
	_add_box(Vector3(0.42, 0.55, 0.42), Vector3(0.5, 1.66, 0.5), Color("4b4947"))
	_add_machine_indicator(Vector3(1.15, 1.08, -0.02))


func _add_machine_indicator(position: Vector3) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = 0.10
	mesh.height = 0.18
	mesh.radial_segments = 8
	mesh.rings = 4
	_machine_indicator = _add_mesh(mesh, position, Color("bc5048"))
	_update_machine_indicator()


func _update_machine_indicator() -> void:
	if _machine_indicator == null:
		return
	var material := _machine_indicator.material_override as StandardMaterial3D
	var color := Color("d4aa4d") if factory_processing else Color("58b86a") if not factory_outputs.is_empty() else Color("bc5048")
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 1.4


func _add_box(size: Vector3, position: Vector3, color: Color, yaw := 0.0) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var instance := _add_mesh(mesh, position, color)
	instance.rotation.y = yaw
	return instance


func _add_mesh(mesh: PrimitiveMesh, position: Vector3, color: Color) -> MeshInstance3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = position
	add_child(instance)
	return instance


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and _obstacle_registered:
		ObstacleRegistry.unregister(get_instance_id())
