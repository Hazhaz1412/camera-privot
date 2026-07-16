@tool
extends GroundActor

@export var rotation_speed := 12.0
@export var disable_movement_in_build_mode := true
@export var camera_pivot_path: NodePath = ^"../CameraPivot"
@export var build_grid_path: NodePath = ^"../BuildGrid"
@export var visual_root_path: NodePath = ^"Node3D"
@export var animation_player_path: NodePath = ^"AnimationPlayer"
@export var model_root_path: NodePath = ^"Node3D/Man_01_02"
@export var idle_animation := &"Idle_breath"
@export var walk_animation := &"Walk"
@export var animation_blend_time := 0.15
@export var inventory_path: NodePath = ^"Inventory"
@export var pickup_distance := 2.25
@export var interaction_distance := 2.75

@onready var camera_pivot: Node3D = get_node_or_null(camera_pivot_path)
@onready var build_grid: Node = get_node_or_null(build_grid_path)
@onready var visual_root: Node3D = get_node_or_null(visual_root_path)
@onready var animation_player: AnimationPlayer = get_node_or_null(animation_player_path)
@onready var model_root: Node = get_node_or_null(model_root_path)
@onready var inventory: InventoryData = get_node_or_null(inventory_path) as InventoryData

var animations_sanitized := false
var resolved_idle_animation := &""
var resolved_walk_animation := &""
var inventory_open := false
var active_tool_id := ""

const TOOL_ORDER := ["stone_axe", "stone_pickaxe", "stone_hammer"]


func _ready():
	super._ready()
	_resolve_nodes()
	if inventory == null:
		inventory = get_node_or_null(inventory_path) as InventoryData
	if inventory != null and inventory.has_signal("inventory_changed"):
		var validate_callable := Callable(self, "_validate_active_tool")
		if not inventory.is_connected("inventory_changed", validate_callable):
			inventory.connect("inventory_changed", validate_callable)
	_setup_animation_player()
	if Engine.is_editor_hint():
		set_process(true)
		set_physics_process(false)
		return
	_play_animation(resolved_idle_animation)


func _process(_delta):
	if Engine.is_editor_hint():
		_resolve_nodes()
		_sanitize_animation_library()
		_resolve_animation_names()


func _physics_process(delta):
	if Engine.is_editor_hint():
		return

	_resolve_nodes()
	if grid_map != null and spawn_snap_pending:
		_try_snap_to_spawn_surface()
		if spawn_snap_pending:
			return

	var input_dir := _get_move_input()
	if inventory_open:
		input_dir = Vector2.ZERO
	if disable_movement_in_build_mode and _is_build_mode_enabled():
		input_dir = Vector2.ZERO

	var move_direction := _get_camera_relative_direction(input_dir)

	move_on_grid(move_direction, delta)

	_update_visual_rotation(move_direction, delta)
	_update_animation()


func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint() or inventory_open:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F:
		cycle_active_tool()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E:
		if _try_interact_nearest(event.shift_pressed):
			get_viewport().set_input_as_handled()
		return
	if (
		event is InputEventMouseButton
		and event.pressed
		and event.button_index == MouseButton.MOUSE_BUTTON_LEFT
		and not _is_build_mode_enabled()
	):
		if _use_active_tool():
			get_viewport().set_input_as_handled()


func _resolve_nodes():
	if camera_pivot == null:
		camera_pivot = get_node_or_null(camera_pivot_path)
	if build_grid == null:
		build_grid = get_node_or_null(build_grid_path)
	if animation_player == null:
		animation_player = get_node_or_null(animation_player_path)
	if model_root == null:
		model_root = get_node_or_null(model_root_path)
	if inventory == null:
		inventory = get_node_or_null(inventory_path) as InventoryData


func set_inventory_open(open: bool) -> void:
	inventory_open = open
	if inventory_open:
		velocity.x = 0.0
		velocity.z = 0.0


func is_inventory_open() -> bool:
	return inventory_open


