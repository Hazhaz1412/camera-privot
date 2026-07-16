extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := load("res://tiledmap/tscn/camera.tscn") as PackedScene
	var world := scene.instantiate()
	root.add_child(world)
	var player: GroundActor = world.get_node("Player")
	var lowest_y := player.global_position.y

	for _frame in range(120):
		await physics_frame
		lowest_y = minf(lowest_y, player.global_position.y)
		if not player.spawn_snap_pending:
			break

	if player.spawn_snap_pending:
		push_error("SPAWN_STREAMING_TEST_FAILED: terrain dưới Player không load xong")
		quit(1)
		return
	if lowest_y < -0.5:
		push_error("SPAWN_STREAMING_TEST_FAILED: Player rơi xuống y=%.2f" % lowest_y)
		quit(1)
		return

	print("SPAWN_STREAMING_TEST_OK y=%.2f lowest=%.2f chunks=%d" % [
		player.global_position.y,
		lowest_y,
		world.get_node("BuildGrid/TerrainGenerator").get_loaded_chunk_count(),
	])
	quit(0)
