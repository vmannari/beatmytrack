extends SceneTree

func _initialize() -> void:
	var builder := preload("res://track/shoulder_mesh.gd").new()
	# Opposing two-metre shoulders overlap by one metre.
	builder.add_quad(Vector2(0,0),Vector2(10,0),Vector2(0,2),Vector2(10,2))
	builder.add_quad(Vector2(10,3),Vector2(0,3),Vector2(10,1),Vector2(0,1))
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	builder.emit(tool)
	var mesh: ArrayMesh = tool.commit()
	var arrays: Array = mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var area: float = 0
	var failures: int = 0
	var polygons: Array[PackedVector2Array] = []
	for i: int in range(0,vertices.size(),3):
		var polygon := PackedVector2Array()
		var center := Vector2.ZERO
		for j: int in range(3):
			var point := Vector2(vertices[i+j].x,-vertices[i+j].z)
			polygon.append(point)
			center += point/3.0
		area += absf((polygon[1]-polygon[0]).cross(polygon[2]-polygon[0]))*0.5
		var actual: float = (uv[i].y+uv[i+1].y+uv[i+2].y)/3.0
		var expected: float = minf(center.y,3.0-center.y)/2.0
		if absf(actual-expected) > 0.0001: failures += 1
		polygons.append(polygon)
	for i: int in range(polygons.size()):
		for j: int in range(i):
			for overlap: PackedVector2Array in Geometry2D.intersect_polygons(polygons[i],polygons[j]):
				var twice_area: float = 0
				for k: int in range(overlap.size()): twice_area += overlap[k].cross(overlap[(k+1)%overlap.size()])
				if absf(twice_area) > 0.0001: failures += 1
	if absf(area-30.0) > 0.001: failures += 1
	print("SHOULDER_TESTS: union area=%f, triangles=%d, failures=%d; nearest-road shading and no overlapping interiors" % [area,polygons.size(),failures])
	quit(0 if failures == 0 else 1)
