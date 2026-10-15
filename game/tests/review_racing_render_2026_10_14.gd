extends "res://tests/test_winter_snow_wind.gd"
## Review only: in-memory alternatives; shipping rendering remains untouched.
var folder := "res://../build/racing-render-review-2026-10-14"
var report: Dictionary = {}

func script_from(source: String) -> GDScript:
	var script := GDScript.new()
	script.source_code = source
	check(script.reload() == OK, "review instrumentation parses")
	return script

func picture() -> Image:
	for frame: int in range(4): await RenderingServer.frame_post_draw
	var result: Image = root.get_texture().get_image()
	result.convert(Image.FORMAT_RGBA8)
	return result

func difference(a: Image, b: Image) -> Dictionary:
	var left := a.get_data(); var right := b.get_data()
	check(left.size() == right.size(), "paired image dimensions match")
	var count: int = 0; var maximum: int = 0
	for index: int in range(left.size()):
		var delta: int = absi(int(left[index])-int(right[index]))
		if delta: count += 1
		maximum = maxi(maximum,delta)
	return {"changed_bytes":count,"maximum":maximum}

func winter(track: NativeTrack) -> void:
	var world := Node3D.new(); root.add_child(world)
	var visual := NativeTrackVisual.new(); world.add_child(visual)
	await visual.build(track,BridgePresentation.new(track))
	var camera := Camera3D.new(); world.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL; camera.size = 32
	camera.position = Vector3(-12,23,5); camera.look_at(Vector3(0,0,18)); camera.make_current()
	var light := DirectionalLight3D.new(); light.rotation_degrees = Vector3(-55,-25,0)
	world.add_child(light)
	var source := FileAccess.get_file_as_string("res://track/winter_snow_wind.gd").replace("class_name WinterSnowWind\n", "")
	source += "\nvar review_skip_fallback: bool = false\nvar review_ground: int = 0\nvar review_banks: int = 0\n"
	source = source.replace("func _place_ground() -> void:\n", "func _place_ground() -> void:\n\tif review_skip_fallback and not surface_materials.is_empty(): return\n\treview_ground += 1\n")
	source = source.replace("func _place_banks(focus: Vector2) -> void:\n", "func _place_banks(focus: Vector2) -> void:\n\tif review_skip_fallback and not surface_materials.is_empty(): return\n\treview_banks += 1\n")
	source = source.replace("for material: ShaderMaterial in [ground_material, powder_material,airborne.material_override]:", "for material: ShaderMaterial in ([airborne.material_override] if review_skip_fallback and not surface_materials.is_empty() else [ground_material, powder_material,airborne.material_override]):")
	var wind = script_from(source).new(); world.add_child(wind)
	var began := Time.get_ticks_usec(); wind.configure(track,visual)
	var configured_ms := (Time.get_ticks_usec()-began)/1000.0
	check(not wind.surface_materials.is_empty(),"actual Winter world binds integrated snow materials")
	var source_timings: Array = []
	for repetition: int in range(3):
		began = Time.get_ticks_usec(); wind._prepare_visual_sources(track)
		source_timings.append((Time.get_ticks_usec()-began)/1000.0)
	var timings: Array = []
	for repetition: int in range(4):
		for skip: bool in ([false,true] if repetition%2 == 0 else [true,false]):
			wind.review_skip_fallback = skip; wind.reset(); wind.review_ground = 0; wind.review_banks = 0
			began = Time.get_ticks_usec()
			for frame: int in range(600): wind.present(1.0/60.0,Vector2(frame*0.3,-18),0.8,false,false)
			timings.append({"skip":skip,"ms":(Time.get_ticks_usec()-began)/1000.0,"ground_refreshes":wind.review_ground,"bank_refreshes":wind.review_banks,"ground_visible":wind.ground.multimesh.visible_instance_count,"powder_visible":wind.powder.multimesh.visible_instance_count})
			check(wind.ground.multimesh.visible_instance_count == 0 and wind.powder.multimesh.visible_instance_count == 0,"fallback batches remain undrawn")
	wind.review_skip_fallback = false; wind.reset()
	for frame: int in range(90): wind.present(1.0/60.0,Vector2(0,-18),0.8,false,false)
	var before: Image = await picture()
	var frozen_control := difference(before,await picture())
	wind.reset()
	for frame: int in range(90): wind.present(1.0/60.0,Vector2(0,-18),0.8,false,false)
	var control_image := await picture()
	var reset_control := difference(before,control_image)
	wind.review_skip_fallback = true; wind.reset()
	for frame: int in range(90): wind.present(1.0/60.0,Vector2(0,-18),0.8,false,false)
	var after: Image = await picture(); var pixels := difference(control_image,after)
	check(pixels.maximum == 0,"skipping suppressed Winter fallback retains exact pixels")
	report.winter = {"configuration_ms":configured_ms,"fallback_source_ms":source_timings,"surface_materials":wind.surface_materials.size(),"anchors":wind.anchors.size(),"timings":timings,"pixels":pixels,"frozen_control":frozen_control,"reset_control":reset_control}
	control_image.save_png(folder.path_join("winter-before.png")); after.save_png(folder.path_join("winter-after.png"))
	world.free(); await process_frame

