extends SceneTree
const CACHE = preload("res://track/road_mesh_disk_cache.gd")
var checks: int = 0
var failures: int = 0

func _initialize() -> void: call_deferred("run")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures += 1; push_error(message)

func signature(node: Node) -> Array:
	var result: Array = []
	for child: Node in node.get_children():
		if not child is MeshInstance3D: continue
		var data: Array = [child.transform,child.layers,child.cast_shadow]
		for surface: int in range(child.mesh.get_surface_count()): data.append(child.mesh.surface_get_arrays(surface))
		var material: ShaderMaterial = child.material_override
		data.append(material.shader.resource_path)
		for uniform: Dictionary in material.shader.get_shader_uniform_list():
			var value: Variant = material.get_shader_parameter(uniform.name)
			if value is Texture2D:
				if value.resource_path.begins_with("res://assets/"):
					value = value.resource_path
				else:
					var texture_image: Image = value.get_image()
					value = [texture_image.get_size(),texture_image.get_format(),texture_image.has_mipmaps(),texture_image.get_data()]
			data.append([uniform.name,value])
		result.append(data)
	return result

func run() -> void:
	CACHE.directory = "user://road_cache_test_"+TrackLibrary.unique_id()
	var last_entry: Dictionary = {}
	for theme: String in ["pine","desert","winter","night_city"]:
		NativeTrackVisual._road_mesh_cache.clear()
		var document: Dictionary = TrackDocument.create_default()
		document.theme = theme
		document.pieces = [RoadPieces.create("curve",Vector2.ZERO),RoadPieces.create("hairpin",Vector2(10,-20))]
		var track: NativeTrack = TrackCompiler.compile(document)
		var key: Array = [track.content_hash,NativeTrackVisual.VERSION,theme,TrackTheme.palette(theme),true]
		var original := NativeTrackVisual.new()
		original.theme_id = theme
		original.colors = TrackTheme.palette(theme)
		root.add_child(original)
		original._build_creator_roads(track)
		var expected: Array = signature(original)
		check(not expected.is_empty(),theme+" road fixture is nonempty")
		last_entry = CACHE.read_entry(key)
		check(not last_entry.is_empty(),theme+" cache survives a real resource save/load")
		NativeTrackVisual._road_mesh_cache.clear()
		var restored := NativeTrackVisual.new()
		restored.theme_id = theme
		restored.colors = TrackTheme.palette(theme)
		root.add_child(restored)
		restored._build_creator_roads(track)
		check(signature(restored) == expected,theme+" disk-loaded meshes, materials, masks and render flags exactly match")
		for name: String in original.get_meta_list():
			check(restored.get_meta(name,null) == original.get_meta(name),theme+" retains "+name)
		original.free()
		restored.free()
		check(CACHE.read_entry([track.content_hash,"changed-kit",theme,TrackTheme.palette(theme),true]).is_empty(),"visual revision invalidates disk cache")
		check(CACHE.read_entry(["edited-track",NativeTrackVisual.VERSION,theme,TrackTheme.palette(theme),true]).is_empty(),"track edit invalidates disk cache")
		check(CACHE.read_entry([track.content_hash,NativeTrackVisual.VERSION,theme,TrackTheme.palette(theme),false]).is_empty(),"lighting partition option invalidates disk cache")
		var path: String = CACHE.directory.path_join(CACHE.identity(key)+".res")
		var file := FileAccess.open(path,FileAccess.WRITE)
		file.store_string("incomplete cache write")
		file.close()
		check(CACHE.read_entry(key).is_empty(),"corrupt artifact is rejected before resource parsing")
		check(CACHE.write_entry(last_entry),"corrupt artifact can be atomically replaced")
		check(not CACHE.read_entry(key).is_empty(),"replacement artifact is usable")
		DirAccess.remove_absolute(path+".sha256")
		check(CACHE.read_entry(key).is_empty(),"interrupted checksum commit is a cache miss")
		NativeTrackVisual._road_mesh_cache.clear()
		NativeTrackVisual.request_saved_road_bake(track)
		var editor := NativeTrackVisual.new()
		editor.editor_preview = true
		editor.theme_id = theme
		editor.colors = TrackTheme.palette(theme)
		root.add_child(editor)
		editor._build_creator_roads(track)
		check(not CACHE.read_entry(key).is_empty(),"saved editor road is baked when pending geometry completes")
		DirAccess.remove_absolute(path+".sha256")
		NativeTrackVisual.request_saved_road_bake(track)
		check(not CACHE.read_entry(key).is_empty(),"save immediately bakes an already completed editor road")
		editor.free()
		await process_frame
	var unrelated: String = CACHE.directory.path_join("player-file.json")
	var sentinel := FileAccess.open(unrelated,FileAccess.WRITE)
	sentinel.store_string("keep")
	sentinel.close()
	for index: int in range(CACHE.MAX_FILES+2):
		last_entry.key = ["eviction-"+str(index),NativeTrackVisual.VERSION,"night_city",TrackTheme.palette("night_city"),true]
		check(CACHE.write_entry(last_entry),"bounded cache write "+str(index))
	var count: int = 0
	var bytes: int = 0
	for name: String in DirAccess.get_files_at(CACHE.directory):
		if not CACHE._artifact_filename(name): continue
		count += 1
		var file := FileAccess.open(CACHE.directory.path_join(name),FileAccess.READ)
		bytes += file.get_length()
		file.close()
	check(count <= CACHE.MAX_FILES and bytes <= CACHE.MAX_TOTAL_BYTES,"disk cache stays within count/size limits")
	check(FileAccess.get_file_as_string(unrelated) == "keep","pruning ignores non-cache files")
	# Delete only the unique scratch directory created by this test.
	for name: String in DirAccess.get_files_at(CACHE.directory): DirAccess.remove_absolute(CACHE.directory.path_join(name))
	DirAccess.remove_absolute(CACHE.directory)
	print("ROAD_CACHE_TESTS: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
