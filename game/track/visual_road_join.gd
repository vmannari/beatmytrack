class_name VisualRoadJoin
extends RefCounted
## Small cosmetic fillets only; canonical outlines and contact geometry stay intact.

static func build(pieces: Array, index: int, margin: float = 0.0) -> Dictionary:
	var cuts: Array[Dictionary] = RoadEdges._join_cuts(pieces,index)
	var polygon: PackedVector2Array = RoadEdges._trim_join_outline(RoadPieces.section_outline(pieces,index,margin),cuts)
	polygon = fair_contour(polygon,cuts)
	var replacements: Dictionary = {}
	var source_cuts: Array[Dictionary] = cuts.duplicate(true)
	for cut: Dictionary in cuts:
		var partner: Array = RoadPieces._partner(pieces,index,int(cut.endpoint))[0]
		var other: int = int(partner[0])
		if pieces[other].kind == "bridge": continue
		var other_cuts: Array[Dictionary] = RoadEdges._join_cuts(pieces,other)
		var other_polygon: PackedVector2Array = RoadEdges._trim_join_outline(RoadPieces.section_outline(pieces,other,margin),other_cuts)
		other_polygon = fair_contour(other_polygon,other_cuts)
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
	return {"polygon":rounded,"cuts":cuts}

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

static func kerb_triangles(document: Dictionary) -> Array[Dictionary]:
	var pieces: Array = document.get("pieces",[])
	var outlines: Array[Dictionary] = []
	for index: int in range(pieces.size()):
		if pieces[index].kind == "bridge": continue
		var polygon: PackedVector2Array = RoadPieces.section_outline(pieces,index)
		var bounds := Rect2(polygon[0],Vector2.ZERO)
		for point: Vector2 in polygon: bounds = bounds.expand(point)
		outlines.append({"index":index,"polygon":polygon,"bounds":bounds})
	var segments: Array[Dictionary] = []
	for index: int in range(pieces.size()):
		if pieces[index].kind == "bridge": continue
		var shape: Dictionary = build(pieces,index,-0.2)
		var polygon: PackedVector2Array = shape.polygon
		var cuts: Array[Dictionary] = shape.cuts
		var points: PackedVector2Array = RoadPieces.samples(pieces[index])
		var distance: float = 0
		for edge: int in range(polygon.size()):
			var a: Vector2 = polygon[edge]
			var b: Vector2 = polygon[(edge+1)%polygon.size()]
			if RoadEdges._on_join_cut(a,b,cuts): continue
			var na: Vector2 = RoadEdges._roadside_miter(polygon,edge,cuts)
			var nb: Vector2 = RoadEdges._roadside_miter(polygon,(edge+1)%polygon.size(),cuts)
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
				if Geometry2D.is_point_in_polygon(middle+outward,polygon): outward = -outward
				if not RoadEdges._road_edge_exposed(middle+outward,index,outlines,pieces): continue
				if RoadEdges._on_join_plane(a,b,cuts) or RoadEdges._inner_bend_distance(middle,points) < 0: continue
				segments.append({"a":p,"b":q,"outer_a":p+np*0.75,"outer_b":q+nq*0.75,"start":start,"end":distance,"piece":index})
	var visual := RoadKerbs.new()
	var first: int = 0
	while first < segments.size():
		var last: int = first
		while last+1 < segments.size():
			var a: Dictionary = segments[last]
			var b: Dictionary = segments[last+1]
			if a.piece != b.piece or absf(a.end-b.start) > 0.0001 or Vector2(a.b).distance_to(b.a) > 0.001: break
			last += 1
		var origin: float = segments[first].start
		var length: float = segments[last].end-origin
		if length < 2.0:
			first = last+1
			continue # Omit isolated decorative kerb slivers at offset inflections.
		for i: int in range(first,last+1):
			var segment: Dictionary = segments[i]
			visual._strip(segment.a,segment.b,segment.outer_a,segment.outer_b,segment.start-origin,segment.end-origin,length)
		first = last+1
	return visual.triangles
