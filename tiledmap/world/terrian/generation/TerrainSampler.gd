class_name TerrainSampler
extends RefCounted

enum AnimalType {
	NONE,
	RABBIT,
	COW,
	FROG,
	GOAT,
	CHICKEN,
	SHEEP,
	PIG,
}
enum TreeType {
	OAK,
	OAK2,
	OAK3,
}

const RANDOM_TREE := 303
const RANDOM_TREE_PRIORITY := 306
const RANDOM_ANIMAL := 304
const RANDOM_ANIMAL_TYPE := 305
const MAX_CACHE_ENTRIES := 32768

var _cfg: TerrainConfig
var _noise: TerrainNoise
var _profile: TerrainProfile
var _sample_cache: Dictionary = {}


func setup(
	cfg: TerrainConfig,
	noise: TerrainNoise,
	profile: TerrainProfile
) -> void:

	_cfg = cfg
	_noise = noise
	_profile = profile
	_sample_cache.clear()


func clear_cache() -> void:
	_sample_cache.clear()


func sample_terrain(world_x: int, world_z: int) -> Dictionary:
	var cache_key := Vector2i(world_x, world_z)
	if _sample_cache.has(cache_key):
		return _sample_cache[cache_key]

	var profile := _profile.get_terrain_profile(world_x, world_z)
	var biome := _get_biome(world_x, world_z, profile)
	
	var surface_y := _profile.sample_surface_height(
		world_x,
		world_z,
		profile
	)

	var moisture := (
		_noise.moisture_noise.get_noise_2d(world_x, world_z) + 1.0
	) * 0.5

	var lake_value := (
		_noise.lake_noise.get_noise_2d(world_x, world_z) + 1.0
	) * 0.5

	var tree_density := (
		_noise.tree_density_noise.get_noise_2d(world_x, world_z) + 1.0
	) * 0.5

	var animal_density := (
		_noise.animal_density_noise.get_noise_2d(world_x, world_z) + 1.0
	) * 0.5
	
	var tree_type := TreeType.OAK
	match biome:
		"forest":
			tree_type = TreeType.OAK
		"plains":
			tree_type = TreeType.OAK2
		"swamp":
			tree_type = TreeType.OAK3
		"rocky":
			tree_type = TreeType.OAK

	var tree_roll := TerrainUtils.random_01(
		world_x,
		world_z,
		RANDOM_TREE,
		_cfg.generation_seed
	)

	var animal_roll := TerrainUtils.random_01(
		world_x,
		world_z,
		RANDOM_ANIMAL,
		_cfg.generation_seed
	)

	var animal_type_roll := TerrainUtils.random_01(
		world_x,
		world_z,
		RANDOM_ANIMAL_TYPE,
		_cfg.generation_seed
	)

	var is_spawn_area := (
		Vector2(world_x, world_z).length()
		< float(_cfg.spawn_protection_radius)
	)

	var has_lake_basin := (
		not is_spawn_area
		and profile != "cliff"
		and lake_value < _cfg.lake_threshold
	)

	var has_water := (
		has_lake_basin
		or (
			not is_spawn_area
			and profile != "flat"
			and surface_y < _cfg.water_level
		)
	)

	var surface_item := _cfg.grass_item
	
	if has_water:
		surface_y = maxi(0, _cfg.water_level - 1)
		surface_item = _cfg.dirt_item

	elif surface_y >= _cfg.mountain_level or biome == "rocky":

		surface_item = _cfg.stone_item

	elif moisture < _cfg.dirt_surface_chance:

		surface_item = _cfg.dirt_item


	# -----------------------------------------------------------------
	# Tree
	# -----------------------------------------------------------------

	var has_tree := (
		not is_spawn_area
		and not has_water
		and surface_item == _cfg.grass_item
		and surface_y < _cfg.mountain_level
		and _should_spawn_tree(world_x, world_z, biome, tree_density, tree_roll)
	)


	# -----------------------------------------------------------------
	# Animal
	# -----------------------------------------------------------------

	var animal_type := AnimalType.NONE
	var has_animal := false

