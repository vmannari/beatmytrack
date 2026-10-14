extends SceneTree
var failures: int = 0
var checks: int = 0
var materials: Array[ShaderMaterial] = []
var game: Node
func freeze_capture() -> void:
	game.paused = false
	game.hud.visible = false
	game.hud.pause_menu.hide()
	game.set_process(false)
	game.set_physics_process(false)
	game.process_mode = Node.PROCESS_MODE_DISABLED
const BEFORE: String = "res://../docs/evidence/desert-sun-glints-2026-10-13/before-source/game/track/"
func expand_shader(source: String) -> String:
	var include := RegEx.new()
	include.compile('#include "([^"]+)"')
	for pass_index: int in range(4):
		for match: RegExMatch in include.search_all(source):
			var path: String = match.get_string(1)
			var saved: String = BEFORE+path.get_file()
			var body: String = FileAccess.get_file_as_string(saved if FileAccess.file_exists(saved) else path)
			source = source.replace(match.get_string(),body)
	return source
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)
func finish(value: float) -> void:
	for material: ShaderMaterial in materials: material.set_shader_parameter("desert_glint_strength",value)
func shot() -> Image:
	for frame: int in range(45):
		freeze_capture()
		await RenderingServer.frame_post_draw
	var captured: Image = root.get_texture().get_image()
	captured.convert(Image.FORMAT_RGBA8)
	return captured
func difference(a: Image,b: Image) -> Dictionary:
	var count: int = 0
	var peak: float = 0.0
	var sum: float = 0.0
	for y: int in range(190,660):
		for x: int in range(180,1410):
			var ca: Color = a.get_pixel(x,y)
			var cb: Color = b.get_pixel(x,y)
			var d: float = maxf(absf(ca.r-cb.r),maxf(absf(ca.g-cb.g),absf(ca.b-cb.b)))
			if d > 1.0/255.0: count += 1
			peak = maxf(peak,d); sum += d
	return {"pixels":count,"peak":peak,"mean":sum/(470.0*1230.0)}
