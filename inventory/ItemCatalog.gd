class_name ItemCatalog
extends RefCounted

const ITEMS := {
	"stick": {
		"display_name": "Que khô",
		"short_name": "QUE",
		"size": Vector2i(1, 2),
		"weight": 0.3,
		"color": Color("b9824f"),
		"description": "Que nhỏ có thể dùng làm dụng cụ hoặc nhóm lửa.",
	},
	"vine": {
		"display_name": "Dây leo",
		"short_name": "DÂY",
		"size": Vector2i(2, 1),
		"weight": 0.2,
		"color": Color("5e9f55"),
		"description": "Sợi dây tự nhiên dùng để buộc và chế tạo.",
	},
	"stone": {
		"display_name": "Đá",
		"short_name": "ĐÁ",
		"size": Vector2i(2, 2),
		"weight": 2.5,
		"color": Color("7f8790"),
		"description": "Đá thô, nặng nhưng hữu ích để xây dựng.",
	},
	"wood": {
		"display_name": "Khúc gỗ",
		"short_name": "GỖ",
		"size": Vector2i(3, 2),
		"weight": 4.0,
		"color": Color("8c593b"),
		"description": "Tài nguyên cơ bản để xây và chế tạo.",
	},
	"coal": {
		"display_name": "Than đá",
		"short_name": "THAN",
		"size": Vector2i(1, 1),
		"weight": 1.1,
		"color": Color("34383d"),
		"description": "Nhiên liệu cơ bản cho lò nung. Dùng Cuốc đá để khai thác hiệu quả.",
	},
	"iron_ore": {
		"display_name": "Quặng sắt",
		"short_name": "Q.SẮT",
		"size": Vector2i(2, 2),
		"weight": 3.2,
		"color": Color("9a6855"),
		"description": "Quặng thô; cần nghiền rồi nung để tạo Thỏi sắt.",
	},
	"crushed_iron": {
		"display_name": "Quặng sắt nghiền",
		"short_name": "SẮT VỤN",
		"size": Vector2i(1, 1),
		"weight": 1.4,
		"color": Color("b77a62"),
		"description": "Quặng đã nghiền, là đầu vào của Lò nung.",
	},
	"iron_ingot": {
		"display_name": "Thỏi sắt",
		"short_name": "SẮT",
		"size": Vector2i(2, 1),
		"weight": 2.2,
		"color": Color("aeb8be"),
		"description": "Kim loại nền tảng để chế tạo linh kiện và máy móc.",
	},
	"iron_gear": {
		"display_name": "Bánh răng sắt",
		"short_name": "NHÔNG",
		"size": Vector2i(2, 2),
		"weight": 1.8,
		"color": Color("81909a"),
		"description": "Linh kiện cơ khí đầu tiên của dây chuyền factory.",
	},
	"rope": {
		"display_name": "Dây thừng",
		"short_name": "THỪNG",
		"size": Vector2i(1, 2),
		"weight": 0.35,
		"color": Color("c3a568"),
		"description": "Dây đã bện chắc, dùng trong nhiều công thức.",
	},
	"plank": {
		"display_name": "Ván gỗ",
		"short_name": "VÁN",
		"size": Vector2i(1, 2),
		"weight": 1.4,
		"color": Color("b87646"),
		"description": "Gỗ đã sơ chế, nhẹ và dễ lắp ghép.",
	},
	"campfire": {
		"display_name": "Bếp lửa",
		"short_name": "LỬA",
		"size": Vector2i(2, 2),
		"weight": 3.0,
		"color": Color("d96b38"),
		"description": "Bếp lửa đơn giản để sưởi và nấu ăn.",
	},
	"crafting_table": {
		"display_name": "Bàn chế tạo",
		"short_name": "BÀN",
		"size": Vector2i(3, 3),
		"weight": 8.0,
		"color": Color("76513b"),
		"description": "Có trong túi sẽ mở khóa công thức công cụ nâng cao.",
	},
	"stone_axe": {
		"display_name": "Rìu đá",
		"short_name": "RÌU",
		"size": Vector2i(2, 3),
		"weight": 2.8,
		"color": Color("718b91"),
		"description": "Nhấn F để trang bị, chuột trái gần gỗ/que để thu hoạch gấp đôi.",
	},
	"stone_pickaxe": {
		"display_name": "Cuốc đá",
		"short_name": "CUỐC",
		"size": Vector2i(3, 2),
		"weight": 3.4,
		"color": Color("657981"),
		"description": "Nhấn F để trang bị, chuột trái gần đá/than/quặng để khai thác gấp đôi.",
	},
	"stone_hammer": {
		"display_name": "Búa đá",
		"short_name": "BÚA",
		"size": Vector2i(2, 3),
		"weight": 3.1,
		"color": Color("846f68"),
		"description": "Bắt buộc để lắp máy factory; chuột trái gần máy để hỗ trợ tăng tốc.",
	},
	"stone_block": {
		"display_name": "Khối đá xây dựng",
		"short_name": "BLOCK",
		"size": Vector2i(2, 2),
		"weight": 2.2,
		"color": Color("8b8f8a"),
		"description": "Block chịu lực, có thể chọn và đặt trong Build Mode.",
	},
	"wooden_chest": {
		"display_name": "Kho gỗ",
		"short_name": "KHO",
		"size": Vector2i(3, 2),
		"weight": 7.0,
		"color": Color("8f633f"),
		"description": "Kho chứa 24 vật phẩm. E gửi đồ, Shift+E lấy đồ ra.",
	},
	"sawmill": {
		"display_name": "Máy cưa",
		"short_name": "CƯA",
		"size": Vector2i(3, 3),
		"weight": 12.0,
		"color": Color("8b6949"),
		"description": "Tự động biến 1 Khúc gỗ thành 3 Ván gỗ.",
	},
	"stone_crusher": {
		"display_name": "Máy nghiền đá",
		"short_name": "NGHIỀN",
		"size": Vector2i(3, 3),
		"weight": 16.0,
		"color": Color("68737a"),
		"description": "Tự động nghiền 1 Quặng sắt thành 2 Quặng sắt nghiền.",
	},
	"stone_furnace": {
		"display_name": "Lò nung đá",
		"short_name": "LÒ",
		"size": Vector2i(3, 3),
		"weight": 18.0,
		"color": Color("655e59"),
		"description": "Nung 2 Quặng sắt nghiền + 1 Than thành 1 Thỏi sắt.",
	},
}


static func has_item(item_id: String) -> bool:
	return ITEMS.has(item_id)


static func get_item(item_id: String) -> Dictionary:
	return ITEMS.get(item_id, {})


static func get_display_name(item_id: String) -> String:
	var data: Dictionary = get_item(item_id)
	return String(data.get("display_name", item_id))
