class_name ObjectRuns
extends RefCounted
## Shared endpoint-fitting for solid walls; tyres/cones retain physical sizes.
const CONTINUOUS: Array[String] = ["barrier","fence","guardrail","wire_fence"]
const MIN_LENGTH: float = 0.01
const MAX_LENGTH: float = 18.0

static func smooth(path: PackedVector2Array) -> PackedVector2Array:
	var result: PackedVector2Array = path
	for pass_index: int in range(2):
		if result.size() < 3: return result
		var next := PackedVector2Array([result[0]])
		for i: int in range(result.size()-1):
			next.append(result[i].lerp(result[i+1],0.25))
			next.append(result[i].lerp(result[i+1],0.75))
		next.append(result[-1])
		result = next
	return result

static func build(path: PackedVector2Array, kind: String, scale: float, capacity: int) -> Array:
	var result: Array = []
	if path.size() < 2 or capacity <= 0: return result
	if kind in ["tyre_stack","tyre_wall"]: scale = 1.0
	if kind not in CONTINUOUS: return _stamps(path,kind,scale,capacity)
	# Dense samples bound both section length and deviation from curved paths.
	var points := PackedVector2Array([path[0]])
	for i: int in range(path.size()-1):
		var span: float = path[i].distance_to(path[i+1])
		if span < 0.000001: continue
		var count: int = maxi(1,ceili(span/(0.5*scale)))
		for step: int in range(1,count+1): points.append(path[i].lerp(path[i+1],float(step)/count))
	var begin: int = 0
	while begin < points.size()-1 and result.size() < capacity:
		var end: int = begin+1
		while end+1 < points.size():
			var candidate: int = end+1
			if points[begin].distance_to(points[candidate]) > 6.0*scale: break
			var fits: bool = true
			for sample: int in range(begin+1,candidate):
				var nearest: Vector2 = Geometry2D.get_closest_point_to_segment(points[sample],points[begin],points[candidate])
				if nearest.distance_to(points[sample]) > 0.06*scale: fits = false; break
			if not fits: break
			end = candidate
		var a: Vector2 = points[begin]
		var b: Vector2 = points[end]
		var length: float = a.distance_to(b)
		if length >= MIN_LENGTH:
			var center: Vector2 = (a+b)*0.5
			var object: Dictionary = {"kind":kind,"position":[center.x,center.y],"rotation":fposmod(rad_to_deg((b-a).angle()),360.0),"length":length}
			if scale != 1.0: object["scale"] = scale
			if center.abs().x > 110.0 or center.abs().y > 110.0: break
			result.append(object)
		begin = end
	return result

static func _stamps(path: PackedVector2Array, kind: String, scale: float, capacity: int) -> Array:
	var result: Array = []
	var length: float = 0.0
	for i: int in range(path.size()-1): length += path[i].distance_to(path[i+1])
	if length < MIN_LENGTH: return result
	var spacing: float = (2.0 if kind == "cone" else CreatorObjects.dimensions(kind).x)*scale
	var desired: int = maxi(1,ceili(length/spacing))
	var segment: int = 0
	var traveled: float = 0.0
	for i: int in range(mini(capacity,desired)):
		var distance: float = length*(i+0.5)/desired
		while segment < path.size()-2 and traveled+path[segment].distance_to(path[segment+1]) < distance:
			traveled += path[segment].distance_to(path[segment+1]); segment += 1
		var tangent: Vector2 = path[segment+1]-path[segment]
		var center: Vector2 = path[segment].lerp(path[segment+1],clampf((distance-traveled)/maxf(0.001,tangent.length()),0.0,1.0)).clamp(Vector2(-110,-110),Vector2(110,110))
		var object: Dictionary = {"kind":kind,"position":[center.x,center.y],"rotation":fposmod(rad_to_deg(tangent.angle()),360.0)}
		if scale != 1.0: object["scale"] = scale
		result.append(object)
	return result
