extends SceneTree
## Cold-road A/B diagnostic; unchanged real mesh buffers are the acceptance fence.
func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var path: String = ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--document="): path = argument.trim_prefix("--document=")
	var document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	document.theme = "winter"
	var track: NativeTrack = TrackCompiler.compile(document)
	var before := GDScript.new()
	before.source_code = FileAccess.get_file_as_string("res://../docs/evidence/winter-performance-2026-10-11/before-uv-cache.gd").replace("class_name NativeTrackVisual\n", "").replace("class_name NativeTrackVisual\r\n", "")
	# Anonymous archived scripts cannot satisfy this unrelated named-class
	# scenery API. Fail explicitly if the road-only probe ever enters it.
	before.source_code = before.source_code.replace("WinterScenery.build_cover(self,track)",'assert(false,"Road-only probe cannot build cover")')
	if before.reload() != OK: quit(1); return
	var results: Array[Dictionary] = []
	for label: String in ["before","after","before","after"]:
		var visual: Node3D = before.new() if label == "before" else NativeTrackVisual.new()
		visual.theme_id = "winter"
		visual.colors = TrackTheme.palette("winter")
		visual.cache_road_meshes = false
		visual.persist_road_meshes = false
		root.add_child(visual)
		var start: int = Time.get_ticks_usec()
		await visual._build_creator_roads(track)
		var elapsed: float = float(Time.get_ticks_usec()-start)/1000.0
		var digest := HashingContext.new()
		digest.start(HashingContext.HASH_SHA256)
		var vertices: int = 0
		var indices: int = 0
		for node: Node in visual.get_children():
			if not node is MeshInstance3D: continue
			for surface: int in range(node.mesh.get_surface_count()):
				digest.update(var_to_bytes(node.mesh.surface_get_arrays(surface)))
				vertices += node.mesh.surface_get_array_len(surface)
				indices += node.mesh.surface_get_array_index_len(surface)
		var result: Dictionary = {"mode":label,"road_build_ms":elapsed,"mesh_sha256":digest.finish().hex_encode(),"vertices":vertices,"indices":indices}
		results.append(result)
		print("WINTER_ROAD_BUILD: ",JSON.stringify(result))
		visual.queue_free()
		await process_frame
	var exact: bool = true
	for result: Dictionary in results: if result.mesh_sha256 != results[0].mesh_sha256: exact = false
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://../docs/evidence/winter-performance-2026-10-11"))
	var output := FileAccess.open("res://../docs/evidence/winter-performance-2026-10-11/road-build-slippery.json",FileAccess.WRITE)
	output.store_string(JSON.stringify({"track_hash":track.content_hash,"visual_version":NativeTrackVisual.VERSION,"exact_mesh_parity":exact,"results":results},"\t"))
	print("WINTER_ROAD_BUILD_PARITY: ",exact)
	quit(0 if exact else 1)
