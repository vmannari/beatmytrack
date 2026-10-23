extends SceneTree
## Ajorata's near-collinear overlap cutters must retain continuous asphalt.
const HEIGHT = preload("res://track/road_surface_height.gd")
const PREPARATION = preload("res://editor/road_preparation.gd")
const EDGE_PRECISION: float = 0.0001 # 0.1 mm at single-precision Boolean edges.
var checks: int = 0
var failures: int = 0
var measurements: Array[Dictionary] = []

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; print("FAIL: ",label)

func area(polygon: PackedVector2Array) -> float:
	var value: float = 0.0
	for i: int in range(1,polygon.size()-1):
		var u: Vector2 = polygon[i]-polygon[0]
		var v: Vector2 = polygon[i+1]-polygon[0]
		value += float(u.x)*float(v.y)-float(u.y)*float(v.x)
	return absf(value)*0.5

func decode(rows: Array) -> PackedVector2Array:
	var result := PackedVector2Array()
	for row: Array in rows: result.append(Vector2(row[0],row[1]))
	return result

func test_sliver() -> void:
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/ajorata_clip_sliver.json"))
	var clipper: RefCounted = ShoulderMesh.new()
	if "--baseline" in OS.get_cmdline_user_args():
		var old := GDScript.new()
		old.source_code = FileAccess.get_file_as_string("res://../docs/evidence/ajorata-road-2026-10-16/before-source/shoulder_mesh.gd").replace("class_name ShoulderMesh","")
		check(old.reload() == OK,"original clipping helper compiles")
		clipper = old.new()
	for reverse: bool in [false,true]:
		for angle: float in [0.0,37.0,143.0]:
			var source: PackedVector2Array = decode(fixture.fragment)
			var cutter: PackedVector2Array = decode(fixture.cutter)
			var point := Vector2(-14,-41).rotated(deg_to_rad(angle))
			for i: int in range(source.size()): source[i] = source[i].rotated(deg_to_rad(angle))
			for i: int in range(cutter.size()): cutter[i] = cutter[i].rotated(deg_to_rad(angle))
			if reverse: cutter.reverse()
			var remaining: Array[PackedVector2Array] = clipper._subtract_convex(source,cutter)
			var retained: bool = false
			var remaining_area: float = 0.0
			for polygon: PackedVector2Array in remaining:
				retained = retained or Geometry2D.is_point_in_polygon(point,polygon)
				remaining_area += area(polygon)
			var label: String = "sliver winding %s rotation %s"%[reverse,angle]
			check(retained,label+" retains distant asphalt")
			check(absf(remaining_area-area(source)) < 0.002,label+" removes only the microscopic cutter area")
	var source := PackedVector2Array([Vector2(0,0),Vector2(10,0),Vector2(0,10)])
	var cutter := PackedVector2Array([Vector2(0,0),Vector2(1,0),Vector2(2,0)])
	check(clipper._subtract_convex(source,cutter) == [source],"zero-area cutter preserves its source")

func triangles_from(arrays: Array) -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array] = []
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	for i: int in range(0,vertices.size(),3):
		if absf(vertices[i].y-0.062) > 0.00001 or absf(vertices[i+1].y-0.062) > 0.00001 or absf(vertices[i+2].y-0.062) > 0.00001: continue
		var p := PackedVector2Array([Vector2(vertices[i].x,-vertices[i].z),Vector2(vertices[i+1].x,-vertices[i+1].z),Vector2(vertices[i+2].x,-vertices[i+2].z)])
		if area(p) > 0.0000001: result.append(p)
	return result

func native_triangles(visual: NativeTrackVisual) -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array] = []
	for child: Node in visual.get_children():
		if not child is MeshInstance3D or not child.material_override is ShaderMaterial: continue
		if child.material_override.get_shader_parameter("asphalt_surface") != true or child.material_override.get_shader_parameter("edge_fringe") == true: continue
		result.append_array(triangles_from(child.mesh.surface_get_arrays(0)))
	return result

func contains_triangle(point: Vector2, triangle: PackedVector2Array) -> bool:
	# Test the actual sides in double precision. Geometry2D's boundary
	# inclusion can classify both neighbours as containing a near-edge point.
	var positive: bool = false
	var negative: bool = false
	for i: int in range(3):
		var a: Vector2 = triangle[i]
		var b: Vector2 = triangle[(i+1)%3]
		var cross_value: float = (float(b.x)-a.x)*(float(point.y)-a.y)-(float(b.y)-a.y)*(float(point.x)-a.x)
		positive = positive or cross_value > 0.0
		negative = negative or cross_value < 0.0
	return not (positive and negative)

