extends SceneTree
## Review-only attribution. Transient script copies; shipping sources unchanged.
const Cloud = preload("res://backend/cloud_tracks.gd")
const Tracks = preload("res://backend/prepared_track_cache.gd")
const Worlds = preload("res://track/prepared_world_cache.gd")
var folder: String
var output_folder: String = "res://../docs/evidence/track-load-review-2026-10-13"
var report: Dictionary = {"samples": [], "cache": [], "components": []}
var game_script: GDScript
var visual_script: GDScript

func _initialize() -> void: run.call_deferred()

func source(path: String) -> String:
	return FileAccess.get_file_as_string(path).replace("\r\n", "\n")

func script_copy(code: String) -> GDScript:
	var script := GDScript.new()
	script.source_code = code
	assert(script.reload() == OK, "review script compiles")
	return script

func instrument() -> void:
	var code: String = source("res://track/native_track_visual.gd").replace("class_name NativeTrackVisual\n", "")
	code += "\nvar review_marks: Dictionary = {}\nvar review_begin_us: int = 0\nfunc review_mark(label: String) -> void:\n\treview_marks[label] = Time.get_ticks_usec() - review_begin_us\n"
	var begin: int = code.find("func build(")
	var end: int = code.find("\nfunc ", begin + 1)
	var body: String = code.substr(begin, end - begin)
	body = body.replace("\t_menu_slices = menu_slices", "\treview_begin_us = Time.get_ticks_usec()\n\t_menu_slices = menu_slices")
	body = body.replace("\tif reuse_world and PREPARED_WORLDS.restore(world_key,self): return", "\tif reuse_world and PREPARED_WORLDS.restore(world_key,self):\n\t\treview_mark(\"world_restore\")\n\t\treturn")
	body = body.replace("\t\tworld_built = true\n\t\treturn", "\t\treview_mark(\"world_restore\")\n\t\tworld_built = true\n\t\treturn")
	for marker: Array in [["\tawait _build_terrain(track)", "terrain"], ["\tawait _build_creator_roads(track)", "roads"], ["\tawait _build_barriers(track)", "barriers"], ["\t\tawait _build_low_cover(track)", "cover"], ["\t\tawait _build_placed_objects(track)", "objects"], ["\tbridge.build(self)", "bridges"], ["\t_build_finish(track)", "finish"], ["\t_build_snow_banks(track)", "snow"], ["\tif reuse_world: PREPARED_WORLDS.remember(world_key,self,track)", "world_admission"]]:
		assert(body.count(marker[0]) == 1, "visual marker unique: " + marker[1])
		var indent: String = "\t\t" if marker[1] in ["cover", "objects"] else "\t"
		body = body.replace(marker[0], marker[0] + "\n" + indent + "review_mark(\"" + marker[1] + "\")")
	# Retain the NativeTrackVisual type required by the shared sand/road emitters.
	visual_script = script_copy("extends NativeTrackVisual\n" + body + "\nvar review_marks: Dictionary = {}\nvar review_begin_us: int = 0\nfunc review_mark(label: String) -> void:\n\treview_marks[label] = Time.get_ticks_usec() - review_begin_us\n")
	var geometry_argument: bool = code.contains("track: NativeTrack, geometry_key: String")
	var extra_parameter: String = ', geometry_key: String = ""' if geometry_argument else ""
	var extra_argument: String = ",geometry_key" if geometry_argument else ""
	visual_script.source_code += "\nvar review_road_bytes: int = 0\nfunc _remember_road_meshes(key: Array, first_child: int, data: NativeTrack" + extra_parameter + ") -> void:\n\treview_road_bytes = data.grid_width * data.grid_height * 16\n\tfor index: int in range(first_child,get_child_count()):\n\t\tvar node: MeshInstance3D = get_child(index) as MeshInstance3D\n\t\tif node == null or not node.mesh is ArrayMesh: continue\n\t\tfor surface: int in range(node.mesh.get_surface_count()):\n\t\t\treview_road_bytes += node.mesh.surface_get_array_len(surface)*96 + node.mesh.surface_get_array_index_len(surface)*4\n\tsuper._remember_road_meshes(key,first_child,data" + extra_argument + ")\n"
	assert(visual_script.reload() == OK)
	code = source("res://core/game.gd")
	code += "\nvar review_marks: Dictionary = {}\nvar review_begin_us: int = 0\nvar review_visual_script: GDScript\nfunc review_mark(label: String) -> void:\n\treview_marks[label] = Time.get_ticks_usec() - review_begin_us\n"
	begin = code.find("func _ready()")
	end = code.find("\nfunc ", begin + 1)
	body = code.substr(begin, end - begin)
	body = body.replace("func _ready() -> void:", "func _ready() -> void:\n\treview_begin_us = Time.get_ticks_usec()")
	for marker: Array in [["\t_build_ground(world)", "ground"], ["\t_update_weather()", "weather"], ["\tworld.add_child(car)", "car"], ["\tcontact_shadow = ContactShading.car_shadow(world)", "ghost_and_shadow"], ["\tcar_weathering.restore(VehicleCondition.read(preference_records, vehicle_id))", "weathering"], ["\tworld.add_child(trails)", "trails"], ["\t\tsand_dust.configure_snow_surface(track_ground)", "snow_surface"], ["\tworld.add_child(sand_dust)", "particles"], ["\tadd_child(vehicle_audio)", "audio_ready"], ["\tvehicle_audio.configure(vehicle_id,handling,car)", "audio_configure"], ["\tworld.add_child(camera)", "camera"], ["\tadd_child(hud)", "hud"], ["\trestart()", "restart"]]:
		assert(body.count(marker[0]) == 1, "game marker unique: " + marker[1])
		var indent: String = "\t\t" if marker[1] == "snow_surface" else "\t"
		body = body.replace(marker[0], marker[0] + "\n" + indent + "review_mark(\"" + marker[1] + "\")")
	code = code.substr(0, begin) + body + code.substr(end)
	code = code.replace("var visual := NativeTrackVisual.new()", "var visual = review_visual_script.new()")
	game_script = script_copy(code)

