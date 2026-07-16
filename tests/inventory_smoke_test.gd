extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var main_scene := load("res://tiledmap/tscn/camera.tscn") as PackedScene
	_assert(main_scene != null, "Không load được main scene")
	var world := main_scene.instantiate()
	root.add_child(world)
	await process_frame
	await process_frame

	var inventory := world.get_node("Player/Inventory") as InventoryData
	_assert(inventory != null, "Player thiếu InventoryData")
	_assert(inventory.try_add_item("wood"), "Không thêm được gỗ vào túi trống")
	_assert(inventory.try_add_item("stone"), "Không thêm được đá vào túi")
	_assert(inventory.try_add_item("stick"), "Không thêm được que vào túi")
	_assert(inventory.get_used_cell_count() == 12, "Số ô đã dùng phải là 12")
	_assert(is_equal_approx(inventory.get_total_weight(), 6.8), "Tổng cân nặng phải là 6.8 kg")

	var stone := inventory.get_item_at(Vector2i(3, 0))
	_assert(not stone.is_empty(), "Không tìm thấy đá tại vị trí tự xếp")
	var stone_uid := int(stone["uid"])
	_assert(not inventory.move_item(stone_uid, Vector2i(1, 0)), "Không được cho vật phẩm chồng lên gỗ")
	_assert(inventory.move_item(stone_uid, Vector2i(14, 14)), "Phải chuyển được đá tới góc vừa khít")
	_assert(not inventory.move_item(stone_uid, Vector2i(15, 15)), "Không được cho vật phẩm vượt khỏi lưới")

	var inventory_ui := world.get_node("UI") as InventoryUI
	_assert(inventory_ui != null, "UI chưa gắn InventoryUI")
	_send_key(KEY_TAB)
	await process_frame
	_assert(inventory_ui.is_open and inventory_ui.overlay.visible, "Tab UI không mở được")
	_assert(inventory_ui.inventory_grid.size == InventoryGrid.GRID_PIXEL_SIZE, "Lưới không đúng kích thước 16x16")
	_assert(not inventory_ui.craft_buttons.is_empty(), "UI chưa hiển thị danh sách chế tạo")
	_send_key(KEY_TAB)
	await process_frame
	_assert(not inventory_ui.is_open and not inventory_ui.overlay.visible, "Tab lần hai không đóng được UI")

	var spawner := world.get_node("ResourceSpawner") as ResourceSpawner
	_assert(spawner != null, "Main scene thiếu ResourceSpawner")
	spawner._resolve_nodes()
	spawner._spawn_near_player()
	var active_pickups: Dictionary = spawner.get("_active_by_key")
	_assert(not active_pickups.is_empty(), "Spawner chưa tạo tài nguyên trên terrain")
	var player := world.get_node("Player")
	var pickup: WorldPickup = active_pickups.values()[0]
	pickup.global_position = player.global_position
	var item_count_before := inventory.get_items().size()
	var camera_pivot := world.get_node("CameraPivot")
	var yaw_before: float = camera_pivot.yaw_degrees
	var pitch_before: float = camera_pivot.pitch_degrees
	_send_key(KEY_E)
	await process_frame
	_assert(inventory.get_items().size() == item_count_before + 1, "Item nhặt lên chưa vào inventory")
	_assert(is_equal_approx(camera_pivot.yaw_degrees, yaw_before), "E vẫn còn xoay camera")
	_assert(is_equal_approx(camera_pivot.pitch_degrees, pitch_before), "E làm thay đổi góc nghiêng camera")

	var drop_item: Dictionary = inventory.get_items()[0]
	var drop_item_id := String(drop_item["item_id"])
	var count_before_drop := inventory.count_item(drop_item_id)
	var drop_result: Dictionary = player.drop_inventory_item(int(drop_item["uid"]))
	_assert(drop_result["success"], "Không vứt được item khỏi inventory")
	_assert(inventory.count_item(drop_item_id) == count_before_drop - 1, "Vứt item chưa trừ khỏi inventory")
	var dropped_pickup: WorldPickup = drop_result["pickup"]
	for candidate in get_nodes_in_group("world_pickup"):
		if candidate != dropped_pickup:
			candidate.global_position += Vector3(1000.0, 0.0, 1000.0)
	dropped_pickup.global_position = player.global_position
	_assert(player._try_pickup_nearest(), "Không nhặt lại được item vừa vứt")
	_assert(inventory.count_item(drop_item_id) == count_before_drop, "Nhặt lại item không hoàn đúng inventory")

	print("INVENTORY_SMOKE_TEST_OK pickups=%d" % active_pickups.size())
	quit(0)


func _send_key(keycode: Key) -> void:
	var pressed_event := InputEventKey.new()
	pressed_event.keycode = keycode
	pressed_event.physical_keycode = keycode
	pressed_event.pressed = true
	Input.parse_input_event(pressed_event)

	var released_event := pressed_event.duplicate() as InputEventKey
	released_event.pressed = false
	Input.parse_input_event(released_event)


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error("INVENTORY_SMOKE_TEST_FAILED: %s" % message)
	quit(1)
