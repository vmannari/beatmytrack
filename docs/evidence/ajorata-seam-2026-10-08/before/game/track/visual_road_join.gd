class_name VisualRoadJoin
extends RefCounted
## Small cosmetic fillets only; canonical outlines and contact geometry stay intact.

static func build(pieces: Array, index: int, margin: float = 0.0, topology: Dictionary = {}) -> Dictionary:
	if topology.is_empty(): topology = RoadPieces.prepare_endpoints(pieces)
	var shape: Dictionary = _base_shape(pieces,index,margin,topology)
	var cuts: Array[Dictionary] = shape.cuts
	var polygon: PackedVector2Array = shape.polygon
	var replacements: Dictionary = {}
	var source_cuts: Array[Dictionary] = cuts.duplicate(true)
	for cut: Dictionary in cuts:
		var partner: Array = RoadPieces._matches(topology,index,int(cut.endpoint))[0]
		var other: int = int(partner[0])
		if pieces[other].kind == "bridge": continue
		var other_cuts: Array[Dictionary] = RoadEdges._join_cuts(pieces,other,topology)
		var other_polygon := PackedVector2Array()
		if pieces[other].kind == "spline":
			for contour: PackedVector2Array in RoadEdges.presentation_contours(pieces,other,margin,topology):
				if Geometry2D.is_polygon_clockwise(contour): continue
				other_polygon = contour
				if Geometry2D.is_point_in_polygon(cut.point,contour): break
		else:
			other_polygon = _base_shape(pieces,other,margin,topology).polygon
		var ends: Array[Vector2] = []
		for i: int in range(polygon.size()):
			var corner: Vector2 = polygon[i]
			var previous: Vector2 = polygon[(i+polygon.size()-1)%polygon.size()]
			var next: Vector2 = polygon[(i+1)%polygon.size()]
			var cut_before: bool = RoadEdges._on_join_cut(previous,corner,cuts)
			var cut_after: bool = RoadEdges._on_join_cut(corner,next,cuts)
			if not cut_before and not cut_after: continue
			if absf((corner-Vector2(cut.point)).dot(cut.normal)) > 0.001: continue
			var own_step: int = 1 if cut_before else -1
			for j: int in range(other_polygon.size()):
				if corner.distance_to(other_polygon[j]) > 0.01: continue # Width discontinuity is not a shared corner.
				var before: Vector2 = other_polygon[(j+other_polygon.size()-1)%other_polygon.size()]
				var other_step: int = 1 if RoadEdges._on_join_cut(before,other_polygon[j],other_cuts) else -1
				# Measure along the side, not just its first tessellation segment.
				# Folded inside tips can leave an arbitrarily short first segment.
				var own_room: Dictionary = _walk(polygon,i,own_step,source_cuts,3.0)
				var other_room: Dictionary = _walk(other_polygon,j,other_step,other_cuts,3.0)
				var trim: float = minf(1.0,minf(own_room.distance,other_room.distance)*0.45)
				var own: Dictionary = _walk(polygon,i,own_step,source_cuts,trim)
				var away: Dictionary = _walk(other_polygon,j,other_step,other_cuts,trim)
				var shared_corner: Vector2 = (corner+other_polygon[j])*0.5
				var a: Vector2 = away.point
				var b: Vector2 = own.point
				for skipped: int in own.skipped: replacements[skipped] = PackedVector2Array()
				var curve := PackedVector2Array()
				for sample: int in range(5):
					var t: float = 0.5+float(sample)/8.0
					curve.append(a*(1.0-t)*(1.0-t)+shared_corner*2.0*t*(1.0-t)+b*t*t)
				ends.append(curve[0])
				if cut_after: curve.reverse()
				replacements[i] = curve
				break
		if ends.size() == 2:
			var normal: Vector2 = (ends[1]-ends[0]).normalized().orthogonal()
			if normal.dot(cut.normal) < 0: normal = -normal
			cut.point = (ends[0]+ends[1])*0.5
			cut.normal = normal
			cut.span = ends[0].distance_to(ends[1])
	var rounded := PackedVector2Array()
	for i: int in range(polygon.size()):
		if replacements.has(i): rounded.append_array(replacements[i])
		else: rounded.append(polygon[i])
	shape.polygon = rounded
	shape.contours[0] = rounded
	return shape

