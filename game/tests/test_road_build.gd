extends SceneTree
## Exact mesh-array comparison against the pre-optimization builder.
var failures: int = 0
var checks: int = 0

func _initialize() -> void: call_deferred("run")

func digest(value: Array) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(var_to_bytes(value))
	return context.finish().hex_encode()

func signature(node: Node) -> Array:
	var result: Array = []
	if node is MeshInstance3D and node.mesh != null:
		for surface: int in range(node.mesh.get_surface_count()):
			result.append([node.transform,node.mesh.surface_get_arrays(surface)])
	for child: Node in node.get_children(): result.append_array(signature(child))
	return result

func run() -> void:
	NativeTrackVisual.ROAD_DISK_CACHE.directory = "" # Test cold geometry, never a disk hit.
	NativeTrackVisual._road_mesh_cache.clear()
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	var record: bool = "--screen=record" in arguments
	var compare: bool = record or "--screen=local" in arguments
	var golden_path: String = "res://tests/fixtures/road_build_meshes.json"
	var golden: Dictionary = {} if compare else JSON.parse_string(FileAccess.get_file_as_string(golden_path))
	var baseline := GDScript.new()
	var helper_path: String = "user://road_build_baseline_helper.gd"
	if compare:
		var baseline_path: String = "res://../build/road-visual-before.gd"
		var shoulder_path: String = "res://../build/shoulder-before.gd"
		if not FileAccess.file_exists(baseline_path) or not FileAccess.file_exists(shoulder_path):
			push_error("Requires pre-change road/shoulder source snapshots in build; see ROAD_BUILD_OPTIMIZATION.md")
			quit(1)
			return
		var old_shoulder := GDScript.new()
		old_shoulder.source_code = FileAccess.get_file_as_string(shoulder_path).replace("\r\n","\n").replace("class_name ShoulderMesh\n","")
		if old_shoulder.reload() != OK: quit(1); return
		# Save only a test-local script so the old visual can preload the old helper.
		var file := FileAccess.open(helper_path,FileAccess.WRITE)
		file.store_string(old_shoulder.source_code)
		file.close()
		baseline.source_code = FileAccess.get_file_as_string(baseline_path).replace("\r\n","\n").replace("class_name NativeTrackVisual\n","").replace("res://track/shoulder_mesh.gd",helper_path)
		if baseline.reload() != OK: quit(1); return
	var documents: Array[Dictionary] = []
	for theme: String in ["pine","desert","winter","night_city"]:
		var document: Dictionary = TrackDocument.create_default()
		document.theme = theme
		document.pieces = [RoadPieces.create("straight",Vector2(-28,0)),RoadPieces.create("curve",Vector2.ZERO),RoadPieces.create("hairpin",Vector2(10,-20)),RoadPieces.create("bridge",Vector2(-20,30))]
		documents.append(document)
	for argument: String in OS.get_cmdline_user_args():
		if argument == "--screen=local":
			for id: String in ["track_3e26605a8a90165e","track_1e3936d025fe7c82"]:
				var saved: Dictionary = TrackLibrary.new().load_document(id)
				if saved.is_empty(): push_error("Missing local comparison track"); quit(1); return
				documents.append(saved)
	for document: Dictionary in documents:
		var track: NativeTrack = TrackCompiler.compile(document)
		if track == null: push_error("Invalid equivalence fixture"); quit(1); return
		var cells: PackedInt32Array = track.cells.duplicate()
		var contacts: Array = track.kerbs.triangles.duplicate(true)
		var expected: Array = []
		for old: bool in ([true,false] if compare else [false]):
			var visual: Node3D = baseline.new() if old else NativeTrackVisual.new()
			visual.set("theme_id",document.theme)
			visual.set("colors",TrackTheme.palette(document.theme))
			root.add_child(visual)
			var begin: int = Time.get_ticks_usec()
			visual.call("_build_creator_roads",track)
			print("ROAD_EQUIVALENCE ",document.name," ",document.theme," baseline=",old," ms=",(Time.get_ticks_usec()-begin)/1000.0)
			var actual: Array = signature(visual)
			if old:
				expected = actual
				golden[document.theme] = digest(actual)
			else:
				checks += 2
				if actual.is_empty() or (actual != expected if compare else digest(actual) != golden.get(document.theme,"")): failures += 1; push_error("Road mesh arrays differ: "+str(document.theme))
				if track.cells != cells or track.kerbs.triangles != contacts: failures += 1; push_error("Canonical data changed")
				var cached := NativeTrackVisual.new()
				root.add_child(cached)
				checks += 3
				if not cached._restore_road_meshes([track.content_hash,NativeTrackVisual.VERSION,document.theme,TrackTheme.palette(document.theme),true]): failures += 1; push_error("Expected bounded road cache hit")
				if signature(cached) != actual: failures += 1; push_error("Cached road arrays differ")
				if cached.get_child(0) == visual.get_child(0): failures += 1; push_error("Cache reused live scene nodes")
				checks += 1
				for index: int in range(cached.get_child_count()):
					var restored: MeshInstance3D = cached.get_child(index)
					var original: MeshInstance3D = visual.get_child(index)
					if restored.material_override != original.material_override or restored.layers != original.layers or restored.cast_shadow != original.cast_shadow:
						failures += 1; push_error("Cached material/render flags differ")
				for name: String in visual.get_meta_list():
					checks += 1
					if cached.get_meta(name,null) != visual.get_meta(name): failures += 1; push_error("Cache lost road metadata")
				cached.free()
			visual.free()
			await process_frame
	var miss := NativeTrackVisual.new()
	checks += 2
	if miss._restore_road_meshes(["edited-track",NativeTrackVisual.VERSION,"pine",TrackTheme.palette("pine")]): failures += 1; push_error("Edited track reused stale roads")
	var bytes: int = 0
	for entry: Dictionary in NativeTrackVisual._road_mesh_cache: bytes += int(entry.bytes)
	if NativeTrackVisual._road_mesh_cache.size() > 2 or bytes > NativeTrackVisual.ROAD_CACHE_BUDGET: failures += 1; push_error("Road cache exceeded budget")
	var oversized := NativeTrack.new()
	oversized.grid_width = 4096
	oversized.grid_height = 4096
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	miss.add_child(mesh)
	var oversized_key: Array = ["oversized",NativeTrackVisual.VERSION,"pine",TrackTheme.palette("pine")]
	miss._remember_road_meshes(oversized_key,0,oversized)
	checks += 1
	if miss._restore_road_meshes(oversized_key): failures += 1; push_error("Oversized cache entry admitted")
	miss.free()
	if compare: DirAccess.remove_absolute(helper_path)
	if record and failures == 0:
		var output := FileAccess.open(golden_path,FileAccess.WRITE)
		output.store_string(JSON.stringify(golden,"\t",true)+"\n")
		output.close()
	print("ROAD_BUILD_TESTS: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
