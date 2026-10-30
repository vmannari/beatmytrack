class_name SpeedBumpEdit
extends RefCounted
## Width changes affect the transverse span only, preserving the crown profile.
const MIN_SPAN: float = 0.5
const MAX_SPAN: float = 40.0

static func endpoints(object: Dictionary) -> PackedVector2Array:
	var center := Vector2(object.position[0],object.position[1])
	var side: Vector2 = Vector2.UP.rotated(deg_to_rad(float(object.rotation)))
	var half: float = CreatorObjects.size_of(object).y*0.5
	return PackedVector2Array([center-side*half,center+side*half])

static func move_end(object: Dictionary, end: int, point: Vector2) -> Dictionary:
	var ends: PackedVector2Array = endpoints(object)
	var fixed: Vector2 = ends[1-end]
	var direction: Vector2 = (ends[end]-fixed).normalized()
	var span: float = clampf((point-fixed).dot(direction),MIN_SPAN,MAX_SPAN)
	var center: Vector2 = (fixed+direction*span*0.5).clamp(Vector2(-110,-110),Vector2(110,110))
	var result: Dictionary = object.duplicate(true)
	result.position = [center.x,center.y]
	result["span"] = span
	return serialize_ready(result)

static func serialize_ready(object: Dictionary) -> Dictionary:
	# Match the editor's existing JSON precision before committing an edit.
	# Saving/loading then retains the exact authored values and pinned identity.
	return JSON.parse_string(JSON.stringify(object))

static func fit_road(document: Dictionary, object: Dictionary, native: NativeTrack = null) -> Dictionary:
	var point := Vector2(object.position[0],object.position[1])
	var forward: Vector2 = Vector2.RIGHT.rotated(deg_to_rad(float(object.rotation)))
	var best: Dictionary = {}
	var topology: Dictionary = RoadPieces.prepare_endpoints(document.pieces)
	for index: int in range(document.pieces.size()):
		if document.pieces[index].kind == "bridge": continue
		var geometry: Dictionary = RoadPieces.section_geometry(document.pieces,index,topology)
		best = _nearest(geometry.points,geometry.widths,false,point,best)
	if not document.layout.is_empty():
		var geometry: Dictionary = TrackDocument.route_data(document.layout)
		best = _nearest(geometry.points,geometry.widths,true,point,best)
	if best.is_empty() and native != null and native.cell_at(point) in [0,2]:
		# Free-painted/native roads use their actual ground cells. The lap route
		# supplies direction only; it cannot invent the road's physical width.
		best = _nearest(native.route,native.route_widths,true,point,{},false)
		if not best.is_empty():
			var side: Vector2 = Vector2(best.tangent).orthogonal()
			var edges := PackedVector2Array()
			for sign_value: float in [-1.0,1.0]:
				var distance: float = 0.0
				while distance < MAX_SPAN and native.cell_at(point+side*sign_value*distance) in [0,2]: distance += native.cell_size*0.25
				edges.append(point+side*sign_value*maxf(0.0,distance-native.cell_size*0.125))
			best.point = (edges[0]+edges[1])*0.5
			best.width = edges[0].distance_to(edges[1])
			best.distance = 0.0
	if best.is_empty() or float(best.distance) > float(best.width)*0.5: return {}
	var tangent: Vector2 = best.tangent
	if tangent.dot(forward) < 0.0: tangent = -tangent
	var result: Dictionary = object.duplicate(true)
	result.position = [best.point.x,best.point.y]
	result.rotation = fposmod(rad_to_deg(tangent.angle()),360.0)
	result["span"] = clampf(float(best.width),MIN_SPAN,MAX_SPAN)
	return serialize_ready(result)

static func _nearest(points: PackedVector2Array, widths: PackedFloat32Array, closed: bool, point: Vector2, best: Dictionary, inside: bool = true) -> Dictionary:
	for i: int in range(points.size() if closed else points.size()-1):
		var next: int = (i+1)%points.size()
		var nearest: Vector2 = Geometry2D.get_closest_point_to_segment(point,points[i],points[next])
		var distance: float = nearest.distance_to(point)
		if distance >= float(best.get("distance",INF)): continue
		var delta: Vector2 = points[next]-points[i]
		if delta.length_squared() < 0.000001: continue
		var t: float = clampf((nearest-points[i]).dot(delta)/delta.length_squared(),0.0,1.0)
		var width: float = lerpf(widths[i],widths[next],t) if widths.size()==points.size() else 10.0
		if inside and distance > width*0.5: continue
		best = {"point":nearest,"tangent":delta.normalized(),"width":width,"distance":distance}
	return best
