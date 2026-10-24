class_name SplineRoad
extends RefCounted
## Five interpolation points, stored in the piece's local frame.
## Centripetal Catmull-Rom tangents avoid loops within an individual span.

const POINT_COUNT: int = 5

static func validate(piece: Dictionary) -> Array[String]:
	if not RoadPieces._number(piece.width): return ["Spline width must be a finite number."]
	if not piece.get("spline_points") is Array or piece.spline_points.size() != POINT_COUNT or not piece.get("point_widths") is Array or piece.point_widths.size() != POINT_COUNT:
		return ["A spline needs exactly five points and five point widths."]
	for i: int in range(POINT_COUNT):
		var point: Variant = piece.spline_points[i]
		if not point is Array or point.size() != 2: return ["Spline points need two coordinates."]
		for value: Variant in point:
			if not RoadPieces._number(value) or absf(float(value)) > 240.0: return ["Spline coordinates must be finite and inside the map."]
		var width: Variant = piece.point_widths[i]
		if not RoadPieces._number(width) or float(width) < 6.0 or float(width) > 20.0: return ["Use a point width of 6–20 m."]
		if i > 0 and Vector2(point[0],point[1]).distance_to(Vector2(piece.spline_points[i-1][0],piece.spline_points[i-1][1])) < 2.0:
			return ["Keep neighbouring spline points at least 2 m apart."]
	if piece.spline_points[0] != [0.0,0.0]: return ["The first spline point must be at the section origin."]
	if not is_equal_approx(float(piece.width),float(piece.point_widths.max())): return ["Spline bounds must use the widest point width."]
	return []

static func points(piece: Dictionary) -> PackedVector2Array:
	var result := PackedVector2Array()
	var origin := Vector2(piece.position[0],piece.position[1])
	for point: Array in piece.spline_points:
		result.append(origin+Vector2(point[0],float(point[1])*(-1.0 if piece.flip else 1.0)).rotated(deg_to_rad(float(piece.heading))))
	return result

static func tangent(nodes: PackedVector2Array, index: int) -> Vector2:
	if index == 0: return (nodes[1]-nodes[0])/sqrt(nodes[1].distance_to(nodes[0]))
	if index == nodes.size()-1: return (nodes[-1]-nodes[-2])/sqrt(nodes[-1].distance_to(nodes[-2]))
	var before: float = sqrt(nodes[index].distance_to(nodes[index-1]))
	var after: float = sqrt(nodes[index+1].distance_to(nodes[index]))
	return (nodes[index]-nodes[index-1])/before-(nodes[index+1]-nodes[index-1])/(before+after)+(nodes[index+1]-nodes[index])/after

static func geometry(piece: Dictionary) -> Dictionary:
	var nodes: PackedVector2Array = points(piece)
	var samples := PackedVector2Array([nodes[0]])
	var widths := PackedFloat32Array([float(piece.point_widths[0])])
	var indices: Array[int] = [0]
	for span: int in range(POINT_COUNT-1):
		var distance: float = nodes[span].distance_to(nodes[span+1])
		var m0: Vector2 = tangent(nodes,span)*sqrt(distance)
		var m1: Vector2 = tangent(nodes,span+1)*sqrt(distance)
		var steps: int = maxi(4,ceili((distance+m0.length()+m1.length())/0.75))
		var begin: int = samples.size()-1
		var travelled := PackedFloat32Array([0.0])
		for step: int in range(1,steps+1):
			var t: float = float(step)/steps
			var t2: float = t*t
			var t3: float = t2*t
			var point: Vector2 = nodes[span]*(2*t3-3*t2+1)+m0*(t3-2*t2+t)+nodes[span+1]*(-2*t3+3*t2)+m1*(t3-t2)
			if step == steps: point = nodes[span+1]
			travelled.append(travelled[-1]+samples[-1].distance_to(point))
			samples.append(point)
		for step: int in range(1,steps+1):
			widths.append(lerpf(float(piece.point_widths[span]),float(piece.point_widths[span+1]),travelled[step]/maxf(travelled[-1],0.0001)))
		indices.append(begin+steps)
	return {"points":samples,"widths":widths,"node_indices":indices}

static func move_point(piece: Dictionary, index: int, target: Vector2) -> Dictionary:
	var result: Dictionary = piece.duplicate(true)
	var nodes: PackedVector2Array = points(piece)
	nodes[index] = target
	result.position = [nodes[0].x,nodes[0].y]
	for i: int in range(POINT_COUNT):
		var local: Vector2 = (nodes[i]-nodes[0]).rotated(-deg_to_rad(float(piece.heading)))
		result.spline_points[i] = [local.x,local.y*(-1.0 if piece.flip else 1.0)]
	return result if RoadPieces.validate(result).is_empty() else {}

static func with_width(piece: Dictionary, index: int, width: float) -> Dictionary:
	var result: Dictionary = piece.duplicate(true)
	result.point_widths[index] = clampf(width,6.0,20.0)
	result.width = float(result.point_widths.max())
	return result
