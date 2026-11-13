extends RefCounted
## Value-checked derived data; exact source order and narrow phases stay authoritative.
const SPATIAL = preload("res://editor/spatial_bounds.gd")
var scope_depth: int = 0
var validations: int = 0
var source: Array = []
var bumps_source: Array = []
var groups: Dictionary = {}
var indices: Dictionary = {}

func prepare(objects: Array, bumps: Array = []) -> void:
	source = objects.duplicate(true)
	bumps_source = bumps.duplicate(true)
	groups = {"fluids":[],"ramps":[],"bumps":[],"soft":[]}
	indices = {"fluids":SPATIAL.new(8.0),"ramps":SPATIAL.new(8.0),"bumps":SPATIAL.new(8.0)}
	for object: Dictionary in source:
		var group: String = "fluids" if object.kind in ["oil","puddle"] else "ramps" if object.kind == "jump" else "bumps" if object.kind == "speed_bump" else "soft" if object.kind in CreatorCatalog.SOFT else ""
		if group == "bumps": continue
		if group.is_empty(): continue
		groups[group].append(object)
		if not indices.has(group): continue
		var center := Vector2(object.position[0],object.position[1])
		var reach: float = CreatorObjects.size_of(object).length()*0.75+0.001
		indices[group].add(Rect2(center-Vector2.ONE*reach,Vector2.ONE*reach*2.0))
	# Bumps are independently overridable by replay/reference fixtures.
	groups.bumps = bumps_source
	indices.bumps = SPATIAL.new(8.0)
	for object: Dictionary in bumps_source:
		var center := Vector2(object.position[0],object.position[1])
		var reach: float = CreatorObjects.size_of(object).length()*0.75+0.001
		indices.bumps.add(Rect2(center-Vector2.ONE*reach,Vector2.ONE*reach*2.0))

func query(group: String, point: Vector2, previous: Vector2 = Vector2.INF, reach: float = 0.001) -> Array:
	if groups[group].is_empty(): return []
	var area: Rect2 = Rect2(point,Vector2.ZERO) if previous == Vector2.INF else Rect2(previous,point-previous).abs()
	var result: Array = []
	for index: int in indices[group].query(area.grow(reach)): result.append(groups[group][index])
	return result
