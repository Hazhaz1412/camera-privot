class_name InventoryUI
extends CanvasLayer

@export var player_path: NodePath = ^"../Player"

var player: Node
var inventory: InventoryData
var overlay: Control
var inventory_panel: PanelContainer
var inventory_grid: InventoryGrid
var weight_label: Label
var detail_label: Label
var pickup_prompt: Label
var crafting_status: Label
var crafting_hint: Label
var world_status_label: Label
var craft_buttons: Dictionary = {}
var is_open := false
var _world_message_until_msec := 0


func _ready() -> void:
	_resolve_player()
	_build_interface()
	set_process(true)
	set_process_input(true)


func _process(_delta: float) -> void:
	if player == null:
		_resolve_player()
	_update_pickup_prompt()
	_update_world_message()


func _input(event: InputEvent) -> void:
	if _is_inventory_toggle_event(event):
		set_inventory_open(not is_open)
		get_viewport().set_input_as_handled()
		return

	if is_open and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		set_inventory_open(false)
		get_viewport().set_input_as_handled()


func _is_inventory_toggle_event(event: InputEvent) -> bool:
	if not event is InputEventKey:
		return false
	if not event.pressed or event.echo:
		return false
	return (
		event.keycode == KEY_TAB
		or event.physical_keycode == KEY_TAB
		or event.is_action_pressed("toggle_inventory")
	)


func set_inventory_open(open: bool) -> void:
	is_open = open
	overlay.visible = is_open
	pickup_prompt.visible = not is_open and not pickup_prompt.text.is_empty()
	if player != null and player.has_method("set_inventory_open"):
		player.set_inventory_open(is_open)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if is_open else Input.MOUSE_MODE_HIDDEN
	if world_status_label != null:
		world_status_label.visible = false
	if is_open:
		inventory_grid.grab_focus()
	elif inventory != null:
		inventory.set_crafting_table_access(false)
	_update_inventory_summary()


func _resolve_player() -> void:
	player = get_node_or_null(player_path)
	if player == null:
		return
	inventory = player.get_node_or_null("Inventory") as InventoryData
	if inventory != null and not inventory.inventory_changed.is_connected(_update_inventory_summary):
		inventory.inventory_changed.connect(_update_inventory_summary)
	if inventory_grid != null:
		inventory_grid.set_inventory(inventory)


func _build_interface() -> void:
	overlay = Control.new()
	overlay.name = "InventoryOverlay"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)

	var dimmer := ColorRect.new()
	dimmer.color = Color(0.015, 0.025, 0.035, 0.78)
	dimmer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(dimmer)

	inventory_panel = PanelContainer.new()
	inventory_panel.custom_minimum_size = Vector2(980.0, 640.0)
	inventory_panel.set_anchors_preset(Control.PRESET_CENTER)
	inventory_panel.position = -inventory_panel.custom_minimum_size * 0.5
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color("17212b")
	panel_style.border_color = Color("6f8291")
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(8)
	panel_style.content_margin_left = 24.0
	panel_style.content_margin_right = 24.0
	panel_style.content_margin_top = 18.0
	panel_style.content_margin_bottom = 18.0
	inventory_panel.add_theme_stylebox_override("panel", panel_style)
	overlay.add_child(inventory_panel)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	inventory_panel.add_child(content)

	var title := Label.new()
	title.text = "TÚI ĐỒ — 256 Ô"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	content.add_child(title)

	weight_label = Label.new()
	weight_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	weight_label.add_theme_color_override("font_color", Color("b9c7d1"))
	content.add_child(weight_label)

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 24)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(body)

	var inventory_column := VBoxContainer.new()
	inventory_column.custom_minimum_size.x = InventoryGrid.GRID_PIXEL_SIZE.x
	inventory_column.add_theme_constant_override("separation", 8)
	body.add_child(inventory_column)

	inventory_grid = InventoryGrid.new()
	inventory_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	inventory_grid.hovered_item_changed.connect(_on_hovered_item_changed)
	inventory_grid.drop_item_requested.connect(_on_drop_item_requested)
	inventory_column.add_child(inventory_grid)
	inventory_grid.set_inventory(inventory)

	detail_label = Label.new()
	detail_label.custom_minimum_size.y = 52.0
	detail_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_label.add_theme_color_override("font_color", Color("d7e0e6"))
	inventory_column.add_child(detail_label)

	var separator := VSeparator.new()
	body.add_child(separator)
	_build_crafting_panel(body)

	var help := Label.new()
	help.text = "Kéo chuột trái: sắp xếp  •  Chuột phải: vứt đồ  •  Tab / Esc: đóng"
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.add_theme_font_size_override("font_size", 13)
	help.add_theme_color_override("font_color", Color("91a0ab"))
	content.add_child(help)

	pickup_prompt = Label.new()
	pickup_prompt.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	pickup_prompt.position = Vector2(-280.0, -92.0)
	pickup_prompt.size = Vector2(560.0, 64.0)
	pickup_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pickup_prompt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pickup_prompt.add_theme_font_size_override("font_size", 18)
	pickup_prompt.add_theme_color_override("font_color", Color.WHITE)
	pickup_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(pickup_prompt)

	world_status_label = Label.new()
	world_status_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	world_status_label.position = Vector2(-310.0, -156.0)
	world_status_label.size = Vector2(620.0, 42.0)
	world_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	world_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	world_status_label.add_theme_font_size_override("font_size", 17)
	world_status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	world_status_label.visible = false
	add_child(world_status_label)

	overlay.visible = false
	_update_inventory_summary()


