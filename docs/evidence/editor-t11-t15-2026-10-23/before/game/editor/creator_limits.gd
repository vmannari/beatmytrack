extends RefCounted
## Shared authoring admission. Estimates are safety bounds, not device certification.
const MAX_OBJECTS: int = 4096
const MAX_TYRE_STACKS: int = 4096
const MAX_DOCUMENT_BYTES: int = 1024 * 1024
const PROP_MEMORY_BYTES: int = 128 * 1024 * 1024
const LEGACY_OBJECTS: int = 96
const COSTS = preload("res://editor/creator_prop_costs.gd")

static func tyre_cost(kind: String) -> int:
	return 6 if kind == "tyre_wall" else 1 if kind == "tyre_stack" else 0

static func tyre_count(objects: Array) -> int:
	var total: int = 0
	for object: Dictionary in objects: total += tyre_cost(str(object.get("kind","")))
	return total

static func remaining(objects: Array, kind: String) -> int:
	var count: int = maxi(0,MAX_OBJECTS-objects.size())
	var cost: int = tyre_cost(kind)
	return mini(count,maxi(0,(MAX_TYRE_STACKS-tyre_count(objects))/cost)) if cost else count

static func memory_bytes(objects: Array, theme: String = "pine") -> int:
	var total: int = 0
	var instanced: Dictionary = {}
	for object: Dictionary in objects:
		total += _object_bytes(object,theme,instanced)
	return total

static func _object_bytes(object: Dictionary, theme: String, instanced: Dictionary) -> int:
	var kind: String = str(object.get("kind",""))
	var key: String = theme+"/"+kind
	var cost: int = int(COSTS.BYTES.get(key,COSTS.BYTES.get("pine/"+kind,4096)))
	if not tyre_cost(kind): return cost
	var bytes: int = tyre_cost(kind)*192
	if not instanced.has("tyres"): bytes += cost; instanced["tyres"] = true
	return bytes

static func error(objects: Array, theme: String = "pine") -> String:
	if objects.size() > MAX_OBJECTS: return "Use up to %d placed objects." % MAX_OBJECTS
	if tyre_count(objects) > MAX_TYRE_STACKS: return "Use up to %d tyre stacks. A tyre wall contains six stacks." % MAX_TYRE_STACKS
	# Preserve every previously legal small scene. Extra authoring capacity has
	# a conservative live-geometry estimate, separate from idle cache budgets.
	if objects.size() > LEGACY_OBJECTS and memory_bytes(objects,theme) > PROP_MEMORY_BYTES:
		return "This scenery needs too much memory. Remove complex scenery or use simpler objects."
	return ""

static func addition_error(objects: Array, additions: Array, theme: String = "pine") -> String:
	return error(objects+additions,theme)

static func take(objects: Array, candidates: Array, theme: String = "pine") -> Array:
	var accepted: Array = []
	var instanced: Dictionary = {}
	var bytes: int = 0
	for object: Dictionary in objects: bytes += _object_bytes(object,theme,instanced)
	var tyres: int = tyre_count(objects)
	for object: Dictionary in candidates:
		var count: int = objects.size()+accepted.size()+1
		tyres += tyre_cost(str(object.kind)); bytes += _object_bytes(object,theme,instanced)
		if count > MAX_OBJECTS or tyres > MAX_TYRE_STACKS or (count > LEGACY_OBJECTS and bytes > PROP_MEMORY_BYTES): break
		accepted.append(object)
	return accepted