func deltas(marks: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	var previous: int = 0
	for label: String in marks:
		result[label] = (int(marks[label]) - previous) / 1000.0
		previous = int(marks[label])
	return result

func race(track: NativeTrack, label: String, preferences: bool) -> void:
	var game: Node = load("res://core/game.tscn").instantiate()
	game.set_script(game_script)
	game.review_visual_script = visual_script
	game.initial_track = track
	game.production_mode = true
	game.process_mode = Node.PROCESS_MODE_DISABLED
	if preferences:
		var records := LocalRecords.new(folder.path_join("records.json"))
		records.settings.ghost_mode = "off"
		game.preference_records = records
	var started: int = Time.get_ticks_usec()
	root.add_child(game)
	var ready_us: int = Time.get_ticks_usec() - started
	game.hitch_diagnostics.persist_enabled = false
	game._process(0.0)
	var finish: VehicleWeathering = game.car_weathering
	var warm: bool = finish.begin_render_warmup()
	if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw
	finish.end_render_warmup()
	if warm and DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw
	assert(game.sim.state.tick == 0 and game.countdown_ticks == 360 and game.track_session.target_laps == 5)
	var row: Dictionary = {"label": label, "prefs": preferences, "ready_ms": ready_us / 1000.0, "to_prepared_draw_ms": (Time.get_ticks_usec() - started) / 1000.0, "game_ms": deltas(game.review_marks), "world_ms": deltas(game.track_ground.review_marks), "ghost_mesh_built": game.personal_ghost != null and game.personal_ghost.mesh != null, "ghost_mode": game.ghost_mode, "ghost_recordings": game.ghost_bests.size()}
	report.samples.append(row)
	row.road_admission_bytes = game.track_ground.review_road_bytes
	row.road_cache = []
	for cached: Dictionary in NativeTrackVisual._road_mesh_cache: row.road_cache.append({"theme": cached.key[2], "bytes": cached.bytes})
	print("LOAD_REVIEW_SAMPLE ", JSON.stringify(row))
	if preferences:
		var begin: int = Time.get_ticks_usec()
		var mesh: ArrayMesh = PersonalGhost.mesh_for(game.car)
		report.components.append({"label": label, "ghost_mesh_ms": (Time.get_ticks_usec() - begin) / 1000.0, "vertices": mesh.surface_get_array_len(0)})
	game.free()
	await process_frame

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--evidence="): output_folder = argument.trim_prefix("--evidence=")
	folder = ProjectSettings.globalize_path("res://../build/track-load-review-2026-10-13")
	DirAccess.make_dir_recursive_absolute(folder)
	NativeTrackVisual.ROAD_DISK_CACHE.directory = folder.path_join("roads")
	Tracks.clear(); Worlds.entries.clear()
	instrument()
	if "--components-only" in OS.get_cmdline_user_args():
		await components_only()
		write_report("components.json")
		quit()
		return
	if "--artifact-only" in OS.get_cmdline_user_args():
		await artifact_only()
		write_report("artifact.json")
		quit()
		return
	var document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/star_spline_lap.json"))
	var body: String = JSON.stringify(document)
	var path: String = folder.path_join("document.json")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(body); file.close()
	var entry: Dictionary = {"cache_path": path, "content_hash": body.sha256_text(), "id": "fixture", "name": "Fixture", "version_id": "fixture-version", "track_id": "fixture-track", "creator": "Fixture"}
	for index: int in range(4):
		var began: int = Time.get_ticks_usec()
		var track: NativeTrack = Cloud.compile_entry(entry)
		assert(track != null)
		var compile_us: int = Time.get_ticks_usec() - began
		began = Time.get_ticks_usec()
		assert(not Cloud.cached_document(entry).is_empty())
		var validate_us: int = Time.get_ticks_usec() - began
		began = Time.get_ticks_usec()
		assert(Tracks.restore([path, entry.content_hash, TrackCompiler.VERSION]) != null)
		var restore_us: int = Time.get_ticks_usec() - began
		report.cache.append({"pass": index, "compile_ms": compile_us / 1000.0, "document_validation_ms": validate_us / 1000.0, "snapshot_restore_ms": restore_us / 1000.0})
		await race(track, "star-%d" % index, index > 0)
	for theme: String in ["desert", "winter", "storm", "night_city"]:
		document.theme = theme
		var track: NativeTrack = TrackCompiler.compile(document)
		assert(track != null)
		await race(track, theme + "-cold", true)
		await race(track, theme + "-repeat", true)
		var bytes: int = 0
		for cached: Dictionary in Worlds.entries: bytes += int(cached.bytes)
		report.cache.append({"theme": theme, "world_entries": Worlds.entries.size(), "world_bytes": bytes})
	report.engine = Engine.get_version_info().string
	report.renderer = RenderingServer.get_current_rendering_method()
	report.adapter = RenderingServer.get_video_adapter_name()
	var output: String = ProjectSettings.globalize_path(output_folder)
	DirAccess.make_dir_recursive_absolute(output)
	write_report("review-admission.json")
	print("LOAD_REVIEW_COMPLETE samples=", report.samples.size(), " zero_tick_countdown_checks=", report.samples.size())
	quit()

func write_report(filename: String) -> void:
	var output: String = ProjectSettings.globalize_path(output_folder)
	DirAccess.make_dir_recursive_absolute(output)
	var file := FileAccess.open(output.path_join(filename), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t")); file.close()

func components_only() -> void:
	var track: NativeTrack = NativeTrack.read("res://resources/tracks/starter_circuit.json")
	await race(track, "components-prefs", true)
	var material := ShaderMaterial.new()
	material.shader = preload("res://track/creator_road.gdshader")
	material.set_shader_parameter("hybrid_grass", true)
	material.set_shader_parameter("asphalt_surface", true)
	var values: Array[float] = []
	for index: int in range(30):
		var sample: ShaderMaterial = material.duplicate()
		var started: int = Time.get_ticks_usec()
		SurfaceShaderVariants.specialize(sample)
		values.append((Time.get_ticks_usec() - started) / 1000.0)
	values.sort()
	report.components.append({"shader_specialize_warm_median_ms": values[15], "shader_specialize_max_ms": values[-1], "calls": values.size()})
	for loop: String in ["compact_0_load", "compact_1_load", "compact_2_load", "road"]:
		var extension: String = ".ogg" if loop == "road" else ".wav"
		var original: AudioStream = load(VehicleAudio.BANK + loop + extension)
		values.clear()
		for index: int in range(8):
			var started: int = Time.get_ticks_usec()
			var prepared: AudioStream = AudioLoop.prepare(original)
			values.append((Time.get_ticks_usec() - started) / 1000.0)
			assert(prepared != original)
		values.sort()
		report.components.append({"audio_loop": loop, "prepare_median_ms": values[4], "prepare_max_ms": values[-1]})
	print("LOAD_REVIEW_COMPONENTS ", JSON.stringify(report.components))

func artifact_only() -> void:
	var document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/star_spline_lap.json"))
	document.theme = "desert"
	var track: NativeTrack = TrackCompiler.compile(document)
	var visual: NativeTrackVisual = visual_script.new()
	visual.theme_id = "desert"
	visual.colors = TrackTheme.palette("desert")
	visual.persist_road_meshes = false
	root.add_child(visual)
	var started: int = Time.get_ticks_usec()
	await visual._build_creator_roads(track)
	var generated_us: int = Time.get_ticks_usec() - started
	var meshes: Array[Dictionary] = []
	for node: Node in visual.get_children():
		if node is MeshInstance3D and node.mesh is ArrayMesh:
			meshes.append({"mesh":node.mesh,"material":node.material_override,"transform":node.transform,"layers":node.layers,"shadow":node.cast_shadow})
	var artifact = NativeTrackVisual.ROAD_DISK_CACHE.ARTIFACT.new()
	artifact.cache_id = "review-generated-only"
	artifact.meshes = meshes
	artifact.estimated_bytes = visual.review_road_bytes
	var path: String = folder.path_join("large-road-review.res")
	started = Time.get_ticks_usec()
	assert(ResourceSaver.save(artifact,path,ResourceSaver.FLAG_COMPRESS) == OK)
	var save_us: int = Time.get_ticks_usec() - started
	var file := FileAccess.open(path,FileAccess.READ)
	var size: int = file.get_length()
	file.close()
	started = Time.get_ticks_usec()
	var loaded: Resource = ResourceLoader.load(path,"",ResourceLoader.CACHE_MODE_IGNORE)
	var load_us: int = Time.get_ticks_usec() - started
	assert(loaded != null and loaded.meshes.size() == meshes.size())
	for index: int in range(meshes.size()):
		var expected: Dictionary = meshes[index]
		var actual: Dictionary = loaded.meshes[index]
		assert(expected.transform == actual.transform and expected.layers == actual.layers and expected.shadow == actual.shadow)
		assert(expected.mesh.get_surface_count() == actual.mesh.get_surface_count())
		for surface: int in range(expected.mesh.get_surface_count()): assert(expected.mesh.surface_get_arrays(surface) == actual.mesh.surface_get_arrays(surface))
		assert(expected.material.shader.code == actual.material.shader.code)
		for uniform: Dictionary in expected.material.shader.get_shader_uniform_list():
			var a: Variant = expected.material.get_shader_parameter(uniform.name)
			var b: Variant = actual.material.get_shader_parameter(uniform.name)
			if a is Texture2D:
				assert(b is Texture2D and a.get_image().get_data() == b.get_image().get_data())
			else: assert(a == b)
	report.artifact = {"theme":"desert","build_ms":generated_us/1000.0,"admission_estimate_bytes":visual.review_road_bytes,"road_cache_budget":NativeTrackVisual.ROAD_CACHE_BUDGET,"compressed_file_bytes":size,"save_ms":save_us/1000.0,"load_ms":load_us/1000.0,"meshes":meshes.size(),"roundtrip_exact_arrays_shaders_uniforms_textures":true}
	print("LOAD_REVIEW_ARTIFACT ",JSON.stringify(report.artifact))
	visual.free()
