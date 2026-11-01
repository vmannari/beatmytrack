extends "res://tests/profile_biome_shaders.gd"
## Same-scene material A/B against the frozen task-start generator.
const PROBE = preload("res://tests/probe_shader_variant_consolidation.gd")
const SAMPLERS = preload("res://tests/test_sampler_pruning.gd")

func run() -> void:
	folder = OS.get_environment("BMT_VARIANT_FOLDER")
	if folder.is_empty(): push_error("Explicit output folder required"); quit(1); return
	DirAccess.make_dir_recursive_absolute(folder)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var flags: Array = ["kerb","road_marking"]
	if not OS.get_environment("BMT_VARIANT_FLAGS").is_empty(): flags = Array(OS.get_environment("BMT_VARIANT_FLAGS").split(","))
	var candidate: GDScript = PROBE.generator([],false,true)
	if OS.get_environment("BMT_VARIANT_FINAL") == "1": candidate = PROBE.generator([],false,true)
	var baseline: GDScript = SAMPLERS.before_generator()
	if candidate == null: quit(1); return
	themes = ["pine","winter","desert","storm","night_city"]
	if not OS.get_environment("BMT_VARIANT_THEMES").is_empty(): themes.assign(OS.get_environment("BMT_VARIANT_THEMES").split(","))
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--themes="): themes.assign(arg.trim_prefix("--themes=").split(","))
		if arg == "--fringe": flags = ["edge_fringe"]; candidate = PROBE.generator(flags)
		if arg == "--edges": flags = ["asphalt_surface","raised_road_edge","edge_fringe","road_marking"]; candidate = PROBE.generator(flags)
		if arg == "--shoulders": flags = ["grass","gravel"]; candidate = PROBE.generator(flags)
	report = {"renderer":RenderingServer.get_current_rendering_method(),"flags":flags,"shipping_candidate":OS.get_environment("BMT_VARIANT_FINAL") == "1","themes":{},"note":"Same frozen world, camera, lights and textures. Program counts are unique source hashes, not engine pipeline counts. Interleaved desktop renderer timings; no cold driver-cache guarantee."}
	for theme: String in themes:
		root.size = Vector2i(1280,720)
		var doc: Dictionary = SAMPLERS.fixture("mixed_bridge",theme).metadata.creator_document.duplicate(true)
		doc.theme = theme
		var track: NativeTrack = TrackCompiler.compile(doc)
		var game: Node = load("res://core/game.tscn").instantiate()
		game.initial_track = track
		game.production_mode = true
		game.attempt_practice = true
		root.add_child(game)
		while not game.preparation_complete: await process_frame
		game.process_mode = Node.PROCESS_MODE_DISABLED
		game.race_cues.hide()
		game.sand_dust.hide()
		if game.winter_snow_wind != null: game.winter_snow_wind.hide()
		game.trails.hide()
		entries.clear()
		var pairs: Dictionary = {}
		var baseline_hashes: Dictionary = {}
		var candidate_hashes: Dictionary = {}
		for node: Node in game.track_ground.find_children("*","MeshInstance3D",true,false):
			var material: ShaderMaterial = node.material_override as ShaderMaterial
			if material == null or not material.has_meta("surface_dynamic_material"): continue
			var id: int = material.get_instance_id()
			if not pairs.has(id):
				var alternative: ShaderMaterial = material.get_meta("surface_dynamic_material").duplicate()
				alternative.render_priority = material.render_priority
				for uniform: Dictionary in material.shader.get_shader_uniform_list(): alternative.set_shader_parameter(uniform.name,material.get_shader_parameter(uniform.name))
				candidate.specialize(alternative)
				var control: ShaderMaterial = material.get_meta("surface_dynamic_material").duplicate()
				control.render_priority = material.render_priority
				for uniform: Dictionary in material.shader.get_shader_uniform_list(): control.set_shader_parameter(uniform.name,material.get_shader_parameter(uniform.name))
				if not control.get_meta("surface_preserve_branches",false): baseline.specialize(control)
				pairs[id] = {"baseline":control,"optimized":alternative}
			baseline_hashes[pairs[id].baseline.shader.code.sha256_text()] = true
			candidate_hashes[pairs[id].optimized.shader.code.sha256_text()] = true
			entries.append({"node":node,"baseline":pairs[id].baseline,"optimized":pairs[id].optimized})
		var proofs: Array = []
		for view: int in range(3):
			game.camera.follow(track.route[view*track.route.size()/3],Vector2.ZERO,0.0,0.0,true)
			await capture_pair("optimized", "")
			await capture_pair("baseline", "")
			await measure(root.get_viewport_rid(),2.0)
			var before: Image = await capture_pair("baseline",theme+"-"+str(view)+"-before.png")
			var after: Image = await capture_pair("optimized",theme+"-"+str(view)+"-after.png")
			var restored: Image = await capture_pair("baseline","")
			var proof: Dictionary = compare(before,after)
			proof.unstable = compare(before,restored).changed
			check(proof.unstable == 0,theme+" stable frozen control")
			check(proof.max_channel_delta <= 2,theme+" unchanged 2/255 visual allowance")
			proofs.append(proof)
		root.size = Vector2i(2560,1440)
		game.camera.follow(track.route[0],Vector2.ZERO,0.0,0.0,true)
		var viewport: RID = root.get_viewport_rid()
		RenderingServer.viewport_set_measure_render_time(viewport,true)
		var stages: Array = []
		for mode: String in ["baseline","optimized","optimized","baseline"]:
			set_mode(mode)
			await measure(viewport,0.5)
			var stage: Dictionary = await measure(viewport,2.0)
			stage.mode = mode
			stages.append(stage)
		report.themes[theme] = {"nodes":entries.size(),"baseline_programs":baseline_hashes.size(),"candidate_programs":candidate_hashes.size(),"proofs":proofs,"stages":stages}
		print("VARIANT_RENDER ",JSON.stringify({"theme":theme,"result":report.themes[theme]}))
		report.checks = checks; report.failures = failures
		FileAccess.open(folder.path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
		entries.clear()
		game.queue_free()
		for _frame: int in range(5): await process_frame
	print("VARIANT_RENDER_CHECKS ",checks," / ",failures)
	quit(1 if failures else 0)
