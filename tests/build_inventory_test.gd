extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := (load("res://tiledmap/tscn/camera.tscn") as PackedScene).instantiate()
	root.add_child(world)
	var player: Node3D = world.get_node("Player")
	var inventory: InventoryData = player.get_node("Inventory")
	var build_grid: BuildGrid = world.get_node("BuildGrid")
	var ui: InventoryUI = world.get_node("UI")
	var build_menu: BuildMenuUI = world.get_node("UI/BuildMenuUI")

	for _frame in range(180):
		await physics_frame
		if not player.spawn_snap_pending and build_grid.terrain_generator.get_pending_chunk_count() == 0:
			break

	_assert(inventory.try_add_item("stone_block"), "Không thêm được block test")
	_assert(inventory.try_add_item("crafting_table"), "Không thêm được bàn test")
	_assert(inventory.try_add_item("campfire"), "Không thêm được bếp lửa test")
	_assert(inventory.try_add_item("stone_crusher"), "Không thêm được máy nghiền test")

	build_grid.set_build_mode_enabled(true)
	await process_frame
	_assert(build_menu.panel.visible, "Build menu không hiện khi bấm B")
	_assert(build_menu.buttons.has("stone_block"), "Build menu không đọc block từ inventory")
	_assert(build_menu.buttons.has("crafting_table"), "Build menu không đọc bàn từ inventory")
	_assert(build_menu.buttons.has("stone_crusher"), "Build menu không đọc máy factory từ inventory")

	var block_cell := _find_valid_cell(build_grid, "stone_block", Vector2i(3, 3))
	_assert(block_cell.y > 0, "Không tìm được chỗ đặt block")
	build_grid.select_placeable("stone_block")
	_assert(build_grid.place_selected_at_cell(block_cell), "Không đặt được block từ inventory")
	_assert(inventory.count_item("stone_block") == 0, "Đặt block chưa trừ item")
	_assert(build_grid.grid_map.get_cell_item(block_cell) == 5, "Block chưa được ghi vào GridMap")
	_assert(not build_grid.place_selected_at_cell(block_cell + Vector3i.UP), "Hết item nhưng vẫn đặt block vô hạn")
	_assert(build_grid._reclaim_grid_block(block_cell), "Không thu hồi được block")
	_assert(inventory.count_item("stone_block") == 1, "Thu hồi block chưa hoàn item")

	var table_cell := _find_valid_cell(build_grid, "crafting_table", Vector2i(6, 6))
	_assert(table_cell.y > 0, "Không tìm được footprint 2x2 cho bàn")
	build_grid.select_placeable("crafting_table")
	_assert(build_grid.place_selected_at_cell(table_cell), "Không đặt được bàn chế tạo")
	_assert(inventory.count_item("crafting_table") == 0, "Đặt bàn chưa trừ item")
	_assert(build_grid._placed_objects.size() == 1, "Bàn chưa thành placed object")
	var table: PlacedBuildObject = build_grid._placed_objects[0]
	_assert(table.get_interaction_prompt().contains("Bàn chế tạo"), "Bàn không có tương tác E")

	build_grid.set_build_mode_enabled(false)
	player.global_position = table.global_position + Vector3(-1.0, 0.05, 0.0)
	_assert(player._try_interact_nearest(), "Player không tương tác được với bàn bằng luồng E")
	_assert(ui.is_open, "Tương tác bàn không mở crafting UI")
	_assert(inventory.has_crafting_table_access(), "Bàn đặt ngoài map chưa cấp quyền crafting")
	ui.set_inventory_open(false)
	_assert(not inventory.has_crafting_table_access(), "Đóng UI vẫn giữ quyền bàn từ xa")

	_assert(build_grid._reclaim_object(table), "Không thu hồi được bàn")
	_assert(inventory.count_item("crafting_table") == 1, "Thu hồi bàn chưa hoàn item")

	var fire_cell := _find_valid_cell(build_grid, "campfire", Vector2i(10, 10))
	_assert(fire_cell.y > 0, "Không tìm được footprint cho bếp lửa")
	build_grid.select_placeable("campfire")
	_assert(build_grid.place_selected_at_cell(fire_cell), "Không đặt được bếp lửa")
	var campfire: PlacedBuildObject = build_grid._placed_objects[0]
	player.global_position = campfire.global_position + Vector3(-1.0, 0.05, 0.0)
	_assert(player._try_interact_nearest(), "Player không tương tác được với bếp lửa")
	_assert(not campfire.is_lit, "E chưa tắt được bếp lửa")
	build_grid.set_build_mode_enabled(true)
	var camera: Camera3D = world.get_node("CameraPivot/Camera3D")
	var fire_screen_position := camera.unproject_position(campfire.global_position + Vector3(0.5, 0.1, 0.5))
	_assert(build_grid.reclaim_at_mouse(fire_screen_position), "Chuột giữa/X không thu hồi được bếp lửa ngoài GridMap")
	_assert(inventory.count_item("campfire") == 1, "Thu hồi bếp lửa chưa hoàn item")

	var crusher_cell := _find_valid_cell(build_grid, "stone_crusher", Vector2i(13, 13))
	_assert(crusher_cell.y > 0, "Không tìm được footprint cho máy nghiền")
	build_grid.select_placeable("stone_crusher")
	_assert(build_grid.place_selected_at_cell(crusher_cell), "Không đặt được máy nghiền từ inventory")
	_assert(inventory.count_item("stone_crusher") == 0, "Đặt máy nghiền chưa trừ item")
	var crusher: PlacedBuildObject = build_grid._placed_objects[0]
	_assert(FactoryRecipeCatalog.is_machine(crusher.item_id), "Máy đặt ra chưa có logic factory")
	_assert(build_grid._reclaim_object(crusher), "Không thu hồi được máy nghiền")
	_assert(inventory.count_item("stone_crusher") == 1, "Thu hồi máy nghiền chưa hoàn item")

	print("BUILD_INVENTORY_TEST_OK block=%s table=%s fire=%s crusher=%s" % [block_cell, table_cell, fire_cell, crusher_cell])
	quit(0)


func _find_valid_cell(build_grid: BuildGrid, item_id: String, start: Vector2i) -> Vector3i:
	var data := PlaceableCatalog.get_placeable(item_id)
	for radius in range(0, 18):
		for z in range(start.y - radius, start.y + radius + 1):
			for x in range(start.x - radius, start.x + radius + 1):
				var surface := build_grid.terrain_generator.get_surface_cell(x, z)
				var candidate := surface + Vector3i.UP
				if build_grid._can_place(candidate, data):
					return candidate
	return Vector3i(-1, -1, -1)


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error("BUILD_INVENTORY_TEST_FAILED: %s" % message)
	quit(1)
