extends SceneTree
const DISK = preload("res://track/road_mesh_disk_cache.gd")
var checks: int = 0
var failures: int = 0
var metrics: Array = []
var folder: String

class GuardedRoad extends NativeTrackVisual:
	var generated: bool = false
	func _remember_road_meshes(key: Array, first: int, track: NativeTrack, geometry: String = "") -> void:
		generated = true
		super._remember_road_meshes(key,first,track,geometry)

func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)
func digest(visual: Node3D) -> String:
	var hash := HashingContext.new(); hash.start(HashingContext.HASH_SHA256)
	for node: MeshInstance3D in visual.get_children():
		hash.update(var_to_bytes([node.transform,node.layers,node.cast_shadow]))
		for surface: int in range(node.mesh.get_surface_count()): hash.update(var_to_bytes(node.mesh.surface_get_arrays(surface)))
		var material: ShaderMaterial = node.material_override
		hash.update(material.shader.code.to_utf8_buffer())
		for uniform: Dictionary in material.shader.get_shader_uniform_list():
			var value: Variant = material.get_shader_parameter(uniform.name)
			if value is Texture2D:
				value = value.resource_path if value.resource_path.begins_with("res://assets/") else [value.get_image().get_format(),value.get_image().get_data()]
			hash.update(var_to_bytes([uniform.name,value]))
	return hash.finish().hex_encode()

func run() -> void:
	folder = ProjectSettings.globalize_path("res://../build/large-road-cache-2026-10-14/"+RenderingServer.get_current_rendering_method())
	DirAccess.make_dir_recursive_absolute(folder); DISK.directory = folder.path_join("roads")
	var read_only: bool = "--read-only" in OS.get_cmdline_user_args()
	var expected: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(folder.path_join("expected.json"))) if read_only else {}
	for theme: String in ["desert","winter"]:
		var document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/star_spline_lap.json")); document.theme = theme
		var track: NativeTrack = TrackCompiler.compile(document)
		var key: Array = [track.content_hash,NativeTrackVisual.VERSION,theme,TrackTheme.palette(theme),true]
		var original := GuardedRoad.new(); original.theme_id = theme; original.colors = TrackTheme.palette(theme)
		root.add_child(original)
		if not read_only:
			original.persist_road_meshes = false
			var began: int = Time.get_ticks_usec()
			await original._build_creator_roads(track)
			var build_ms: float = (Time.get_ticks_usec()-began)/1000.0
			check(original.generated,"actual cold road geometry was generated")
			expected[theme] = digest(original)
			began = Time.get_ticks_usec(); original.persist_road_meshes = true; original._remember_road_meshes(key,0,track)
			var save_ms: float = (Time.get_ticks_usec()-began)/1000.0
			metrics.append({"theme":theme,"build_ms":build_ms,"save_ms":save_ms})
		original.free()
		NativeTrackVisual._road_mesh_cache.clear()
		var stored: Dictionary = DISK.read_entry(key)
		check(not stored.is_empty(),theme+" oversized roads admitted on disk")
		if not stored.is_empty():
			check(int(stored.bytes) > NativeTrackVisual.ROAD_CACHE_BUDGET and int(stored.bytes) <= DISK.MAX_RESIDENT_BYTES,theme+" fixture exceeds idle RAM budget but respects serialized expansion bound")
			NativeTrackVisual._admit_road_entry(stored)
			check(NativeTrackVisual._road_mesh_cache.is_empty(),"oversized road is never retained in idle memory cache")
		var restored := GuardedRoad.new(); restored.theme_id = theme; restored.colors = TrackTheme.palette(theme); root.add_child(restored)
		var began: int = Time.get_ticks_usec(); await restored._build_creator_roads(track)
		var load_ms: float = (Time.get_ticks_usec()-began)/1000.0
		check(not restored.generated,theme+" production path loaded instead of regenerating")
		check(digest(restored) == expected.get(theme,""),theme+" all arrays, shaders, uniforms, textures and render flags exactly round-trip")
		check(NativeTrackVisual._road_mesh_cache.is_empty(),"active restore leaves idle memory bounded")
		var file := FileAccess.open(DISK.directory.path_join(DISK.identity(key)+".res"),FileAccess.READ)
		var bytes: int = file.get_length() if file != null else 0
		if file != null: file.close()
		metrics.append({"theme":theme,"load_ms":load_ms,"artifact_bytes":bytes,"restart":read_only})
		restored.free(); await process_frame
	var file := FileAccess.open(folder.path_join("expected.json"),FileAccess.WRITE); file.store_string(JSON.stringify(expected)); file.close()
	var output: String = ProjectSettings.globalize_path("res://../docs/evidence/track-load-improvements-2026-10-14")
	file = FileAccess.open(output.path_join("large-roads"+("-restart" if read_only else "")+"-"+RenderingServer.get_current_rendering_method()+".json"),FileAccess.WRITE); file.store_string(JSON.stringify({"checks":checks,"failures":failures,"metrics":metrics},"\t")); file.close()
	print("LARGE_ROAD_CACHE: ",checks," checks, ",failures," failures ",JSON.stringify(metrics))
	quit(1 if failures else 0)
