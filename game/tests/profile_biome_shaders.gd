extends "res://tests/test_winter_environment.gd"
## Explicit, unscored same-scene A/B. Baseline shader sources are archived fixtures.
const BASELINE: String = "res://tests/fixtures/biome_performance_before/"
var folder: String = "res://../docs/evidence/biome-performance-2026-10-13/paired"
var seconds: float = 6.0
var entries: Array[Dictionary] = []
var report: Dictionary = {}
var themes: Array[String] = ["winter","desert"]

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--folder="): folder = argument.trim_prefix("--folder=")
		if argument.begins_with("--seconds="): seconds = float(argument.trim_prefix("--seconds="))
		if argument.begins_with("--themes="): themes.assign(argument.trim_prefix("--themes=").split(","))
	folder += "/" + RenderingServer.get_current_rendering_method()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	NativeTrackVisual.ROAD_DISK_CACHE.directory = ""
	var old_script := GDScript.new()
	var source: String = FileAccess.get_file_as_string(BASELINE + "surface_shader_variants.gd.txt")
	source = source.replace("class_name SurfaceShaderVariants","")
	for path: String in SurfaceShaderVariants.INCLUDES:
		source = source.replace('preload("' + path + '")','preload("' + BASELINE + path.get_file() + '")')
	old_script.source_code = source
	check(old_script.reload() == OK,"archived baseline shader generator compiles")
	var old: RefCounted = old_script.new()
	report = {"engine":Engine.get_version_info().string,"device":RenderingServer.get_video_adapter_name(),"renderer":RenderingServer.get_current_rendering_method(),"visual_version":NativeTrackVisual.VERSION,"note":"Same frozen scene, camera, mesh buffers, artwork and light; shaders, exact mask packing and opaque draw order switch. Effects hidden for pixel proof. Desktop GPU throughput, not phone or sustained driving FPS.","themes":{}}
	for theme: String in themes:
		var doc: Dictionary = make_track().metadata.creator_document.duplicate(true)
		doc.theme = theme
		var track: NativeTrack = TrackCompiler.compile(doc)
		var game: Node = load("res://core/game.tscn").instantiate()
		game.initial_track = track
		game.production_mode = true
		game.attempt_practice = true
		root.add_child(game)
		for i: int in range(10): await process_frame
		check(game.preference_records == null and game.rating_records == null,"diagnostic has no record adapters")
		game.paused = true
		game.set_process(false)
		game.set_physics_process(false)
		game.race_cues.hide()
		game.sand_dust.hide()
		if game.winter_snow_wind != null: game.winter_snow_wind.hide()
		game.trails.hide()
		entries.clear()
		for node: Node in game.track_ground.find_children("*","MeshInstance3D",true,false):
			var material: ShaderMaterial = node.material_override as ShaderMaterial
			if material == null or not material.has_meta("surface_dynamic_material"): continue
			var baseline: ShaderMaterial = material.get_meta("surface_dynamic_material").duplicate()
			baseline.render_priority = 0
			if material.get_shader_parameter("terrain_packed") == true:
				var packed: Image = (material.get_shader_parameter("surface_low") as Texture2D).get_image()
				var slots: Vector4i = material.get_shader_parameter("terrain_slots")
				var low := Image.create(packed.get_width(),packed.get_height(),false,Image.FORMAT_RGBA8)
				var high := Image.create(packed.get_width(),packed.get_height(),false,Image.FORMAT_RGBA8)
				for y: int in range(packed.get_height()):
					for x: int in range(packed.get_width()):
						var channels: Color = packed.get_pixel(x,y)
						var a := Color(0,0,0,0)
						var b := Color(0,0,0,0)
						for channel: int in range(4):
							var kind: int = slots[channel]
							if kind >= 0 and kind < 4: a[kind] = channels[channel]
							elif kind >= 4: b[kind-4] = channels[channel]
						low.set_pixel(x,y,a)
						high.set_pixel(x,y,b)
				baseline.set_shader_parameter("surface_low",ImageTexture.create_from_image(low))
				baseline.set_shader_parameter("surface_high",ImageTexture.create_from_image(high))
			old.call("specialize",baseline)
			entries.append({"node":node,"optimized":material,"baseline":baseline})
		check(not entries.is_empty(),theme + " material pair exists")
		var proofs: Array[Dictionary] = []
		root.size = Vector2i(1600,900)
		for view: int in range(3):
			var point: Vector2 = track.route[view * track.route.size() / 3]
			game.camera.follow(point,Vector2.ZERO,0.0,0.0,true)
			var original: Image = await capture_pair("baseline",theme + "-" + str(view) + "-before.png")
			var optimized: Image = await capture_pair("optimized",theme + "-" + str(view) + "-after.png")
			var restored: Image = await capture_pair("baseline","")
			var proof: Dictionary = compare(original,optimized)
			proof["unstable"] = compare(original,restored).changed
			proof["view"] = view
			proofs.append(proof)
			check(proof.unstable == 0,theme + " frozen baseline is stable")
			check(proof.max_channel_delta <= 2,theme + " optimized pixels retain approved shading within 2/255")
			print("BIOME_PIXEL_PROOF: ",theme," ",JSON.stringify(proof))
		root.size = Vector2i(3840,2160)
		game.camera.follow(track.route[0],Vector2.ZERO,0.0,0.0,true)
		var viewport: RID = root.get_viewport_rid()
		RenderingServer.viewport_set_measure_render_time(viewport,true)
		var stages: Array[Dictionary] = []
		for mode: String in ["baseline","optimized","baseline","optimized"]:
			set_mode(mode)
			await measure(viewport,1.0)
			var stage: Dictionary = await measure(viewport,seconds)
			stage["mode"] = mode
			stages.append(stage)
			print("BIOME_SHADER_STAGE: ",theme," ",JSON.stringify(stage))
		set_mode("optimized")
		var packed_terrain: bool = false
		for entry: Dictionary in entries:
			if entry.optimized.get_shader_parameter("terrain_packed") == true: packed_terrain = true
		report.themes[theme] = {"content_hash":track.content_hash,"materials":entries.size(),"packed_terrain":packed_terrain,"pixel_proofs":proofs,"stages":stages}
		FileAccess.open(folder + "/report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
		game.queue_free()
		await process_frame
	print("BIOME_SHADER_PROFILE: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func set_mode(mode: String) -> void:
	for entry: Dictionary in entries: entry.node.material_override = entry[mode]

func capture_pair(mode: String, filename: String) -> Image:
	set_mode(mode)
	# Let asynchronous Mobile sky/radiance preparation settle before proof.
	await measure(root.get_viewport_rid(),1.0)
	for frame: int in range(8): await RenderingServer.frame_post_draw
	var captured: Image = root.get_texture().get_image()
	captured.convert(Image.FORMAT_RGBA8)
	if not filename.is_empty(): captured.save_png(folder + "/" + filename)
	return captured

func compare(a: Image, b: Image) -> Dictionary:
	var changed: int = 0
	var maximum: int = 0
	var total: int = 0
	var left: PackedByteArray = a.get_data()
	var right: PackedByteArray = b.get_data()
	for pixel: int in range(a.get_width()*a.get_height()):
		var different: bool = false
		for channel: int in range(3):
			var delta: int = absi(left[pixel*4+channel]-right[pixel*4+channel])
			total += delta
			maximum = maxi(maximum,delta)
			different = different or delta > 0
		if different: changed += 1
	return {"changed":changed,"max_channel_delta":maximum,"mean_channel_delta":float(total)/(a.get_width()*a.get_height()*3)}

func measure(viewport: RID, duration: float) -> Dictionary:
	var frames: Array[float] = []
	var gpu: Array[float] = []
	var cpu: Array[float] = []
	var start: int = Time.get_ticks_usec()
	var previous: int = start
	while Time.get_ticks_usec()-start < duration*1000000.0:
		await process_frame
		var now: int = Time.get_ticks_usec()
		frames.append(float(now-previous)/1000.0)
		gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(viewport))
		cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(viewport))
		previous = now
	return {"samples":frames.size(),"frame_ms":quantiles(frames),"gpu_ms":quantiles(gpu),"render_cpu_ms":quantiles(cpu),"viewport":[root.size.x,root.size.y],"scale":root.scaling_3d_scale,"msaa":root.msaa_3d,"draws":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"primitives":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)}

func quantiles(values: Array[float]) -> Dictionary:
	values.sort()
	return {"p50":values[values.size()/2],"p95":values[mini(values.size()-1,floori(values.size()*0.95))],"max":values[-1]}
