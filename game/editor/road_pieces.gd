class_name RoadPieces
extends RefCounted
## Bounded, independent road sections. Heading uses Vector2 degrees (+X = 0).
## Road pieces are geometry; race routing is an explicit, separate operation.

const KINDS: Array[String] = ["straight", "curve", "s_bend", "hairpin", "bridge"]
const KEYS: Array[String] = ["kind", "position", "heading", "length", "radius", "width", "flip"]
const MAX_PIECES: int = 96
const SNAP_DISTANCE: float = 8.0
const JOIN_DISTANCE: float = 0.15
const JOIN_ANGLE: float = 2.0


static func create(kind: String, position: Vector2, heading: float = 0.0, width: float = 10.0) -> Dictionary:
	return {"kind":kind, "position":[position.x,position.y], "heading":fposmod(heading,360.0),
		"length":48.0 if kind == "bridge" else 28.0 if kind == "straight" else 8.0, "radius":12.0 if kind == "hairpin" else 16.0,
		"width":clampf(width,6.0,20.0), "flip":false}


static func validate(piece: Variant) -> Array[String]:
	if not piece is Dictionary or piece.size() != KEYS.size() or not piece.has_all(KEYS):
		return ["Invalid road section."]
	if piece.kind not in KINDS: return ["Choose Straight, Curve, S-bend or Hairpin."]
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
	var local := PackedVector2Array([Vector2.ZERO])
	var length: float = float(piece.length)
	var count: int = maxi(1,ceili(length/0.75))
	for i: int in range(1,count+1):
		if length > 0.0: local.append(Vector2(length*float(i)/count,0.0))
	var radius: float = float(piece.radius)
	var side: float = -1.0 if piece.flip else 1.0
	if piece.kind == "curve": _arc(local,radius,PI*0.5*side,0.0)
	elif piece.kind == "hairpin": _arc(local,radius,PI*side,0.0)
	elif piece.kind == "s_bend":
		_arc(local,radius,PI*0.25*side,0.0)
		_arc(local,radius,-PI*0.25*side,PI*0.25*side)
	var result := PackedVector2Array()
	var origin := Vector2(float(piece.position[0]),float(piece.position[1]))
	for point: Vector2 in local: result.append(origin+point.rotated(deg_to_rad(float(piece.heading))))
	result[-1] = end_pose(piece).position
	return result


static func _arc(points: PackedVector2Array, radius: float, angle: float, heading: float) -> void:
	var origin: Vector2 = points[-1]
	var side: float = signf(angle)
	var count: int = maxi(2,ceili(radius*absf(angle)/0.75))
	for i: int in range(1,count+1):
		var turn: float = absf(angle)*float(i)/count
		points.append(origin+Vector2(radius*sin(turn),side*radius*(1.0-cos(turn))).rotated(heading))


static func end_pose(piece: Dictionary) -> Dictionary:
	var turn: float = 90.0 if piece.kind == "curve" else (180.0 if piece.kind == "hairpin" else 0.0)
	var radius: float = float(piece.radius)
	var side: float = -1.0 if piece.flip else 1.0
	var local := Vector2(float(piece.length),0.0)
	if piece.kind == "curve": local += Vector2(radius,side*radius)
	elif piece.kind == "hairpin": local += Vector2(0.0,side*2.0*radius)
	elif piece.kind == "s_bend": local += Vector2(2.0*radius*sin(PI*0.25),side*2.0*radius*(1.0-cos(PI*0.25)))
	var origin := Vector2(float(piece.position[0]),float(piece.position[1]))
	return {"position":origin+local.rotated(deg_to_rad(float(piece.heading))), "heading":fposmod(float(piece.heading)+turn*side,360.0)}


static func _pose(piece: Dictionary, endpoint: int) -> Dictionary:
	if endpoint == 1:
		var end: Dictionary = end_pose(piece)
		return {"position":end.position,"heading":fposmod(float(end.heading)+180.0,360.0)}
	return {"position":Vector2(piece.position[0],piece.position[1]),"heading":float(piece.heading)}


