class_name CreatorObjects
extends RefCounted
## Original scalable stamps; the same footprint is used in plans and native cells.

const KINDS: Array[String] = ["tree", "rock", "barrier", "tyre_wall", "fence", "dirt", "water", "boulder", "slate", "cliff", "oil", "puddle", "jump"]

static func dimensions(kind: String) -> Vector2:
	match kind:
		"tree": return Vector2(3,3)
		"rock": return Vector2(2,2)
		"boulder": return Vector2(3,3)
		"slate": return Vector2(4,2)
		"cliff": return Vector2(8,3)
		"jump": return Vector2(6,5)
		"barrier": return Vector2(6,1)
		"tyre_wall": return Vector2(6,1)
		"fence": return Vector2(6,0.5)
		_: return Vector2(8,6)

static func size_of(object: Dictionary) -> Vector2:
	return dimensions(object.kind)*float(object.get("scale",1.0))


static func surface(kind: String) -> int:
	match kind:
		"tree", "rock", "boulder", "slate", "cliff", "barrier", "tyre_wall", "fence": return 4
		"oil", "jump": return 0
		"puddle": return 6
		"dirt": return 2
		"water": return 3
	return 7

static func description(kind: String) -> String:
	match kind:
		"tree": return "Tree / solid obstacle"
		"rock": return "Rock / solid obstacle"
		"boulder": return "Boulder / solid obstacle"
		"slate": return "Slate outcrop / solid obstacle"
		"cliff": return "Cliff / solid wall"
		"oil": return "Oil / reduced tyre grip"
		"puddle": return "Shallow water / drag and reduced grip"
		"jump": return "Jump / launches toward the arrow"
		"barrier": return "Concrete barrier / blocks the car"
		"tyre_wall": return "Loose tyre stacks / move on impact"
		"fence": return "Timber fence / blocks the car"
		"dirt": return "Dirt patch / goes under the road"
		_: return "Pond / blocks off-road driving"

static func contains(object: Dictionary, point: Vector2) -> bool:
	var center := Vector2(object.position[0],object.position[1])
	var local: Vector2 = (point-center).rotated(-deg_to_rad(float(object.rotation)))
	var half: Vector2 = size_of(object)*0.5
	if object.kind in ["oil","puddle"]: return (local/half).length() <= spill_radius((local/half).angle())
	if object.kind in ["tree","rock","boulder"]: return local.length_squared() <= half.x*half.x
	# Cardinal rotations can move an exact cell-edge contact a few ulps
	# beyond the bound. Ten micrometres keeps thin fences continuous.
	return absf(local.x) <= half.x+0.00001 and absf(local.y) <= half.y+0.00001

static func outline(object: Dictionary) -> PackedVector2Array:
	var center := Vector2(object.position[0],object.position[1])
	var half: Vector2 = size_of(object)*0.5
	var result := PackedVector2Array()
	for p: Vector2 in [Vector2(-half.x,-half.y),Vector2(half.x,-half.y),half,Vector2(-half.x,half.y)]:
		result.append(center+p.rotated(deg_to_rad(float(object.rotation))))
	return result


static func spill_radius(angle: float) -> float:
	return 0.93+0.04*sin(angle*3.0)+0.03*sin(angle*5.0)