# Spawn đúng 1 con tại (2,2)
	if world_x == 2 and world_z == 2:

		has_animal = true
		animal_type = AnimalType.COW

	else:

		has_animal = (
			not is_spawn_area
			and not has_water
			and surface_item == _cfg.grass_item
			and animal_roll < _get_animal_threshold_flat()
			and animal_density > 0.55
		)

	if has_animal and animal_type == AnimalType.NONE:
		animal_type = _pick_animal_type(animal_type_roll)

	var result := {
		"surface_y": surface_y,
		"surface_item": surface_item,
		"has_water": has_water,
		"has_tree": has_tree,
		"has_animal": has_animal,
		"tree_type": tree_type,
		"animal_type": animal_type,
		"biome": biome,
		"profile": profile,
	}
	if _sample_cache.size() >= MAX_CACHE_ENTRIES:
		_sample_cache.clear()
	_sample_cache[cache_key] = result
	return result
	
	
func _get_biome(
	world_x: int,
	world_z: int,
	profile: String
) -> String:

	if profile == "cliff":
		return "rocky"

	var moisture := (
		_noise.moisture_noise.get_noise_2d(world_x, world_z) + 1.0
	) * 0.5

	var biome_value := (
		_noise.biome_noise.get_noise_2d(world_x, world_z) + 1.0
	) * 0.5

	if moisture > 0.66 and biome_value > 0.42:
		return "forest"

	if moisture > 0.58 and biome_value <= 0.42:
		return "swamp"

	if moisture < 0.22:
		return "rocky"

	return "plains"


func _should_spawn_tree(world_x: int, world_z: int, biome: String, density: float, tree_roll: float) -> bool:
	var gate := 0.56
	var max_chance := 0.30
	match biome:
		"forest":
			gate = 0.50
			max_chance = 0.34
		"swamp":
			gate = 0.60
			max_chance = 0.19
		"plains":
			gate = 0.70
			max_chance = 0.10
		"rocky":
			return false

	if density <= gate:
		return false
	var chance := lerpf(0.035, max_chance, smoothstep(gate, 0.88, density))
	if tree_roll >= chance:
		return false

	# Chọn điểm có priority thấp nhất trong các candidate lân cận để cây không dính thành lưới dày.
	var priority := TerrainUtils.random_01(world_x, world_z, RANDOM_TREE_PRIORITY, _cfg.generation_seed)
	for z_offset in range(-1, 2):
		for x_offset in range(-1, 2):
			if x_offset == 0 and z_offset == 0:
				continue
			var neighbor_x := world_x + x_offset
			var neighbor_z := world_z + z_offset
			var neighbor_density := (_noise.tree_density_noise.get_noise_2d(neighbor_x, neighbor_z) + 1.0) * 0.5
			if neighbor_density <= gate:
				continue
			var neighbor_chance := lerpf(0.035, max_chance, smoothstep(gate, 0.88, neighbor_density))
			var neighbor_roll := TerrainUtils.random_01(neighbor_x, neighbor_z, RANDOM_TREE, _cfg.generation_seed)
			if neighbor_roll >= neighbor_chance:
				continue
			var neighbor_priority := TerrainUtils.random_01(neighbor_x, neighbor_z, RANDOM_TREE_PRIORITY, _cfg.generation_seed)
			if neighbor_priority < priority:
				return false
	return true


func _get_animal_threshold_flat() -> float:
	return 0.025


func _pick_animal_type(roll: float) -> AnimalType:
	# Tỉ lệ cố định, không phụ thuộc biome:
	# chicken 30%, sheep 25%, cow 25%, pig 20%
	if roll < 0.30:
		return AnimalType.CHICKEN
	elif roll < 0.55:
		return AnimalType.SHEEP
	elif roll < 0.80:
		return AnimalType.COW
	else:
		return AnimalType.PIG
