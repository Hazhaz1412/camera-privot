extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var inventory := InventoryData.new()
	root.add_child(inventory)
	_assert(not inventory.can_craft("stone_axe"), "Rìu phải bị khóa khi chưa có bàn")

	for _index in range(2):
		_assert(inventory.try_add_item("wood"), "Không thêm được gỗ")
	for _index in range(4):
		_assert(inventory.try_add_item("vine"), "Không thêm được dây leo")
	for _index in range(3):
		_assert(inventory.try_add_item("stone"), "Không thêm được đá")
	for _index in range(2):
		_assert(inventory.try_add_item("stick"), "Không thêm được que")

	_assert(inventory.try_craft("plank")["success"], "Không chế tạo được lượt ván thứ nhất")
	_assert(inventory.try_craft("plank")["success"], "Không chế tạo được lượt ván thứ hai")
	_assert(inventory.count_item("plank") == 4, "Hai khúc gỗ phải cho 4 ván")
	_assert(inventory.try_craft("rope")["success"], "Không bện được dây cho bàn")
	_assert(inventory.try_craft("rope")["success"], "Không bện được dây cho công cụ")
	_assert(inventory.try_craft("crafting_table")["success"], "Không chế tạo được bàn")
	_assert(inventory.count_item("crafting_table") == 1, "Bàn chế tạo chưa vào túi")
	_assert(not inventory.can_craft("stone_axe"), "Bàn còn trong túi nhưng đã mở khóa công cụ")
	inventory.set_crafting_table_access(true)
	_assert(inventory.can_craft("stone_axe"), "Có bàn và đủ đồ nhưng rìu vẫn bị khóa")
	_assert(inventory.try_craft("stone_axe")["success"], "Không chế tạo được rìu đá")
	_assert(inventory.count_item("stone_axe") == 1, "Rìu đá chưa vào túi")
	_assert(inventory.count_item("crafting_table") == 1, "Bàn không được bị tiêu hao")

	print("CRAFTING_TEST_OK items=%d cells=%d weight=%.2f" % [
		inventory.get_items().size(),
		inventory.get_used_cell_count(),
		inventory.get_total_weight(),
	])
	quit(0)


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error("CRAFTING_TEST_FAILED: %s" % message)
	quit(1)
