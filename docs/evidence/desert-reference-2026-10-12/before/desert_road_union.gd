extends RefCounted
## One visible surface at ground crossings; canonical road data is untouched.
var clipping := ShoulderMesh.new()
var points_by_triangle: Array[PackedVector2Array] = []

func add(polygon: PackedVector2Array, points: PackedVector2Array) -> void:
	var indices: PackedInt32Array = Geometry2D.triangulate_polygon(polygon)
	for i: int in range(0,indices.size(),3):
		var before: int = clipping.triangles.size()
		clipping._add_triangle(PackedVector2Array([polygon[indices[i]],polygon[indices[i+1]],polygon[indices[i+2]]]),Vector3.ZERO)
		if clipping.triangles.size() > before: points_by_triangle.append(points)

func emit(visual: NativeTrackVisual, tool: SurfaceTool) -> int:
	var count: int = 0
	var candidates: Dictionary = {}
	var caches: Dictionary = {}
	for i: int in range(clipping.triangles.size()):
		if visual._menu_yield_due():
			if not await visual._yield_build(): return count
		var source: Dictionary = clipping.triangles[i]
		if not caches.has(points_by_triangle[i]): caches[points_by_triangle[i]] = {}
		for polygon: PackedVector2Array in clipping._fragments(i,source,candidates):
			count += visual._road_polygon(tool,polygon,0.012,points_by_triangle[i],caches[points_by_triangle[i]])
	return count
