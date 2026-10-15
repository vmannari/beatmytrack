extends RefCounted
## One owner per flat blend fragment, retaining the original local UV roles.
const ROAD_UNION = preload("res://track/desert_road_union.gd")
var clipping := ShoulderMesh.new()
var points: Array[PackedVector2Array] = []
var settings: Array[Dictionary] = []

func add(vertices: Array[Vector2], across: Array[float], path: PackedVector2Array, cache: Dictionary) -> void:
	for first: int in [0,3]:
		var before: int = clipping.triangles.size()
		clipping._add_triangle(PackedVector2Array(vertices.slice(first,first+3)),Vector3(across[first],across[first+1],across[first+2]))
		if clipping.triangles.size() > before:
			points.append(path)
			settings.append(cache)

func emit(visual: NativeTrackVisual, tool: SurfaceTool) -> int:
	var count: int = 0
	var candidates: Dictionary = {}
	for i: int in range(clipping.triangles.size()):
		if visual._menu_yield_due() and not await visual._yield_build(): return count
		var source: Dictionary = clipping.triangles[i]
		for polygon: PackedVector2Array in clipping._fragments(i,source,candidates):
			var indices: PackedInt32Array = Geometry2D.triangulate_polygon(polygon)
			for index: int in indices:
				var p: Vector2 = polygon[index]
				tool.set_uv(Vector2(0,clampf(source.gradient.dot(p)+source.offset,0,1)))
				if visual.theme_id == "desert":
					tool.set_uv2(ROAD_UNION.coordinates(visual._sand_coordinates(p,points[i]),settings[i]))
					tool.set_color(settings[i].desert_blend_sampler.blend(p,int(settings[i].desert_piece_index)))
				else: tool.set_uv2(visual._cached_asphalt_axis(p,points[i],settings[i]))
				tool.add_vertex(VisualGeometry.world(p)+Vector3.UP*0.013)
			count += indices.size()/3
	return count
