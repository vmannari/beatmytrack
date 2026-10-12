class_name SplineBorders
extends RefCounted
## Exposed boundary of the variable-width road sweep, including genuine holes.
## Local build caches only; no display, random state, clock or external I/O.

static func contours(geometry: Dictionary, cuts: Array[Dictionary]) -> Array[PackedVector2Array]:
	var points: PackedVector2Array = geometry.points
	var widths: PackedFloat32Array = geometry.widths
	var outer := PackedVector2Array()
	var holes: Array[PackedVector2Array] = []
	var indices: Array[int] = [0]
	var force: Array = geometry.get("node_indices",[])
	for i: int in range(1,points.size()):
		if i == points.size()-1 or i in force or points[i].distance_to(points[indices[-1]]) >= 0.70: indices.append(i)
	var previous: PackedVector2Array = disk(points[0],widths[0]*0.5)
	outer = previous
	for step: int in range(1,indices.size()):
		var i: int = indices[step]
		var circle: PackedVector2Array = disk(points[i],widths[i]*0.5)
		var shape: PackedVector2Array = Geometry2D.convex_hull(previous+circle)
		if shape[0].is_equal_approx(shape[-1]): shape.resize(shape.size()-1)
		previous = circle
		if outer.is_empty(): outer = shape; continue
		var old_holes: Array[PackedVector2Array] = holes
		holes = []
		for polygon: PackedVector2Array in Geometry2D.merge_polygons(outer,shape):
			if Geometry2D.is_polygon_clockwise(polygon): holes.append(polygon)
			else: outer = polygon
		for hole: PackedVector2Array in old_holes:
			for remainder: PackedVector2Array in Geometry2D.clip_polygons(hole,shape):
				if Geometry2D.is_polygon_clockwise(remainder): continue
				remainder.reverse()
				holes.append(remainder)
	if Geometry2D.is_polygon_clockwise(outer): outer.reverse()
	var result: Array[PackedVector2Array] = [rounded(outer,cuts)]
	for hole: PackedVector2Array in holes: result.append(rounded(hole,cuts))
	# Cut only each joined mouth's local cap, never a returning distant branch.
	for cut: Dictionary in cuts:
		var forward: Vector2 = cut.normal
		var normal: Vector2 = forward.orthogonal()
		var reach: float = float(cut.span)*0.5+1.0
		var center: Vector2 = cut.point
		var cap := PackedVector2Array([center+normal*reach,center-normal*reach,center-normal*reach-forward*reach,center+normal*reach-forward*reach])
		var clipped: Array[PackedVector2Array] = []
		for contour: PackedVector2Array in result:
			var hole: bool = Geometry2D.is_polygon_clockwise(contour)
			for polygon: PackedVector2Array in Geometry2D.clip_polygons(contour,cap):
				if hole: polygon.reverse()
				clipped.append(polygon)
		result = clipped
	return result

static func disk(center: Vector2, radius: float) -> PackedVector2Array:
	var result := PackedVector2Array()
	var count: int = maxi(32,ceili(TAU*radius/0.65))
	for i: int in range(count): result.append(center+Vector2.from_angle(TAU*float(i)/count)*radius)
	return result

static func curved_edge(polygon: PackedVector2Array, edge: int, points: PackedVector2Array) -> bool:
	var a: Vector2 = polygon[edge]
	var b: Vector2 = polygon[(edge+1)%polygon.size()]
	var middle: Vector2 = (a+b)*0.5
	var nearest: int = 0
	var best: float = INF
	for i: int in range(points.size()):
		var squared: float = middle.distance_squared_to(points[i])
		if squared < best: best = squared; nearest = i
	if nearest == 0 or nearest == points.size()-1: return false
	var before: Vector2 = perimeter_point(polygon,edge,middle,-1,2.0)
	var after: Vector2 = perimeter_point(polygon,(edge+1)%polygon.size(),middle,1,2.0)
	return absf((middle-before).angle_to(after-middle)) >= deg_to_rad(3.0)

static func kerb_normal(polygon: PackedVector2Array, index: int, normal: Vector2) -> Vector2:
	var incoming: Vector2 = polygon[index]-polygon[posmod(index-1,polygon.size())]
	var outgoing: Vector2 = polygon[(index+1)%polygon.size()]-polygon[index]
	var turn: float = incoming.angle_to(outgoing)
	if turn >= -0.001: return normal
	# Narrow a kerb where its grass-facing offset would pass the local centre
	# of curvature. Broad bends keep the ordinary 0.75 m strip.
	var radius: float = minf(incoming.length(),outgoing.length())/maxf(0.0001,2.0*sin(absf(turn)*0.5))
	return normal*minf(1.0,radius*0.65/maxf(0.0001,normal.length()*0.75))

static func perimeter_point(polygon: PackedVector2Array, vertex: int, origin: Vector2, direction: int, distance: float) -> Vector2:
	var current: Vector2 = origin
	for iteration: int in range(polygon.size()):
		var next: Vector2 = polygon[vertex]
		var length: float = current.distance_to(next)
		if length >= distance: return current.lerp(next,distance/maxf(length,0.00001))
		distance -= length
		current = next
		vertex = posmod(vertex+direction,polygon.size())
	return current

