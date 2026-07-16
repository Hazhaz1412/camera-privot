extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := load("res://tiledmap/tscn/camera.tscn") as PackedScene
	var world := scene.instantiate()
	root.add_child(world)
	await process_frame
	await process_frame

	var camera: Camera3D = world.get_node("CameraPivot/Camera3D")
	var grid_map: GridMap = world.get_node("GridMap")
	var generator: GridTerrainGenerator = world.get_node("BuildGrid/TerrainGenerator")
	world.get_node("BuildGrid").set_process(false)
	world.get_node("ResourceSpawner").set_process(false)

	camera.size = 5.0
	await process_frame
	await _drain_stream(generator, grid_map)
	var chunks_before := generator.get_loaded_chunk_count()
	var wanted_before: int = generator._streamer._get_wanted_chunks(grid_map).size()

	camera.size = 18.0
	await process_frame
	var wanted_after: int = generator._streamer._get_wanted_chunks(grid_map).size()
	var result := await _measure_stream(generator, grid_map)
	var chunks_after := generator.get_loaded_chunk_count()
	var max_ms: float = result["max_ms"]
	var total_ms: float = result["total_ms"]
	var frames: int = result["frames"]
	if chunks_after <= chunks_before:
		push_error("STREAMING_BUDGET_TEST_FAILED: zoom xa không nạp thêm chunk (wanted %d -> %d, loaded %d -> %d)" % [wanted_before, wanted_after, chunks_before, chunks_after])
		quit(1)
		return
	if max_ms > 16.7:
		push_error("STREAMING_BUDGET_TEST_FAILED: frame streaming %.2f ms > 16.7 ms" % max_ms)
		quit(1)
		return

	print("STREAMING_BUDGET_TEST_OK before=%d after=%d frames=%d max_ms=%.2f total_ms=%.2f" % [
		chunks_before,
		chunks_after,
		frames,
		max_ms,
		total_ms,
	])
	quit(0)


func _drain_stream(generator: GridTerrainGenerator, grid_map: GridMap) -> void:
	generator.update_stream(grid_map, 0.0, true)
	for _index in range(120):
		generator.update_stream(grid_map, 1.0 / 60.0)
		await process_frame
		if generator.get_pending_chunk_count() == 0:
			for _settle in range(6):
				generator.update_stream(grid_map, 1.0 / 60.0)
				await process_frame
			return


func _measure_stream(generator: GridTerrainGenerator, grid_map: GridMap) -> Dictionary:
	var max_ms := 0.0
	var total_ms := 0.0
	var frames := 0
	generator.update_stream(grid_map, 0.0, true)
	for _index in range(120):
		var started := Time.get_ticks_usec()
		generator.update_stream(grid_map, 1.0 / 60.0)
		var elapsed_ms := float(Time.get_ticks_usec() - started) / 1000.0
		max_ms = maxf(max_ms, elapsed_ms)
		total_ms += elapsed_ms
		frames += 1
		await process_frame
		if generator.get_pending_chunk_count() == 0:
			for _settle in range(6):
				started = Time.get_ticks_usec()
				generator.update_stream(grid_map, 1.0 / 60.0)
				elapsed_ms = float(Time.get_ticks_usec() - started) / 1000.0
				max_ms = maxf(max_ms, elapsed_ms)
				total_ms += elapsed_ms
				frames += 1
				await process_frame
			return {"max_ms": max_ms, "total_ms": total_ms, "frames": frames}
	return {"max_ms": max_ms, "total_ms": total_ms, "frames": frames}
