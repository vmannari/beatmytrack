class_name CreatorObjects
extends RefCounted
## Original scalable stamps; the same footprint is used in plans and native cells.

const KINDS: Array[String] = ["tree", "rock", "barrier", "tyre_wall", "fence", "dirt", "water", "boulder", "slate", "cliff", "oil", "puddle", "jump", "speed_bump", "tyre_stack", "broadleaf", "bush", "grass_clump", "flowers", "pebbles", "log", "guardrail", "wire_fence", "cone", "chevron", "braking_board", "banner", "flag", "light", "gantry", "crate", "barrel", "pallet", "parked_car", "van", "car_wreck", "container", "shed", "hut", "grandstand"]

static func dimensions(kind: String) -> Vector2:
	match kind:
		"speed_bump": return Vector2(2.0,8.0)
		"tyre_stack": return Vector2(1,1)
		"broadleaf": return Vector2(4,4)
		"bush": return Vector2(2,2)
		"grass_clump", "flowers", "pebbles", "cone", "light": return Vector2(1,1)
		"log": return Vector2(4,0.8)
		"guardrail", "wire_fence": return Vector2(6,0.5)
		"chevron", "braking_board": return Vector2(1.5,0.5)
		"banner": return Vector2(4,0.6)
		"flag": return Vector2(1,1)
		"gantry": return Vector2(12,1)
		"crate", "barrel": return Vector2(1.2,1.2)
		"pallet": return Vector2(2,1.4)
		"parked_car", "car_wreck": return Vector2(4.2,1.8)
		"van": return Vector2(5,2)
		"container": return Vector2(6,2.5)
		"shed": return Vector2(7,5)
		"hut": return Vector2(2.5,2.5)
		"grandstand": return Vector2(8,4)
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
	var size: Vector2 = dimensions(object.kind)*float(object.get("scale",1.0))
	if object.kind == "speed_bump": size.y = float(object.get("span",size.y))
	if object.kind in ObjectRuns.CONTINUOUS: size.x = float(object.get("length",size.x))
	return size


static func surface(kind: String) -> int:
	if kind == "speed_bump": return 0
	if not CreatorCatalog.family(kind).is_empty(): return 0 if kind in CreatorCatalog.DECORATIVE or kind in CreatorCatalog.SOFT else 4
	match kind:
		"tree", "rock", "boulder", "slate", "cliff", "barrier", "tyre_wall", "fence": return 4
		"oil", "jump": return 0
		"puddle": return 6
		"dirt": return 2
		"water": return 3
	return 7

static func description(kind: String) -> String:
	if not CreatorCatalog.family(kind).is_empty(): return CreatorCatalog.label(kind)+" / "+CreatorCatalog.behavior(kind)
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

static func solid_contains(object: Dictionary, point: Vector2) -> bool:
	var local: Vector2 = (point-Vector2(object.position[0],object.position[1])).rotated(-deg_to_rad(float(object.rotation)))
	var scale: float = float(object.get("scale",1.0))
	if object.kind in ["tree","broadleaf"]: return local.length()<=maxf(0.36,0.4*scale)
	if object.kind == "light": return local.length()<=maxf(0.36,0.22*scale)
	if object.kind == "gantry": return absf(absf(local.x)-5.7*scale)<=maxf(0.36,0.3*scale) and absf(local.y)<=maxf(0.36,0.5*scale)
	return contains(object,point)