func get_nearest_pickup() -> Node3D:
	if inventory_open:
		return null
	var nearest: Node3D = null
	var nearest_distance_sq := pickup_distance * pickup_distance
	for candidate in get_tree().get_nodes_in_group("world_pickup"):
		if not candidate is Node3D or not is_instance_valid(candidate):
			continue
		var distance_sq := global_position.distance_squared_to(candidate.global_position)
		if distance_sq > nearest_distance_sq:
			continue
		nearest = candidate
		nearest_distance_sq = distance_sq
	return nearest


func is_pickup_interaction_available() -> bool:
	return get_nearest_pickup() != null


func _try_pickup_nearest() -> bool:
	if inventory == null:
		return false
	var pickup := get_nearest_pickup()
	if pickup == null:
		return false
	var item_id := String(pickup.get("item_id"))
	if not inventory.try_add_item(item_id):
		return false
	if pickup.has_method("collect"):
		pickup.collect()
	return true


func drop_inventory_item(uid: int) -> Dictionary:
	if inventory == null:
		return {"success": false, "reason": "Không tìm thấy túi đồ."}
	var item := inventory.get_item_by_uid(uid)
	if item.is_empty():
		return {"success": false, "reason": "Vật phẩm không còn trong túi."}

	var item_id := String(item["item_id"])
	var pickup := WorldPickup.new()
	get_parent().add_child(pickup)
	pickup.setup(item_id, "dropped:%d:%d" % [Time.get_ticks_usec(), uid])

	var forward := Vector3.FORWARD
	if visual_root != null:
		forward = visual_root.global_transform.basis.z
	forward.y = 0.0
	if forward.length_squared() < 0.0001:
		forward = Vector3.FORWARD
	forward = forward.normalized()
	pickup.global_position = global_position + forward * 1.35 + Vector3.UP * 0.12

	if not inventory.try_remove_item_by_uid(uid):
		pickup.queue_free()
		return {"success": false, "reason": "Không thể vứt vật phẩm."}

	return {
		"success": true,
		"reason": "Đã vứt %s ra trước mặt." % ItemCatalog.get_display_name(item_id),
		"pickup": pickup,
	}


func get_nearest_placed_object() -> PlacedBuildObject:
	var nearest: PlacedBuildObject = null
	var nearest_distance_sq := interaction_distance * interaction_distance
	for candidate in get_tree().get_nodes_in_group("placed_build_object"):
		if not candidate is PlacedBuildObject or not is_instance_valid(candidate):
			continue
		var distance_sq := global_position.distance_squared_to(candidate.global_position)
		if distance_sq > nearest_distance_sq:
			continue
		nearest = candidate
		nearest_distance_sq = distance_sq
	return nearest


func get_interaction_prompt() -> String:
	var pickup := get_nearest_pickup()
	if pickup != null:
		return "[E] Nhặt %s" % ItemCatalog.get_display_name(String(pickup.get("item_id")))
	var placed := get_nearest_placed_object()
	return placed.get_interaction_prompt() if placed != null else ""


func _try_interact_nearest(alternate := false) -> bool:
	if _try_pickup_nearest():
		return true
	var placed := get_nearest_placed_object()
	if placed == null:
		return false
	placed.interact(self, alternate)
	return true


func cycle_active_tool() -> void:
	var available_tools: Array[String] = []
	for tool_id: String in TOOL_ORDER:
		if inventory != null and inventory.count_item(tool_id) > 0:
			available_tools.append(tool_id)
	if available_tools.is_empty():
		active_tool_id = ""
		show_interaction_message("Chưa có công cụ. Hãy chế tạo Rìu, Cuốc hoặc Búa đá.", false)
		return
	var current_index := available_tools.find(active_tool_id)
	active_tool_id = available_tools[(current_index + 1) % available_tools.size()]
	show_interaction_message("Đã trang bị %s." % ItemCatalog.get_display_name(active_tool_id), true)


func get_tool_hud_text() -> String:
	_validate_active_tool()
	if active_tool_id.is_empty():
		return "[F] Chọn công cụ"
	var action := "Chặt gỗ" if active_tool_id == "stone_axe" else "Khai thác" if active_tool_id == "stone_pickaxe" else "Hỗ trợ máy"
	return "[F] %s  •  [Chuột trái] %s" % [ItemCatalog.get_display_name(active_tool_id), action]


