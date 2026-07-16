extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var player_id := 900001
	var animal_id := 900002
	var player_position := Vector3.ZERO
	var animal_position := Vector3(0.40, 0.0, 0.0)
	var radius := 0.35

	ObstacleRegistry.register(player_id, player_position, radius)
	ObstacleRegistry.register(animal_id, animal_position, radius)

	_assert(
		not ObstacleRegistry.is_movement_blocked(player_position, Vector3(-0.10, 0.0, 0.0), radius, player_id),
		"Player phải thoát được khỏi động vật đang overlap"
	)
	_assert(
		ObstacleRegistry.is_movement_blocked(player_position, Vector3(0.10, 0.0, 0.0), radius, player_id),
		"Bước đâm sâu hơn vào động vật phải bị chặn"
	)
	_assert(
		ObstacleRegistry.is_movement_blocked(Vector3(-1.0, 0.0, 0.0), Vector3(-0.20, 0.0, 0.0), radius, player_id),
		"Actor chưa overlap không được đi xuyên vào động vật"
	)

	ObstacleRegistry.unregister(animal_id)
	_assert(
		not ObstacleRegistry.get_blocking_obstacle(animal_position, radius, player_id),
		"Động vật despawn không được để lại obstacle"
	)
	ObstacleRegistry.unregister(player_id)

	var world := (load("res://tiledmap/tscn/camera.tscn") as PackedScene).instantiate()
	root.add_child(world)
	var player: GroundActor = world.get_node("Player")
	for _frame in range(120):
		await physics_frame
		if not player.spawn_snap_pending:
			break
	_assert(not player.spawn_snap_pending, "Player chưa đứng ổn định trên terrain")

	var cow := (load("res://tiledmap/tscn/animals/cow.tscn") as PackedScene).instantiate() as GroundActor
	world.add_child(cow)
	cow.set_physics_process(false)
	cow.set_grid_map(world.get_node("GridMap"))
	cow.spawn_snap_pending = false
	cow.global_position = player.global_position + Vector3(0.40, 0.0, 0.0)
	cow.move_on_grid(Vector3.ZERO, 0.0)

	var before_x := player.global_position.x
	player.velocity = Vector3.ZERO
	player.move_on_grid(Vector3.LEFT, 0.1)
	_assert(player.global_position.x < before_x - 0.01, "Player thật vẫn bị dính khi cố đi ra khỏi Cow")

	ObstacleRegistry.unregister(cow.get_instance_id())
	cow.queue_free()
	print("ACTOR_COLLISION_TEST_OK escaped=%.3f" % (before_x - player.global_position.x))
	quit(0)


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error("ACTOR_COLLISION_TEST_FAILED: %s" % message)
	ObstacleRegistry.unregister(900001)
	ObstacleRegistry.unregister(900002)
	quit(1)
