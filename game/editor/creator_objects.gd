class_name CreatorObjects
extends RefCounted
## Original fixed-size stamps; the same footprint is used in plans and native cells.

const KINDS: Array[String] = ["tree", "rock", "barrier", "dirt", "water"]

static func dimensions(kind: String) -> Vector2:
	match kind:
		"tree": return Vector2(3,3)
		"rock": return Vector2(2,2)
		"barrier": return Vector2(6,1)
		_: return Vector2(8,6)

static func surface(kind: String) -> int:
	match kind:
		"barrier": return 4
		"dirt": return 2
		"water": return 3
	return 7

static func description(kind: String) -> String:
	match kind:
		"tree": return "Low tree / slows the car"
		"rock": return "Low rock / slows the car"
		"barrier": return "Concrete barrier / blocks the car"
		"dirt": return "Dirt patch / goes under the road"
		_: return "Pond / blocks off-road driving"

static func contains(object: Dictionary, point: Vector2) -> bool:
	var center := Vector2(object.position[0],object.position[1])
	var local: Vector2 = (point-center).rotated(-deg_to_rad(float(object.rotation)))
	var half: Vector2 = dimensions(object.kind)*0.5
	if object.kind in ["tree","rock"]: return local.length_squared() <= half.x*half.x
	return absf(local.x) <= half.x and absf(local.y) <= half.y

static func outline(object: Dictionary) -> PackedVector2Array:
	var center := Vector2(object.position[0],object.position[1])
	var half: Vector2 = dimensions(object.kind)*0.5
	var result := PackedVector2Array()
	for p: Vector2 in [Vector2(-half.x,-half.y),Vector2(half.x,-half.y),half,Vector2(-half.x,half.y)]:
		result.append(center+p.rotated(deg_to_rad(float(object.rotation))))
	return result