static func _base_shape(pieces: Array, index: int, margin: float, topology: Dictionary) -> Dictionary:
	var cuts: Array[Dictionary] = RoadEdges._join_cuts(pieces,index,topology)
	if not topology.has("visual_folded"): topology.visual_folded = {}
	if not topology.visual_folded.has(index):
		var outline: PackedVector2Array = RoadEdges._trim_join_outline(RoadPieces.section_outline(pieces,index,0.0,topology),cuts)
		topology.visual_folded[index] = _crosses(outline)
	var swept: bool = topology.visual_folded[index]
	var contours: Array[PackedVector2Array] = []
	if swept:
		# Offset sides can run backwards when the inner radius is narrower than
		# half the road. Draw only the exposed sweep, never those internal folds.
		# This cache is local to the presentation build; canonical kerbs stay pinned.
		if not topology.has("visual_sweeps"): topology.visual_sweeps = {}
		if not topology.visual_sweeps.has(index):
			topology.visual_sweeps[index] = SplineBorders.contours(RoadPieces.section_geometry(pieces,index,topology),cuts)
		contours = SplineBorders.keep_join_planes(SplineBorders.offset(topology.visual_sweeps[index],margin),cuts,margin).duplicate()
		_align_mouths(contours,cuts,RoadPieces.section_outline(pieces,index,margin,topology))
	else:
		var outline: PackedVector2Array = RoadEdges._trim_join_outline(RoadPieces.section_outline(pieces,index,margin,topology),cuts)
		contours.append(fair_contour(outline,cuts))
	return {"polygon":contours[0],"contours":contours,"cuts":cuts,"swept":swept}

static func _align_mouths(contours: Array[PackedVector2Array], cuts: Array[Dictionary], outline: PackedVector2Array) -> void:
	# The sampled sweep's round cap can be a few centimetres narrower than
	# the exact shared cross-section. Both pieces must meet at identical tips.
	var count: int = outline.size()/2
	for cut: Dictionary in cuts:
		var across: Vector2 = Vector2(cut.normal).orthogonal()
		var a: Vector2 = outline[0 if cut.endpoint == 0 else count-1]
		var b: Vector2 = outline[-1 if cut.endpoint == 0 else count]
		if (a-b).dot(across) > 0.0:
			var swap: Vector2 = a; a = b; b = swap
		for contour: int in range(contours.size()):
			var polygon: PackedVector2Array = contours[contour]
			var left: int = -1
			var right: int = -1
			for i: int in range(polygon.size()):
				var delta: Vector2 = polygon[i]-Vector2(cut.point)
				if absf(delta.dot(cut.normal)) > 0.002 or absf(delta.dot(across)) > float(cut.span)*0.5+1.0: continue
				if left < 0 or polygon[i].dot(across) < polygon[left].dot(across): left = i
				if right < 0 or polygon[i].dot(across) > polygon[right].dot(across): right = i
			if left >= 0 and right >= 0 and left != right:
				polygon[left] = a; polygon[right] = b
				contours[contour] = polygon

static func _crosses(polygon: PackedVector2Array) -> bool:
	for i: int in range(polygon.size()):
		var a: Vector2 = polygon[i]
		var b: Vector2 = polygon[(i+1)%polygon.size()]
		for j: int in range(i+2,polygon.size()):
			if i == 0 and j == polygon.size()-1: continue
			var c: Vector2 = polygon[j]
			var d: Vector2 = polygon[(j+1)%polygon.size()]
			if a.min(b).x > c.max(d).x or c.min(d).x > a.max(b).x or a.min(b).y > c.max(d).y or c.min(d).y > a.max(b).y: continue
			var hit: Variant = Geometry2D.segment_intersects_segment(a,b,c,d)
			if hit is Vector2 and minf(minf(hit.distance_to(a),hit.distance_to(b)),minf(hit.distance_to(c),hit.distance_to(d))) > 0.001: return true
	return false