func scan(triangles: Array[PackedVector2Array], support: RefCounted, label: String) -> void:
	var bins: Dictionary = {}
	for i: int in range(triangles.size()):
		var p: PackedVector2Array = triangles[i]
		var bounds := Rect2(p[0],Vector2.ZERO).expand(p[1]).expand(p[2])
		for y: int in range(floori(bounds.position.y/4),floori(bounds.end.y/4)+1):
			for x: int in range(floori(bounds.position.x/4),floori(bounds.end.x/4)+1):
				var key := Vector2i(x,y)
				if not bins.has(key): bins[key] = []
				bins[key].append(i)
	var sampled: int = 0
	var missing: int = 0
	var overlap: int = 0
	var boundary_samples: int = 0
	var max_boundary_distance: float = 0.0
	for y: int in range(-190,225):
		for x: int in range(-190,190):
			var point := Vector2(x*0.25+0.037,y*0.25+0.071)
			if not support.on_floor(point): continue
			sampled += 1
			var count: int = 0
			var nearest: float = INF
			for i: int in bins.get(Vector2i(floori(point.x/4),floori(point.y/4)),[]):
				var p: PackedVector2Array = triangles[i]
				if contains_triangle(point,p): count += 1
			if count != 1:
				for i: int in bins.get(Vector2i(floori(point.x/4),floori(point.y/4)),[]):
					var p: PackedVector2Array = triangles[i]
					for j: int in range(3): nearest = minf(nearest,point.distance_to(Geometry2D.get_closest_point_to_segment(point,p[j],p[(j+1)%3])))
			if count == 0:
				if nearest <= EDGE_PRECISION:
					boundary_samples += 1
					max_boundary_distance = maxf(max_boundary_distance,nearest)
				else: missing += 1
			if count > 1 and nearest > EDGE_PRECISION: overlap += 1
	check(sampled > 72000,label+" scans the full authored asphalt at 25 cm intervals")
	check(missing == 0,label+" has no missing asphalt beyond 0.1 mm numerical edges")
	check(overlap == 0,label+" retains one asphalt owner away from numerical edges")
	for point: Vector2 in [Vector2(-14,-41),Vector2(-21.5,-41),Vector2(-7,-38)]:
		var count: int = 0
		for p: PackedVector2Array in triangles:
			if contains_triangle(point,p): count += 1
		check(count == 1,label+" covers the original road hole exactly once at "+str(point))
	measurements.append({"path":label,"triangles":triangles.size(),"sampled":sampled,"missing":missing,"overlap":overlap,"numerical_edge_samples":boundary_samples,"max_edge_distance_m":max_boundary_distance})

func run() -> void:
	test_sliver()
	if "--baseline" not in OS.get_cmdline_user_args():
		var document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/ajorata.json"))
		var frozen: PackedByteArray = var_to_bytes(document)
		var track: NativeTrack = TrackCompiler.compile(document)
		var cells: PackedInt32Array = track.cells.duplicate()
		var kerbs: PackedByteArray = var_to_bytes(track.kerbs.triangles)
		check(track.content_hash == "abcc56697857a83aa2423f4b5e9b4c5cf2fd67514a36040cf19ae60683af65d3","current Ajorata canonical content hash is unchanged")
		var support: RefCounted = HEIGHT.new(track)
		var packet: Dictionary = PREPARATION.prepare(track,true)
		var triangles: Array[PackedVector2Array] = []
		for part: Dictionary in packet.parts:
			if part.role == "road" and part.arguments[5] and not part.arguments[6]: triangles.append_array(triangles_from(part.arrays))
		scan(triangles,support,"CPU preparation")
		var direct := NativeTrackVisual.new()
		direct.cache_road_meshes = false; direct.persist_road_meshes = false
		direct.theme_id = "pine"; direct.colors = TrackTheme.palette("pine")
		root.add_child(direct)
		await direct._build_creator_roads(track)
		scan(native_triangles(direct),support,"direct native mesh")
		var restored := NativeTrackVisual.new()
		restored.theme_id = "pine"; restored.colors = TrackTheme.palette("pine")
		restored.ground_support = support
		root.add_child(restored)
		restored._install_prepared_roads(track,packet)
		scan(native_triangles(restored),support,"uploaded prepared mesh")
		check(var_to_bytes(document) == frozen and track.cells == cells and var_to_bytes(track.kerbs.triangles) == kerbs,"authored document, route, physical surfaces and kerbs remain exact")
		direct.free(); restored.free()
	var folder: String = "res://../docs/evidence/ajorata-road-2026-10-16/"
	var mode: String = "headless" if DisplayServer.get_name() == "headless" else RenderingServer.get_current_rendering_method()
	var file := FileAccess.open(folder+("baseline" if "--baseline" in OS.get_cmdline_user_args() else "coverage-"+mode)+".json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"scans":measurements},"\t")); file.close()
	print("AJORATA_ROAD_COVERAGE: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