static func snap(piece: Dictionary, pieces: Array, exclude: int = -1) -> Dictionary:
	var result: Dictionary = {"piece":piece.duplicate(true),"matched":false,"target_index":-1,"endpoint":-1,"distance":SNAP_DISTANCE}
	for index: int in range(pieces.size()):
		if index == exclude: continue
		for target_end: int in range(2):
			var target: Dictionary = _pose(pieces[index],target_end)
			if _partner(pieces,index,target_end,exclude).size() > 0: continue
			for endpoint: int in range(2):
				var pose: Dictionary = _pose(piece,endpoint)
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


static func _partner(pieces: Array, index: int, endpoint: int, exclude: int = -1) -> Array:
	var pose: Dictionary = _pose(pieces[index],endpoint)
	var matches: Array = []
	for other: int in range(pieces.size()):
		if other == index or other == exclude: continue
		for other_end: int in range(2):
			var candidate: Dictionary = _pose(pieces[other],other_end)
			if Vector2(pose.position).distance_to(candidate.position) > JOIN_DISTANCE: continue
			# Touching endpoints connect even at a sharp angle or width change.
			matches.append([other,other_end])
	return matches


static func move_endpoint(piece: Dictionary, endpoint: int, target: Vector2) -> Dictionary:
	var result: Dictionary = piece.duplicate(true)
	var start := Vector2(piece.position[0],piece.position[1])
	var end: Vector2 = end_pose(piece).position
	var old_chord: Vector2 = end-start
	var chord: Vector2 = target-start if endpoint == 1 else end-target
	if chord.length() < 0.01 or old_chord.length() < 0.01: return {}
	var factor: float = chord.length()/old_chord.length()
	result.heading = fposmod(float(piece.heading)+rad_to_deg(old_chord.angle_to(chord)),360.0)
	result.length = float(piece.length)*factor
	if piece.kind not in ["straight","bridge"]: result.radius = float(piece.radius)*factor
	if endpoint == 0: result.position = [target.x,target.y]
	return result if validate(result).is_empty() else {}


static func snap_endpoint(target: Vector2, pieces: Array, exclude: int) -> Vector2:
	var best: float = SNAP_DISTANCE
	var result: Vector2 = target
	for i: int in range(pieces.size()):
		if i == exclude: continue
		for endpoint: int in range(2):
			if not _partner(pieces,i,endpoint,exclude).is_empty(): continue
			var position: Vector2 = _pose(pieces[i],endpoint).position
			var distance: float = target.distance_to(position)
			if distance < best:
				best = distance
				result = position
	return result


static func joins(pieces: Array) -> Array[Dictionary]:
	var issues: Array[Dictionary] = []
	for index: int in range(pieces.size()):
		for endpoint: int in range(2):
			var matches: Array = _partner(pieces,index,endpoint)
			if matches.size() == 1: continue
			issues.append({"index":index,"endpoint":endpoint,"position":_pose(pieces[index],endpoint).position,
				"message":"Open road end" if matches.is_empty() else "More than two sections meet here"})
	return issues


static func connected_route(pieces: Array) -> Dictionary:
	var fail: Dictionary = {"ok":false,"points":PackedVector2Array(),"widths":PackedFloat32Array(),"errors":["Connect the road ends to make one closed lap."]}
	if pieces.size() < 2 or not joins(pieces).is_empty(): return fail
	var points := PackedVector2Array()
	var widths := PackedFloat32Array()
	var visited: Array[int] = []
	var index: int = 0
	var endpoint: int = 0
	while index not in visited:
		visited.append(index)
		var section: PackedVector2Array = samples(pieces[index])
		if endpoint == 1: section.reverse()
		for i: int in range(section.size()-1):
			points.append(section[i])
			widths.append(float(pieces[index].width))
		var partner: Array = _partner(pieces,index,1-endpoint)[0]
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