func _validate_active_tool() -> void:
	if not active_tool_id.is_empty() and (inventory == null or inventory.count_item(active_tool_id) <= 0):
		active_tool_id = ""


func _use_active_tool() -> bool:
	_validate_active_tool()
	if active_tool_id.is_empty():
		cycle_active_tool()
		return true
	if active_tool_id == "stone_hammer":
		var placed := get_nearest_factory_machine()
		if placed == null or not placed.apply_hammer_boost():
			show_interaction_message("Búa chỉ tăng tốc khi đứng gần một máy đang chạy.", false)
			return true
		show_interaction_message("Đã dùng Búa đá hỗ trợ máy +1.25 giây.", true)
		return true

	var allowed_items: Array = ["wood", "stick"] if active_tool_id == "stone_axe" else ["stone", "coal", "iron_ore"]
	var target := _get_nearest_pickup_matching(allowed_items)
	if target == null:
		show_interaction_message(
			"Rìu dùng cho gỗ/que." if active_tool_id == "stone_axe" else "Cuốc dùng cho đá, than và quặng sắt.",
			false
		)
		return true
	var harvested_item_id := String(target.get("item_id"))
	if inventory == null or not inventory.try_add_items({harvested_item_id: 2}):
		show_interaction_message("Túi không đủ chỗ để thu hoạch.", false)
		return true
	if target.has_method("collect"):
		target.collect()
	show_interaction_message("Thu hoạch hiệu quả: %s ×2." % ItemCatalog.get_display_name(harvested_item_id), true)
	return true


func get_nearest_factory_machine() -> PlacedBuildObject:
	var nearest: PlacedBuildObject = null
	var nearest_distance_sq := interaction_distance * interaction_distance
	for candidate in get_tree().get_nodes_in_group("placed_build_object"):
		if not candidate is PlacedBuildObject or not is_instance_valid(candidate):
			continue
		if not FactoryRecipeCatalog.is_machine(candidate.item_id):
			continue
		var distance_sq := global_position.distance_squared_to(candidate.global_position)
		if distance_sq > nearest_distance_sq:
			continue
		nearest = candidate
		nearest_distance_sq = distance_sq
	return nearest


func _get_nearest_pickup_matching(allowed_items: Array) -> Node3D:
	var nearest: Node3D = null
	var nearest_distance_sq := pickup_distance * pickup_distance
	for candidate in get_tree().get_nodes_in_group("world_pickup"):
		if not candidate is Node3D or not is_instance_valid(candidate):
			continue
		if String(candidate.get("item_id")) not in allowed_items:
			continue
		var distance_sq := global_position.distance_squared_to(candidate.global_position)
		if distance_sq > nearest_distance_sq:
			continue
		nearest = candidate
		nearest_distance_sq = distance_sq
	return nearest


func open_crafting_table(_table: PlacedBuildObject) -> void:
	var ui := get_node_or_null("../UI") as InventoryUI
	if ui != null:
		ui.open_at_crafting_table()


func show_interaction_message(message: String, success := true) -> void:
	var ui := get_node_or_null("../UI") as InventoryUI
	if ui != null:
		ui.show_world_message(message, success)


func _setup_animation_player():
	if animation_player == null:
		return

	_sanitize_animation_library()
	_resolve_animation_names()


func _sanitize_animation_library():
	if animations_sanitized and not Engine.is_editor_hint():
		return
	if animation_player == null:
		return
	if model_root == null:
		return

	for animation_name in animation_player.get_animation_list():
		var animation := animation_player.get_animation(animation_name)
		if animation == null:
			continue

		animation.loop_mode = Animation.LOOP_LINEAR
		_sanitize_animation_tracks(animation)

	if not Engine.is_editor_hint():
		animations_sanitized = true


func _resolve_animation_names():
	resolved_idle_animation = _get_existing_animation_name(idle_animation, [&"Idle_breath", &"Idle"])
	resolved_walk_animation = _get_existing_animation_name(walk_animation, [&"Walk", &"walk"])


