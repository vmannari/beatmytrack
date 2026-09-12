class_name TrackDocument
extends RefCounted
## Bounded JSON authoring contract. No scripts, images, paths or engine objects.

const SCHEMA: String = "creator-track-v1"
const THEMES: Array[String] = ["pine", "coast", "desert"]
const MAX_POINTS: int = 24
const MAX_BYTES: int = 16384
const MAX_COORD: float = 120.0
const KEYS: Array[String] = ["schema", "id", "name", "theme", "width", "surface", "points"]


static func create_default() -> Dictionary:
	return {"schema": SCHEMA, "id": "my_track", "name": "My circuit", "theme": "pine", "width": 10.0,
		"surface": "asphalt", "points": [[-38.0,-12.0],[-25.0,22.0],[12.0,28.0],[39.0,9.0],[25.0,-25.0],[-10.0,-28.0]]}


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
	if data.get("theme") not in THEMES:
		errors.append("Choose Pine, Coast or Desert.")
	if data.get("surface") not in ["asphalt", "dirt"]:
		errors.append("Choose asphalt or dirt for the road.")
	var width: Variant = data.get("width")
	if not _number(width) or float(width) < 8.0 or float(width) > 14.0:
		errors.append("Road width must be between 8 and 14 metres.")
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
	if not errors.is_empty():
		return errors
	for i: int in range(points.size()):
		if _point(points[i]).distance_to(_point(points[(i+1) % points.size()])) < 8.0:
			return ["Move neighbouring points at least 8 metres apart."]
		for j: int in range(i+2,points.size()):
			if i == 0 and j == points.size()-1:
				continue
			if Geometry2D.segment_intersects_segment(_point(points[i]),_point(points[(i+1)%points.size()]),_point(points[j]),_point(points[(j+1)%points.size()])) != null:
				return ["Separate nearby road sections; crossings and overlapping roads are not supported."]
	var route: PackedVector2Array = smooth_points(data)
	var length: float = route_length(route)
	if length < 110.0 or length > 750.0:
		return ["Keep the complete route between 110 and 750 metres."]
	# Curvature is checked on the same sampled line used to build the road.
	for i: int in range(route.size()):
		var a: Vector2 = route[posmod(i-2, route.size())]
		var b: Vector2 = route[i]
		var c: Vector2 = route[(i+2) % route.size()]
		var cross: float = absf((b-a).cross(c-a))
		if cross <= 0.001 and (b-a).dot(c-b) < 0.0:
			return ["Open up the sharp bend so the car has room to turn."]
		if cross > 0.001:
			var radius: float = a.distance_to(b) * b.distance_to(c) * c.distance_to(a) / (2.0 * cross)
			if radius < float(width) * 0.65:
				return ["Open up the sharp bend so the car has room to turn."]
	# Uniform samples bound work independently of pointer-event rate. Ignore
	# only nearby positions on this route, never another branch of a crossing.
	var clearance: float = float(width) + 2.0
	var local_span: int = ceili(clearance * 1.7)
	for i: int in range(route.size()):
		for j: int in range(i+2, route.size()):
			var separation: int = mini(j-i, route.size()-(j-i))
			if separation <= local_span:
				continue
			var a: Vector2 = route[i]
			var b: Vector2 = route[j]
			if absf(a.x-b.x) >= clearance or absf(a.y-b.y) >= clearance:
				continue
			if a.distance_squared_to(b) < clearance * clearance:
				return ["Separate nearby road sections; crossings and overlapping roads are not supported."]
	return errors


static func smooth_points(document: Dictionary) -> PackedVector2Array:
	# Uniform Catmull-Rom interpolation; resample at <=1 metre for the native
	# driver, validity checks, editor guide and raster compiler alike.
	var points: Array = document.points
	var dense := PackedVector2Array()
	for i: int in range(points.size()):
		var a: Vector2 = _point(points[posmod(i-1, points.size())])
		var b: Vector2 = _point(points[i])
		var c: Vector2 = _point(points[(i+1) % points.size()])
		var d: Vector2 = _point(points[(i+2) % points.size()])
		var steps: int = clampi(ceili(b.distance_to(c) * 2.0), 12, 600)
		for step: int in range(steps):
			var t: float = float(step) / steps
			dense.append((b*2.0 + (c-a)*t + (a*2.0-b*5.0+c*4.0-d)*t*t + (-a+b*3.0-c*3.0+d)*t*t*t)*0.5)
	var length: float = route_length(dense)
	var count: int = maxi(4, ceili(length))
	var result := PackedVector2Array()
	var segment: int = 0
	var traveled: float = 0.0
	for index: int in range(count):
		var target: float = length * index / count
		var next: int = (segment+1) % dense.size()
		var span: float = dense[segment].distance_to(dense[next])
		while traveled + span < target and segment < dense.size()-1:
			traveled += span
			segment += 1
			next = (segment+1) % dense.size()
			span = dense[segment].distance_to(dense[next])
		result.append(dense[segment].lerp(dense[next], clampf((target-traveled)/maxf(span,0.0001),0.0,1.0)))
	return result


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