func storm() -> void:
	var source := FileAccess.get_file_as_string("res://track/storm_weather.gd").replace("class_name StormWeather\n", "")
	source += "\nvar review_batch: bool = false\nvar review_usec: int = 0\nvar review_callbacks: int = 0\nvar review_seeds: Array = []\n"
	source = source.replace("func _ready() -> void:\n", "func _ready() -> void:\n\tfor i: int in range(190):\n\t\tvar seed: float = float(i)\n\t\treview_seeds.append([sin(seed*127.1+9.4)*43758.5453,sin(seed*311.7+2.6)*19341.917,0.65+fmod(seed,4.0)*0.07,13.0+fmod(seed,12.0)])\n")
	source = source.replace("\t# Bounded rain streaks", "\tvar review_started := Time.get_ticks_usec()\n\tvar review_lines := PackedVector2Array()\n\tif review_batch: review_lines.resize(380)\n\t# Bounded rain streaks")
	source = source.replace("sin(seed*127.1+9.4)*43758.5453-elapsed*0.12", "(review_seeds[i][0] if review_batch else sin(seed*127.1+9.4)*43758.5453)-elapsed*0.12")
	source = source.replace("sin(seed*311.7+2.6)*19341.917+elapsed*(0.65+fmod(seed,4.0)*0.07)", "(review_seeds[i][1] if review_batch else sin(seed*311.7+2.6)*19341.917)+elapsed*(review_seeds[i][2] if review_batch else (0.65+fmod(seed,4.0)*0.07))")
	source = source.replace("(13.0+fmod(seed,12.0))*size.y", "(review_seeds[i][3] if review_batch else (13.0+fmod(seed,12.0)))*size.y")
	source = source.replace("\t\tdraw_line(Vector2(x,y),Vector2(x-length*0.35,y+length),Color(0.72,0.83,0.90,0.27),1.0,true)", "\t\tif review_batch:\n\t\t\treview_lines[i*2] = Vector2(x,y); review_lines[i*2+1] = Vector2(x-length*0.35,y+length)\n\t\telse: draw_line(Vector2(x,y),Vector2(x-length*0.35,y+length),Color(0.72,0.83,0.90,0.27),1.0,true)")
	source = source.replace("\t_draw_lens_trails()", "\tif review_batch: draw_multiline(review_lines,Color(0.72,0.83,0.90,0.27),1.0,true)\n\t_draw_lens_trails()")
	source = source.replace("\n# Analytic presentation", "\n\treview_usec += Time.get_ticks_usec()-review_started\n\treview_callbacks += 1\n\n# Analytic presentation")
	var weather = script_from(source).new(); root.add_child(weather)
	weather.elapsed = 3.2; weather._update_lens()
	var pairs: Array = []
	for elapsed: float in [0.3,3.2,11.5]:
		weather.elapsed = elapsed; weather._update_lens(); weather.review_batch = false; weather.queue_redraw()
		var before := await picture()
		weather.review_batch = true; weather.queue_redraw(); var after := await picture()
		var pixels := difference(before,after); pairs.append({"elapsed":elapsed,"pixels":pixels})
		# Review alternatives can fail pixel parity; retain the result as evidence.
		before.save_png(folder.path_join("rain-"+str(elapsed)+"-before.png")); after.save_png(folder.path_join("rain-"+str(elapsed)+"-after.png"))
	var timings: Array = []
	for batch: bool in [false,true,true,false]:
		weather.review_batch = batch; weather.review_usec = 0; weather.review_callbacks = 0
		for frame: int in range(100):
			weather.elapsed += 1.0/60.0; weather._update_lens(); weather.queue_redraw()
			await RenderingServer.frame_post_draw
		timings.append({"batched":batch,"callback_us":weather.review_usec,"callbacks":weather.review_callbacks})
	report.storm = {"pixels":pairs,"timings":timings,"rain_api_calls_before":190,"rain_api_calls_candidate":1,"note":"Candidate also precomputes immutable rain seeds/speeds/lengths. Canvas API calls; renderer can already batch GPU submissions. Timings include unchanged lens trails."}
	weather.free(); await process_frame

