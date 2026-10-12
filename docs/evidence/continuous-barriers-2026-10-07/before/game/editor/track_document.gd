class_name TrackDocument
extends RefCounted
## Bounded JSON authoring contract. No scripts, images, paths or engine objects.

const SCHEMA: String = "creator-track-v5"
const THEMES: Array[String] = TrackTheme.IDS
const MAX_POINTS: int = 96
const MAX_BYTES: int = 524288
const MAX_COORD: float = 120.0
const KEYS: Array[String] = ["schema", "id", "name", "creator", "theme", "width", "surface", "points", "widths", "corners", "objects", "layout", "paint", "base_track", "route_override", "pieces", "practice_start", "start_line", "hidden_scenery"]


static func create_default() -> Dictionary:
	var doc: Dictionary = {"schema": SCHEMA, "id": "my_track", "name": "My circuit", "theme": "pine", "width": 10.0,
		"surface": "asphalt", "points": [[-38.0,-12.0],[-25.0,22.0],[12.0,28.0],[39.0,9.0],[25.0,-25.0],[-10.0,-28.0]],
		"widths":[10.0,10.0,10.0,10.0,10.0,10.0], "corners":["smooth","smooth","smooth","smooth","smooth","smooth"], "objects":[], "layout":{}, "paint":[], "base_track":"", "route_override":true, "pieces":[]}
	doc.layout = road_layout(doc)
	return doc


static func create_blank() -> Dictionary:
	var doc: Dictionary = create_default()
	doc.layout = {}
	return doc


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


