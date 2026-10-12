class_name RoadPieces
extends RefCounted
## Bounded, independent road sections. Heading uses Vector2 degrees (+X = 0).
## Road pieces are geometry; race routing is an explicit, separate operation.

const KINDS: Array[String] = ["straight", "taper", "curve", "s_bend", "hairpin", "bridge", "spline"]
const KEYS: Array[String] = ["kind", "position", "heading", "length", "radius", "width", "flip"]
const S_END_LENGTH: float = 2.0
const MAX_PIECES: int = 96
const SNAP_DISTANCE: float = 8.0
const JOIN_DISTANCE: float = 0.15
const JOIN_ANGLE: float = 2.0


static func create(kind: String, position: Vector2, heading: float = 0.0, width: float = 10.0) -> Dictionary:
	var piece: Dictionary = {"kind":kind, "position":[position.x,position.y], "heading":fposmod(heading,360.0),
		"length":48.0 if kind == "bridge" else 28.0 if kind == "straight" else 0.0 if kind in ["hairpin","curve"] else S_END_LENGTH, "radius":12.0 if kind == "hairpin" else 16.0,
		"width":clampf(width,6.0,20.0), "flip":false}
	if kind == "taper":
		piece.length = 28.0
		piece.narrow_width = minf(6.0,float(piece.width))
	if kind == "spline":
		piece.length = 0.0
		piece.spline_points = [[0.0,0.0],[12.0,0.0],[24.0,8.0],[36.0,0.0],[48.0,0.0]]
		piece.point_widths = [piece.width,piece.width,piece.width,piece.width,piece.width]
	return piece


static func validate(piece: Variant) -> Array[String]:
	if not piece is Dictionary or piece.size() != KEYS.size() + (1 if piece.has("angle") else 0) + (1 if piece.has("height") else 0) + (1 if piece.has("curvature") else 0) + (1 if piece.has("narrow_width") else 0) + (1 if piece.has("spline_points") else 0) + (1 if piece.has("point_widths") else 0) or not piece.has_all(KEYS):
		return ["Invalid road section."]
	if piece.kind == "spline":
		var spline_errors: Array[String] = SplineRoad.validate(piece)
		if not spline_errors.is_empty(): return spline_errors
	elif piece.has("spline_points") or piece.has("point_widths"): return ["Only spline sections can have interpolation points."]
	if piece.kind == "taper" and (not piece.has("narrow_width") or not _number(piece.narrow_width) or float(piece.narrow_width) < 6.0 or float(piece.narrow_width) > float(piece.width)): return ["Taper narrow width must be 6 metres or more and no wider than its wide end."]
	if piece.has("narrow_width") and piece.kind != "taper": return ["Only taper sections can have a narrow width."]
	if piece.has("curvature") and (piece.kind != "curve" or not _number(piece.curvature) or absf(float(piece.curvature)) > 0.3): return ["Curve curvature must be between -0.3 and 0.3."]
	if piece.has("angle") and (not _number(piece.angle) or float(piece.angle) < 5 or float(piece.angle) > 270): return ["Curve angle must be 5 to 270 degrees."]
	if piece.has("height") and (piece.kind != "s_bend" or not _number(piece.height) or float(piece.height) < 2.0 or float(piece.height) > 60.0): return ["S-bend height must be 2 to 60 metres."]
	if piece.kind not in KINDS: return ["Choose a built-in road section."]
	if not piece.position is Array or piece.position.size() != 2: return ["Road sections need two coordinates."]
	for value: Variant in piece.position:
		if not _number(value) or absf(float(value)) > 120.0: return ["Keep road sections inside the map."]
	for key: String in ["heading", "length", "radius", "width"]:
		if not _number(piece[key]): return ["Road section dimensions must be finite numbers."]
	if float(piece.heading) < 0.0 or float(piece.heading) >= 360.0: return ["Road heading must be between 0 and 359 degrees."]
	if piece.kind == "bridge" and float(piece.length) < 24.0: return ["A bridge needs at least 24 m for its two ramps."]
	if float(piece.length) < (2.0 if piece.kind == "straight" else 0.0) or float(piece.length) > 120.0:
		return ["Use a straight length of 2–120 m or a lead-in of 0–120 m."]
	if float(piece.radius) < 3.0 or float(piece.radius) > 60.0: return ["Use a bend radius of 3–60 m."]
	if float(piece.width) < 6.0 or float(piece.width) > 20.0: return ["Use a road width of 6–20 m."]
	if not piece.flip is bool: return ["Road mirror must be on or off."]
	for point: Vector2 in samples(piece):
		if point.abs().x > 120.0 or point.abs().y > 120.0: return ["Keep the whole road section inside the map."]
	return []


