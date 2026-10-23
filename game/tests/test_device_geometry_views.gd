extends SceneTree
## Original two-pass worlds versus CPU-finished worlds, rendered together.
const ORIGINAL = preload("res://tests/fixtures/desert_relief_before_editor_latency.gd")
const ROADS = preload("res://editor/road_preparation.gd")
var checks: int = 0
var failures: int = 0
var metrics: Array = []
var output: String

func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)

func value_key(value: Variant) -> Variant:
	if value is Texture2D: return value.resource_path if not value.resource_path.is_empty() else [value.get_image().get_format(),value.get_image().get_data()]
	return value

func signature(node: Node) -> Array:
	var result: Array = [node.get_class()]
	if node is Node3D: result.append(node.transform)
	var mesh: Mesh
	if node is MeshInstance3D: mesh = node.mesh
	if node is MultiMeshInstance3D and node.multimesh != null:
		mesh = node.multimesh.mesh
		result.append([node.multimesh.instance_count,node.multimesh.buffer,node.multimesh.custom_aabb])
	if node is GeometryInstance3D:
		result.append([node.layers,node.cast_shadow])
		var material: Material = node.material_override
		if material is ShaderMaterial:
			var values: Array = [material.shader.code]
			for uniform: Dictionary in material.shader.get_shader_uniform_list(): values.append([uniform.name,value_key(material.get_shader_parameter(uniform.name))])
			result.append(values)
		elif material is BaseMaterial3D: result.append([material.albedo_color,material.roughness,material.cull_mode])
	if mesh != null:
		for i: int in range(mesh.get_surface_count()): result.append(mesh.surface_get_arrays(i))
	for child: Node in node.get_children(): result.append(signature(child))
	return result

func make_view(theme: String, track: NativeTrack) -> SubViewport:
	var viewport := SubViewport.new(); viewport.size = Vector2i(960,540)
	viewport.own_world_3d = true; viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var camera := Camera3D.new(); camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 90; viewport.add_child(camera)
	var target := Vector3(track.spawn.x,0,-track.spawn.y)
	camera.position = target+Vector3(18,66,55); camera.look_at(target); camera.current = true
	var light := DirectionalLight3D.new(); light.shadow_enabled = true; viewport.add_child(light)
	var environment := WorldEnvironment.new(); environment.environment = Environment.new()
	viewport.add_child(environment); TrackTheme.apply_lighting(theme,environment.environment,light)
	return viewport

func raw_packet(track: NativeTrack, theme: String) -> Dictionary:
	var builder := NativeTrackVisual.new(); builder.theme_id = theme; builder.colors = TrackTheme.palette(theme)
	builder._capture_road_arrays = true; builder.cache_road_meshes = false; builder.persist_road_meshes = false
	await builder._build_creator_roads(track)
	var metadata: Dictionary = {}
	for name: String in ["winter_smooth_sections","winter_deposits","desert_clod_count","desert_bank_sections"]:
		if builder.has_meta(name): metadata[name] = builder.get_meta(name)
	var result: Dictionary = {"key":ROADS.key_for(track),"parts":builder._prepared_road_parts,"metadata":metadata}
	builder.free()
	return result

func scene_case(theme: String, bridge: bool) -> void:
	ROADS.entries.clear(); ROADS.bytes = 0; ROADS.account_gpu([])
	NativeTrackVisual._road_mesh_cache.clear()
	var document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/knit_bridge_regression.json" if bridge else "res://tests/fixtures/star_spline_lap.json"))
	document.theme = theme
	var track: NativeTrack = TrackCompiler.compile(document)
	var canonical: String = var_to_bytes([track.metadata,track.content_hash,track.cells,track.deck_cells,track.route]).hex_encode().sha256_text()
	var before: SubViewport = make_view(theme,track)
	var after: SubViewport = make_view(theme,track)
	var began: int = Time.get_ticks_usec()
	var packet: Dictionary = await raw_packet(track,theme)
	var original := NativeTrackVisual.new(); original.cache_road_meshes = false; original.persist_road_meshes = false; original.race_road_packet = packet
	before.add_child(original)
	var support := BridgePresentation.new(track)
	if theme == "desert": support.visual_relief = ORIGINAL.new(track)
	await original.build(track,support)
	var original_ms: float = (Time.get_ticks_usec()-began)/1000.0
	began = Time.get_ticks_usec()
	var job = preload("res://editor/road_preparation_job.gd").start(track,self)
	while not job.done: await process_frame
	var current := NativeTrackVisual.new(); current.cache_road_meshes = false; current.persist_road_meshes = false; current.race_road_packet = job.result
	after.add_child(current)
	await current.build(track,BridgePresentation.new(track))
	var current_ms: float = (Time.get_ticks_usec()-began)/1000.0
	var label: String = theme+("-bridge" if bridge else "-star")
	check(signature(original) == signature(current),label+" exact geometry, material parameters and render flags")
	check(canonical == var_to_bytes([track.metadata,track.content_hash,track.cells,track.deck_cells,track.route]).hex_encode().sha256_text(),label+" canonical track remains unchanged")
	if DisplayServer.get_name() != "headless":
		for frame: int in range(5): await RenderingServer.frame_post_draw
		var image_before: Image = before.get_texture().get_image()
		var image_after: Image = after.get_texture().get_image()
		check(image_before.get_data() == image_after.get_data(),label+" exact native pixels")
		image_before.save_png(output.path_join(label+"-original.png")); image_after.save_png(output.path_join(label+"-device.png"))
	metrics.append({"case":label,"original_cpu_and_install_ms":original_ms,"device_cpu_and_install_ms":current_ms})
	print("DEVICE_GEOMETRY_VIEW ",JSON.stringify(metrics[-1]))
	before.free(); after.free(); await process_frame

func run() -> void:
	output = ProjectSettings.globalize_path("res://../build/device-track-loading/views-"+RenderingServer.get_current_rendering_method()+"-"+DisplayServer.get_name())
	DirAccess.make_dir_recursive_absolute(output)
	NativeTrackVisual.ROAD_DISK_CACHE.directory = ""
	if "--winter-only" in OS.get_cmdline_user_args():
		await scene_case("winter",false)
	else:
		for theme: String in ["desert","pine","winter"]: await scene_case(theme,false)
		await scene_case("desert",true)
	var file := FileAccess.open(output.path_join("report.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"metrics":metrics},"\t")); file.close()
	print("DEVICE_GEOMETRY_VIEWS: ",checks," checks, ",failures," failures; ",output)
	quit(1 if failures else 0)
