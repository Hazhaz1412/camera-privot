class_name InventoryData
extends Node

signal inventory_changed

const GRID_SIZE := Vector2i(16, 16)
const TOTAL_CELLS := GRID_SIZE.x * GRID_SIZE.y

var _items: Dictionary = {}
var _next_uid := 1
var crafting_table_access := false


func try_add_item(item_id: String) -> bool:
	var added := _try_add_item_internal(item_id)
	if added:
		inventory_changed.emit()
	return added


func _try_add_item_internal(item_id: String) -> bool:
	if not ItemCatalog.has_item(item_id):
		push_warning("Không tồn tại item: %s" % item_id)
		return false

	var size: Vector2i = ItemCatalog.get_item(item_id)["size"]
	var free_position := find_free_position(size)
	if free_position.x < 0:
		return false

	var uid := _next_uid
	_next_uid += 1
	_items[uid] = {
		"uid": uid,
		"item_id": item_id,
		"position": free_position,
		"size": size,
	}
	return true


func count_item(item_id: String) -> int:
	var count := 0
	for item: Dictionary in _items.values():
		if String(item["item_id"]) == item_id:
			count += 1
	return count


func try_remove_item(item_id: String) -> bool:
	for uid: int in _items.keys():
		if String(_items[uid]["item_id"]) != item_id:
			continue
		_items.erase(uid)
		inventory_changed.emit()
		return true
	return false


func try_remove_item_by_uid(uid: int) -> bool:
	if not _items.has(uid):
		return false
	_items.erase(uid)
	inventory_changed.emit()
	return true


func get_item_by_uid(uid: int) -> Dictionary:
	return _items.get(uid, {})


func set_crafting_table_access(enabled: bool) -> void:
	if crafting_table_access == enabled:
		return
	crafting_table_access = enabled
	inventory_changed.emit()


func has_crafting_table_access() -> bool:
	return crafting_table_access


func has_items(requirements: Dictionary) -> bool:
	for item_id: String in requirements.keys():
		if count_item(item_id) < int(requirements[item_id]):
			return false
	return true


func can_craft(recipe_id: String) -> bool:
	var recipe := CraftingCatalog.get_recipe(recipe_id)
	if recipe.is_empty():
		return false
	if bool(recipe.get("requires_table", false)) and not has_crafting_table_access():
		return false
	var required_tool := String(recipe.get("requires_tool", ""))
	if not required_tool.is_empty() and count_item(required_tool) <= 0:
		return false
	return has_items(recipe.get("ingredients", {}))


func try_craft(recipe_id: String) -> Dictionary:
	var recipe := CraftingCatalog.get_recipe(recipe_id)
	if recipe.is_empty():
		return {"success": false, "reason": "Công thức không tồn tại."}
	if bool(recipe.get("requires_table", false)) and not has_crafting_table_access():
		return {"success": false, "reason": "Cần có Bàn chế tạo trong túi."}
	var required_tool := String(recipe.get("requires_tool", ""))
	if not required_tool.is_empty() and count_item(required_tool) <= 0:
		return {"success": false, "reason": "Cần có %s trong túi." % ItemCatalog.get_display_name(required_tool)}
	var ingredients: Dictionary = recipe.get("ingredients", {})
	if not has_items(ingredients):
		return {"success": false, "reason": "Chưa đủ nguyên liệu."}

	var previous_items := _items.duplicate(true)
	var previous_next_uid := _next_uid
	_remove_items_internal(ingredients)
	var outputs: Dictionary = recipe.get("output", {})
	for item_id: String in outputs.keys():
		for _index in range(int(outputs[item_id])):
			if not _try_add_item_internal(item_id):
				_items = previous_items
				_next_uid = previous_next_uid
				return {"success": false, "reason": "Túi không đủ chỗ cho sản phẩm."}

	inventory_changed.emit()
	return {"success": true, "reason": "Đã chế tạo %s." % recipe.get("display_name", recipe_id)}


func try_add_items(items: Dictionary) -> bool:
	var previous_items := _items.duplicate(true)
	var previous_next_uid := _next_uid
	for item_id: String in items.keys():
		for _index in range(int(items[item_id])):
			if not _try_add_item_internal(item_id):
				_items = previous_items
				_next_uid = previous_next_uid
				return false
	inventory_changed.emit()
	return true


func try_remove_items(requirements: Dictionary) -> bool:
	if not has_items(requirements):
		return false
	_remove_items_internal(requirements)
	inventory_changed.emit()
	return true


func _remove_items_internal(requirements: Dictionary) -> void:
	for item_id: String in requirements.keys():
		var remaining := int(requirements[item_id])
		for uid: int in _items.keys().duplicate():
			if remaining <= 0:
				break
			if String(_items[uid]["item_id"]) != item_id:
				continue
			_items.erase(uid)
			remaining -= 1


func move_item(uid: int, new_position: Vector2i) -> bool:
	if not _items.has(uid):
		return false
	if not can_place_item(uid, new_position):
		return false

	_items[uid]["position"] = new_position
	inventory_changed.emit()
	return true


func can_place_item(uid: int, position: Vector2i) -> bool:
	if not _items.has(uid):
		return false
	var size: Vector2i = _items[uid]["size"]
	return _is_area_free(position, size, uid)


func find_free_position(size: Vector2i) -> Vector2i:
	for y in range(GRID_SIZE.y - size.y + 1):
		for x in range(GRID_SIZE.x - size.x + 1):
			var candidate := Vector2i(x, y)
			if _is_area_free(candidate, size):
				return candidate
	return Vector2i(-1, -1)


func get_item_at(cell: Vector2i) -> Dictionary:
	for item: Dictionary in _items.values():
		var position: Vector2i = item["position"]
		var size: Vector2i = item["size"]
		if cell.x >= position.x and cell.y >= position.y:
			if cell.x < position.x + size.x and cell.y < position.y + size.y:
				return item
	return {}


func get_items() -> Array:
	return _items.values()


func get_total_weight() -> float:
	var total := 0.0
	for item: Dictionary in _items.values():
		var item_data := ItemCatalog.get_item(String(item["item_id"]))
		total += float(item_data.get("weight", 0.0))
	return total


func get_used_cell_count() -> int:
	var used := 0
	for item: Dictionary in _items.values():
		var size: Vector2i = item["size"]
		used += size.x * size.y
	return used


func _is_area_free(position: Vector2i, size: Vector2i, ignored_uid := -1) -> bool:
	if position.x < 0 or position.y < 0:
		return false
	if position.x + size.x > GRID_SIZE.x or position.y + size.y > GRID_SIZE.y:
		return false

	for item: Dictionary in _items.values():
		if int(item["uid"]) == ignored_uid:
			continue
		var other_position: Vector2i = item["position"]
		var other_size: Vector2i = item["size"]
		if _rects_overlap(position, size, other_position, other_size):
			return false
	return true


func _rects_overlap(a_position: Vector2i, a_size: Vector2i, b_position: Vector2i, b_size: Vector2i) -> bool:
	return (
		a_position.x < b_position.x + b_size.x
		and a_position.x + a_size.x > b_position.x
		and a_position.y < b_position.y + b_size.y
		and a_position.y + a_size.y > b_position.y
	)