static func samples(piece: Dictionary) -> PackedVector2Array:
	if piece.kind == "spline": return SplineRoad.geometry(piece).points
	var local := PackedVector2Array([Vector2.ZERO])
	var length: float = 0.0 if piece.kind == "curve" else S_END_LENGTH if piece.kind == "s_bend" else float(piece.length)
	var count: int = maxi(1,ceili(length/0.75))
	for i: int in range(1,count+1):
		if length > 0.0: local.append(Vector2(length*float(i)/count,0.0))
	var radius: float = float(piece.radius)
	var side: float = -1.0 if piece.flip else 1.0
	if piece.kind == "curve":
		_arc(local,radius,deg_to_rad(float(piece.get("angle",90.0)))*side,0.0,1.0+3.0*absf(float(piece.get("curvature",0.0))))
		var amount: float = float(piece.get("curvature",0.0))*curve_bulge_scale(piece)
		for i: int in range(1,local.size()-1):
			var fraction: float = float(i)/(local.size()-1)
			var turn: float = deg_to_rad(float(piece.get("angle",90.0)))*fraction
			local[i] += Vector2(sin(turn),-side*cos(turn))*amount*pow(sin(PI*fraction),2)
	elif piece.kind == "hairpin":
		_arc(local,radius,PI*side,0.0)
		for i: int in range(1,count+1):
			if length > 0.0: local.append(Vector2(length*(1.0-float(i)/count),side*2.0*radius))
	elif piece.kind == "s_bend":
		_arc(local,radius,PI*0.25*side,0.0)
		_arc(local,radius,-PI*0.25*side,PI*0.25*side)
		var exit_start: Vector2 = local[-1]
		for i: int in range(1,count+1): local.append(exit_start+Vector2(S_END_LENGTH*float(i)/count,0))
	if piece.kind == "s_bend":
		var height_scale: float = height(piece)/(2.0*radius*(1.0-cos(PI*0.25)))
		for i: int in range(local.size()): local[i].y *= height_scale
	elif piece.kind == "taper":
		var shift: float = (float(piece.width)-float(piece.narrow_width))*0.5*(-1.0 if piece.flip else 1.0)
		for i: int in range(local.size()): local[i].y += shift*float(i)/maxf(1.0,float(local.size()-1))
	var result := PackedVector2Array()
	var origin := Vector2(float(piece.position[0]),float(piece.position[1]))
	for point: Vector2 in local: result.append(origin+point.rotated(deg_to_rad(float(piece.heading))))
	result[-1] = end_pose(piece).position
	return result


static func curve_bulge_scale(piece: Dictionary) -> float:
	# Shallow bends get a smaller range, avoiding a large bulge on a tiny arc.
	return float(piece.radius)*pow(minf(1.0,float(piece.get("angle",90.0))/90.0),2)


static func height(piece: Dictionary) -> float:
	return float(piece.get("height",2.0*float(piece.radius)*(1.0-cos(PI*0.25))))


static func _arc(points: PackedVector2Array, radius: float, angle: float, heading: float, density: float = 1.0) -> void:
	var origin: Vector2 = points[-1]
	var side: float = signf(angle)
	var count: int = maxi(2,ceili(radius*absf(angle)*density/0.75))
	for i: int in range(1,count+1):
		var turn: float = absf(angle)*float(i)/count
		points.append(origin+Vector2(radius*sin(turn),side*radius*(1.0-cos(turn))).rotated(heading))


static func end_pose(piece: Dictionary) -> Dictionary:
	if piece.kind == "spline":
		var nodes: PackedVector2Array = SplineRoad.points(piece)
		return {"position":nodes[-1],"heading":fposmod(rad_to_deg(SplineRoad.tangent(nodes,4).angle()),360.0)}
	var turn: float = float(piece.get("angle",90.0)) if piece.kind == "curve" else (180.0 if piece.kind == "hairpin" else 0.0)
	var radius: float = float(piece.radius)
	var side: float = -1.0 if piece.flip else 1.0
	var local := Vector2(0.0 if piece.kind == "curve" else float(piece.length),0.0)
	if piece.kind == "curve": local += Vector2(radius*sin(deg_to_rad(turn)),side*radius*(1.0-cos(deg_to_rad(turn))))
	elif piece.kind == "hairpin": local = Vector2(0.0,side*2.0*radius)
	elif piece.kind == "s_bend": local = Vector2(2.0*S_END_LENGTH+2.0*radius*sin(PI*0.25),side*height(piece))
	elif piece.kind == "taper": local.y = (float(piece.width)-float(piece.narrow_width))*0.5*(-1.0 if piece.flip else 1.0)
	var origin := Vector2(float(piece.position[0]),float(piece.position[1]))
	return {"position":origin+local.rotated(deg_to_rad(float(piece.heading))), "heading":fposmod(float(piece.heading)+turn*side,360.0)}


