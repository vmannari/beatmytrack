class_name CreatorStartLine
extends RefCounted
## Start position and travel direction are independent of road geometry.

static func place(document: Dictionary, target: Vector2, native: NativeTrack) -> Dictionary:
	var paths: Array[Dictionary] = []
	for piece: Dictionary in document.pieces:
		var geometry: Dictionary = SplineRoad.geometry(piece) if piece.kind == "spline" else {}
		paths.append({"points":geometry.points if not geometry.is_empty() else RoadPieces.samples(piece),"width":float(piece.width),"widths":geometry.get("widths",PackedFloat32Array()),"closed":false})
	if paths.is_empty() and native != null:
		paths.append({"points":native.route,"width":float(document.width),"closed":true})
	var best: float = INF
	var result: Dictionary = {}
	for path: Dictionary in paths:
		var points: PackedVector2Array = path.points
		for i: int in range(points.size() if path.closed else points.size()-1):
			var a: Vector2 = points[i]
			var b: Vector2 = points[(i+1)%points.size()]
			var projected: Vector2 = Geometry2D.get_closest_point_to_segment(target,a,b)
			var distance: float = target.distance_to(projected)
			var width: float = float(path.width)
			if not path.get("widths",PackedFloat32Array()).is_empty():
				width = lerpf(float(path.widths[i]),float(path.widths[i+1]),a.distance_to(projected)/maxf(a.distance_to(b),0.0001))
			if distance >= best or distance > width*0.5+3.0: continue
			best = distance
			var heading: float = fposmod(rad_to_deg((b-a).angle()),360.0)
			if document.has("start_line"):
				var direction: Vector2 = Vector2.RIGHT.rotated(deg_to_rad(float(document.start_line.heading)))
				if direction.dot(b-a) < 0: heading = fposmod(heading+180.0,360.0)
			result = {"position":[projected.x,projected.y],"heading":heading}
	return result

static func route_from_start(points: PackedVector2Array, widths: PackedFloat32Array, pose: Dictionary) -> Dictionary:
	var target := Vector2(pose.position[0],pose.position[1])
	var segment: int = 0
	var nearest := Vector2.ZERO
	var best: float = INF
	for i: int in range(points.size()):
		var p: Vector2 = Geometry2D.get_closest_point_to_segment(target,points[i],points[(i+1)%points.size()])
		if p.distance_squared_to(target) < best:
			best = p.distance_squared_to(target)
			segment = i
			nearest = p
	var forward: Vector2 = Vector2.RIGHT.rotated(deg_to_rad(float(pose.heading)))
	var next: int = (segment+1)%points.size()
	var reverse: bool = forward.dot(points[next]-points[segment]) < 0
	var span: float = points[segment].distance_to(points[next])
	var start_width: float = lerpf(widths[segment],widths[next],points[segment].distance_to(nearest)/maxf(span,0.001))
	var route := PackedVector2Array([nearest])
	var result_widths := PackedFloat32Array([start_width])
	for offset: int in range(points.size()):
		var index: int = posmod(segment-offset if reverse else next+offset,points.size())
		if route[-1].distance_to(points[index]) < 0.01 or nearest.distance_to(points[index]) < 0.01: continue
		route.append(points[index])
		result_widths.append(widths[index])
	return {"points":route,"widths":result_widths}
