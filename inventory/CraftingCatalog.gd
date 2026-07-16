class_name CraftingCatalog
extends RefCounted

const RECIPES := {
	"rope": {
		"display_name": "Bện dây thừng",
		"output": {"rope": 1},
		"ingredients": {"vine": 2},
		"requires_table": false,
	},
	"plank": {
		"display_name": "Chẻ ván gỗ",
		"output": {"plank": 2},
		"ingredients": {"wood": 1},
		"requires_table": false,
	},
	"campfire": {
		"display_name": "Bếp lửa",
		"output": {"campfire": 1},
		"ingredients": {"stick": 3, "stone": 2},
		"requires_table": false,
	},
	"crafting_table": {
		"display_name": "Bàn chế tạo",
		"output": {"crafting_table": 1},
		"ingredients": {"plank": 4, "rope": 1, "stone": 1},
		"requires_table": false,
	},
	"stone_block": {
		"display_name": "Khối đá xây dựng",
		"output": {"stone_block": 2},
		"ingredients": {"stone": 1},
		"requires_table": false,
	},
	"stone_axe": {
		"display_name": "Rìu đá",
		"output": {"stone_axe": 1},
		"ingredients": {"stick": 2, "stone": 2, "rope": 1},
		"requires_table": true,
	},
	"stone_pickaxe": {
		"display_name": "Cuốc đá",
		"output": {"stone_pickaxe": 1},
		"ingredients": {"stick": 2, "stone": 3, "rope": 1},
		"requires_table": true,
	},
	"stone_hammer": {
		"display_name": "Búa đá",
		"output": {"stone_hammer": 1},
		"ingredients": {"stick": 1, "stone": 2, "rope": 1},
		"requires_table": true,
	},
	"wooden_chest": {
		"display_name": "Kho gỗ",
		"output": {"wooden_chest": 1},
		"ingredients": {"plank": 6, "rope": 2},
		"requires_table": true,
		"requires_tool": "stone_hammer",
	},
	"sawmill": {
		"display_name": "Máy cưa",
		"output": {"sawmill": 1},
		"ingredients": {"plank": 8, "stone": 3, "rope": 2},
		"requires_table": true,
		"requires_tool": "stone_hammer",
	},
	"stone_crusher": {
		"display_name": "Máy nghiền đá",
		"output": {"stone_crusher": 1},
		"ingredients": {"stone": 8, "plank": 4, "rope": 2},
		"requires_table": true,
		"requires_tool": "stone_hammer",
	},
	"stone_furnace": {
		"display_name": "Lò nung đá",
		"output": {"stone_furnace": 1},
		"ingredients": {"stone": 10, "plank": 2, "rope": 1},
		"requires_table": true,
		"requires_tool": "stone_hammer",
	},
	"iron_gear": {
		"display_name": "Bánh răng sắt",
		"output": {"iron_gear": 1},
		"ingredients": {"iron_ingot": 2},
		"requires_table": true,
		"requires_tool": "stone_hammer",
	},
}


static func get_recipe(recipe_id: String) -> Dictionary:
	return RECIPES.get(recipe_id, {})


static func get_recipe_ids() -> Array:
	return RECIPES.keys()


static func format_ingredients(recipe: Dictionary) -> String:
	var parts: PackedStringArray = []
	var ingredients: Dictionary = recipe.get("ingredients", {})
	for item_id: String in ingredients.keys():
		parts.append("%s ×%d" % [ItemCatalog.get_display_name(item_id), int(ingredients[item_id])])
	var requires_tool := String(recipe.get("requires_tool", ""))
	if not requires_tool.is_empty():
		parts.append("cần %s" % ItemCatalog.get_display_name(requires_tool))
	return ", ".join(parts)
