class_name VisualRoadJoin
extends RefCounted
## Small cosmetic fillets only; canonical outlines and contact geometry stay intact.

static func build(pieces: Array, index: int, margin: float = 0.0) -> Dictionary:
	var cuts: Array[Dictionary] = RoadEdges._join_cuts(pieces,index)
	var polygon: PackedVector2Array = RoadEdges._trim_join_outline(RoadPieces.section_outline(pieces,index,margin),cuts)
	var replacements: Dictionary = {}
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
			var own: Vector2 = next if cut_before else previous
			for j: int in range(other_polygon.size()):
				if corner.distance_to(other_polygon[j]) > 0.01: continue # Width discontinuity is not a shared corner.
				var before: Vector2 = other_polygon[(j+other_polygon.size()-1)%other_polygon.size()]
				var after: Vector2 = other_polygon[(j+1)%other_polygon.size()]
				var away: Vector2 = after if RoadEdges._on_join_cut(before,other_polygon[j],other_cuts) else before
				var own_direction: Vector2 = (own-corner).normalized()
				var other_direction: Vector2 = (away-other_polygon[j]).normalized()
				var shared_corner: Vector2 = (corner+other_polygon[j])*0.5
				# Equal trim distances produce the same midpoint from either piece.
				var trim: float = minf(1.0,minf(own.distance_to(corner),away.distance_to(other_polygon[j]))*0.45)
				var a: Vector2 = shared_corner+other_direction*trim
				var b: Vector2 = shared_corner+own_direction*trim
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
