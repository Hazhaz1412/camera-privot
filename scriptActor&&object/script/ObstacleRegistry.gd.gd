class_name ObstacleRegistry
extends RefCounted

const BUCKET_SIZE := 4.0

static var _obstacles: Dictionary = {}       # instance_id -> {"position": Vector3, "radius": float, "bucket": Vector2i}
static var _buckets: Dictionary = {}          # Vector2i -> Dictionary[instance_id -> true]


static func _bucket_for(position: Vector3) -> Vector2i:
	return Vector2i(
		floori(position.x / BUCKET_SIZE),
		floori(position.z / BUCKET_SIZE)
	)


static func register(id: int, position: Vector3, radius: float) -> void:
	var bucket := _bucket_for(position)
	_obstacles[id] = {
		"position": position,
		"radius": radius,
		"bucket": bucket,
	}
	_add_to_bucket(bucket, id)


static func update_position(id: int, position: Vector3) -> void:
	if not _obstacles.has(id):
		return

	var entry: Dictionary = _obstacles[id]
	var new_bucket := _bucket_for(position)
	var old_bucket: Vector2i = entry["bucket"]

	if new_bucket != old_bucket:
		_remove_from_bucket(old_bucket, id)
		_add_to_bucket(new_bucket, id)
		entry["bucket"] = new_bucket

	entry["position"] = position


static func unregister(id: int) -> void:
	if not _obstacles.has(id):
		return

	var entry: Dictionary = _obstacles[id]
	_remove_from_bucket(entry["bucket"], id)
	_obstacles.erase(id)


static func get_blocking_obstacle(
	position: Vector3,
	own_radius: float,
	exclude_id: int
) -> bool:
	var center_bucket := _bucket_for(position)

	for x_offset in range(-1, 2):
		for z_offset in range(-1, 2):
			var bucket := Vector2i(center_bucket.x + x_offset, center_bucket.y + z_offset)
			if not _buckets.has(bucket):
				continue

			for id in _buckets[bucket].keys():
				if id == exclude_id:
					continue

				var obstacle: Dictionary = _obstacles[id]
				var other_position: Vector3 = obstacle["position"]
				var other_radius: float = obstacle["radius"]

				var dx := position.x - other_position.x
				var dz := position.z - other_position.z
				var distance_squared := dx * dx + dz * dz
				var min_distance := own_radius + other_radius

				if distance_squared < min_distance * min_distance:
					return true

	return false


static func _add_to_bucket(bucket: Vector2i, id: int) -> void:
	if not _buckets.has(bucket):
		_buckets[bucket] = {}
	_buckets[bucket][id] = true


static func _remove_from_bucket(bucket: Vector2i, id: int) -> void:
	if not _buckets.has(bucket):
		return
	_buckets[bucket].erase(id)
	if _buckets[bucket].is_empty():
		_buckets.erase(bucket)
