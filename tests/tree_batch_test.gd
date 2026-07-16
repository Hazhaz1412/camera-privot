extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := (load("res://tiledmap/tscn/camera.tscn") as PackedScene).instantiate()
	root.add_child(world)
	await process_frame
	var generator: GridTerrainGenerator = world.get_node("BuildGrid/TerrainGenerator")
	var grid_map: GridMap = world.get_node("GridMap")
	var spawner: TreeSpawner = world.get_node("TreeContainer/TreeSpawner")
	world.get_node("BuildGrid").set_process(false)

	for _frame in range(180):
		generator.update_stream(grid_map, 1.0 / 60.0)
		await process_frame
		if generator.get_pending_chunk_count() == 0 and generator.get_loaded_chunk_count() >= 16:
			break

	var tree_count := spawner.get_tree_count()
	var renderer_count := spawner.get_renderer_count()
	if tree_count <= 0:
		push_error("TREE_BATCH_TEST_FAILED: không có cây trong vùng test")
		quit(1)
		return
	if renderer_count >= tree_count:
		push_error("TREE_BATCH_TEST_FAILED: batching không giảm node render (%d/%d)" % [renderer_count, tree_count])
		quit(1)
		return
	if tree_count > 280:
		push_error("TREE_BATCH_TEST_FAILED: mật độ cây vẫn quá dày (%d)" % tree_count)
		quit(1)
		return

	print("TREE_BATCH_TEST_OK trees=%d renderers=%d loaded_chunks=%d" % [
		tree_count,
		renderer_count,
		generator.get_loaded_chunk_count(),
	])
	quit(0)
