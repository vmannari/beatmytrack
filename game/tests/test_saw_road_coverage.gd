extends SceneTree
## The catalog review found the same near-collinear clipping failure on Saw.
const HEIGHT = preload("res://track/road_surface_height.gd")
const PREPARATION = preload("res://editor/road_preparation.gd")
const PROBES: Array[Vector2] = [Vector2(-63.539196,38.571),Vector2(-63.241701,38.321),Vector2(-62.944206,38.071)]
var checks: int = 0
var failures: int = 0

func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures += 1; print("FAIL: ",label)

func coverage(arrays: Array,point: Vector2) -> int:
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var count: int = 0
	for i: int in range(0,vertices.size(),3):
		if absf(vertices[i].y-0.062)>0.00001 or absf(vertices[i+1].y-0.062)>0.00001 or absf(vertices[i+2].y-0.062)>0.00001: continue
		if Geometry2D.is_point_in_polygon(point,PackedVector2Array([Vector2(vertices[i].x,-vertices[i].z),Vector2(vertices[i+1].x,-vertices[i+1].z),Vector2(vertices[i+2].x,-vertices[i+2].z)])): count += 1
	return count

func native_coverage(visual: NativeTrackVisual,point: Vector2) -> int:
	var count: int = 0
	for child: Node in visual.get_children():
		if not child is MeshInstance3D or not child.material_override is ShaderMaterial: continue
		if child.material_override.get_shader_parameter("asphalt_surface") != true or child.material_override.get_shader_parameter("edge_fringe") == true: continue
		count += coverage(child.mesh.surface_get_arrays(0),point)
	return count

func run() -> void:
	var document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/saw_road_coverage.json"))
	var frozen: PackedByteArray = var_to_bytes(document)
	var track: NativeTrack = TrackCompiler.compile(document)
	var canonical: PackedByteArray = var_to_bytes([track.cells,track.kerbs.triangles,track.route,track.content_hash])
	var support: RefCounted = HEIGHT.new(track)
	var old := GDScript.new()
	old.source_code = FileAccess.get_file_as_string("res://../docs/evidence/ajorata-road-2026-10-16/before-source/shoulder_mesh.gd").replace("class_name ShoulderMesh","")
	check(old.reload() == OK,"retained original clipping helper compiles")
	var original: RefCounted = old.new()
	for polygon: PackedVector2Array in support.floors:
		var indices: PackedInt32Array = Geometry2D.triangulate_polygon(polygon)
		for i: int in range(0,indices.size(),3): original._add_triangle(PackedVector2Array([polygon[indices[i]],polygon[indices[i+1]],polygon[indices[i+2]]]),Vector3.ZERO)
	var before: Array[PackedVector2Array] = []
	var lists: Dictionary = {}
	for i: int in range(original.triangles.size()):
		for polygon: PackedVector2Array in original._fragments(i,original.triangles[i],lists):
			var indices: PackedInt32Array = Geometry2D.triangulate_polygon(polygon)
			for j: int in range(0,indices.size(),3): before.append(PackedVector2Array([polygon[indices[j]],polygon[indices[j+1]],polygon[indices[j+2]]]))
	var packet: Dictionary = PREPARATION.prepare(track,true)
	var direct := NativeTrackVisual.new()
	direct.cache_road_meshes = false; direct.persist_road_meshes = false
	direct.theme_id = "pine"; direct.colors = TrackTheme.palette("pine")
	root.add_child(direct); await direct._build_creator_roads(track)
	var restored := NativeTrackVisual.new()
	restored.theme_id = "pine"; restored.colors = TrackTheme.palette("pine"); restored.ground_support = support
	root.add_child(restored); restored._install_prepared_roads(track,packet)
	for point: Vector2 in PROBES:
		var old_count: int = 0
		for triangle: PackedVector2Array in before:
			if Geometry2D.is_point_in_polygon(point,triangle): old_count += 1
		check(old_count == 0,"original helper reproduces the missing Saw road at "+str(point))
		check(support.on_floor(point),"Saw hole retains original asphalt presentation support")
		var cpu_count: int = 0
		for part: Dictionary in packet.parts:
			if part.role == "road" and part.arguments[5] and not part.arguments[6]: cpu_count += coverage(part.arrays,point)
		check(cpu_count == 1,"CPU-prepared Saw road covers the original hole exactly once")
		check(native_coverage(direct,point) == 1,"direct native Saw road covers the original hole exactly once")
		check(native_coverage(restored,point) == 1,"uploaded prepared Saw road covers the original hole exactly once")
	check(var_to_bytes(document) == frozen and canonical == var_to_bytes([track.cells,track.kerbs.triangles,track.route,track.content_hash]),"Saw document and canonical road data remain exact")
	direct.free(); restored.free()
	var mode: String = "headless" if DisplayServer.get_name() == "headless" else RenderingServer.get_current_rendering_method()
	var file := FileAccess.open("res://../docs/evidence/catalog-road-review-2026-10-16/saw-"+mode+".json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"native_hash":track.content_hash},"\t")); file.close()
	print("SAW_ROAD_COVERAGE: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
