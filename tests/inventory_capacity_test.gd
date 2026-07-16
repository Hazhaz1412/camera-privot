extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var inventory := InventoryData.new()
	root.add_child(inventory)
	_assert(InventoryData.GRID_SIZE == Vector2i(16, 16), "Inventory không phải lưới 16x16")
	_assert(InventoryData.TOTAL_CELLS == 256, "Inventory không có 256 ô")

	# Que khô chiếm 1x2, nên 128 que phải lấp chính xác 256 ô.
	for index in range(128):
		_assert(inventory.try_add_item("stick"), "Không thêm được que thứ %d" % (index + 1))
	_assert(inventory.get_used_cell_count() == 256, "Túi đầy nhưng không báo 256/256 ô")
	_assert(not inventory.try_add_item("stick"), "Túi 256 ô vẫn nhận thêm vật phẩm")

	var first_item: Dictionary = inventory.get_items()[0]
	_assert(inventory.try_remove_item_by_uid(int(first_item["uid"])), "Không xóa được item theo uid")
	_assert(inventory.get_used_cell_count() == 254, "Xóa item 1x2 không giải phóng hai ô")
	_assert(inventory.try_add_item("stick"), "Không tái sử dụng được ô vừa giải phóng")

	print("INVENTORY_CAPACITY_TEST_OK items=%d cells=%d" % [
		inventory.get_items().size(),
		inventory.get_used_cell_count(),
	])
	quit(0)


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error("INVENTORY_CAPACITY_TEST_FAILED: %s" % message)
	quit(1)
