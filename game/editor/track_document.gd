class_name TrackDocument
extends RefCounted
## Bounded JSON authoring contract. No scripts, images, paths or engine objects.

const SCHEMA: String = "creator-track-v2"
const THEMES: Array[String] = ["pine", "coast", "desert"]
const MAX_POINTS: int = 24
const MAX_BYTES: int = 16384
const MAX_COORD: float = 120.0
const KEYS: Array[String] = ["schema", "id", "name", "creator", "theme", "width", "surface", "points", "widths", "corners", "objects"]


static func create_default() -> Dictionary:
	return {"schema": SCHEMA, "id": "my_track", "name": "My circuit", "theme": "pine", "width": 10.0,
		"surface": "asphalt", "points": [[-38.0,-12.0],[-25.0,22.0],[12.0,28.0],[39.0,9.0],[25.0,-25.0],[-10.0,-28.0]],
		"widths":[10.0,10.0,10.0,10.0,10.0,10.0], "corners":["smooth","smooth","smooth","smooth","smooth","smooth"], "objects":[]}


static func valid_id(value: Variant) -> bool:
	if not value is String or value.length() < 1 or value.length() > 48:
		return false
	for character: String in value:
		if character not in "abcdefghijklmnopqrstuvwxyz0123456789_":
			return false
	if value in ["con", "prn", "aux", "nul"]:
		return false
	if value.length() == 4 and value.left(3) in ["com", "lpt"] and value.right(1) in "123456789":
		return false
	return true


static func validate(data: Variant) -> Array[String]:
	var errors: Array[String] = []
	if not data is Dictionary:
		return ["Choose a creator track JSON file."]
	for key: Variant in data:
		if not key is String or key not in KEYS:
			return ["This file contains unsupported track data."]
	if data.get("schema") != SCHEMA:
		errors.append("This track format is not supported.")
	if not valid_id(data.get("id")):
		errors.append("The track identifier is invalid.")
	var title: Variant = data.get("name")
	if not title is String or title.strip_edges().is_empty() or title.length() > 40:
		errors.append("Give the track a name of 1 to 40 characters.")
	elif _has_control(title):
		errors.append("The name cannot contain control characters.")
	if data.has("creator"):
		var creator: Variant = data.creator
		if not creator is String or creator.strip_edges().is_empty() or creator.length() > 40:
			errors.append("Use a creator name of 1 to 40 characters.")
		elif _has_control(creator):
			errors.append("The creator name cannot contain control characters.")
	if data.get("theme") not in THEMES:
		errors.append("Choose Pine, Coast or Desert.")
	if data.get("surface") not in ["asphalt", "dirt"]:
		errors.append("Choose asphalt or dirt for the road.")
	var width: Variant = data.get("width")
	if not _number(width) or float(width) < 6.0 or float(width) > 20.0:
		errors.append("Road width must be between 6 and 20 metres.")
	var points: Variant = data.get("points")
	if not points is Array or points.size() < 4 or points.size() > MAX_POINTS:
		errors.append("Use 4 to 24 route points.")
		return errors
	for point: Variant in points:
		if not point is Array or point.size() != 2 or not _number(point[0]) or not _number(point[1]):
			errors.append("Every route point must contain two finite numbers.")
			return errors
		if absf(float(point[0])) > MAX_COORD or absf(float(point[1])) > MAX_COORD:
			errors.append("Keep the route within the editing area.")
			return errors
	if data.get("schema") == SCHEMA:
		for field: String in ["widths", "corners"]:
			if not data.get(field) is Array or data[field].size() != points.size():
				return ["Every road node needs its own width and corner shape."]
		for value: Variant in data.widths:
			if not _number(value) or float(value) < 6.0 or float(value) > 20.0:
				return ["Node widths must be between 6 and 20 metres."]
		for value: Variant in data.corners:
			if value not in ["smooth", "sharp"]: return ["Choose a smooth or sharp corner."]
		if not data.get("objects") is Array or data.objects.size() > 96:
			return ["Use up to 96 placed objects."]
		for object: Variant in data.objects:
			if not object is Dictionary or object.size() != 3 or object.get("kind") not in CreatorObjects.KINDS:
				return ["Choose an object from the built-in palette."]
			if not object.get("position") is Array or object.position.size() != 2:
				return ["Object positions need two coordinates."]
			for value: Variant in object.position:
				if not _number(value) or absf(float(value)) > 110.0: return ["Keep objects inside the editing area."]
			if not _number(object.get("rotation")) or float(object.rotation) < 0 or float(object.rotation) >= 360:
				return ["Object rotation must be between 0 and 359 degrees."]
	if not errors.is_empty():
		return errors
	for i: int in range(points.size()):
		if _point(points[i]).distance_to(_point(points[(i+1) % points.size()])) < 2.0:
			return ["Move neighbouring points at least 2 metres apart."]
		for j: int in range(i+2,points.size()):
			if i == 0 and j == points.size()-1:
				continue
			if Geometry2D.segment_intersects_segment(_point(points[i]),_point(points[(i+1)%points.size()]),_point(points[j]),_point(points[(j+1)%points.size()])) != null:
				return ["Separate nearby road sections; crossings and overlapping roads are not supported."]
	var route: PackedVector2Array = smooth_points(data)
	var length: float = route_length(route)
	if length < 40.0 or length > 750.0:
		return ["Keep the complete route between 40 and 750 metres."]
	# Tight turns and touching shoulders are legitimate authoring choices.
	# Reject a genuinely crossing centreline, including spline overshoot.
	for i: int in range(route.size()):
		for j: int in range(i+2,route.size()):
			if i == 0 and j == route.size()-1: continue
			if Geometry2D.segment_intersects_segment(route[i],route[(i+1)%route.size()],route[j],route[(j+1)%route.size()]) != null:
				return ["The road crosses itself. Move a node or make that corner sharp."]
	return errors


