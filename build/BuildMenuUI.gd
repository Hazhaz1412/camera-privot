class_name BuildMenuUI
extends Node

@export var build_grid_path: NodePath = ^"../../BuildGrid"
@export var player_path: NodePath = ^"../../Player"

var build_grid: BuildGrid
var inventory: InventoryData
var panel: PanelContainer
var option_row: HFlowContainer
var status_label: Label
var buttons: Dictionary = {}


func _ready() -> void:
	build_grid = get_node_or_null(build_grid_path) as BuildGrid
	var player := get_node_or_null(player_path)
	if player != null:
		inventory = player.get_node_or_null("Inventory") as InventoryData
	_build_ui()
	if build_grid != null:
		build_grid.build_mode_changed.connect(_on_build_mode_changed)
		build_grid.build_selection_changed.connect(_refresh)
		build_grid.build_status_changed.connect(_on_build_status_changed)
	if inventory != null:
		inventory.inventory_changed.connect(_refresh)
	_refresh()


func _build_ui() -> void:
	panel = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	panel.position = Vector2(-390.0, -128.0)
	panel.custom_minimum_size = Vector2(780.0, 142.0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.07, 0.09, 0.92)
	style.border_color = Color("66808d")
	style.set_border_width_all(2)
	style.set_corner_radius_all(7)
	style.set_content_margin_all(10.0)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	panel.add_child(column)

	var title := Label.new()
	title.text = "BUILD MODE — Chọn vật phẩm trong túi"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 16)
	column.add_child(title)

	option_row = HFlowContainer.new()
	option_row.custom_minimum_size.x = 750.0
	option_row.alignment = FlowContainer.ALIGNMENT_CENTER
	option_row.add_theme_constant_override("h_separation", 8)
	option_row.add_theme_constant_override("v_separation", 6)
	column.add_child(option_row)

	status_label = Label.new()
	status_label.text = "Chuột trái: đặt  •  Chuột giữa / X: thu hồi  •  B: đóng"
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_color_override("font_color", Color("aebbc2"))
	column.add_child(status_label)
	panel.visible = false


func _refresh(_unused = null) -> void:
	if option_row == null:
		return
	for child in option_row.get_children():
		child.queue_free()
	buttons.clear()
	if inventory == null or build_grid == null:
		return

	var first_available := ""
	for item_id: String in PlaceableCatalog.get_placeable_ids():
		var count := inventory.count_item(item_id)
		if count <= 0:
			continue
		if first_available.is_empty():
			first_available = item_id
		var data := PlaceableCatalog.get_placeable(item_id)
		var button := Button.new()
		button.text = "%s ×%d" % [data.get("display_name", item_id), count]
		button.toggle_mode = true
		button.button_pressed = build_grid.selected_item_id == item_id
		button.pressed.connect(build_grid.select_placeable.bind(item_id))
		option_row.add_child(button)
		buttons[item_id] = button

	if buttons.is_empty():
		var empty_label := Label.new()
		empty_label.text = "Không có vật phẩm nào có thể đặt. Hãy chế tạo trước."
		empty_label.add_theme_color_override("font_color", Color("e09983"))
		option_row.add_child(empty_label)
		build_grid.select_placeable("")
	elif not buttons.has(build_grid.selected_item_id):
		build_grid.select_placeable(first_available)


func _on_build_mode_changed(enabled: bool) -> void:
	panel.visible = enabled
	if enabled:
		_refresh()


func _on_build_status_changed(message: String, success: bool) -> void:
	status_label.text = message
	status_label.add_theme_color_override("font_color", Color("7ed995") if success else Color("e58279"))