func contacts(track: NativeTrack) -> void:
	var observer := script_from("extends SurfaceAudioModel\nvar calls: Array = []\nfunc sample_contacts(state: VehicleState, track: NativeTrack, grounded: bool) -> void:\n\tvar began := Time.get_ticks_usec()\n\tsuper.sample_contacts(state,track,grounded)\n\tcalls.append({\"key\":str([state.tick,state.position,state.heading,state.track_elevated,state.tire_water,grounded,wheelbase,track_width]),\"us\":Time.get_ticks_usec()-began,\"values\":[pavement,grass,sand,gravel,water,kerb]})\n")
	var game = load("res://core/game.tscn").instantiate()
	game.initial_track = track; game.ai_enabled = true; game.attempt_practice = true
	root.add_child(game); game.process_mode = Node.PROCESS_MODE_DISABLED
	var audio: SurfaceAudioModel = observer.new(); audio.configure(game.handling); game.vehicle_audio.surface_model = audio
	var finish: SurfaceAudioModel = observer.new(); finish.configure(game.handling); game.car_weathering.contacts = finish
	for frame: int in range(120):
		game._physics_process(1.0/120.0); game._physics_process(1.0/120.0)
		game._present_frame(1.0/60.0)
	var keys: Dictionary = {}; var total_us: int = 0; var redundant_us: int = 0; var redundant: int = 0
	for row: Dictionary in audio.calls+finish.calls:
		total_us += int(row.us)
		if keys.has(row.key):
			redundant += 1; redundant_us += int(row.us)
			check(keys[row.key] == row.values,"same contact input produces identical material mix")
		else: keys[row.key] = row.values
	report.contacts = {"physics_steps":240,"rendered_frames":120,"calls":audio.calls.size()+finish.calls.size(),"distinct_inputs":keys.size(),"redundant_calls":redundant,"total_us":total_us,"redundant_us":redundant_us,"tick":game.sim.state.tick,"note":"Actual game callbacks, unchanged queries. Observer cost is outside the recorded sampler time. One track/handling in this fixture; production reuse must fence changes/reset/rewind and distinct grounded thresholds."}
	check(game.sim.state.tick == 240,"unscored contact probe advances all intended physics ticks")
	game.free(); await process_frame

func run() -> void:
	checks = 0; failures = 0
	folder = folder.path_join(RenderingServer.get_current_rendering_method())
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	root.size = Vector2i(1280,720); DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	report = {"engine":Engine.get_version_info().string,"renderer":RenderingServer.get_current_rendering_method(),"adapter":RenderingServer.get_video_adapter_name(),"native_visual":NativeTrackVisual.VERSION,"wind":WinterSnowWind.VERSION,"sources":{},"note":"Review-only desktop components, no shipping edits, no phone FPS claim."}
	for path: String in ["track/winter_snow_wind.gd","track/storm_weather.gd","vehicle/surface_audio_model.gd","vehicle/vehicle_audio.gd","vehicle/vehicle_weathering.gd"]: report.sources[path] = FileAccess.get_file_as_string("res://"+path).sha256_text()
	var track := make_track()
	await winter(track); await storm(); await contacts(track)
	report.checks = checks; report.failures = failures
	FileAccess.open(folder.path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("RACING_RENDER_REVIEW: ",checks," checks, ",failures," failures")
	for frame: int in range(3): await RenderingServer.frame_post_draw
	quit(1 if failures else 0)