func run() -> void:
	root.size = Vector2i(1600,900)
	var folder: String = "res://../docs/evidence/desert-sun-glints-2026-10-13/"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--folder="): folder = argument.trim_prefix("--folder=").trim_suffix("/")+"/"
	folder += RenderingServer.get_current_rendering_method()+"/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	var doc: Dictionary = TrackLibrary.new().load_document("track_3e26605a8a90165e")
	if doc.is_empty(): doc = TrackDocument.create_default()
	doc.theme = "desert"
	var track: NativeTrack = TrackCompiler.compile(doc)
	var cells: PackedInt32Array = track.cells.duplicate()
	var content: String = track.content_hash
	game = load("res://core/game.tscn").instantiate()
	game.initial_track = track; game.production_mode = true
	game.hitch_diagnostics_enabled = false
	root.add_child(game)
	game.set_process(false); game.set_physics_process(false)
	game.race_cues.hide(); game.sand_dust.hide(); game.trails.hide()
	if game.cloud_shadow != null: game.cloud_shadow.hide()
	game.hud.message_label.hide()
	game.countdown_ticks = 0
	var pairs: Array[Dictionary] = []
	var state_before: Array = game.sim.state.snapshot()
	for node: Node in game.track_ground.find_children("*","MeshInstance3D",true,false):
		var material: ShaderMaterial = node.material_override as ShaderMaterial
		if material == null: continue
		for uniform: Dictionary in material.shader.get_shader_uniform_list():
			if uniform.name == "desert_glint_strength":
				materials.append(material)
				var dynamic: ShaderMaterial = material.get_meta("surface_dynamic_material",material)
				if node.name == "DesertLowCover":
					var original := VisualGeometry.material(Color.WHITE)
					original.vertex_color_use_as_albedo = true
					original.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT
					original.cull_mode = BaseMaterial3D.CULL_DISABLED
					pairs.append({"node":node,"before":original,"after":material})
				else:
					var original: ShaderMaterial = dynamic.duplicate()
					var shader := Shader.new()
					# Disposable caches can restore a compiled shader without a
					# resource path; role uniforms still identify its source.
					var source_file: String = "desert_road.gdshader"
					if material.get_shader_parameter("color_0") != null: source_file = "terrain.gdshader"
					elif material.get_shader_parameter("ground_color") != null: source_file = "ground.gdshader"
					elif node.name.begins_with("Hazard"): source_file = "hazard.gdshader"
					elif node.name == "BridgeAsphalt": source_file = "desert_bridge_road.gdshader"
					var path: String = BEFORE+source_file
					shader.code = expand_shader(FileAccess.get_file_as_string(path if FileAccess.file_exists(path) else "res://track/"+source_file))
					original.shader = shader
					if not node.name.begins_with("Hazard"):
						game.track_ground.call("_bind_grass",original)
						SurfaceShaderVariants.specialize(original)
					pairs.append({"node":node,"before":original,"after":material})
				break
	check(materials.size() > 4,"terrain, skirt, banks and pebbles receive scoped mineral finish")
	var cover: MeshInstance3D = game.track_ground.get_node("DesertLowCover")
	var arrays: Array = cover.mesh.surface_get_arrays(0)
	var stones: int = 0
	var scrub: int = 0
	for tag: Vector2 in arrays[Mesh.ARRAY_TEX_UV2]:
		if tag.x > 0.5: stones += 1
		else: scrub += 1
	check(stones > 0 and scrub > 0,"existing cover batch separates stone finish from matte scrub")
	var camera: FollowCamera = game.camera
	var report: Dictionary = {"renderer":RenderingServer.get_current_rendering_method(),"views":[]}
	for fraction: float in [0.0,0.35]:
		var point: Vector2 = track.route[int(track.route.size()*fraction)]
		camera.follow(point,Vector2.ZERO,0.0,0.0,true)
		finish(0.0); var before: Image = await shot()
		finish(1.0); var after: Image = await shot()
		finish(0.0); var restored: Image = await shot()
		var delta: Dictionary = difference(before,after)
		var stability: Dictionary = difference(before,restored)
		if stability.peak > 0.0:
			print("RESTORATION_DIAGNOSTIC: ",fraction," ",JSON.stringify(stability))
			before.save_png(folder+"unstable-before.png")
			restored.save_png(folder+"unstable-restored.png")
		report.views.append({"fraction":fraction,"contribution":delta,"restored":stability})
		check(stability.peak == 0.0,"on/off comparison preserves base pigment and scene")
		check(delta.pixels > 100 and delta.peak > 0.01,"real sun produces visible mineral highlights")
		for entry: Array in [["before",before],["after",after]]:
			check(entry[1].save_png(folder+str(entry[0])+"-%02d.png"%int(fraction*100)) == OK,"sun-finish capture saved")
	# Isolate actual terrain: disable bank/pebble finishes so their visible
	# highlights cannot satisfy the owner's flat-sand requirement.
	finish(0.0)
	var terrain_before: Image = await shot()
	for material: ShaderMaterial in materials:
		if material.get_shader_parameter("color_0") != null or material.get_shader_parameter("ground_color") != null or material.get_shader_parameter("grass") == true:
			material.set_shader_parameter("desert_glint_strength",1.0)
	var terrain_only: Image = await shot()
	var terrain_delta: Dictionary = difference(terrain_before,terrain_only)
	report["terrain_only"] = terrain_delta
	check(terrain_delta.pixels > 1000 and terrain_delta.peak > 0.03,"terrain texture reflects sunlight with banks and pebbles disabled")
	terrain_only.save_png(folder+"terrain-only.png")
	finish(1.0)
	var origin: Vector3 = camera.position
	var baseline: Image = await shot()
	baseline.save_png(folder+"motion-reference.png")
	var maximum: float = 0.0
	# Tiny subpixel camera shifts: stable pigment, bounded physical glint motion.
	for frame: int in range(24):
		freeze_capture()
		camera.position = origin+Vector3(sin(frame*.4)*0.002,0,cos(frame*.3)*0.002)
		await RenderingServer.frame_post_draw
		var current: Image = root.get_texture().get_image()
		current.convert(Image.FORMAT_RGBA8)
		var delta: Dictionary = difference(baseline,current)
		maximum = maxf(maximum,float(delta.mean))
		if delta.mean >= 0.01: print("MOTION_DIAGNOSTIC: ",frame," ",JSON.stringify(delta)," camera=",camera.position)
		if frame%4 == 0: current.save_png(folder+"motion-%02d.png"%frame)
	report["motion_mean_max"] = maximum
	print("GLINT_MOTION_DELTA: ",maximum)
	check(maximum < 0.01,"subpixel camera movement has bounded highlight/pigment change")
	camera.position = origin
	finish(0.0)
	var disabled: Image = await shot()
	for pair: Dictionary in pairs: pair.node.material_override = pair.before
	var original: Image = await shot()
	var original_delta: Dictionary = difference(original,disabled)
	print("ORIGINAL_DISABLED_DELTA: ",JSON.stringify(original_delta))
	original.save_png(folder+"original-materials.png")
	disabled.save_png(folder+"disabled-materials.png")
	if original_delta.peak > 2.0/255.0:
		for pair: Dictionary in pairs: pair.node.material_override = pair.after
		for pair: Dictionary in pairs:
			pair.node.material_override = pair.before
			var diagnostic: Image = await shot()
			print("MATERIAL_BASELINE: ",pair.node.name," ",JSON.stringify(difference(disabled,diagnostic)))
			pair.node.material_override = pair.after
	report["original_disabled_delta"] = original_delta
	check(original_delta.peak <= 2.0/255.0,"disabled finish retains original diffuse/pigment, including pebbles")
	# Paired complete material cost, including the new mineral sample and BRDF.
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var viewport: RID = root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(viewport,true)
	var stages: Array[Dictionary] = []
	for enabled: bool in [false,true,false,true]:
		for pair: Dictionary in pairs: pair.node.material_override = pair.after if enabled else pair.before
		finish(1.0)
		var start: int = Time.get_ticks_usec()
		while Time.get_ticks_usec()-start < 1000000:
			freeze_capture(); await process_frame
		var gpu: Array[float] = []
		start = Time.get_ticks_usec()
		while Time.get_ticks_usec()-start < 2000000:
			freeze_capture()
			await process_frame
			gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(viewport))
		gpu.sort()
		stages.append({"enabled":enabled,"samples":gpu.size(),"gpu_p50_ms":gpu[gpu.size()/2],"gpu_p95_ms":gpu[int(gpu.size()*.95)],"draws":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"triangles":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)})
	report["paired_gpu"] = stages
	check(cells == track.cells and content == track.content_hash and state_before == game.sim.state.snapshot(),"finish preserves canonical cells/hash/state")
	FileAccess.open(folder+"report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("DESERT_SUN_GLINTS: ",checks," checks; ",failures," failures; ",JSON.stringify(report))
	game.queue_free(); await process_frame
	quit(1 if failures else 0)
