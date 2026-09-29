class_name VisualRoadJoin
extends RefCounted
## Small cosmetic fillets only; canonical outlines and contact geometry stay intact.

static func build(pieces: Array, index: int, margin: float = 0.0) -> Dictionary:
	var cuts: Array[Dictionary] = RoadEdges._join_cuts(pieces,index)
	var polygon: PackedVector2Array = RoadEdges._trim_join_outline(RoadPieces.section_outline(pieces,index,margin),cuts)
	var replacements: Dictionary = {}
	var source_cuts: Array[Dictionary] = cuts.duplicate(true)
	for cut: Dictionary in cuts:
		var partner: Array = RoadPieces._partner(pieces,index,int(cut.endpoint))[0]
		var other: int = int(partner[0])
		if pieces[other].kind == "bridge": continue
		var other_cuts: Array[Dictionary] = RoadEdges._join_cuts(pieces,other)
		var other_polygon: PackedVector2Array = RoadEdges._trim_join_outline(RoadPieces.section_outline(pieces,other,margin),other_cuts)
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
