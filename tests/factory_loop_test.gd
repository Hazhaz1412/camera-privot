extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var player := Node3D.new()
	player.name = "Player"
	root.add_child(player)
	var inventory := InventoryData.new()
	inventory.name = "Inventory"
	player.add_child(inventory)

	_assert(inventory.try_add_item("iron_ore"), "Không thêm được quặng sắt")
	var crusher := PlacedBuildObject.new()
	crusher.setup("stone_crusher", Vector3i.ZERO, Vector2i(2, 2))
	root.add_child(crusher)
	crusher.interact(player)
	_assert(crusher.factory_processing, "Máy nghiền chưa bắt đầu chạy")
	_assert(inventory.count_item("iron_ore") == 0, "Máy nghiền chưa lấy đầu vào")
	crusher.advance_factory_time(3.0)
	_assert(not crusher.factory_processing, "Máy nghiền chưa hoàn tất")
	_assert(crusher.factory_outputs.get("crushed_iron", 0) == 2, "Máy nghiền cho sai sản lượng")
	crusher.interact(player)
	_assert(inventory.count_item("crushed_iron") == 2, "Không lấy được quặng nghiền")

	_assert(inventory.try_add_item("coal"), "Không thêm được than")
	var furnace := PlacedBuildObject.new()
	furnace.setup("stone_furnace", Vector3i(3, 0, 0), Vector2i(2, 2))
	root.add_child(furnace)
	furnace.interact(player)
	_assert(furnace.factory_processing, "Lò nung chưa bắt đầu chạy")
	_assert(furnace.apply_hammer_boost(1.25), "Búa không tăng tốc được máy")
	_assert(furnace.factory_progress >= 1.25, "Tiến độ máy không tăng sau khi dùng búa")
	furnace.advance_factory_time(3.75)
	furnace.interact(player)
	_assert(inventory.count_item("iron_ingot") == 1, "Dây chuyền chưa tạo được thỏi sắt")

	_assert(inventory.try_add_item("wood"), "Không thêm được gỗ để test kho")
	var chest := PlacedBuildObject.new()
	chest.setup("wooden_chest", Vector3i(6, 0, 0), Vector2i(2, 2))
	root.add_child(chest)
	chest.interact(player)
	_assert(_count_items(chest.chest_contents) == 1, "Kho chưa nhận vật phẩm")
	chest.interact(player, true)
	_assert(chest.chest_contents.is_empty(), "Shift+E chưa làm trống kho")
	_assert(inventory.count_item("wood") == 1, "Shift+E chưa lấy vật phẩm khỏi kho")

	print("FACTORY_LOOP_TEST_OK crushed=2 ingot=%d chest=%d" % [
		inventory.count_item("iron_ingot"),
		chest.chest_contents.size(),
	])
	quit(0)


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error("FACTORY_LOOP_TEST_FAILED: %s" % message)
	quit(1)


func _count_items(items: Dictionary) -> int:
	var total := 0
	for count in items.values():
		total += int(count)
	return total
