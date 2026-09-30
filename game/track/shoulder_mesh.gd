class_name ShoulderMesh
extends RefCounted
## Resolve overlapping sand strips by their distance from the road. Each area
## belongs to the strip with the smallest UV.y (most sand), without depth ties.

var triangles: Array[Dictionary] = []
var bins: Dictionary = {}
const CELL: float = 4.0

func add_quad(a: Vector2, b: Vector2, outer_a: Vector2, outer_b: Vector2) -> void:
	_add_triangle(PackedVector2Array([a,outer_b,b]),Vector3(0,1,0))
	_add_triangle(PackedVector2Array([a,outer_a,outer_b]),Vector3(0,1,1))

func _add_triangle(p: PackedVector2Array, weights: Vector3) -> void:
	var u: Vector2 = p[1]-p[0]
	var v: Vector2 = p[2]-p[0]
	var determinant: float = u.cross(v)
	if absf(determinant) < 0.000001: return
	var gradient := Vector2((weights.y-weights.x)*v.y-(weights.z-weights.x)*u.y,
		u.x*(weights.z-weights.x)-v.x*(weights.y-weights.x))/determinant
	var bounds := Rect2(p[0],Vector2.ZERO).expand(p[1]).expand(p[2])
	var index: int = triangles.size()
	triangles.append({"polygon":p,"gradient":gradient,"offset":weights.x-gradient.dot(p[0]),"bounds":bounds})
	for cell: Vector2i in _cells(bounds):
		if not bins.has(cell): bins[cell] = []
		bins[cell].append(index)

func _cells(bounds: Rect2) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for y: int in range(floori(bounds.position.y/CELL),floori(bounds.end.y/CELL)+1):
		for x: int in range(floori(bounds.position.x/CELL),floori(bounds.end.x/CELL)+1):
			result.append(Vector2i(x,y))
	return result

func emit(tool: SurfaceTool, yield_budget: Callable = Callable()) -> int:
	# Workers read frozen geometry and return plain arrays, never scene/GPU data.
	# Keep the cooperative editor path and small jobs on the calling thread.
	if yield_budget.is_valid() or triangles.size() < 512:
		return await _emit_serial(tool,yield_budget)
	var workers: int = clampi(OS.get_processor_count()-1,1,4)
	var jobs: Array[Dictionary] = []
	for worker: int in range(workers):
		var first: int = triangles.size()*worker/workers
		var last: int = triangles.size()*(worker+1)/workers
		var thread := Thread.new()
		if thread.start(_collect_range.bind(first,last)) == OK:
			jobs.append({"thread":thread})
		else:
			jobs.append({"result":_collect_range(first,last)})
	var vertices: int = 0
	for job: Dictionary in jobs:
		var result: Dictionary = job.thread.wait_to_finish() if job.has("thread") else job.result
		var points: PackedVector2Array = result.points
		var uv: PackedVector2Array = result.uv
		for index: int in range(points.size()):
			tool.set_uv(uv[index])
			tool.add_vertex(VisualGeometry.world(points[index])+Vector3.UP*-0.02)
		vertices += points.size()
	return vertices/3

func _emit_serial(tool: SurfaceTool, yield_budget: Callable = Callable()) -> int:
	var count: int = 0
	# Most small triangles query the same bin rectangle. Share its ordered
	# candidate list, preserving the original clipping/tie-break order exactly.
	var candidate_lists: Dictionary = {}
	for index: int in range(triangles.size()):
		if yield_budget.is_valid() and not await yield_budget.call(): return count
		var source: Dictionary = triangles[index]
		var fragments: Array[PackedVector2Array] = _fragments(index,source,candidate_lists)
		for polygon: PackedVector2Array in fragments:
			var indices: PackedInt32Array = Geometry2D.triangulate_polygon(polygon)
			for vertex: int in indices:
				var point: Vector2 = polygon[vertex]
				tool.set_uv(Vector2(0,clampf(source.gradient.dot(point)+source.offset,0,1)))
				tool.add_vertex(VisualGeometry.world(point)+Vector3.UP*-0.02)
			count += indices.size()/3
	return count