static func _pose(piece: Dictionary, endpoint: int) -> Dictionary:
	if endpoint == 1:
		var end: Dictionary = end_pose(piece)
		return {"position":end.position,"heading":fposmod(float(end.heading)+180.0,360.0)}
	if piece.kind == "spline":
		var nodes: PackedVector2Array = SplineRoad.points(piece)
		return {"position":nodes[0],"heading":fposmod(rad_to_deg(SplineRoad.tangent(nodes,0).angle()),360.0)}
	return {"position":Vector2(piece.position[0],piece.position[1]),"heading":float(piece.heading)}


static func snap(piece: Dictionary, pieces: Array, exclude: int = -1) -> Dictionary:
	var result: Dictionary = {"piece":piece.duplicate(true),"matched":false,"target_index":-1,"endpoint":-1,"distance":SNAP_DISTANCE}
	var topology: Dictionary = prepare_endpoints(pieces)
	var poses: Array = [_pose(piece,0),_pose(piece,1)]
	for index: int in range(pieces.size()):
		if index == exclude: continue
		for target_end: int in range(2):
			var target: Dictionary = topology.poses[index*2+target_end]
			if not _matches(topology,index,target_end,exclude).is_empty(): continue
			for endpoint: int in range(2):
				var pose: Dictionary = poses[endpoint]
				var distance: float = Vector2(pose.position).distance_to(target.position)
				if distance >= float(result.distance): continue
				var fitted: Dictionary = piece.duplicate(true)
				var delta: float = wrapf(float(target.heading)+180.0-float(pose.heading),-180.0,180.0)
				fitted.heading = fposmod(float(piece.heading)+delta,360.0)
				var moved: Dictionary = _pose(fitted,endpoint)
				var shift: Vector2 = Vector2(target.position)-Vector2(moved.position)
				fitted.position = [float(fitted.position[0])+shift.x,float(fitted.position[1])+shift.y]
				if not validate(fitted).is_empty(): continue
				result = {"piece":fitted,"matched":true,"target_index":index,"endpoint":target_end,"distance":distance}
	return result


## Local immutable preparation: no shared cache or thread-dependent state.
## Keep the old piece/endpoint ordering and exact distance test at bucket edges.
static func prepare_endpoints(pieces: Array) -> Dictionary:
	var poses: Array[Dictionary] = []
	var buckets: Dictionary = {}
	for index: int in range(pieces.size()):
		for endpoint: int in range(2):
			var pose: Dictionary = _pose(pieces[index],endpoint)
			var bucket := Vector2i(floori(pose.position.x/JOIN_DISTANCE),floori(pose.position.y/JOIN_DISTANCE))
			if not buckets.has(bucket): buckets[bucket] = []
			buckets[bucket].append(poses.size())
			poses.append(pose)
	var partners: Array = []
	for id: int in range(poses.size()):
		var position: Vector2 = poses[id].position
		var bucket := Vector2i(floori(position.x/JOIN_DISTANCE),floori(position.y/JOIN_DISTANCE))
		var candidates: Array = []
		for x: int in range(-1,2):
			for y: int in range(-1,2): candidates.append_array(buckets.get(bucket+Vector2i(x,y),[]))
		candidates.sort()
		var matches: Array = []
		for other: int in candidates:
			if other/2 == id/2: continue
			if position.distance_to(poses[other].position) <= JOIN_DISTANCE: matches.append([other/2,other%2])
		partners.append(matches)
	return {"poses":poses,"partners":partners}

static func _matches(topology: Dictionary, index: int, endpoint: int, exclude: int = -1) -> Array:
	var matches: Array = topology.partners[index*2+endpoint]
	if exclude < 0: return matches
	var filtered: Array = []
	for match: Array in matches:
		if int(match[0]) != exclude: filtered.append(match)
	return filtered

