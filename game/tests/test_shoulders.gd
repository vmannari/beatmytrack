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
	failures += _test_joins()
	failures += _test_internal_contours()
	quit(0 if failures == 0 else 1)

func _test_joins() -> int:
	var failures: int = 0
	var checks: int = 0
	for turn: float in [0.0,30.0,-30.0,75.0,-75.0]:
		var first: Dictionary = RoadPieces.create("straight",Vector2(-28,0))
		var second: Dictionary = RoadPieces.create("straight",Vector2.ZERO,fposmod(turn,360.0))
		var pieces: Array = [first,second]
		var before: Array = pieces.duplicate(true)
		for margin: float in [0.0,-0.2]:
			var left: Dictionary = preload("res://track/visual_road_join.gd").build(pieces,0,margin)
			var right: Dictionary = preload("res://track/visual_road_join.gd").build(pieces,1,margin)
			var matches: int = 0
			var visual := NativeTrackVisual.new()
			for i: int in range(left.polygon.size()):
				for j: int in range(right.polygon.size()):
					if left.polygon[i].distance_to(right.polygon[j]) > 0.0001: continue
					matches += 1
					if absf(turn) >= 30.0:
						var original: PackedVector2Array = RoadPieces.section_outline(pieces,0,margin)
						var nearest: float = INF
						for vertex: Vector2 in original: nearest = minf(nearest,vertex.distance_to(left.polygon[i]))
						checks += 1
						if nearest < 0.10: failures += 1 # Both inside and outside receive visible rounding.
					var a: Vector2 = visual._roadside_miter(left.polygon,i,left.cuts)
					var b: Vector2 = visual._roadside_miter(right.polygon,j,right.cuts)
					checks += 1
					if a.distance_to(b) > 0.0001: failures += 1
			visual.free()
			checks += 3
			if matches != 2:
				failures += 1
				print("JOIN_MISMATCH turn=",turn," margin=",margin," matches=",matches)
			if Geometry2D.triangulate_polygon(left.polygon).is_empty(): failures += 1
			if Geometry2D.triangulate_polygon(right.polygon).is_empty(): failures += 1
		checks += 1
		if pieces != before: failures += 1
	print("VISUAL_JOIN_TESTS: %d checks, %d failures; shared road/marking/shoulder endpoints, valid meshes and unchanged authored data" % [checks,failures])
	return failures

func _test_internal_contours() -> int:
	var helper = preload("res://track/visual_road_join.gd")
	var original := PackedVector2Array([Vector2(0,0),Vector2(4,0),Vector2(5,0.3),Vector2(5.2,0),Vector2(8,0),Vector2(8,5),Vector2(0,5)])
	var cuts: Array[Dictionary] = [{"point":Vector2(0,2.5),"normal":Vector2.RIGHT,"span":5.0},{"point":Vector2(8,2.5),"normal":Vector2.LEFT,"span":5.0}]
	var preserved: PackedVector2Array = original.duplicate()
	var smooth: PackedVector2Array = helper.fair_contour(original,cuts)
	var failures: int = 0
	var checks: int = 0
	checks += 3
	if original != preserved: failures += 1
	if smooth[2].y >= original[2].y-0.05:
		failures += 1
		print("NO SMOOTH ",smooth)
	if Geometry2D.triangulate_polygon(smooth).is_empty(): failures += 1
	for i: int in range(original.size()):
		checks += 1
		if original[i].distance_to(smooth[i]) > 0.25001: failures += 1
	for i: int in [0,4,5,6]:
		checks += 1
		if smooth[i] != original[i]:
			failures += 1
			print("END MOVED ",i)
	var document: Dictionary = TrackDocument.create_default()
	document.pieces = [RoadPieces.create("hairpin",Vector2.ZERO)]
	var track: NativeTrack = TrackCompiler.compile(document)
	var contacts: Array[Dictionary] = track.kerbs.triangles.duplicate(true)
	var cells: PackedInt32Array = track.cells.duplicate()
	var rendered: Array[Dictionary] = helper.kerb_triangles(document)
	checks += 3
	if rendered.is_empty():
		failures += 1
		print("EMPTY RENDERED FIXTURE: ",document.get("pieces",[]).size())
	if track.kerbs.triangles != contacts: failures += 1
	if track.cells != cells: failures += 1
	var fragments: bool = false
	for triangle: Dictionary in rendered:
		for uv: Vector2 in triangle.uv:
			if uv.y < 2.0: fragments = true
	checks += 1
	if fragments: failures += 1
	print("INTERNAL_CONTOUR_TESTS: %d checks, %d failures; bounded smoothing, fixed joins, no isolated kerb slivers, canonical contacts/cells preserved" % [checks,failures])
	return failures