static func validate(data: Variant, require_race_route: bool = true) -> Array[String]:
	var errors: Array[String] = []
	if not data is Dictionary:
		return ["Choose a creator track JSON file."]
	for key: Variant in data:
		if not key is String or key not in KEYS:
			return ["This file contains unsupported track data."]
	if data.get("schema") != SCHEMA:
		errors.append("This track format is not supported.")
	if data.has("hidden_scenery"):
		if not data.hidden_scenery is Array or data.hidden_scenery.size() > 256: return ["Too many removed scenery trees."]
		for key: Variant in data.hidden_scenery:
			if not key is String or key.length() > 40: return ["Invalid scenery identifier."]
	for pose_key: String in ["practice_start","start_line"]:
		if not data.has(pose_key): continue
		var start: Variant = data[pose_key]
		if not start is Dictionary or start.size() != 2 or not start.has_all(["position","heading"]):
			return ["The start needs a position and heading."]
		if not start.position is Array or start.position.size() != 2:
			return ["The start needs two coordinates."]
		for value: Variant in start.position:
			if not _number(value) or absf(float(value)) > 110.0:
				return ["Keep the start inside the editing area."]
		if not _number(start.heading) or float(start.heading) < 0.0 or float(start.heading) >= 360.0:
			return ["Start heading must be between 0 and 359 degrees."]
	if not data.get("pieces") is Array or data.pieces.size() > RoadPieces.MAX_PIECES:
		return ["Use up to 96 road sections."]
	var piece_length: float = 0.0
	for piece: Variant in data.pieces:
		var piece_errors: Array[String] = RoadPieces.validate(piece)
		if not piece_errors.is_empty(): return piece_errors
		var section: PackedVector2Array = RoadPieces.samples(piece)
		for i: int in range(1,section.size()): piece_length += section[i-1].distance_to(section[i])
	if piece_length > 4000.0: return ["Use up to 4000 metres of road sections."]
	var bridge_errors: Array[String] = CreatorBridges.validate(data.pieces,data.get("base_track", "") if data.get("base_track") is String else "")
	if not bridge_errors.is_empty(): return bridge_errors
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
	if not data.get("theme") is String or (data.theme not in THEMES and data.theme != "coast"):
		errors.append("Choose Grass, Desert, Night, Winter or Storm.")
	if data.get("surface") not in ["asphalt", "dirt"]:
		errors.append("Choose asphalt or dirt for the road.")
	var width: Variant = data.get("width")
	if not _number(width) or float(width) < 6.0 or float(width) > 20.0:
		errors.append("Road width must be between 6 and 20 metres.")
	var points: Variant = data.get("points")
	if not points is Array or points.size() < 4 or points.size() > MAX_POINTS:
		errors.append("Use 4 to 96 route points.")
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
			if not object is Dictionary or object.size() != 3+(1 if object.has("scale") else 0) or not object.get("kind") is String or object.kind not in CreatorObjects.KINDS:
				return ["Choose an object from the built-in palette."]
			if object.has("scale"):
				if not _number(object.scale) or float(object.scale) < 0.5 or float(object.scale) > 3.0: return ["Object scale must be 0.5 to 3 times."]
				if object.kind in ["tyre_wall","tyre_stack"] and float(object.scale) != 1.0: return ["Tyre stacks use their physical size; extend the line instead."]
				if object.kind in CreatorCatalog.DECORATIVE and float(object.scale)>1.5: return ["Decorative objects are limited to 1.5x size."]
			if not object.get("position") is Array or object.position.size() != 2:
				return ["Object positions need two coordinates."]
			for value: Variant in object.position:
				if not _number(value) or absf(float(value)) > 110.0: return ["Keep objects inside the editing area."]
			if not _number(object.get("rotation")) or float(object.rotation) < 0 or float(object.rotation) >= 360:
				return ["Object rotation must be between 0 and 359 degrees."]
	if not data.get("route_override") is bool or not data.get("base_track") is String:
		return ["Choose a built-in base and route mode."]
	if data.base_track != "" and BuiltinTracks.metadata(data.base_track).is_empty():
		return ["This built-in base is not available."]
	if not data.get("layout") is Dictionary: return ["The road layout is invalid."]
	if not data.layout.is_empty():
		if data.layout.size() != 4 or not data.layout.has_all(["points","widths","corners","surface"]): return ["The road layout is invalid."]
		var road: Dictionary = data.duplicate(true)
		road.merge(data.layout,true)
		road.layout = {}
		road.paint = []
		road.base_track = ""
		road.route_override = true
		var road_errors: Array[String] = validate(road)
		if not road_errors.is_empty(): return road_errors
	if not data.get("paint") is Array or data.paint.size() > 256: return ["Use up to 256 paint strokes; undo a stroke or start a new map."]
	var painted_points: int = 0
	for stroke: Variant in data.paint:
		if not stroke is Dictionary or stroke.size() != 4 + (1 if stroke.has("protect_road") else 0) + (1 if stroke.has("mode") else 0) or not stroke.has_all(["surface","width","shape","points"]): return ["Invalid paint stroke."]
		if stroke.has("protect_road") and not stroke.protect_road is bool: return ["Road protection must be on or off."]
		if not _number(stroke.surface) or float(stroke.surface) != floorf(float(stroke.surface)) or int(stroke.surface) not in range(8): return ["Choose a built-in surface."]
		if not _number(stroke.width) or float(stroke.width) < 0.5 or float(stroke.width) > 40 or stroke.shape not in ["round","square"]: return ["Use a round or square brush, 0.5 to 40 metres wide."]
		if not stroke.points is Array or stroke.points.is_empty() or stroke.points.size() > 512: return ["Paint stroke is too long."]
		if stroke.get("mode","free") not in ["free","line","area"]: return ["Choose a surface placement mode."]
		if stroke.get("mode","free") != "free" and (stroke.points.size() > 64 or stroke.points.size() < (3 if stroke.mode == "area" else 2)): return ["Use 2?64 line points or 3?64 area points."]
		painted_points += stroke.points.size()
		for point: Variant in stroke.points:
			if not point is Array or point.size() != 2: return ["Invalid paint position."]
			for value: Variant in point:
				if not _number(value) or absf(float(value)) > 110: return ["Keep paint inside the editing area."]
		if stroke.get("mode","") == "area" and not SurfacePaint.valid_area(stroke.points): return ["Use a simple enclosed surface area without crossings."]
	if painted_points > 16384: return ["The map has too many paint points."]
	if not errors.is_empty():
		return errors
	if not require_race_route: return errors
	for i: int in range(points.size()):
		if _point(points[i]).distance_to(_point(points[(i+1) % points.size()])) < 2.0:
			return ["Move neighbouring points at least 2 metres apart."]
	var route: PackedVector2Array = smooth_points(data)
	var length: float = route_length(route)
	if length < 40.0 or length > 1600.0:
		return ["Keep the complete route between 40 and 1600 metres."]
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


static func road_layout(doc: Dictionary) -> Dictionary:
	return {"points":doc.points.duplicate(true),"widths":doc.widths.duplicate(),"corners":doc.corners.duplicate(),"surface":doc.surface}

static func from_builtin(track: NativeTrack) -> Dictionary:
	var doc: Dictionary = create_default()
	doc.id = TrackLibrary.unique_id()
	doc.name = (str(track.metadata.get("title",BuiltinTracks.metadata(track.identity).get("name","Circuit")))+" remix").left(40)
	doc.theme = TrackTheme.normalized(str(track.metadata.get("theme","pine")))
	doc.base_track = track.identity
	doc.route_override = false
	doc.layout = {}
	doc.points = []
	doc.widths = []
	doc.corners = []
	var step: int = maxi(1,ceili(track.route.size()/48.0))
	for i: int in range(0,track.route.size(),step):
		if not doc.points.is_empty() and _point(doc.points[-1]).distance_to(track.route[i]) < 2.0: continue
		doc.points.append([track.route[i].x,track.route[i].y])
		doc.widths.append(10.0)
		doc.corners.append("sharp")
	while doc.points.size() > 4 and _point(doc.points[-1]).distance_to(_point(doc.points[0])) < 2.0:
		doc.points.pop_back()
		doc.widths.pop_back()
		doc.corners.pop_back()
	return doc