func _build_crafting_panel(parent: Control) -> void:
	var crafting_column := VBoxContainer.new()
	crafting_column.custom_minimum_size = Vector2(410.0, 480.0)
	crafting_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	crafting_column.add_theme_constant_override("separation", 8)
	parent.add_child(crafting_column)

	var title := Label.new()
	title.text = "CHẾ TẠO"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	crafting_column.add_child(title)

	crafting_hint = Label.new()
	crafting_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	crafting_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	crafting_hint.add_theme_color_override("font_color", Color("d9bd78"))
	crafting_column.add_child(crafting_hint)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	crafting_column.add_child(scroll)

	var recipe_list := VBoxContainer.new()
	recipe_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	recipe_list.add_theme_constant_override("separation", 8)
	scroll.add_child(recipe_list)

	for recipe_id: String in CraftingCatalog.get_recipe_ids():
		var recipe := CraftingCatalog.get_recipe(recipe_id)
		var card := PanelContainer.new()
		var card_style := StyleBoxFlat.new()
		card_style.bg_color = Color("202d37")
		card_style.border_color = Color("455864")
		card_style.set_border_width_all(1)
		card_style.set_corner_radius_all(5)
		card_style.set_content_margin_all(8.0)
		card.add_theme_stylebox_override("panel", card_style)
		recipe_list.add_child(card)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		card.add_child(row)

		var description := Label.new()
		description.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		description.text = "%s%s\n%s" % [
			recipe.get("display_name", recipe_id),
			"  [BÀN]" if bool(recipe.get("requires_table", false)) else "",
			CraftingCatalog.format_ingredients(recipe),
		]
		row.add_child(description)

		var craft_button := Button.new()
		craft_button.text = "Chế tạo"
		craft_button.custom_minimum_size.x = 86.0
		craft_button.pressed.connect(_on_craft_pressed.bind(recipe_id))
		row.add_child(craft_button)
		craft_buttons[recipe_id] = craft_button

	crafting_status = Label.new()
	crafting_status.custom_minimum_size.y = 38.0
	crafting_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	crafting_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	crafting_column.add_child(crafting_status)


func _update_inventory_summary() -> void:
	if weight_label == null:
		return
	if inventory == null:
		weight_label.text = "0.0 kg  •  0 / 256 ô đã dùng"
		return
	weight_label.text = "%.1f kg  •  %d / 256 ô đã dùng" % [
		inventory.get_total_weight(),
		inventory.get_used_cell_count(),
	]
	_update_crafting_state()


