extends RefCounted
## Editor-only picking and group transforms. Authored objects retain their schema.
static func candidates(objects: Array, point: Vector2, world_point: Vector2, project: Callable) -> Array[int]:
	var hits: Array[Dictionary] = []
	for index: int in range(objects.size()):
		var object: Dictionary = objects[index]
		var distance: float = Vector2(project.call(Vector2(object.position[0],object.position[1]))).distance_to(point)
		var inside: bool = CreatorObjects.contains(object,world_point)
		if inside or distance <= 30.0: hits.append({"index":index,"distance":distance,"inside":inside})
	hits.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a.inside != b.inside: return a.inside
		if not is_equal_approx(a.distance,b.distance): return a.distance < b.distance
		return a.index > b.index)
	var result: Array[int] = []
	for hit: Dictionary in hits: result.append(hit.index)
	return result

static func bounded_delta(objects: Array, indices: Array[int], delta: Vector2) -> Vector2:
	var low := Vector2(-INF,-INF); var high := Vector2(INF,INF)
	for index: int in indices:
		var p := Vector2(objects[index].position[0],objects[index].position[1])
		low = low.max(Vector2(-110,-110)-p); high = high.min(Vector2(110,110)-p)
	return delta.clamp(low,high)

static func moved(objects: Array, indices: Array[int], delta: Vector2) -> Array:
	var result: Array = objects.duplicate()
	delta = bounded_delta(objects,indices,delta)
	for index: int in indices:
		var object: Dictionary = objects[index].duplicate(true)
		object.position = [float(object.position[0])+delta.x,float(object.position[1])+delta.y]
		result[index] = object
	return result

static func rotated(objects: Array, indices: Array[int], degrees: float) -> Array:
	var result: Array = objects.duplicate()
	var center := Vector2.ZERO
	for index: int in indices: center += Vector2(objects[index].position[0],objects[index].position[1])
	center /= maxi(1,indices.size())
	for index: int in indices:
		var object: Dictionary = objects[index].duplicate(true)
		var position: Vector2 = center+(Vector2(object.position[0],object.position[1])-center).rotated(deg_to_rad(degrees))
		if position.abs().x > 110.0 or position.abs().y > 110.0: return []
		object.position = [position.x,position.y]
		object.rotation = fposmod(float(object.rotation)+degrees,360.0)
		result[index] = object
	return result