static func _partner(pieces: Array, index: int, endpoint: int, exclude: int = -1) -> Array:
	return _matches(prepare_endpoints(pieces),index,endpoint,exclude)


static func attached_end(piece: Dictionary, pieces: Array, exclude: int = -1) -> int:
	var attached: Array[bool] = [false,false]
	var topology: Dictionary = prepare_endpoints(pieces)
	for endpoint: int in [0,1]:
		var position: Vector2 = _pose(piece,endpoint).position
		for index: int in range(pieces.size()):
			if index == exclude: continue
			for other_end: int in [0,1]:
				if position.distance_to(topology.poses[index*2+other_end].position) <= JOIN_DISTANCE:
					attached[endpoint] = true
	return -1 if attached[0] == attached[1] else 0 if attached[0] else 1

static func keep_attachment(before: Dictionary, changed: Dictionary, endpoint: int, keep_tangent: bool = true) -> Dictionary:
	if endpoint < 0: return changed
	var result: Dictionary = changed.duplicate(true)
	var fixed: Dictionary = _pose(before,endpoint)
	if keep_tangent:
		var turn: float = wrapf(float(fixed.heading)-float(_pose(result,endpoint).heading),-180.0,180.0)
		result.heading = fposmod(float(result.heading)+turn,360.0)
	var shift: Vector2 = Vector2(fixed.position)-Vector2(_pose(result,endpoint).position)
	result.position = [float(result.position[0])+shift.x,float(result.position[1])+shift.y]
	return result


static func move_endpoint(piece: Dictionary, endpoint: int, target: Vector2) -> Dictionary:
	if piece.kind == "spline": return SplineRoad.move_point(piece,0 if endpoint == 0 else 4,target)
	var result: Dictionary = piece.duplicate(true)
	var start := Vector2(piece.position[0],piece.position[1])
	var end: Vector2 = end_pose(piece).position
	var old_chord: Vector2 = end-start
	var chord: Vector2 = target-start if endpoint == 1 else end-target
	if chord.length() < 0.01 or old_chord.length() < 0.01: return {}
	if piece.kind == "taper":
		var lateral: float = (float(piece.width)-float(piece.narrow_width))*0.5*(-1.0 if piece.flip else 1.0)
		if chord.length() <= absf(lateral): return {}
		result.length = sqrt(chord.length_squared()-lateral*lateral)
		var local := Vector2(float(result.length),lateral)
		result.heading = fposmod(rad_to_deg(chord.angle()-local.angle()),360.0)
		if endpoint == 0: result.position = [target.x,target.y]
		return result if validate(result).is_empty() else {}
	if piece.kind == "s_bend":
		# Scale only the curved span; the two 2 m tangents never scale.
		var x: float = 2.0*float(piece.radius)*sin(PI*0.25)
		var y: float = height(piece)
		var fixed: float = 2.0*S_END_LENGTH
		var square: float = x*x+y*y
		var discriminant: float = fixed*fixed*x*x+square*(chord.length_squared()-fixed*fixed)
		if discriminant <= 0.0: return {}
		var scale: float = (-fixed*x+sqrt(discriminant))/square
		if scale <= 0.0: return {}
		result.radius = float(piece.radius)*scale
		result.height = y*scale
		result.length = S_END_LENGTH
		var local := Vector2(fixed+x*scale,(-1.0 if piece.flip else 1.0)*y*scale)
		result.heading = fposmod(rad_to_deg(chord.angle()-local.angle()),360.0)
		if endpoint == 0: result.position = [target.x,target.y]
		return result if validate(result).is_empty() else {}
	var factor: float = chord.length()/old_chord.length()
	result.heading = fposmod(float(piece.heading)+rad_to_deg(old_chord.angle_to(chord)),360.0)
	result.length = 0.0 if piece.kind == "curve" else float(piece.length)*factor
	if piece.has("height"): result.height = float(piece.height)*factor
	if piece.kind not in ["straight","bridge"]: result.radius = float(piece.radius)*factor
	if endpoint == 0: result.position = [target.x,target.y]
	return result if validate(result).is_empty() else {}


