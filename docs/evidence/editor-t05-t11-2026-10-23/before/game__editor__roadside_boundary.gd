class_name RoadsideBoundary
extends RefCounted
## Exposed spline-sweep perimeter; raw inside offsets can reverse or self-cross.
## Small editor-only geometry cache, independent of canonical simulation.
static var _cache: Array[Dictionary] = []
const CACHE_BUDGET: int = 8 * 1024 * 1024
static var cache_bytes: int = 0

static func run(path: Dictionary, begin: float, delta: float, side: float, clearance: float, single_length: float = 0.0) -> PackedVector2Array:
	var contours: Array[PackedVector2Array] = _contours(path,clearance)
	var first: Dictionary = RoadPieces._at(path,begin)
	var last: Dictionary = RoadPieces._at(path,begin+delta)
	var first_normal := Vector2(-first.tangent.y,first.tangent.x)*side
	var last_normal := Vector2(-last.tangent.y,last.tangent.x)*side
	var a: Vector2 = Vector2(first.point)+first_normal*(float(first.width)*0.5+clearance)
	var b: Vector2 = Vector2(last.point)+last_normal*(float(last.width)*0.5+clearance)
	var best: Dictionary = {}
	var score: float = INF
	for polygon: PackedVector2Array in contours:
		var boundary: Dictionary = {"points":polygon,"widths":PackedFloat32Array(),"closed":true}
		boundary.widths.resize(polygon.size()); boundary.widths.fill(1.0)
		var start: Dictionary = RoadPieces._nearest(boundary,a)
		var finish: Dictionary = RoadPieces._nearest(boundary,b)
		var start_pose: Dictionary = RoadPieces._at(boundary,float(start.along))
		var finish_pose: Dictionary = RoadPieces._at(boundary,float(finish.along))
		# Do not switch to the opposite side or connect separate grass islands.
		if (Vector2(start_pose.point)-Vector2(first.point)).dot(first_normal) <= 0.0: continue
		if (Vector2(finish_pose.point)-Vector2(last.point)).dot(last_normal) <= 0.0: continue
		var distance: float = float(start.distance)+float(finish.distance)
		if distance < score:
			score = distance
			best = {"path":boundary,"start":start.along,"finish":finish.along,"tangent":start_pose.tangent}
	if best.is_empty(): return PackedVector2Array()
	var direction: float = signf(Vector2(best.tangent).dot(Vector2(first.tangent)*(1.0 if delta >= 0.0 else -1.0)))
	if direction == 0.0: direction = -side*(1.0 if delta >= 0.0 else -1.0)
	var length: float = RoadPieces._path_length(best.path)
	if absf(delta) < 0.01:
		var single: float = minf(single_length,length*0.5)
		return _slice(best.path,float(best.start)-direction*single*0.5,single,direction)
	var travel: float = fposmod((float(best.finish)-float(best.start))*direction,length)
	return _slice(best.path,float(best.start),travel,direction)

static func _slice(path: Dictionary, begin: float, distance: float, direction: float) -> PackedVector2Array:
	var result := PackedVector2Array([Vector2(RoadPieces._at(path,begin).point)])
	var vertices: Array[Dictionary] = []
	var points: PackedVector2Array = path.points
	var length: float = RoadPieces._path_length(path)
	var along: float = 0.0
	for i: int in range(points.size()):
		var travel: float = fposmod((along-begin)*direction,length)
		if travel > 0.00001 and travel < distance-0.00001: vertices.append({"point":points[i],"distance":travel})
		along += points[i].distance_to(points[(i+1)%points.size()])
	vertices.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return float(a.distance)<float(b.distance))
	for vertex: Dictionary in vertices: result.append(vertex.point)
	result.append(Vector2(RoadPieces._at(path,begin+distance*direction).point))
	return result

static func _contours(path: Dictionary, clearance: float) -> Array[PackedVector2Array]:
	var entry: Dictionary = {}
	for saved: Dictionary in _cache:
		if saved.points == path.points and saved.widths == path.widths and saved.closed == path.closed and saved.node_indices == path.get("node_indices",[]):
			entry = saved; break
	if entry.is_empty():
		var points: PackedVector2Array = path.points.duplicate()
		var widths: PackedFloat32Array = path.widths.duplicate()
		if path.closed:
			points.append(points[0]); widths.append(widths[0])
		entry = {"points":path.points.duplicate(),"widths":path.widths.duplicate(),"closed":path.closed,"node_indices":path.get("node_indices",[]).duplicate(),
			"geometry":{"points":points,"widths":widths,"node_indices":path.get("node_indices",[])},
			"road":SplineBorders.contours({"points":points,"widths":widths,"node_indices":path.get("node_indices",[])},[]),"offsets":{}}
		_cache.append(entry)
		if _cache.size() > 4: _cache.pop_front()
	if not entry.offsets.has(clearance):
		if entry.offsets.size() >= 8: entry.offsets.clear()
		# Expand the actual variable-width sweep before the union. Applying a
		# normal/polygon offset afterwards can fold or retain a hidden return.
		var expanded: Dictionary = entry.geometry.duplicate(true)
		var widths: PackedFloat32Array = expanded.widths
		for i: int in range(widths.size()): widths[i] += clearance*2.0
		expanded.widths = widths
		var cleaned: Array[PackedVector2Array] = []
		for polygon: PackedVector2Array in SplineBorders.contours(expanded,[]):
			cleaned.append(SplineBorders.simplify(polygon,0.015))
		entry.offsets[clearance] = cleaned
	cache_bytes = 0
	for saved: Dictionary in _cache: cache_bytes += var_to_bytes(saved).size()
	while not _cache.is_empty() and cache_bytes > CACHE_BUDGET: cache_bytes -= var_to_bytes(_cache.pop_front()).size()
	return entry.offsets[clearance]