static func rounded(source: PackedVector2Array, _cuts: Array[Dictionary]) -> PackedVector2Array:
	var polygon: PackedVector2Array = simplify(source,0.025)
	var distances := PackedFloat32Array([0.0])
	for i: int in range(polygon.size()): distances.append(distances[-1]+polygon[i].distance_to(polygon[(i+1)%polygon.size()]))
	var length: float = distances[-1]
	var corners: Array[int] = []
	for i: int in range(polygon.size()):
		var incoming: Vector2 = polygon[i]-polygon[posmod(i-1,polygon.size())]
		var outgoing: Vector2 = polygon[(i+1)%polygon.size()]-polygon[i]
		if absf(incoming.angle_to(outgoing)) > 0.25: corners.append(i)
	var replacements: Dictionary = {}
	var skipped: Dictionary = {}
	for index: int in corners:
		var trim: float = 1.4
		for other: int in corners:
			if other == index: continue
			trim = minf(trim,absf(wrapf(distances[other]-distances[index],-length*0.5,length*0.5))*0.4)
		var center: Vector2 = polygon[index]
		var a: Vector2 = perimeter_point(polygon,posmod(index-1,polygon.size()),center,-1,trim)
		var b: Vector2 = perimeter_point(polygon,(index+1)%polygon.size(),center,1,trim)
		var curve := PackedVector2Array()
		var steps: int = maxi(4,ceili(trim*2.0/0.15))
		for sample: int in range(steps+1):
			var t: float = float(sample)/steps
			curve.append(a*(1.0-t)*(1.0-t)+center*2.0*t*(1.0-t)+b*t*t)
		replacements[index] = curve
		for i: int in range(polygon.size()):
			if i != index and absf(wrapf(distances[i]-distances[index],-length*0.5,length*0.5)) < trim: skipped[i] = true
	var result := PackedVector2Array()
	for i: int in range(polygon.size()):
		if replacements.has(i): result.append_array(replacements[i])
		elif not skipped.has(i): result.append(polygon[i])
	return simplify(result,0.015)

static func simplify(source: PackedVector2Array, tolerance: float) -> PackedVector2Array:
	if source.size() < 5: return source
	var points: PackedVector2Array = source+PackedVector2Array([source[0]])
	var retained := PackedByteArray()
	retained.resize(points.size())
	var middle: int = source.size()/2
	var stack: Array[Vector2i] = [Vector2i(0,middle),Vector2i(middle,source.size())]
	retained[0] = 1; retained[middle] = 1; retained[-1] = 1
	while not stack.is_empty():
		var span: Vector2i = stack.pop_back()
		var worst: int = -1
		var maximum: float = tolerance*tolerance
		for i: int in range(span.x+1,span.y):
			var distance: float = points[i].distance_squared_to(Geometry2D.get_closest_point_to_segment(points[i],points[span.x],points[span.y]))
			if distance > maximum: maximum = distance; worst = i
		if worst >= 0:
			retained[worst] = 1
			stack.append(Vector2i(span.x,worst)); stack.append(Vector2i(worst,span.y))
	var result := PackedVector2Array()
	for i: int in range(source.size()):
		if retained[i] != 0: result.append(source[i])
	return result

static func offset(contours_in: Array[PackedVector2Array], margin: float) -> Array[PackedVector2Array]:
	if is_zero_approx(margin): return contours_in
	var result: Array[PackedVector2Array] = []
	for contour: PackedVector2Array in contours_in:
		var hole: bool = Geometry2D.is_polygon_clockwise(contour)
		for polygon: PackedVector2Array in Geometry2D.offset_polygon(contour,-margin if hole else margin,Geometry2D.JOIN_ROUND):
			if hole: polygon.reverse()
			result.append(polygon)
	return result

static func surface(contours_in: Array[PackedVector2Array]) -> Array[PackedVector2Array]:
	# Even/odd horizontal slabs tessellate outer contours and holes together.
	# Every slab is simple: no overlapping strips, hidden fold or filled island.
	var levels: Array[float] = []
	var edges: Array[PackedVector2Array] = []
	for contour: PackedVector2Array in contours_in:
		for i: int in range(contour.size()):
			var a: Vector2 = contour[i]
			var b: Vector2 = contour[(i+1)%contour.size()]
			levels.append(a.y)
			if absf(a.y-b.y) > 0.00001: edges.append(PackedVector2Array([a,b]))
	levels.sort()
	var result: Array[PackedVector2Array] = []
	for i: int in range(levels.size()-1):
		var lo: float = levels[i]
		var hi: float = levels[i+1]
		if hi-lo < 0.00001: continue
		var y: float = (lo+hi)*0.5
		var hits: Array[Dictionary] = []
		for edge: PackedVector2Array in edges:
			if y <= minf(edge[0].y,edge[1].y) or y >= maxf(edge[0].y,edge[1].y): continue
			var low: float = lerpf(edge[0].x,edge[1].x,(lo-edge[0].y)/(edge[1].y-edge[0].y))
			var high: float = lerpf(edge[0].x,edge[1].x,(hi-edge[0].y)/(edge[1].y-edge[0].y))
			hits.append({"lo":low,"hi":high,"middle":(low+high)*0.5})
		hits.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return float(a.middle)<float(b.middle))
		for hit: int in range(0,hits.size()-1,2):
			result.append(PackedVector2Array([Vector2(hits[hit].lo,lo),Vector2(hits[hit+1].lo,lo),Vector2(hits[hit+1].hi,hi),Vector2(hits[hit].hi,hi)]))
	return result