static func _walk(polygon: PackedVector2Array, start: int, step: int, cuts: Array[Dictionary], limit: float) -> Dictionary:
	var distance: float = 0.0
	var skipped: Array[int] = []
	var current: int = start
	for iteration: int in range(polygon.size()-1):
		var next: int = posmod(current+step,polygon.size())
		var a: Vector2 = polygon[current]
		var b: Vector2 = polygon[next]
		if RoadEdges._on_join_cut(a,b,cuts): break
		var length: float = a.distance_to(b)
		if distance+length >= limit:
			return {"point":a.lerp(b,(limit-distance)/maxf(length,0.000001)),"distance":limit,"skipped":skipped}
		distance += length
		skipped.append(next)
		current = next
	return {"point":polygon[current],"distance":distance,"skipped":skipped}

static func fair_contour(source: PackedVector2Array, cuts: Array[Dictionary]) -> PackedVector2Array:
	# Tight offset S-bends can bunch samples into a short zigzag. Fair only
	# around abrupt internal turns; keep joined endpoints and broad curves.
	var sharp: Array[Vector2] = []
	for i: int in range(source.size()):
		var a: Vector2 = source[posmod(i-1,source.size())]
		var b: Vector2 = source[i]
		var c: Vector2 = source[(i+1)%source.size()]
		if RoadEdges._on_join_cut(a,b,cuts) or RoadEdges._on_join_cut(b,c,cuts): continue
		if absf((b-a).angle_to(c-b)) > 0.18: sharp.append(b)
	var result: PackedVector2Array = source.duplicate()
	for i: int in range(source.size()):
		var weight: float = 0.0
		for point: Vector2 in sharp: weight = maxf(weight,1.0-smoothstep(0.5,2.0,source[i].distance_to(point)))
		if weight <= 0: continue
		var left: Dictionary = _walk(source,i,-1,cuts,1.2)
		var right: Dictionary = _walk(source,i,1,cuts,1.2)
		# Fade before a join instead of changing its shared endpoint.
		weight *= smoothstep(0.0,1.2,minf(left.distance,right.distance))
		var displacement: Vector2 = ((Vector2(left.point)+Vector2(right.point))*0.5-source[i])*0.65
		result[i] += displacement.limit_length(0.25)*weight
	return result