func _collect_range(first: int, last: int) -> Dictionary:
	var output := PackedVector2Array()
	var uv := PackedVector2Array()
	# Most small triangles query the same bin rectangle. Share its ordered
	# candidate list, preserving the original clipping/tie-break order exactly.
	var candidate_lists: Dictionary = {}
	for index: int in range(first,last):
		var source: Dictionary = triangles[index]
		var fragments: Array[PackedVector2Array] = _fragments(index,source,candidate_lists)
		for polygon: PackedVector2Array in fragments:
			var indices: PackedInt32Array = Geometry2D.triangulate_polygon(polygon)
			for vertex: int in indices:
				var point: Vector2 = polygon[vertex]
				uv.append(Vector2(0,clampf(source.gradient.dot(point)+source.offset,0,1)))
				output.append(point)
	return {"points":output,"uv":uv}

func _fragments(index: int, source: Dictionary, candidate_lists: Dictionary) -> Array[PackedVector2Array]:
	var fragments: Array[PackedVector2Array] = [source.polygon]
	var bounds: Rect2 = source.bounds
	var key := Vector4i(floori(bounds.position.x/CELL),floori(bounds.position.y/CELL),floori(bounds.end.x/CELL),floori(bounds.end.y/CELL))
	if not candidate_lists.has(key):
		var candidates: Dictionary = {}
		for cell: Vector2i in _cells(bounds):
			for other: int in bins[cell]: candidates[other] = true
		candidate_lists[key] = PackedInt32Array(candidates.keys())
	for other: int in candidate_lists[key]:
		if other == index: continue
		var rival: Dictionary = triangles[other]
		if not bounds.intersects(rival.bounds): continue
		var gradient: Vector2 = rival.gradient-source.gradient
		var offset: float = rival.offset-source.offset
		var cutter: PackedVector2Array
		if gradient.length_squared() < 0.00000001:
			if offset > 0.000001 or (absf(offset) <= 0.000001 and other > index): continue
			cutter = rival.polygon
		else:
			cutter = _lower_half(rival.polygon,gradient,offset)
		if cutter.size() < 3: continue
		var remaining: Array[PackedVector2Array] = []
		for fragment: PackedVector2Array in fragments:
			remaining.append_array(_subtract_convex(fragment,cutter))
		fragments = remaining
		if fragments.is_empty(): break
	return fragments

func _subtract_convex(source: PackedVector2Array, cutter: PackedVector2Array) -> Array[PackedVector2Array]:
	# Keep convex fragments rather than hole contours, which cannot be passed
	# independently to triangulate_polygon without filling the hole again.
	var result: Array[PackedVector2Array] = []
	if Geometry2D.intersect_polygons(source,cutter).is_empty():
		result.append(source)
		return result
	var inside: PackedVector2Array = source
	var center := Vector2.ZERO
	for point: Vector2 in cutter: center += point
	center /= cutter.size()
	for i: int in range(cutter.size()):
		var a: Vector2 = cutter[i]
		var edge: Vector2 = cutter[(i+1)%cutter.size()]-a
		if edge.length_squared() < 0.00000001: continue
		var normal := Vector2(-edge.y,edge.x).normalized()
		if normal.dot(center-a) > 0: normal = -normal
		var outside: PackedVector2Array = _lower_half(inside,-normal,normal.dot(a))
		if outside.size() >= 3: result.append(outside)
		inside = _lower_half(inside,normal,-normal.dot(a))
		if inside.size() < 3: break
	return result

func _lower_half(polygon: PackedVector2Array, gradient: Vector2, offset: float) -> PackedVector2Array:
	var result := PackedVector2Array()
	for i: int in range(polygon.size()):
		var a: Vector2 = polygon[i]
		var b: Vector2 = polygon[(i+1)%polygon.size()]
		var da: float = gradient.dot(a)+offset
		var db: float = gradient.dot(b)+offset
		if da <= 0: result.append(a)
		if (da < 0 and db > 0) or (da > 0 and db < 0): result.append(a.lerp(b,da/(da-db)))
	return result