func _update_crafting_state() -> void:
	if crafting_hint == null:
		return
	var has_table := inventory != null and inventory.has_crafting_table_access()
	if has_table:
		crafting_hint.text = "Đang dùng Bàn chế tạo — công cụ nâng cao đã mở khóa."
	elif inventory != null and inventory.count_item("crafting_table") > 0:
		crafting_hint.text = "Hãy đặt Bàn chế tạo trong Build Mode rồi đến gần nhấn E."
	else:
		crafting_hint.text = "Chế tạo và đặt Bàn chế tạo để mở khóa công cụ nâng cao."
	for recipe_id: String in craft_buttons.keys():
		var recipe := CraftingCatalog.get_recipe(recipe_id)
		var button: Button = craft_buttons[recipe_id]
		var table_locked := bool(recipe.get("requires_table", false)) and not has_table
		var required_tool := String(recipe.get("requires_tool", ""))
		var tool_locked := not required_tool.is_empty() and (inventory == null or inventory.count_item(required_tool) <= 0)
		button.disabled = inventory == null or not inventory.can_craft(recipe_id)
		button.text = "Cần bàn" if table_locked else "Cần búa" if tool_locked else "Chế tạo"


func open_at_crafting_table() -> void:
	if inventory != null:
		inventory.set_crafting_table_access(true)
	set_inventory_open(true)


func show_world_message(message: String, success := true) -> void:
	if crafting_status != null:
		crafting_status.text = message
		crafting_status.add_theme_color_override("font_color", Color("73d18a") if success else Color("e37b76"))
	if world_status_label != null and not is_open:
		world_status_label.text = message
		world_status_label.add_theme_color_override("font_color", Color("86e29a") if success else Color("f09085"))
		world_status_label.visible = true
		_world_message_until_msec = Time.get_ticks_msec() + 2600


func _update_world_message() -> void:
	if world_status_label == null or not world_status_label.visible:
		return
	if is_open or Time.get_ticks_msec() >= _world_message_until_msec:
		world_status_label.visible = false


func _on_craft_pressed(recipe_id: String) -> void:
	if inventory == null:
		return
	var result := inventory.try_craft(recipe_id)
	crafting_status.text = String(result.get("reason", ""))
	crafting_status.add_theme_color_override(
		"font_color",
		Color("73d18a") if bool(result.get("success", false)) else Color("e37b76")
	)


func _on_drop_item_requested(uid: int) -> void:
	if player == null or not player.has_method("drop_inventory_item"):
		return
	var result: Dictionary = player.drop_inventory_item(uid)
	crafting_status.text = String(result.get("reason", ""))
	crafting_status.add_theme_color_override(
		"font_color",
		Color("73d18a") if bool(result.get("success", false)) else Color("e37b76")
	)


func _on_hovered_item_changed(item_id: String) -> void:
	if item_id.is_empty():
		detail_label.text = ""
		return
	var data := ItemCatalog.get_item(item_id)
	var size: Vector2i = data.get("size", Vector2i.ONE)
	detail_label.text = "%s  •  %dx%d ô  •  %.1f kg\n%s" % [
		data.get("display_name", item_id),
		size.x,
		size.y,
		float(data.get("weight", 0.0)),
		data.get("description", ""),
	]


func _update_pickup_prompt() -> void:
	if pickup_prompt == null or player == null or is_open:
		if pickup_prompt != null:
			pickup_prompt.visible = false
		return
	if not player.has_method("get_interaction_prompt"):
		pickup_prompt.visible = false
		return
	var prompt := String(player.get_interaction_prompt())
	var tool_text := String(player.get_tool_hud_text()) if player.has_method("get_tool_hud_text") else ""
	var combined := prompt
	if not tool_text.is_empty():
		combined = "%s\n%s" % [prompt, tool_text] if not prompt.is_empty() else tool_text
	if combined.is_empty():
		pickup_prompt.text = ""
		pickup_prompt.visible = false
		return
	pickup_prompt.text = combined
	pickup_prompt.visible = true
