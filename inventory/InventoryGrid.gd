class_name InventoryGrid
extends Control

signal hovered_item_changed(item_id: String)
signal drop_item_requested(uid: int)

const CELL_SIZE := 28.0
const GRID_SIZE := InventoryData.GRID_SIZE
const GRID_PIXEL_SIZE := Vector2(CELL_SIZE * GRID_SIZE.x, CELL_SIZE * GRID_SIZE.y)

var inventory: InventoryData
var _dragged_uid := -1
var _drag_anchor := Vector2i.ZERO
var _drag_cell := Vector2i.ZERO
var _hovered_item_id := ""


func _ready() -> void:
	custom_minimum_size = GRID_PIXEL_SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	gui_input.connect(_on_gui_input)
	mouse_exited.connect(_on_mouse_exited)


func set_inventory(value: InventoryData) -> void:
	if inventory != null and inventory.inventory_changed.is_connected(_on_inventory_changed):
		inventory.inventory_changed.disconnect(_on_inventory_changed)
	inventory = value
	if inventory != null:
		inventory.inventory_changed.connect(_on_inventory_changed)
	queue_redraw()


func _draw() -> void:
	_draw_cells()
	if inventory == null:
		return

	for item: Dictionary in inventory.get_items():
		var uid := int(item["uid"])
		var alpha := 0.25 if uid == _dragged_uid else 1.0
		_draw_item(item, item["position"], alpha, false)

	if _dragged_uid >= 0:
		var dragged_item := _find_item(_dragged_uid)
		if not dragged_item.is_empty():
			var valid := inventory.can_place_item(_dragged_uid, _drag_cell)
			_draw_item(dragged_item, _drag_cell, 0.88, true, valid)


func _draw_cells() -> void:
	for y in range(GRID_SIZE.y):
		for x in range(GRID_SIZE.x):
			var rect := Rect2(Vector2(x, y) * CELL_SIZE + Vector2.ONE, Vector2.ONE * (CELL_SIZE - 2.0))
			draw_rect(rect, Color("25303a"), true)
			draw_rect(rect, Color("52606d"), false, 1.0)


func _draw_item(item: Dictionary, cell: Vector2i, alpha: float, is_ghost: bool, valid := true) -> void:
	var item_data := ItemCatalog.get_item(String(item["item_id"]))
	var item_size: Vector2i = item["size"]
	var rect := Rect2(
		Vector2(cell) * CELL_SIZE + Vector2(3.0, 3.0),
		Vector2(item_size) * CELL_SIZE - Vector2(6.0, 6.0)
	)
	var color: Color = item_data.get("color", Color.WHITE)
	if is_ghost:
		color = color.lerp(Color("69d17d") if valid else Color("e35d6a"), 0.55)
	color.a = alpha
	draw_rect(rect, color, true)
	draw_rect(rect, Color(1.0, 1.0, 1.0, alpha * 0.72), false, 2.0)

	var font := ThemeDB.fallback_font
	var font_size := 10
	var text := String(item_data.get("short_name", item["item_id"]))
	var text_position := rect.position + Vector2(2.0, 12.0)
	draw_string(font, text_position, text, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x - 4.0, font_size, Color(1, 1, 1, alpha))
	if item_size.y > 1 and rect.size.x >= 48.0:
		var weight_text := "%.1f kg" % float(item_data.get("weight", 0.0))
		draw_string(font, rect.end - Vector2(rect.size.x - 3.0, 4.0), weight_text, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 6.0, 9, Color(0.95, 0.95, 0.95, alpha))


func _on_gui_input(event: InputEvent) -> void:
	if inventory == null:
		return

	if event is InputEventMouseButton and event.button_index == MouseButton.MOUSE_BUTTON_LEFT:
		if event.pressed:
			_begin_drag(event.position)
		else:
			_end_drag()
		accept_event()
		return

	if event is InputEventMouseButton and event.button_index == MouseButton.MOUSE_BUTTON_RIGHT and event.pressed:
		var item := inventory.get_item_at(_position_to_cell(event.position))
		if not item.is_empty():
			drop_item_requested.emit(int(item["uid"]))
		accept_event()
		return

	if event is InputEventMouseMotion:
		_update_hover(event.position)
		if _dragged_uid >= 0:
			_drag_cell = _position_to_cell(event.position) - _drag_anchor
			queue_redraw()
		accept_event()


func _begin_drag(mouse_position: Vector2) -> void:
	var clicked_cell := _position_to_cell(mouse_position)
	var item := inventory.get_item_at(clicked_cell)
	if item.is_empty():
		return
	_dragged_uid = int(item["uid"])
	_drag_anchor = clicked_cell - Vector2i(item["position"])
	_drag_cell = Vector2i(item["position"])
	queue_redraw()


func _end_drag() -> void:
	if _dragged_uid < 0:
		return
	inventory.move_item(_dragged_uid, _drag_cell)
	_dragged_uid = -1
	queue_redraw()


func _update_hover(mouse_position: Vector2) -> void:
	var item := inventory.get_item_at(_position_to_cell(mouse_position))
	var item_id := "" if item.is_empty() else String(item["item_id"])
	if item_id == _hovered_item_id:
		return
	_hovered_item_id = item_id
	hovered_item_changed.emit(item_id)


func _on_mouse_exited() -> void:
	if _hovered_item_id.is_empty():
		return
	_hovered_item_id = ""
	hovered_item_changed.emit("")


func _on_inventory_changed() -> void:
	queue_redraw()


func _position_to_cell(position: Vector2) -> Vector2i:
	return Vector2i(floori(position.x / CELL_SIZE), floori(position.y / CELL_SIZE))


func _find_item(uid: int) -> Dictionary:
	for item: Dictionary in inventory.get_items():
		if int(item["uid"]) == uid:
			return item
	return {}
