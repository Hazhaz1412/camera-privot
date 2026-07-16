class_name PlaceableCatalog
extends RefCounted

const PLACEABLES := {
	"stone_block": {
		"display_name": "Khối đá xây dựng",
		"kind": "grid_block",
		"mesh_library_item": 5,
		"footprint": Vector2i.ONE,
		"height": 1.0,
		"color": Color("8b8f8a"),
	},
	"campfire": {
		"display_name": "Bếp lửa",
		"kind": "object",
		"footprint": Vector2i(2, 2),
		"height": 0.75,
		"color": Color("d96b38"),
	},
	"crafting_table": {
		"display_name": "Bàn chế tạo",
		"kind": "object",
		"footprint": Vector2i(2, 2),
		"height": 1.15,
		"color": Color("76513b"),
	},
	"wooden_chest": {
		"display_name": "Kho gỗ",
		"kind": "object",
		"footprint": Vector2i(2, 2),
		"height": 1.0,
		"color": Color("8f633f"),
	},
	"sawmill": {
		"display_name": "Máy cưa",
		"kind": "object",
		"footprint": Vector2i(2, 2),
		"height": 1.2,
		"color": Color("8b6949"),
	},
	"stone_crusher": {
		"display_name": "Máy nghiền đá",
		"kind": "object",
		"footprint": Vector2i(2, 2),
		"height": 1.5,
		"color": Color("68737a"),
	},
	"stone_furnace": {
		"display_name": "Lò nung đá",
		"kind": "object",
		"footprint": Vector2i(2, 2),
		"height": 1.5,
		"color": Color("655e59"),
	},
}


static func is_placeable(item_id: String) -> bool:
	return PLACEABLES.has(item_id)


static func get_placeable(item_id: String) -> Dictionary:
	return PLACEABLES.get(item_id, {})


static func get_placeable_ids() -> Array:
	return PLACEABLES.keys()