static func snap_endpoint(target: Vector2, pieces: Array, exclude: int) -> Vector2:
	var best: float = SNAP_DISTANCE
	var result: Vector2 = target
	var topology: Dictionary = prepare_endpoints(pieces)
	for i: int in range(pieces.size()):
		if i == exclude: continue
		for endpoint: int in range(2):
			if not _matches(topology,i,endpoint,exclude).is_empty(): continue
			var position: Vector2 = topology.poses[i*2+endpoint].position
			var distance: float = target.distance_to(position)
			if distance < best:
				best = distance
				result = position
	return result


static func joins(pieces: Array, topology: Dictionary = {}) -> Array[Dictionary]:
	if topology.is_empty(): topology = prepare_endpoints(pieces)
	var issues: Array[Dictionary] = []
	for index: int in range(pieces.size()):
		for endpoint: int in range(2):
			var matches: Array = _matches(topology,index,endpoint)
			if matches.size() == 1: continue
			issues.append({"index":index,"endpoint":endpoint,"position":topology.poses[index*2+endpoint].position,
				"message":"Open road end" if matches.is_empty() else "More than two sections meet here"})
	return issues


static func connected_route(pieces: Array) -> Dictionary:
	var fail: Dictionary = {"ok":false,"points":PackedVector2Array(),"widths":PackedFloat32Array(),"errors":["Connect the road ends to make one closed lap."]}
	var topology: Dictionary = prepare_endpoints(pieces)
	if pieces.size() < 2 or not joins(pieces,topology).is_empty(): return fail
	var points := PackedVector2Array()
	var widths := PackedFloat32Array()
	var visited: Array[int] = []
	var index: int = 0
	var endpoint: int = 0
	while index not in visited:
		visited.append(index)
		var geometry: Dictionary = section_geometry(pieces,index,topology)
		var section: PackedVector2Array = geometry.points
		var section_widths: PackedFloat32Array = geometry.widths
		if endpoint == 1:
			section.reverse()
			section_widths.reverse()
		for i: int in range(section.size()-1):
			points.append(section[i])
			widths.append(section_widths[i])
		var partner: Array = _matches(topology,index,1-endpoint)[0]
		index = int(partner[0])
		endpoint = int(partner[1])
	if index != 0 or endpoint != 0 or visited.size() != pieces.size(): return fail
	return {"ok":true,"points":points,"widths":widths,"errors":[]}


static func route_from_pieces(document: Dictionary) -> Dictionary:
	var route: Dictionary = connected_route(document.pieces)
	if not route.ok: return {"ok":false,"document":document.duplicate(true),"errors":route.errors}
	var doc: Dictionary = document.duplicate(true)
	var points: PackedVector2Array = route.points
	var widths: PackedFloat32Array = route.widths
	var length: float = TrackDocument.route_length(points)
	if length < 40.0 or length > 1600.0: return {"ok":false,"document":doc,"errors":["Keep the complete lap between 40 and 1600 metres."]}
	var count: int = clampi(floori(length/2.5),4,TrackDocument.MAX_POINTS)
	doc.points = []
	doc.widths = []
	doc.corners = []
	var segment: int = 0
	var traveled: float = 0.0
	for i: int in range(count):
		var target: float = length*float(i)/count
		var span: float = points[segment].distance_to(points[(segment+1)%points.size()])
		while traveled+span < target and segment < points.size()-1:
			traveled += span
			segment += 1
			span = points[segment].distance_to(points[(segment+1)%points.size()])
		var blend: float = clampf((target-traveled)/maxf(span,0.0001),0.0,1.0)
		var point: Vector2 = points[segment].lerp(points[(segment+1)%points.size()],blend)
		doc.points.append([point.x,point.y])
		doc.widths.append(widths[segment])
		doc.corners.append("sharp")
	doc.route_override = true
	var errors: Array[String] = TrackDocument.validate(doc)
	return {"ok":errors.is_empty(),"document":doc,"errors":errors}


static func _number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))


