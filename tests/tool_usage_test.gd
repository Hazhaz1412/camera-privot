extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := (load("res://tiledmap/tscn/camera.tscn") as PackedScene).instantiate()
	root.add_child(world)
	var player = world.get_node("Player")
	var inventory: InventoryData = player.get_node("Inventory")

	_assert(inventory.try_add_item("stone_pickaxe"), "Không thêm được cuốc")
	var ore := WorldPickup.new()
	world.add_child(ore)
	ore.setup("iron_ore", "tool-test-ore")
	ore.global_position = player.global_position + Vector3(0.5, 0.0, 0.0)
	player.active_tool_id = "stone_pickaxe"
	_assert(player._use_active_tool(), "Cuốc không xử lý thao tác")
	_assert(inventory.count_item("iron_ore") == 2, "Cuốc chưa khai thác quặng gấp đôi")

	_assert(inventory.try_add_item("stone_axe"), "Không thêm được rìu")
	var wood := WorldPickup.new()
	world.add_child(wood)
	wood.setup("wood", "tool-test-wood")
	wood.global_position = player.global_position + Vector3(0.6, 0.0, 0.0)
	player.active_tool_id = "stone_axe"
	_assert(player._use_active_tool(), "Rìu không xử lý thao tác")
	_assert(inventory.count_item("wood") == 2, "Rìu chưa thu hoạch gỗ gấp đôi")

	print("TOOL_USAGE_TEST_OK ore=%d wood=%d" % [
		inventory.count_item("iron_ore"),
		inventory.count_item("wood"),
	])
	quit(0)


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error("TOOL_USAGE_TEST_FAILED: %s" % message)
	quit(1)
