class_name CreatorObjects
extends RefCounted
## Original fixed-size stamps; the same footprint is used in plans and native cells.

const KINDS: Array[String] = ["tree", "rock", "barrier", "tyre_wall", "fence", "dirt", "water"]

static func dimensions(kind: String) -> Vector2:
	match kind:
		"tree": return Vector2(3,3)
		"rock": return Vector2(2,2)
		"barrier": return Vector2(6,1)
		"tyre_wall": return Vector2(6,1)
		"fence": return Vector2(6,0.5)
		_: return Vector2(8,6)

static func surface(kind: String) -> int:
	match kind:
		"tree", "rock", "barrier", "tyre_wall", "fence": return 4
		"dirt": return 2
		"water": return 3
	return 7

static func description(kind: String) -> String:
	match kind:
		"tree": return "Tree / solid obstacle"
		"rock": return "Rock / solid obstacle"
		"barrier": return "Concrete barrier / blocks the car"
		"tyre_wall": return "Loose tyre stacks / move on impact"
		"fence": return "Timber fence / blocks the car"
		"dirt": return "Dirt patch / goes under the road"
		_: return "Pond / blocks off-road driving"

static func contains(object: Dictionary, point: Vector2) -> bool:
	var center := Vector2(object.position[0],object.position[1])
	var local: Vector2 = (point-center).rotated(-deg_to_rad(float(object.rotation)))
	var half: Vector2 = dimensions(object.kind)*0.5
	if object.kind in ["tree","rock"]: return local.length_squared() <= half.x*half.x
	# Cardinal rotations can move an exact cell-edge contact a few ulps
	# beyond the bound. Ten micrometres keeps thin fences continuous.
	return absf(local.x) <= half.x+0.00001 and absf(local.y) <= half.y+0.00001

static func outline(object: Dictionary) -> PackedVector2Array:
	var center := Vector2(object.position[0],object.position[1])
	var half: Vector2 = dimensions(object.kind)*0.5
	var result := PackedVector2Array()
	for p: Vector2 in [Vector2(-half.x,-half.y),Vector2(half.x,-half.y),half,Vector2(-half.x,half.y)]:
		result.append(center+p.rotated(deg_to_rad(float(object.rotation))))
	return result
