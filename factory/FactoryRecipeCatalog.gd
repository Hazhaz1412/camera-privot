class_name FactoryRecipeCatalog
extends RefCounted

const RECIPES := {
	"sawmill": {
		"display_name": "Cưa ván",
		"inputs": {"wood": 1},
		"outputs": {"plank": 3},
		"duration": 2.0,
	},
	"stone_crusher": {
		"display_name": "Nghiền quặng sắt",
		"inputs": {"iron_ore": 1},
		"outputs": {"crushed_iron": 2},
		"duration": 3.0,
	},
	"stone_furnace": {
		"display_name": "Luyện thỏi sắt",
		"inputs": {"crushed_iron": 2, "coal": 1},
		"outputs": {"iron_ingot": 1},
		"duration": 5.0,
	},
}


static func is_machine(item_id: String) -> bool:
	return RECIPES.has(item_id)


static func get_recipe(item_id: String) -> Dictionary:
	return RECIPES.get(item_id, {})


static func format_items(items: Dictionary) -> String:
	var parts: PackedStringArray = []
	for item_id: String in items.keys():
		parts.append("%s ×%d" % [ItemCatalog.get_display_name(item_id), int(items[item_id])])
	return ", ".join(parts)
