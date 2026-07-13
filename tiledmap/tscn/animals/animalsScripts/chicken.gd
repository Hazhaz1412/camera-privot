class_name ChickenWander
extends GroundActor

@export var wander_radius_blocks := 50.0

var _wander_direction := Vector3.ZERO
var _wander_timer := 0.0
var _home_position := Vector3.ZERO


func _ready() -> void:
	super._ready()
	move_speed = 1.2  
	_home_position = global_position
	_pick_new_wander_direction()


func _physics_process(delta: float) -> void:
	_wander_timer -= delta
	if _wander_timer <= 0.0:
		_pick_new_wander_direction()

	move_on_grid(_wander_direction, delta)

	if _wander_direction.length_squared() > 0.0001:
		var target_rotation := atan2(_wander_direction.x, _wander_direction.z)
		rotation.y = lerp_angle(rotation.y, target_rotation, 6.0 * delta)


func _pick_new_wander_direction() -> void:
	_wander_timer = randf_range(1.5, 4.0)

	# Chicken pauses more often and for shorter random bursts.
	if randf() < 0.35:
		_wander_direction = Vector3.ZERO
		return

	var offset_from_home := global_position - _home_position
	var distance_from_home := Vector2(offset_from_home.x, offset_from_home.z).length()
	var max_distance := wander_radius_blocks

	if distance_from_home >= max_distance:
		var back_direction := Vector3(-offset_from_home.x, 0.0, -offset_from_home.z).normalized()
		var angle_spread := randf_range(-PI / 4.0, PI / 4.0)
		_wander_direction = back_direction.rotated(Vector3.UP, angle_spread)
	else:
		var angle := randf() * TAU
		_wander_direction = Vector3(sin(angle), 0.0, cos(angle))
