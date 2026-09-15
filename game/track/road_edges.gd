class_name RoadEdges
extends RefCounted
## Pure road-edge construction shared by contact geometry and rendering.

static func _join_cuts(pieces: Array, index: int) -> Array[Dictionary]:
	var cuts: Array[Dictionary] = []
	var outline: PackedVector2Array = RoadPieces.section_outline(pieces,index)
	var count: int = outline.size()/2
	for endpoint: int in range(2):
		if RoadPieces._partner(pieces,index,endpoint).size() != 1: continue
		var a: Vector2 = outline[0 if endpoint == 0 else count-1]
		var b: Vector2 = outline[-1 if endpoint == 0 else count]
		var normal: Vector2 = (b-a).normalized().orthogonal()
		var inward: Vector2 = Vector2.RIGHT.rotated(deg_to_rad(float(RoadPieces._pose(pieces[index],endpoint).heading)))
		if normal.dot(inward) < 0.0: normal = -normal
		cuts.append({"point":(a+b)*0.5,"normal":normal,"endpoint":endpoint,"span":a.distance_to(b)})
	return cuts


static func _trim_join_outline(source: PackedVector2Array, cuts: Array[Dictionary]) -> PackedVector2Array:
	# Only trim the contiguous folded tip. An infinite half-plane clip would
	# also remove distant sections of a hairpin that return across that plane.
	var count: int = source.size()/2
	var left: PackedVector2Array = source.slice(0,count)
	var right: PackedVector2Array = source.slice(count)
	right.reverse()
	for cut: Dictionary in cuts:
		if int(cut.endpoint) == 1:
			left.reverse()
			right.reverse()
		left = _trim_side_tip(left,cut)
		right = _trim_side_tip(right,cut)
		if int(cut.endpoint) == 1:
			left.reverse()
			right.reverse()
	right.reverse()
	return _clean_outline(left+right)


static func _trim_side_tip(side: PackedVector2Array, cut: Dictionary) -> PackedVector2Array:
	var index: int = 1
	while index < side.size()-1 and (side[index]-Vector2(cut.point)).dot(cut.normal) < -0.00001: index += 1
	if index == 1: return side
	var a: Vector2 = side[index-1]
	var b: Vector2 = side[index]
	var da: float = (a-Vector2(cut.point)).dot(cut.normal)
	var db: float = (b-Vector2(cut.point)).dot(cut.normal)
	return PackedVector2Array([side[0],a.lerp(b,da/(da-db))])+side.slice(index)


static func _on_join_cut(a: Vector2, b: Vector2, cuts: Array[Dictionary]) -> bool:
	for cut: Dictionary in cuts:
		if a.distance_to(b) > float(cut.span)*0.5 and absf((a-Vector2(cut.point)).dot(cut.normal)) < 0.001 and absf((b-Vector2(cut.point)).dot(cut.normal)) < 0.001: return true
	return false


static func _on_join_plane(a: Vector2, b: Vector2, cuts: Array[Dictionary]) -> bool:
	for cut: Dictionary in cuts:
		if absf((a-Vector2(cut.point)).dot(cut.normal)) < 0.001 and absf((b-Vector2(cut.point)).dot(cut.normal)) < 0.001: return true
	return false


static func _roadside_miter(polygon: PackedVector2Array, index: int, cuts: Array[Dictionary]) -> Vector2:
	var point: Vector2 = polygon[index]
	var before: Vector2 = polygon[(index+polygon.size()-1)%polygon.size()]
	var after: Vector2 = polygon[(index+1)%polygon.size()]
	var tangent := Vector2.ZERO
	if _on_join_cut(before,point,cuts): tangent = after-point
	elif _on_join_cut(point,after,cuts): tangent = point-before
	else: return _edge_miter(polygon,index)
	var normal: Vector2 = tangent.normalized().orthogonal()
	var area: float = 0.0
	for i: int in range(polygon.size()): area += polygon[i].cross(polygon[(i+1)%polygon.size()])
	return -normal if area < 0.0 else normal


static func _clean_outline(source: PackedVector2Array) -> PackedVector2Array:
	# Offset operations can retain microscopic segments along rotated straights.
	# Their unstable tangent produces long triangular spikes when extruded.
	var result := PackedVector2Array()
	for point: Vector2 in source:
		if result.is_empty() or result[-1].distance_to(point) > 0.01: result.append(point)
	if result.size() > 3 and result[0].distance_to(result[-1]) < 0.01: result.remove_at(result.size()-1)
	return result


static func _edge_miter(polygon: PackedVector2Array, index: int) -> Vector2:
	var point: Vector2 = polygon[index]
	var before: Vector2 = (point-polygon[(index+polygon.size()-1)%polygon.size()]).normalized().orthogonal()
	var after: Vector2 = (polygon[(index+1)%polygon.size()]-point).normalized().orthogonal()
	var normal: Vector2 = (before+after).normalized()
	# A tiny containment probe at a nearly-collinear boundary is unstable.
	# Use the whole polygon's winding so consecutive normals cannot flip.
	var area: float = 0.0
	for i: int in range(polygon.size()): area += polygon[i].cross(polygon[(i+1)%polygon.size()])
	if area < 0.0: normal = -normal
	return normal / maxf(absf(normal.dot(after)),0.5)


static func _inner_bend_distance(point: Vector2, points: PackedVector2Array) -> float:
	# Curbs only on the inside of locally curved sections, never straight ends.
	var nearest: int = 0
	var best: float = INF
	var distance: float = 0.0
	var nearest_distance: float = 0.0
	for i: int in range(points.size()):
		if i > 0: distance += points[i-1].distance_to(points[i])
		var squared: float = point.distance_squared_to(points[i])
		if squared < best:
			best = squared
			nearest = i
			nearest_distance = distance
	if nearest == 0 or nearest == points.size()-1: return -1.0
	var inward: Vector2 = (points[nearest+1]-points[nearest]).normalized()-(points[nearest]-points[nearest-1]).normalized()
	if inward.length_squared() < 0.0001 or (point-points[nearest]).dot(inward) <= 0.0: return -1.0
	return nearest_distance


static func _road_edge_exposed(point: Vector2, index: int, outlines: Array[Dictionary], pieces: Array = []) -> bool:
	for outline: Dictionary in outlines:
		if int(outline.index) == index or not Rect2(outline.bounds).has_point(point): continue
		var joined_neighbor: bool = false
		if not pieces.is_empty():
			for endpoint: int in range(2):
				var matches: Array = RoadPieces._partner(pieces,index,endpoint)
				if matches.size() == 1 and int(matches[0][0]) == int(outline.index):
					var pose: Dictionary = RoadPieces._pose(pieces[index],endpoint)
					if point.distance_to(pose.position) < float(pieces[index].width): joined_neighbor = true
		if not joined_neighbor and Geometry2D.is_point_in_polygon(point,outline.polygon): return false
	return true
