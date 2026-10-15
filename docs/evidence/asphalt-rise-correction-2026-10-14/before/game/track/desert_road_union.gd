extends RefCounted
## One visible surface at ground crossings; canonical road data is untouched.
var clipping := ShoulderMesh.new()
var points_by_triangle: Array[PackedVector2Array] = []
var phase_by_triangle: Array[Dictionary] = []
var piece_points: Dictionary = {}
var piece_outlines: Dictionary = {}
var piece_bounds: Dictionary = {}
var candidates: Dictionary = {}
var settings: Dictionary = {}
var blend_cache: Dictionary = {}
var edge_bins: Dictionary = {}

func configure(pieces: Array, outlines: Array[Dictionary], phase_settings: Dictionary) -> void:
	settings = phase_settings
	for i: int in range(pieces.size()):
		if pieces[i].kind == "bridge": continue
		piece_points[i] = RoadPieces.samples(pieces[i])
		piece_outlines[i] = []
		candidates[i] = []
	for outline: Dictionary in outlines:
		piece_outlines[outline.index].append(outline)
		piece_bounds[outline.index] = Rect2(piece_bounds[outline.index]).merge(outline.bounds) if piece_bounds.has(outline.index) else outline.bounds
		if not edge_bins.has(outline.index): edge_bins[outline.index] = {}
		var polygon: PackedVector2Array = outline.polygon
		for j: int in range(polygon.size()):
			var a: Vector2 = polygon[j]
			var b: Vector2 = polygon[(j+1)%polygon.size()]
			var bounds: Rect2 = Rect2(a,Vector2.ZERO).expand(b).grow(2.5)
			for y: int in range(floori(bounds.position.y/6.0),floori(bounds.end.y/6.0)+1):
				for x: int in range(floori(bounds.position.x/6.0),floori(bounds.end.x/6.0)+1):
					var key := Vector2i(x,y)
					if not edge_bins[outline.index].has(key): edge_bins[outline.index][key] = PackedVector4Array()
					edge_bins[outline.index][key].append(Vector4(a.x,a.y,b.x,b.y))
	for i: int in piece_bounds:
		for other: int in piece_bounds:
			if i != other and Rect2(piece_bounds[i]).grow(2.5).intersects(piece_bounds[other]): candidates[i].append(other)

func strength(point: Vector2, index: int) -> float:
	if not piece_bounds.has(index) or not Rect2(piece_bounds[index]).grow(2.5).has_point(point): return 0.0
	var inside: bool = false
	var in_hole: bool = false
	var nearest: float = INF
	for outline: Dictionary in piece_outlines[index]:
		var polygon: PackedVector2Array = outline.polygon
		if Geometry2D.is_point_in_polygon(point,polygon):
			if outline.hole: in_hole = true
			else: inside = true
	for edge: Vector4 in edge_bins[index].get(Vector2i(floori(point.x/6.0),floori(point.y/6.0)),PackedVector4Array()):
		nearest = minf(nearest,point.distance_to(Geometry2D.get_closest_point_to_segment(point,Vector2(edge.x,edge.y),Vector2(edge.z,edge.w))))
	return smoothstep(-2.5,2.5,nearest if inside and not in_hole else -nearest)

func blend(point: Vector2, index: int) -> Color:
	var key: Array = [index,point]
	if blend_cache.has(key): return blend_cache[key]
	var other_index: int = -1
	var other_strength: float = 0.0
	for other: int in candidates.get(index,[]):
		var value: float = strength(point,other)
		if value > other_strength: other_strength = value; other_index = other
	var encoded := Color(1.0,0.5,0.5,0.0)
	if other_strength > 0.001:
		var points: PackedVector2Array = piece_points[other_index]
		var nearest: float = INF
		var along: float = 0.0
		var local := Vector2.ZERO
		for j: int in range(points.size()-1):
			var delta: Vector2 = points[j+1]-points[j]
			var length: float = delta.length()
			if length < 0.00001: continue
			var axis: Vector2 = delta/length
			var projected: float = clampf((point-points[j]).dot(axis),0,length)
			var closest: Vector2 = points[j]+axis*projected
			var squared: float = point.distance_squared_to(closest)
			if squared < nearest: nearest = squared; local = Vector2(along+projected,(point-closest).dot(axis.orthogonal()))
			along += length
		var uv: Vector2 = coordinates(local,settings.get(other_index,{}))
		var weight: float = other_strength/maxf(strength(point,index)+other_strength,0.001)
		encoded = Color(0.5+cos(TAU*uv.x/10.0)*0.5,0.5+sin(TAU*uv.x/10.0)*0.5,clampf(uv.y/32.0+0.5,0,1),weight)
	blend_cache[key] = encoded
	return encoded

func add(polygon: PackedVector2Array, points: PackedVector2Array, phase_data: Dictionary = {}) -> void:
	var indices: PackedInt32Array = Geometry2D.triangulate_polygon(polygon)
	for i: int in range(0,indices.size(),3):
		var before: int = clipping.triangles.size()
		clipping._add_triangle(PackedVector2Array([polygon[indices[i]],polygon[indices[i+1]],polygon[indices[i+2]]]),Vector3.ZERO)
		if clipping.triangles.size() > before:
			points_by_triangle.append(points)
			phase_by_triangle.append(phase_data.duplicate())

