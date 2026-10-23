extends SceneTree
## NRG01/NRG02: scalar and native road kernels under the same scene renderer.
const ACCEL = preload("res://track/geometry_acceleration.gd")
const ROADS = preload("res://editor/road_preparation.gd")
var checks: int = 0
var failures: int = 0
var metrics: Array = []
var output: String

func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; print("FAILED ",label)

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

func share_equal_materials(expected: Node, actual: Node) -> void:
	# Exact independent material/mesh signatures were checked above. Reuse only
	# the equal material resources so coplanar seam ownership is not reordered
	# by newly allocated material RIDs in the two independent viewports.
	if expected is GeometryInstance3D and actual is GeometryInstance3D:
		actual.material_override = expected.material_override
	for index: int in range(expected.get_child_count()):
		share_equal_materials(expected.get_child(index),actual.get_child(index))

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
	if theme == "storm":
		# Each world owns a completed copy of the static reflection sky. The
		# shipping incremental Sky resource otherwise settles independently.
		environment.environment.sky = environment.environment.sky.duplicate(true)
		environment.environment.sky.process_mode = Sky.PROCESS_MODE_QUALITY
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
	after.render_target_update_mode = SubViewport.UPDATE_DISABLED
	var began: int = Time.get_ticks_usec()
	ACCEL.winter_enabled = not ("--winter-port" in OS.get_cmdline_user_args() or "--winter-port-repeat" in OS.get_cmdline_user_args())
	ACCEL.roads_enabled = false
	var packet: Dictionary = await raw_packet(track,theme)
	var original := NativeTrackVisual.new(); original.process_mode = Node.PROCESS_MODE_DISABLED; original.cache_road_meshes = false; original.persist_road_meshes = false; original.race_road_packet = packet
	before.add_child(original)
	var support := BridgePresentation.new(track)
	await original.build(track,support)
	var original_ms: float = (Time.get_ticks_usec()-began)/1000.0
	ACCEL.winter_enabled = true
	ACCEL.roads_enabled = not "--scalar-control" in OS.get_cmdline_user_args()
	began = Time.get_ticks_usec()
	var prepared: Dictionary = await raw_packet(track,theme)
	var current := NativeTrackVisual.new(); current.process_mode = Node.PROCESS_MODE_DISABLED; current.cache_road_meshes = false; current.persist_road_meshes = false; current.race_road_packet = prepared
	before.add_child(current)
	current.hide()
	await current.build(track,BridgePresentation.new(track))
	var current_ms: float = (Time.get_ticks_usec()-began)/1000.0
	var label: String = theme+("-bridge" if bridge else "-star")
	check(signature(original) == signature(current),label+" exact geometry, material parameters and render flags")
	check(canonical == var_to_bytes([track.metadata,track.content_hash,track.cells,track.deck_cells,track.route]).hex_encode().sha256_text(),label+" canonical track remains unchanged")
	if DisplayServer.get_name() != "headless":
		share_equal_materials(original,current)
		# Render each certified scene through the same camera, reflection sky,
		# shadow maps and viewport. Separate World3D radiance caches can differ
		# by one quantisation level even for identical source geometry.
		after.render_target_update_mode = SubViewport.UPDATE_DISABLED
		current.hide(); original.show()
		before.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		for frame: int in range(5): await RenderingServer.frame_post_draw
		before.render_target_update_mode = SubViewport.UPDATE_DISABLED
		await RenderingServer.frame_post_draw
		var image_before: Image = before.get_texture().get_image()
		if "--repeat-control" in OS.get_cmdline_user_args() or "--winter-port-repeat" in OS.get_cmdline_user_args():
			original.show(); current.hide()
		else:
			original.hide(); current.show()
		before.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		for frame: int in range(5): await RenderingServer.frame_post_draw
		before.render_target_update_mode = SubViewport.UPDATE_DISABLED
		await RenderingServer.frame_post_draw
		var image_after: Image = before.get_texture().get_image()
		image_before.save_png(output.path_join(label+"-original.png")); image_after.save_png(output.path_join(label+"-device.png"))
		if image_before.get_data() != image_after.get_data():
			var a: PackedByteArray = image_before.get_data()
			var b: PackedByteArray = image_after.get_data()
			var changed: int = 0
			var maximum: int = 0
			for i: int in range(a.size()):
				if a[i] != b[i]: changed += 1; maximum = maxi(maximum,absi(int(a[i])-int(b[i])))
			print("PIXEL_DIFFERENCE ",label," bytes=",changed," maximum=",maximum)
		check(image_before.get_data() == image_after.get_data(),label+" exact native pixels")
	metrics.append({"case":label,"original_cpu_and_install_ms":original_ms,"device_cpu_and_install_ms":current_ms})
	print("NATIVE_ROAD_VIEW ",JSON.stringify(metrics[-1]))
	before.free(); after.free(); await process_frame

func run() -> void:
	Engine.time_scale = 0.0
	output = ProjectSettings.globalize_path("res://../build/native-road-loading/views-"+RenderingServer.get_current_rendering_method()+"-"+DisplayServer.get_name())
	if "--winter-port" in OS.get_cmdline_user_args() or "--winter-port-repeat" in OS.get_cmdline_user_args(): output = ProjectSettings.globalize_path("res://../build/native-winter-raster/views-"+RenderingServer.get_current_rendering_method()+"-"+DisplayServer.get_name())
	if "--repeat-control" in OS.get_cmdline_user_args() or "--winter-port-repeat" in OS.get_cmdline_user_args(): output += "-repeat-control"
	DirAccess.make_dir_recursive_absolute(output)
	NativeTrackVisual.ROAD_DISK_CACHE.directory = ""
	if "--repeat-control" in OS.get_cmdline_user_args() or "--winter-port-repeat" in OS.get_cmdline_user_args():
		await scene_case("winter",false)
		await scene_case("storm",false)
	elif "--winter-port" in OS.get_cmdline_user_args():
		await scene_case("winter",false)
		await scene_case("winter",true)
	elif "--tail-only" in OS.get_cmdline_user_args():
		await scene_case("storm",false)
		await scene_case("night_city",false)
		await scene_case("desert",true)
	elif "--storm-only" in OS.get_cmdline_user_args():
		await scene_case("storm",false)
	elif "--winter-only" in OS.get_cmdline_user_args():
		await scene_case("winter",false)
	else:
		for theme: String in ["desert","pine","winter","storm","night_city"]: await scene_case(theme,false)
		await scene_case("desert",true)
	var file := FileAccess.open(output.path_join("report.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"metrics":metrics},"\t")); file.close()
	print("NATIVE_ROAD_VIEWS: ",checks," checks, ",failures," failures; ",output)
	quit(1 if failures else 0)