static func node_width(document: Dictionary, index: int) -> float:
	return float(document.widths[index])


static func smooth_points(document: Dictionary) -> PackedVector2Array:
	return route_data(document).points


static func route_data(document: Dictionary) -> Dictionary:
	var points: Array = document.points
	var dense := PackedVector2Array()
	var widths := PackedFloat32Array()
	var sharp_indices: Array[int] = []
	for i: int in range(points.size()):
		var a: Vector2 = _point(points[posmod(i-1, points.size())])
		var b: Vector2 = _point(points[i])
		var c: Vector2 = _point(points[(i+1) % points.size()])
		var d: Vector2 = _point(points[(i+2) % points.size()])
		var start_sharp: bool = document.corners[i] == "sharp"
		var end_sharp: bool = document.corners[(i+1)%points.size()] == "sharp"
		if start_sharp: sharp_indices.append(dense.size())
		var steps: int = clampi(ceili(b.distance_to(c) * 2.0), 12, 600)
		for step: int in range(steps):
			var t: float = float(step) / steps
			if not start_sharp and not end_sharp:
				dense.append((b*2.0 + (c-a)*t + (a*2.0-b*5.0+c*4.0-d)*t*t + (-a+b*3.0-c*3.0+d)*t*t*t)*0.5)
			else:
				var outgoing: Vector2 = c-b if start_sharp else (c-a)*0.5
				var incoming: Vector2 = c-b if end_sharp else (d-b)*0.5
				dense.append(b*(2*t*t*t-3*t*t+1)+outgoing*(t*t*t-2*t*t+t)+c*(-2*t*t*t+3*t*t)+incoming*(t*t*t-t*t))
			widths.append(lerpf(node_width(document,i),node_width(document,(i+1)%points.size()),t))
	var length: float = route_length(dense)
	var count: int = maxi(4, ceili(length))
	var targets: Array[float] = []
	for index: int in range(count): targets.append(length*index/count)
	var distance: float = 0.0
	for i: int in range(dense.size()):
		if i in sharp_indices: targets.append(distance)
		distance += dense[i].distance_to(dense[(i+1)%dense.size()])
	targets.sort()
	var result := PackedVector2Array()
	var result_widths := PackedFloat32Array()
	var segment: int = 0
	var traveled: float = 0.0
	for target: float in targets:
		var next: int = (segment+1) % dense.size()
		var span: float = dense[segment].distance_to(dense[next])
		while traveled + span < target and segment < dense.size()-1:
			traveled += span
			segment += 1
			next = (segment+1) % dense.size()
			span = dense[segment].distance_to(dense[next])
		var blend: float = clampf((target-traveled)/maxf(span,0.0001),0.0,1.0)
		var point: Vector2 = dense[segment].lerp(dense[next],blend)
		if not result.is_empty() and result[-1].distance_to(point) < 0.01: continue
		result.append(point)
		result_widths.append(lerpf(widths[segment],widths[next],blend))
	return {"points":result,"widths":result_widths}


static func route_length(route: PackedVector2Array) -> float:
	var length: float = 0.0
	for i: int in range(route.size()):
		length += route[i].distance_to(route[(i+1) % route.size()])
	return length


static func _point(value: Array) -> Vector2:
	return Vector2(float(value[0]), float(value[1]))


static func _number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))


static func _has_control(value: String) -> bool:
	for i: int in range(value.length()):
		if value.unicode_at(i) < 32 or value.unicode_at(i) == 127:
			return true
	return false
