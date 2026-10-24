class_name SurfacePaint
extends RefCounted
## Shared bounded smoothing for previews, raster surfaces and road masks.
static func contour(points: Array, mode: String) -> PackedVector2Array:
	var result := PackedVector2Array()
	for p: Array in points: result.append(Vector2(p[0],p[1]))
	if mode == "free" or result.size() < 3: return result
	# Chaikin subdivision stays inside the authored hull without overshoot.
	for pass_index: int in range(3):
		var next := PackedVector2Array()
		if mode != "area": next.append(result[0])
		for i: int in range(result.size() if mode == "area" else result.size()-1):
			var a: Vector2 = result[i]
			var b: Vector2 = result[(i+1)%result.size()]
			next.append(a.lerp(b,0.25))
			next.append(a.lerp(b,0.75))
		if mode != "area": next.append(result[-1])
		result = next
	return result

static func prepared(stroke: Dictionary) -> Dictionary:
	var result: Dictionary = stroke.duplicate(true)
	result.points = []
	for p: Vector2 in contour(stroke.points,str(stroke.get("mode","free"))): result.points.append([p.x,p.y])
	return result

static func cell_bounds(polygon: PackedVector2Array, extent: Vector2, cell_size: float, grid: Vector2i) -> Rect2i:
	var low: Vector2 = polygon[0]
	var high: Vector2 = low
	for p: Vector2 in polygon:
		low = low.min(p)
		high = high.max(p)
	var start := Vector2i(maxi(0,floori((low.x+extent.x)/cell_size)),maxi(0,floori((extent.y-high.y)/cell_size)))
	var end := Vector2i(mini(grid.x,ceili((high.x+extent.x)/cell_size)),mini(grid.y,ceili((extent.y-low.y)/cell_size)))
	return Rect2i(start,end-start)

static func valid_area(points: Array) -> bool:
	var path := PackedVector2Array()
	for p: Array in points: path.append(Vector2(p[0],p[1]))
	for i: int in range(path.size()):
		if path[i].distance_to(path[(i+1)%path.size()]) < 0.05: return false
		for j: int in range(i+2,path.size()):
			if i == 0 and j == path.size()-1: continue
			if Geometry2D.segment_intersects_segment(path[i],path[(i+1)%path.size()],path[j],path[(j+1)%path.size()]) != null: return false
	return not Geometry2D.triangulate_polygon(contour(points,"area")).is_empty()