static func barrier_run(document: Dictionary, start: Vector2, finish: Vector2, kind: String = "barrier", scale: float = 1.0) -> Array:
	var result: Array = []
	if kind not in CreatorObjects.KINDS: return result
	var capacity: int = maxi(0,96-document.objects.size())
	if capacity == 0: return result
	var candidates: Array[Dictionary] = _paths(document.pieces)
	if not document.layout.is_empty():
		var layout: Dictionary = TrackDocument.route_data(document.layout)
		candidates.append({"points":layout.points,"widths":layout.widths,"closed":true})
	for stroke: Dictionary in document.paint:
		if int(stroke.surface) not in [0,2] or stroke.get("mode","free") == "area" or stroke.points.size() < 2: continue
		var path: PackedVector2Array = SurfacePaint.contour(stroke.points,str(stroke.get("mode","free")))
		var widths := PackedFloat32Array()
		widths.resize(path.size()); widths.fill(float(stroke.width))
		candidates.append({"points":path,"widths":widths,"closed":false})
	if candidates.is_empty(): return result
	var best: Dictionary = {}
	var score: float = INF
	for path: Dictionary in candidates:
		var a: Dictionary = _nearest(path,start)
		var b: Dictionary = _nearest(path,finish)
		if float(a.distance)+float(b.distance) < score:
			score = float(a.distance)+float(b.distance)
			best = {"path":path,"a":a,"b":b}
	if best.is_empty(): return result
	var path: Dictionary = best.path
	var length: float = _path_length(path)
	var begin: float = float(best.a.along)
	var delta: float = float(best.b.along)-begin
	if path.closed and absf(delta) > length*0.5: delta -= signf(delta)*length
	var anchor: Dictionary = _at(path,begin)
	var tangent: Vector2 = anchor.tangent
	var side: float = 1.0 if tangent.cross(start-Vector2(anchor.point)) >= 0.0 else -1.0
	var dimensions: Vector2 = CreatorObjects.dimensions(kind)
	if kind in ["tyre_stack","tyre_wall"]: scale = 1.0
	dimensions *= scale
	if path.get("spline",false) and kind in ObjectRuns.CONTINUOUS:
		return ObjectRuns.build(RoadsideBoundary.run(path,begin,delta,side,dimensions.y*0.5+0.8,dimensions.x),kind,scale,capacity)
	if absf(delta) < 0.01:
		var center: Vector2 = Vector2(anchor.point)+Vector2(-tangent.y,tangent.x)*side*(float(anchor.width)*0.5+dimensions.y*0.5+0.8)
		if center.abs().x <= 110.0 and center.abs().y <= 110.0:
			var object: Dictionary = {"kind":kind,"position":[center.x,center.y],"rotation":fposmod(rad_to_deg(tangent.angle()),360.0)}
			if scale != 1.0: object["scale"] = scale
			result.append(object)
		return result
	var offset_points := PackedVector2Array()
	var edge_points: PackedVector2Array = _offset_edge(path,side,dimensions.y*0.5+0.8)
	var count: int = maxi(1,ceili(absf(delta)/0.75))
	for i: int in range(count+1):
		var sample: Dictionary = _at(path,begin+delta*float(i)/count)
		var index: int = sample.index
		offset_points.append(edge_points[index].lerp(edge_points[(index+1)%edge_points.size()],float(sample.blend)))
	return ObjectRuns.build(offset_points,kind,scale,capacity)


static func _offset_edge(path: Dictionary, side: float, clearance: float) -> PackedVector2Array:
	var points: PackedVector2Array = path.points
	var result := PackedVector2Array()
	for i: int in range(points.size()):
		var previous: int = (i-1+points.size())%points.size()
		var next: int = (i+1)%points.size()
		var incoming: Vector2 = (points[i]-points[previous]).normalized()
		var outgoing: Vector2 = (points[next]-points[i]).normalized()
		if not path.closed and i == 0: incoming = outgoing
		if not path.closed and i == points.size()-1: outgoing = incoming
		var first := Vector2(-incoming.y,incoming.x)
		var second := Vector2(-outgoing.y,outgoing.x)
		var normal: Vector2 = (first+second).normalized()
		if normal.is_zero_approx(): normal = first
		var reach: float = (float(path.widths[i])*0.5+clearance)/maxf(0.5,normal.dot(first))
		result.append(points[i]+normal*side*reach)
	return result


