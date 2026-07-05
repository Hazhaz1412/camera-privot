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

@onready var camera_pivot: Node3D = get_node_or_null(camera_pivot_path)
@onready var build_grid: Node = get_node_or_null(build_grid_path)
@onready var visual_root: Node3D = get_node_or_null(visual_root_path)
@onready var animation_player: AnimationPlayer = get_node_or_null(animation_player_path)
@onready var model_root: Node = get_node_or_null(model_root_path)

var animations_sanitized := false
var resolved_idle_animation := &""
var resolved_walk_animation := &""


func _ready():
	super._ready()
	_resolve_nodes()
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
	if disable_movement_in_build_mode and _is_build_mode_enabled():
		input_dir = Vector2.ZERO

	var move_direction := _get_camera_relative_direction(input_dir)

	move_on_grid(move_direction, delta)

	_update_visual_rotation(move_direction, delta)
	_update_animation()


func _resolve_nodes():
	if camera_pivot == null:
		camera_pivot = get_node_or_null(camera_pivot_path)
	if build_grid == null:
		build_grid = get_node_or_null(build_grid_path)
	if animation_player == null:
		animation_player = get_node_or_null(animation_player_path)
	if model_root == null:
		model_root = get_node_or_null(model_root_path)


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