static func kerb_triangles(document: Dictionary, yield_budget: Callable = Callable()) -> Array[Dictionary]:
	var pieces: Array = document.get("pieces",[])
	var topology: Dictionary = RoadPieces.prepare_endpoints(pieces)
	var outlines: Array[Dictionary] = []
	for index: int in range(pieces.size()):
		if yield_budget.is_valid() and not await yield_budget.call(): return []
		if pieces[index].kind == "bridge": continue
		var contours: Array[PackedVector2Array] = []
		if pieces[index].kind == "spline": contours = RoadEdges.section_contours(pieces,index,0.0,topology)
		else:
			var shape: Dictionary = _base_shape(pieces,index,0.0,topology)
			if shape.swept: contours = shape.contours
			else: contours.append(RoadPieces.section_outline(pieces,index,0.0,topology))
		for polygon: PackedVector2Array in contours:
			var bounds := Rect2(polygon[0],Vector2.ZERO)
			for point: Vector2 in polygon: bounds = bounds.expand(point)
			var swept: bool = pieces[index].kind == "spline" or topology.get("visual_folded",{}).get(index,false)
			outlines.append({"index":index,"polygon":polygon,"bounds":bounds,"hole":swept and Geometry2D.is_polygon_clockwise(polygon)})
	var segments: Array[Dictionary] = []
	for index: int in range(pieces.size()):
		if yield_budget.is_valid() and not await yield_budget.call(): return []
		if pieces[index].kind in ["bridge","spline"]: continue
		var shape: Dictionary = build(pieces,index,-0.2,topology)
		var cuts: Array[Dictionary] = shape.cuts
		var points: PackedVector2Array = RoadPieces.samples(pieces[index])
		for polygon: PackedVector2Array in shape.contours:
			var hole: bool = shape.swept and Geometry2D.is_polygon_clockwise(polygon)
			var distance: float = 0
			for edge: int in range(polygon.size()):
				if yield_budget.is_valid() and not await yield_budget.call(): return []
				var a: Vector2 = polygon[edge]
				var b: Vector2 = polygon[(edge+1)%polygon.size()]
				if RoadEdges._on_join_cut(a,b,cuts) or (shape.swept and RoadEdges._on_join_cap(a,b,cuts)): continue
				var na: Vector2 = RoadEdges._roadside_miter(polygon,edge,cuts,shape.swept)
				var nb: Vector2 = RoadEdges._roadside_miter(polygon,(edge+1)%polygon.size(),cuts,shape.swept)
				if hole: na = -na; nb = -nb
				if shape.swept:
					na = SplineBorders.kerb_normal(polygon,edge,na)
					nb = SplineBorders.kerb_normal(polygon,(edge+1)%polygon.size(),nb)
				var steps: int = maxi(1,ceili(a.distance_to(b)/0.2))
				for step: int in range(steps):
					var p: Vector2 = a.lerp(b,float(step)/steps)
					var q: Vector2 = a.lerp(b,float(step+1)/steps)
					var np: Vector2 = na.lerp(nb,float(step)/steps)
					var nq: Vector2 = na.lerp(nb,float(step+1)/steps)
					var start: float = distance
					distance += (p+np*0.375).distance_to(q+nq*0.375)
					var middle: Vector2 = (p+q)*0.5
					var outward: Vector2 = (q-p).normalized().orthogonal()*0.425
					if Geometry2D.is_point_in_polygon(middle+outward,polygon) != hole: outward = -outward
					if not RoadEdges._road_edge_exposed(middle+outward,index,outlines,pieces,topology): continue
					var curved: bool = RoadEdges._inner_bend_distance(middle,points) >= 0
					if RoadEdges._on_join_plane(a,b,cuts) or not curved: continue
					segments.append({"a":p,"b":q,"outer_a":p+np*0.75,"outer_b":q+nq*0.75,"start":start,"end":distance,"piece":index})
	# Splines keep exactly the same swept contours, curvature classification
	# and bounded kerb offsets used by their solitary/canonical renderer.
	var has_spline: bool = false
	for piece: Dictionary in pieces: has_spline = has_spline or piece.kind == "spline"
	if has_spline:
		if yield_budget.is_valid() and not await yield_budget.call(): return []
		segments.append_array(RoadKerbs.creator_segments(document,"spline",true))
	var visual := RoadKerbs.new()
	var first: int = 0
	while first < segments.size():
		if yield_budget.is_valid() and not await yield_budget.call(): return []
		var last: int = first
		while last+1 < segments.size():
			var a: Dictionary = segments[last]
			var b: Dictionary = segments[last+1]
			if a.piece != b.piece or absf(a.end-b.start) > 0.0001 or Vector2(a.b).distance_to(b.a) > 0.001: break
			last += 1
		var origin: float = segments[first].start
		var length: float = segments[last].end-origin
		if length < 2.0 and pieces[int(segments[first].piece)].kind != "spline":
			first = last+1
			continue # Omit isolated decorative kerb slivers at offset inflections.
		for i: int in range(first,last+1):
			var segment: Dictionary = segments[i]
			visual._strip(segment.a,segment.b,segment.outer_a,segment.outer_b,segment.start-origin,segment.end-origin,length)
		first = last+1
	return visual.triangles