static func _paths(pieces: Array) -> Array[Dictionary]:
	var paths: Array[Dictionary] = []
	var visited: Array[int] = []
	var topology: Dictionary = prepare_endpoints(pieces)
	# Open chains first, then remaining closed chains. Intersections in the
	# surface do not silently switch the selected road at a crossing.
	for open_only: bool in [true,false]:
		for seed: int in range(pieces.size()):
			if seed in visited: continue
			var start_end: int = 0
			if open_only:
				if _matches(topology,seed,0).is_empty(): start_end = 0
				elif _matches(topology,seed,1).is_empty(): start_end = 1
				else: continue
			var points := PackedVector2Array()
			var widths := PackedFloat32Array()
			var nodes: Array[int] = []
			var index: int = seed
			var endpoint: int = start_end
			var closed: bool = false
			var has_spline: bool = false
			while index not in visited:
				visited.append(index)
				has_spline = has_spline or pieces[index].kind == "spline"
				var geometry: Dictionary = section_geometry(pieces,index,topology)
				var section: PackedVector2Array = geometry.points
				var section_widths: PackedFloat32Array = geometry.widths
				var section_nodes: Array = geometry.get("node_indices",[0,section.size()-1])
				if endpoint == 1:
					section.reverse()
					section_widths.reverse()
					var reversed_nodes: Array[int] = []
					for node: int in section_nodes: reversed_nodes.append(section.size()-1-node)
					section_nodes = reversed_nodes
				for section_index: int in range(section.size()):
					var point: Vector2 = section[section_index]
					if not points.is_empty() and points[-1].distance_to(point) < 0.01: continue
					points.append(point)
					widths.append(section_widths[section_index])
					if section_index in section_nodes: nodes.append(points.size()-1)
				var matches: Array = _matches(topology,index,1-endpoint)
				if matches.size() != 1: break
				index = int(matches[0][0])
				endpoint = int(matches[0][1])
				if index == seed and endpoint == start_end: closed = true
			if closed and points[0].distance_to(points[-1]) < 0.01:
				points.resize(points.size()-1)
				widths.resize(widths.size()-1)
			paths.append({"points":points,"widths":widths,"closed":closed,"spline":has_spline,"node_indices":nodes})
	return paths


static func _path_length(path: Dictionary) -> float:
	var length: float = 0.0
	var points: PackedVector2Array = path.points
	for i: int in range(points.size() if path.closed else points.size()-1):
		length += points[i].distance_to(points[(i+1)%points.size()])
	return length


static func _nearest(path: Dictionary, point: Vector2) -> Dictionary:
	var result: Dictionary = {"distance":INF,"along":0.0}
	var traveled: float = 0.0
	var points: PackedVector2Array = path.points
	for i: int in range(points.size() if path.closed else points.size()-1):
		var a: Vector2 = points[i]
		var b: Vector2 = points[(i+1)%points.size()]
		var nearest: Vector2 = Geometry2D.get_closest_point_to_segment(point,a,b)
		var distance: float = nearest.distance_to(point)
		if distance < float(result.distance): result = {"distance":distance,"along":traveled+a.distance_to(nearest)}
		traveled += a.distance_to(b)
	return result


static func _at(path: Dictionary, along: float) -> Dictionary:
	var points: PackedVector2Array = path.points
	var widths: PackedFloat32Array = path.widths
	var total: float = _path_length(path)
	var target: float = fposmod(along,total) if path.closed and total > 0.0 else clampf(along,0.0,total)
	var traveled: float = 0.0
	var segments: int = points.size() if path.closed else points.size()-1
	for i: int in range(segments):
		var next: int = (i+1)%points.size()
		var span: float = points[i].distance_to(points[next])
		if traveled+span >= target or i == segments-1:
			var blend: float = clampf((target-traveled)/maxf(span,0.0001),0.0,1.0)
			return {"point":points[i].lerp(points[next],blend),"tangent":(points[next]-points[i]).normalized(),"width":lerpf(widths[i],widths[next],blend),"index":i,"blend":blend}
		traveled += span
	return {"point":points[0],"tangent":Vector2.RIGHT,"width":widths[0],"index":0,"blend":0.0}


## Shared width samples for surface compilation and presentation.
static func endpoint_width(piece: Dictionary, endpoint: int) -> float:
	if piece.kind == "spline": return float(piece.point_widths[0 if endpoint == 0 else 4])
	return float(piece.width) if endpoint == 0 else float(piece.get("narrow_width",piece.width))