static func barrier_run(document: Dictionary, start: Vector2, finish: Vector2, kind: String = "barrier") -> Array:
	var result: Array = []
	if kind not in CreatorObjects.KINDS: return result
	var capacity: int = maxi(0,96-document.objects.size())
	if capacity == 0: return result
	var candidates: Array[Dictionary] = _paths(document.pieces)
	if not document.layout.is_empty():
		var layout: Dictionary = TrackDocument.route_data(document.layout)
		candidates.append({"points":layout.points,"widths":layout.widths,"closed":true})
	if candidates.is_empty():
		var guide: Dictionary = TrackDocument.route_data(document)
		candidates.append({"points":guide.points,"widths":guide.widths,"closed":true})
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
	if absf(delta) < 0.01:
		var center: Vector2 = Vector2(anchor.point)+Vector2(-tangent.y,tangent.x)*side*(float(anchor.width)*0.5+dimensions.y*0.5+0.8)
		if center.abs().x <= 110.0 and center.abs().y <= 110.0:
			result.append({"kind":kind,"position":[center.x,center.y],"rotation":fposmod(rad_to_deg(tangent.angle()),360.0)})
		return result
	var offset_points := PackedVector2Array()
	var count: int = maxi(1,ceili(absf(delta)/0.75))
	for i: int in range(count+1):
		var sample: Dictionary = _at(path,begin+delta*float(i)/count)
		var normal := Vector2(-sample.tangent.y,sample.tangent.x)
		offset_points.append(Vector2(sample.point)+normal*side*(float(sample.width)*0.5+dimensions.y*0.5+0.8))
	var offset_widths := PackedFloat32Array()
	offset_widths.resize(offset_points.size())
	offset_widths.fill(1.0)
	var offset_path: Dictionary = {"points":offset_points,"widths":offset_widths,"closed":false}
	var run_length: float = _path_length(offset_path)
	var step: float = dimensions.x+0.2
	var stamps: int = mini(capacity,maxi(1,floori(run_length/step)+1))
	for i: int in range(stamps):
		var sample: Dictionary = _at(offset_path,minf(float(i)*step,run_length))
		var center: Vector2 = sample.point
		if center.abs().x > 110.0 or center.abs().y > 110.0: continue
		result.append({"kind":kind,"position":[center.x,center.y],"rotation":fposmod(rad_to_deg(Vector2(sample.tangent).angle()),360.0)})
	return result


static func _paths(pieces: Array) -> Array[Dictionary]:
	var paths: Array[Dictionary] = []
	var visited: Array[int] = []
	# Open chains first, then remaining closed chains. Intersections in the
	# surface do not silently switch the selected road at a crossing.
	for open_only: bool in [true,false]:
		for seed: int in range(pieces.size()):
			if seed in visited: continue
			var start_end: int = 0
			if open_only:
				if _partner(pieces,seed,0).is_empty(): start_end = 0
				elif _partner(pieces,seed,1).is_empty(): start_end = 1
				else: continue
			var points := PackedVector2Array()
			var widths := PackedFloat32Array()
			var index: int = seed
			var endpoint: int = start_end
			var closed: bool = false
			while index not in visited:
				visited.append(index)
				var section: PackedVector2Array = samples(pieces[index])
				if endpoint == 1: section.reverse()
				for point: Vector2 in section:
					if not points.is_empty() and points[-1].distance_to(point) < 0.01: continue
					points.append(point)
					widths.append(float(pieces[index].width))
				var matches: Array = _partner(pieces,index,1-endpoint)
				if matches.size() != 1: break
				index = int(matches[0][0])
				endpoint = int(matches[0][1])
				if index == seed and endpoint == start_end: closed = true
			if closed and points[0].distance_to(points[-1]) < 0.01:
				points.resize(points.size()-1)
				widths.resize(widths.size()-1)
			paths.append({"points":points,"widths":widths,"closed":closed})
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
			return {"point":points[i].lerp(points[next],blend),"tangent":(points[next]-points[i]).normalized(),"width":lerpf(widths[i],widths[next],blend)}
		traveled += span
	return {"point":points[0],"tangent":Vector2.RIGHT,"width":widths[0]}