static func coordinates(local: Vector2, cache: Dictionary) -> Vector2:
	var sign_value: float = float(cache.get("desert_sign",1.0))
	return Vector2((local.x*sign_value+float(cache.get("desert_phase",0.0)))*float(cache.get("desert_scale",1.0)),local.y*sign_value)

static func phases(pieces: Array, topology: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	var lengths: Array[float] = []
	var samples: Array[PackedVector2Array] = []
	for piece: Dictionary in pieces:
		var points: PackedVector2Array = RoadPieces.samples(piece)
		samples.append(points)
		var length: float = 0.0
		for i: int in range(points.size()-1): length += points[i].distance_to(points[i+1])
		lengths.append(length)
	var links: Array[Array] = []
	for index: int in range(pieces.size()):
		var ends: Array = [[],[]]
		for endpoint: int in range(2):
			for match_value: Array in RoadPieces._matches(topology,index,endpoint):
				ends[endpoint].append({"other":int(match_value[0]),"along":lengths[int(match_value[0])] if int(match_value[1]) == 1 else 0.0,"sign":1.0 if endpoint != int(match_value[1]) else -1.0})
			# Free-placed roads may overlap beyond an endpoint rather than snap
			# exactly. Continue wear through near-parallel physical road joins.
			if not ends[endpoint].is_empty() or samples[index].size() < 2: continue
			var source: PackedVector2Array = samples[index]
			var point: Vector2 = source[0] if endpoint == 0 else source[-1]
			var direction: Vector2 = ((source[1]-source[0]) if endpoint == 0 else (source[-1]-source[-2])).normalized()
			var best: float = INF
			var selected: Dictionary = {}
			for other: int in range(pieces.size()):
				if other == index: continue
				var along: float = 0.0
				for j: int in range(samples[other].size()-1):
					var a: Vector2 = samples[other][j]
					var delta: Vector2 = samples[other][j+1]-a
					var length: float = delta.length()
					if length < 0.00001: continue
					var axis: Vector2 = delta/length
					var projected: float = clampf((point-a).dot(axis),0,length)
					var alignment: float = direction.dot(axis)
					var squared: float = point.distance_squared_to(a+axis*projected)
					var score: float = squared+(1.0-absf(alignment))*2.0
					var width: float = minf(float(pieces[index].width),float(pieces[other].width))
					if absf(alignment) > 0.75 and squared < width*width*0.09 and minf(along+projected,lengths[other]-along-projected) < width and score < best:
						best = score
						selected = {"other":other,"along":along+projected,"sign":1.0 if alignment >= 0.0 else -1.0}
					along += length
			if not selected.is_empty(): ends[endpoint].append(selected)
		links.append(ends)
	for root_index: int in range(pieces.size()):
		if result.has(root_index): continue
		result[root_index] = {"desert_phase":0.0,"desert_sign":1.0}
		var queue: Array[int] = [root_index]
		var read_index: int = 0
		var component_length: float = 0.0
		var closure: float = 0.0
		while read_index < queue.size():
			var index: int = queue[read_index]
			read_index += 1
			component_length += lengths[index]
			for endpoint: int in range(2):
				var end_phase: float = float(result[index].desert_phase)+float(result[index].desert_sign)*(lengths[index] if endpoint == 1 else 0.0)
				for link: Dictionary in links[index][endpoint]:
					var other: int = int(link.other)
					if result.has(other):
						closure = maxf(closure,absf(end_phase-float(result[other].desert_phase)-float(result[other].desert_sign)*float(link.along)))
						continue
					var sign_value: float = float(result[index].desert_sign)*float(link.sign)
					result[other] = {"desert_sign":sign_value,"desert_phase":end_phase-sign_value*float(link.along)}
					queue.append(other)
		var span: float = closure if closure > 1.0 else component_length
		var scale: float = 10.0*maxf(1.0,roundf(span/10.0))/maxf(span,0.01)
		for index: int in queue: result[index]["desert_scale"] = scale
	return result

func emit(visual: NativeTrackVisual, tool: SurfaceTool) -> int:
	var count: int = 0
	var candidate_lists: Dictionary = {}
	var caches: Dictionary = {}
	for i: int in range(clipping.triangles.size()):
		if visual._menu_yield_due():
			if not await visual._yield_build(): return count
		var source: Dictionary = clipping.triangles[i]
		if not caches.has(points_by_triangle[i]): caches[points_by_triangle[i]] = phase_by_triangle[i].duplicate()
		caches[points_by_triangle[i]]["desert_blend_sampler"] = self
		for polygon: PackedVector2Array in clipping._fragments(i,source,candidate_lists):
			count += visual._road_polygon(tool,polygon,0.012,points_by_triangle[i],caches[points_by_triangle[i]])
	return count