static func section_geometry(pieces: Array, index: int, topology: Dictionary = {}) -> Dictionary:
	if topology.is_empty(): topology = prepare_endpoints(pieces)
	var piece: Dictionary = pieces[index]
	var spline: Dictionary = SplineRoad.geometry(piece) if piece.kind == "spline" else {}
	var points: PackedVector2Array = spline.points if not spline.is_empty() else samples(piece)
	var widths := PackedFloat32Array()
	var distances := PackedFloat32Array([0.0])
	for i: int in range(1,points.size()): distances.append(distances[-1]+points[i-1].distance_to(points[i]))
	var total: float = distances[-1]
	var authored_ends: Array[float] = [endpoint_width(piece,0),endpoint_width(piece,1)]
	var ends: Array[float] = authored_ends.duplicate()
	for endpoint: int in range(2):
		var matches: Array = _matches(topology,index,endpoint)
		if matches.size() == 1:
			var other: Dictionary = pieces[int(matches[0][0])]
			var other_width: float = endpoint_width(other,int(matches[0][1]))
			ends[endpoint] = (authored_ends[endpoint]+other_width)*0.5
	var reach: float = minf(total*0.5,maxf(8.0,absf(ends[1]-ends[0])*4.0))
	for sample_index: int in range(distances.size()):
		var distance: float = distances[sample_index]
		var fraction: float = distance/maxf(total,0.0001)
		var width: float = float(spline.widths[sample_index]) if not spline.is_empty() else lerpf(authored_ends[0],authored_ends[1],fraction)
		if not spline.is_empty():
			# Match joined mouths without changing the three internal point widths.
			var entry_reach: float = minf(reach,distances[spline.node_indices[1]])
			var exit_reach: float = minf(reach,total-distances[spline.node_indices[3]])
			if ends[0] != authored_ends[0]: width = lerpf(ends[0],width,smoothstep(0.0,entry_reach,distance))
			if ends[1] != authored_ends[1]: width = lerpf(ends[1],width,smoothstep(0.0,exit_reach,total-distance))
		else:
			width += (ends[0]-authored_ends[0])*(1.0-smoothstep(0.0,reach,distance))
			width += (ends[1]-authored_ends[1])*(1.0-smoothstep(0.0,reach,total-distance))
		widths.append(width)
	var result: Dictionary = {"points":points,"widths":widths}
	if not spline.is_empty(): result["node_indices"] = spline.node_indices
	return result


## Both sides of a join use the same cross-section, even for reversed pieces.
static func section_outline(pieces: Array, index: int, margin: float = 0.0, topology: Dictionary = {}) -> PackedVector2Array:
	if topology.is_empty(): topology = prepare_endpoints(pieces)
	var geometry: Dictionary = section_geometry(pieces,index,topology)
	var points: PackedVector2Array = geometry.points
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	for i: int in range(points.size()):
		var tangent: Vector2 = (points[mini(i+1,points.size()-1)]-points[maxi(0,i-1)]).normalized()
		if pieces[index].kind == "taper": tangent = Vector2.RIGHT.rotated(deg_to_rad(float(pieces[index].heading)))
		if i == 0: tangent = Vector2.RIGHT.rotated(deg_to_rad(float(_pose(pieces[index],0).heading)))
		if i == points.size()-1: tangent = Vector2.RIGHT.rotated(deg_to_rad(float(end_pose(pieces[index]).heading)))
		var normal := Vector2(-tangent.y,tangent.x)
		var center: Vector2 = points[i]
		if i == 0 or i == points.size()-1:
			var endpoint: int = 0 if i == 0 else 1
			var matches: Array = _matches(topology,index,endpoint)
			if matches.size() == 1:
				var pose: Dictionary = topology.poses[int(matches[0][0])*2+int(matches[0][1])]
				var other: Vector2 = Vector2.RIGHT.rotated(deg_to_rad(float(pose.heading))) * (-1.0 if endpoint == 0 else 1.0)
				var shared: Vector2 = (normal+Vector2(-other.y,other.x)).normalized()
				normal = shared/maxf(0.25,shared.dot(normal))
				center = center.lerp(pose.position,0.5)
		left.append(center+normal*(float(geometry.widths[i])*0.5+margin))
		right.append(center-normal*(float(geometry.widths[i])*0.5+margin))
	right.reverse()
	return left+right


## Resolve road geometry independently from the authored lap-route direction.
static func road_frame(pieces: Array, point: Vector2, forward: Vector2) -> Dictionary:
	var best: Dictionary = {}
	var distance: float = INF
	var topology: Dictionary = prepare_endpoints(pieces)
	for index: int in range(pieces.size()):
		var geometry: Dictionary = section_geometry(pieces,index,topology)
		var path: Dictionary = {"points":geometry.points,"widths":geometry.widths,"closed":false}
		var nearest: Dictionary = _nearest(path,point)
		if float(nearest.distance) >= distance: continue
		distance = nearest.distance
		best = _at(path,nearest.along)
		if Vector2(best.tangent).dot(forward) < 0.0: best.tangent = -Vector2(best.tangent)
	return best if distance <= float(best.get("width",0.0))*0.5 else {}