func _get_existing_animation_name(preferred_name: StringName, fallback_names: Array[StringName]) -> StringName:
	if animation_player == null:
		return &""
	if animation_player.has_animation(preferred_name):
		return preferred_name

	for fallback_name in fallback_names:
		if animation_player.has_animation(fallback_name):
			return fallback_name

	return &""


func _sanitize_animation_tracks(animation: Animation):
	for track_index in range(animation.get_track_count()):
		var track_path := String(animation.track_get_path(track_index))
		var remapped_path := _get_existing_bone_track_path(track_path)
		if remapped_path.is_empty():
			animation.track_set_enabled(track_index, false)
			continue

		if remapped_path != track_path:
			animation.track_set_path(track_index, NodePath(remapped_path))
		animation.track_set_enabled(track_index, true)


func _get_existing_bone_track_path(track_path: String) -> String:
	var separator_index := track_path.find(":")
	if separator_index == -1:
		return ""

	var bone_name := track_path.substr(separator_index + 1)
	if bone_name.is_empty():
		return ""

	var skeleton := _find_skeleton_with_bone(bone_name)
	if skeleton == null:
		return ""

	var skeleton_path := String(model_root.get_path_to(skeleton))
	return "%s:%s" % [skeleton_path, bone_name]


func _find_skeleton_with_bone(bone_name: String) -> Skeleton3D:
	if model_root == null:
		return null

	return _find_skeleton_with_bone_recursive(model_root, bone_name)


func _find_skeleton_with_bone_recursive(node: Node, bone_name: String) -> Skeleton3D:
	if node is Skeleton3D and node.find_bone(bone_name) != -1:
		return node

	for child in node.get_children():
		var skeleton := _find_skeleton_with_bone_recursive(child, bone_name)
		if skeleton != null:
			return skeleton

	return null


func _update_animation():
	if animation_player == null:
		return
	if String(resolved_idle_animation).is_empty() or String(resolved_walk_animation).is_empty():
		_resolve_animation_names()

	var horizontal_speed_sq := velocity.x * velocity.x + velocity.z * velocity.z
	if horizontal_speed_sq > 0.01:
		_play_animation(resolved_walk_animation)
	else:
		_play_animation(resolved_idle_animation)


func _play_animation(animation_name: StringName):
	if String(animation_name).is_empty():
		return
	if animation_player.current_animation == animation_name:
		return
	if not animation_player.has_animation(animation_name):
		return

	animation_player.play(animation_name, animation_blend_time)


func _get_move_input() -> Vector2:
	var input_dir := Vector2.ZERO

	if Input.is_key_pressed(KEY_D):
		input_dir.x += 1.0
	if Input.is_key_pressed(KEY_A):
		input_dir.x -= 1.0
	if Input.is_key_pressed(KEY_S):
		input_dir.y += 1.0
	if Input.is_key_pressed(KEY_W):
		input_dir.y -= 1.0

	return input_dir.normalized() if input_dir.length() > 1.0 else input_dir


func _get_camera_relative_direction(input_dir: Vector2) -> Vector3:
	if input_dir == Vector2.ZERO:
		return Vector3.ZERO

	var right := Vector3.RIGHT
	var forward := Vector3.FORWARD
	if camera_pivot != null:
		right = camera_pivot.global_transform.basis.x
		forward = -camera_pivot.global_transform.basis.z

	right.y = 0.0
	forward.y = 0.0
	right = right.normalized()
	forward = forward.normalized()

	return (right * input_dir.x + forward * -input_dir.y).normalized()


func _update_visual_rotation(move_direction: Vector3, delta: float):
	if visual_root == null or move_direction.length_squared() < 0.0001:
		return

	var target_yaw := atan2(move_direction.x, move_direction.z)
	visual_root.rotation.y = lerp_angle(
		visual_root.rotation.y,
		target_yaw,
		clampf(delta * rotation_speed, 0.0, 1.0)
	)


func _is_build_mode_enabled() -> bool:
	if build_grid == null or not build_grid.has_method("is_build_mode_enabled"):
		return false

	return build_grid.is_build_mode_enabled()
