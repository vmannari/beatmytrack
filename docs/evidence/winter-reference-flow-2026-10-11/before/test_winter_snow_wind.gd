extends SceneTree
const OUT: String = "res://../docs/evidence/winter-soft-fast-2026-10-11"
var checks: int = 0
var failures: int = 0

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ", label)

func make_track() -> NativeTrack:
	var document: Dictionary = TrackDocument.create_blank()
	document.theme = "winter"
	var position := Vector2(-28, -18)
	var heading: float = 0.0
	for kind: String in ["straight", "hairpin", "straight", "hairpin"]:
		var piece: Dictionary = RoadPieces.create(kind, position, heading)
		piece.length = 56.0 if kind == "straight" else 0.0
		piece.radius = 18.0
		document.pieces.append(piece)
		var pose: Dictionary = RoadPieces.end_pose(piece)
		position = pose.position
		heading = pose.heading
	document = RoadPieces.route_from_pieces(document).document
	document.start_line = {"position": [0.0, -18.0], "heading": 0.0}
	return TrackCompiler.compile(JSON.parse_string(JSON.stringify(document)))

func run() -> void:
	var track: NativeTrack = make_track()
	var before_cells: PackedInt32Array = track.cells.duplicate()
	var before_banks: String = str(track.snow_banks.triangles)
	var wind := WinterSnowWind.new()
	root.add_child(wind)
	wind.configure(track)
	check(wind.get_child_count() == 2 and wind.anchors.size() > 0, "two batches and prepared exposed bank anchors")
	wind.present(2.0, Vector2(0, -18), 1.0, false, false)
	check(wind.ground.multimesh.instance_count == 81 and wind.powder.multimesh.instance_count == 36, "restored 81 ground / 36 bank-wisp budget independent of track size")
	check(wind.powder.multimesh.mesh is PlaneMesh and (wind.powder.multimesh.mesh as PlaneMesh).subdivide_width == 5, "restored previous six-span bank-to-road shape")
	check(wind._basis(true) == wind._basis(false), "previous shape retains world surface orientation")
	check(wind.active_banks.size() > 0 and wind.active_banks.size() <= 12, "nearby bank pool bounded")
	for at: Vector3 in wind.active_banks:
		check(track.snow_banks.height_at(Vector2(at.x, -at.z)) > 0.19 and at.y < 0.5, "powder source lies on real low snowbank")
	var start: Array = [wind.elapsed, wind.travel, wind.intensity, wind.center, wind.active_banks.duplicate()]
	wind.present(1.0, Vector2(1000, 1000), 0.0, true, false)
	check(start == [wind.elapsed, wind.travel, wind.intensity, wind.center, wind.active_banks], "pause freezes motion and placement")
	wind.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	wind.present(1.0, Vector2.ZERO, 1.0, false, false)
	check(start == [wind.elapsed, wind.travel, wind.intensity, wind.center, wind.active_banks], "background freezes visual wind")
	wind.notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	wind.present(NAN, Vector2.ZERO, 1.0, false, false)
	check(wind.elapsed == start[0], "invalid delta cannot poison visual uniforms")
	for i: int in range(60): wind.present(1.0 / 60.0, Vector2(0, -18), 1.0, false, false)
	var strong: float = wind.intensity
	var gust_start: float = wind.travel
	for i: int in range(60): wind.present(1.0 / 60.0, Vector2(0, -18), 1.0, false, false)
	check(is_equal_approx(wind.travel - gust_start, 24.0), "harsh gust carries powder 24 world metres per second")
	for i: int in range(60): wind.present(1.0 / 60.0, Vector2(0, -18), 0.0, false, false)
	check(strong > 0.95 and is_equal_approx(wind.intensity, 0.24), "smooth gust strengthens both effects with light calm floor")
	var pinned: Transform3D = wind.ground.multimesh.get_instance_transform(40)
	wind.present(0.01, Vector2(0.5, -18), 0.0, false, false)
	check(wind.ground.multimesh.get_instance_transform(40) == pinned, "sub-cell camera-follow motion cannot drag snow across world")
	check(wind._basis().x.dot(VisualGeometry.world(WinterSnowWind.WIND)) > 0.999, "shared world wind direction")
	for i: int in range(60): wind.present(1.0 / 60.0, Vector2.ZERO, 1.0, false, true)
	check(wind.intensity == 0, "finish fades visuals out")
	wind.reset()
	check(wind.elapsed == 0 and wind.travel == 0 and wind.powder.multimesh.visible_instance_count == 0, "retry clears visual history")
	var timer: int = Time.get_ticks_usec()
	for i: int in range(3600): wind.present(1.0 / 60.0, Vector2(float(i % 120) * 0.25, -18), 0.5, false, false)
	print("WINTER_WIND_CPU_US_PER_PRESENT: ", float(Time.get_ticks_usec() - timer) / 3600.0)
	check(track.cells == before_cells and str(track.snow_banks.triangles) == before_banks, "canonical road and snowbank contacts unchanged")
	track.metadata.theme = "pine"
	wind.configure(track)
	check(not wind.enabled and not wind.visible and wind.anchors.is_empty(), "other biomes disable and release geometry lookup")
	track.metadata.theme = "winter"
	wind.queue_free()
	await process_frame
	var game: Node = load("res://core/game.tscn").instantiate()
	game.initial_track = track
	game.production_mode = true
	root.add_child(game)
	game.set_physics_process(false)
	game.set_process(false)
	game.paused = true
	game.race_cues.hide()
	check(game.winter_snow_wind != null and game.winter_snow_wind.get_parent() == game.get_node("World"), "actual Winter race owns world-space wind")
	var snapshot: Array = game.sim.state.snapshot().duplicate(true)
	var fx: WinterSnowWind = game.winter_snow_wind
	for i: int in range(8): await process_frame
	fx.notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	fx.present(0.25, Vector2(0, -18), 1.0, false, false)
	check(fx.sources_from_visual, "actual race emits from visible analytic snowbank geometry")
	for i: int in range(120): fx.present(1.0 / 60.0, Vector2(0, -18), 1.0, false, false)
	if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw
	game.call("_process", 0.1)
	check(game.sim.state.snapshot() == snapshot, "presentation leaves actual simulation snapshot exact")
	if "--capture" in OS.get_cmdline_user_args(): await capture(game, fx)
	game.restart()
	check(fx.elapsed == 0 and fx.intensity == 0, "actual retry resets visual clock")
	var released: WeakRef = weakref(fx)
	track.metadata.theme = "pine"
	game.call("_update_weather")
	await process_frame
	check(game.winter_snow_wind == null and released.get_ref() == null, "biome change frees visual node and batches")
	game.queue_free()
	await process_frame
	print("WINTER_SNOW_WIND: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func capture(game: Node, fx: WinterSnowWind) -> void:
	root.size = Vector2i(1280, 720)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	game.call("_process", 0.0)
	for i: int in range(4): await RenderingServer.frame_post_draw
	fx.visible = false
	await RenderingServer.frame_post_draw
	var baseline: Image = root.get_texture().get_image()
	check(baseline.save_png(OUT + "/before.png") == OK, "baseline screenshot")
	fx.visible = true
	for i: int in range(4): await RenderingServer.frame_post_draw
	var gust: Image = root.get_texture().get_image()
	check(gust.save_png(OUT + "/gust.png") == OK, "gust screenshot")
	var changed: int = 0
	var roof_samples: int = 0
	var roof_changed: int = 0
	for y: int in range(320, 358):
		for x: int in range(616, 661):
			var pixel: Color = baseline.get_pixel(x, y)
			var differs: bool = pixel != gust.get_pixel(x, y)
			if differs: changed += 1
			if pixel.r > 0.63 and pixel.g > 0.59 and pixel.r > pixel.b * 1.04 and pixel.g > pixel.b * 1.02:
				roof_samples += 1
				if differs: roof_changed += 1
	print("WINTER_SNOW_CAR_RECT_CHANGED_PIXELS: ", changed)
	print("WINTER_SNOW_ROOF_SAMPLES: ", roof_samples, " changed=", roof_changed)
	check(roof_samples > 100 and roof_changed == 0, "winter wind cannot paint over opaque car roof")
	await lighting_capture(game, fx)
	if "--video" in OS.get_cmdline_user_args(): await driving_preview(game, fx)
	await profile(fx)
	var camera: Camera3D = game.camera
	var focus: Vector3 = Vector3(34, 0, 10)
	camera.position = focus + Vector3(0, 20, 15)
	camera.look_at(focus)
	camera.size = 29.0
	for i: int in range(120): fx.present(1.0 / 60.0, Vector2(34, -10), 1.0, false, false)
	for i: int in range(4): await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(OUT + "/bend.png") == OK, "curve and bank screenshot")
	if "--video" in OS.get_cmdline_user_args():
		root.size = Vector2i(640, 360)
		for frame: int in range(3): await RenderingServer.frame_post_draw
		var frames: Array[String] = []
		for frame: int in range(120):
			fx.present(1.0 / 30.0, Vector2(34, -10), 1.0 if frame < 75 else 0.0, false, false)
			await RenderingServer.frame_post_draw
			frames.append("data:image/jpeg;base64," + Marshalls.raw_to_base64(root.get_texture().get_image().save_jpg_to_buffer(0.90)))
		var preview := FileAccess.open(OUT + "/motion.html", FileAccess.WRITE)
		preview.store_string("<!doctype html><meta charset='utf-8'><title>Winter soft wind</title><style>body{background:#172129;color:#edf1f3;font:16px system-ui;max-width:960px;margin:32px auto}img{width:100%;height:auto}button{padding:10px;margin:12px 0}</style><h1>Winter soft wind</h1><p>Actual Godot captures · 4 seconds at 30 fps · restored soft shape, faster gusts</p><img id='view'><button id='toggle'>Pause</button><script>const frames=" + JSON.stringify(frames) + ";let frame=0,playing=true;const view=document.getElementById('view'),button=document.getElementById('toggle');view.src=frames[0];button.onclick=()=>{playing=!playing;button.textContent=playing?'Pause':'Play'};setInterval(()=>{if(playing){frame=(frame+1)%frames.length;view.src=frames[frame]}},1000/30)</script>")
		preview.close()
		root.size = Vector2i(1280, 720)
	camera.position = focus + Vector3(18, 20, 0)
	camera.look_at(focus)
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(OUT + "/rotated.png") == OK, "rotated camera world-space snow")
	root.size = Vector2i(960, 540)
	for i: int in range(4): await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(OUT + "/compact.png") == OK, "compact viewport screenshot")

func profile(fx: WinterSnowWind) -> void:
	var viewport: RID = root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(viewport, true)
	var results: Array[Dictionary] = []
	for enabled: bool in [false, true, true, false]:
		fx.visible = enabled
		for frame: int in range(30): await RenderingServer.frame_post_draw
		var gpu: Array[float] = []
		var cpu: Array[float] = []
		for frame: int in range(120):
			await RenderingServer.frame_post_draw
			gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(viewport))
			cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(viewport))
		gpu.sort()
		cpu.sort()
		results.append({"enabled": enabled, "gpu_ms_median": gpu[60], "gpu_ms_p95": gpu[114], "render_cpu_ms_median": cpu[60], "draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), "primitives": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)})
	fx.visible = true
	var output := FileAccess.open(OUT + "/profile.json", FileAccess.WRITE)
	output.store_string(JSON.stringify({"device": RenderingServer.get_video_adapter_name(), "renderer": RenderingServer.get_current_rendering_method(), "samples_per_pass": 120, "results": results}, "\t"))
	output.close()
	print("WINTER_SNOW_RENDER_PROFILE: ", JSON.stringify(results))

func lighting_capture(game: Node, fx: WinterSnowWind) -> void:
	var light: DirectionalLight3D = game.biome_light
	var environment: Environment = game.biome_environment
	var energy: float = light.light_energy
	var ambient: float = environment.ambient_light_energy
	var reflected: Environment.ReflectionSource = environment.reflected_light_source
	var deltas: Array[float] = []
	for dark: bool in [false, true]:
		light.light_energy = 0.0 if dark else energy
		environment.ambient_light_energy = 0.0 if dark else ambient
		environment.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED if dark else reflected
		fx.visible = false
		for i: int in range(3): await RenderingServer.frame_post_draw
		var base: Image = root.get_texture().get_image()
		fx.visible = true
		for i: int in range(3): await RenderingServer.frame_post_draw
		var with_snow: Image = root.get_texture().get_image()
		var difference: float = 0.0
		var affected: int = 0
		var samples: int = 0
		for y: int in range(210, 500, 2):
			for x: int in range(140, 1110, 2):
				var a: Color = base.get_pixel(x, y)
				var b: Color = with_snow.get_pixel(x, y)
				var delta: float = absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b)
				difference += delta
				samples += 1
				if delta > 0.005: affected += 1
		deltas.append(difference)
		if not dark:
			print("WINTER_WIND_COVERAGE: ", affected, "/", samples, " fraction=", float(affected) / samples)
			# The owner explicitly restores the softer shape; sparse-grain coverage
			# is historical only. Keep light/roof/canonical requirements intact.
		if dark: with_snow.save_png(OUT + "/unlit-lighting-check.png")
	light.light_energy = energy
	environment.ambient_light_energy = ambient
	environment.reflected_light_source = reflected
	for i: int in range(3): await RenderingServer.frame_post_draw
	print("WINTER_LIGHT_RESPONSE: bright_delta=", deltas[0], " dark_delta=", deltas[1])
	check(deltas[0] > 1.0 and deltas[1] < deltas[0] * 0.10, "wind receives actual scene light and cannot glow over an unlit world")

func driving_preview(game: Node, fx: WinterSnowWind) -> void:
	var original_sim: VehicleSimulation = game.sim
	var driving := VehicleSimulation.new(game.handling)
	driving.reset(original_sim.state.position, original_sim.state.heading)
	driving.state.route_index = original_sim.state.route_index
	game.sim = driving
	var car_pose: Transform3D = game.car.transform
	var camera_pose: Transform3D = game.camera.transform
	var previous: Vector2 = game.previous_position
	root.size = Vector2i(960, 540)
	for i: int in range(3): await RenderingServer.frame_post_draw
	var frames: Array[String] = []
	var input: DriveFrame = DriveFrame.sample(0, 0.35, 0)
	game.paused = false
	# Actual canonical straight-line driving fixture. No tickets/uploads/results.
	for frame: int in range(120):
		for tick: int in range(4): game.sim.step(input, game.native_track)
		game.previous_position = game.sim.state.position
		game.previous_heading = game.sim.state.heading
		game.frame = input
		# Force a strong/calm visual cycle for review, independently of the
		# random recorded-wind opening. Runtime still shares its real envelope.
		fx.present(1.0 / 30.0, game.sim.state.position, 1.0 if frame < 75 else 0.0, false, false)
		game.call("_process", 0.0)
		game.camera.follow(game.sim.state.position, game.sim.state.velocity, game.sim.state.heading, 1.0 / 30.0)
		game.hud.update_values(game.sim.state, input, 1.0 / 30.0, false, false)
		await RenderingServer.frame_post_draw
		if frame % 40 == 0:
			var with_wind: Image = root.get_texture().get_image()
			fx.visible = false
			await RenderingServer.frame_post_draw
			var without: Image = root.get_texture().get_image()
			fx.visible = true
			await RenderingServer.frame_post_draw
			var pixel: Vector2 = game.camera.unproject_position(game.car.global_position + Vector3.UP * 0.7)
			pixel *= Vector2(without.get_width(), without.get_height()) / game.camera.get_viewport().get_visible_rect().size
			var samples: int = 0
			var changed: int = 0
			for y: int in range(maxi(0, int(pixel.y) - 35), mini(root.size.y, int(pixel.y) + 35)):
				for x: int in range(maxi(0, int(pixel.x) - 50), mini(root.size.x, int(pixel.x) + 50)):
					var color: Color = without.get_pixel(x, y)
					if color.r > 0.63 and color.g > 0.59 and color.r > color.b * 1.04 and color.g > color.b * 1.02:
						samples += 1
						if color != with_wind.get_pixel(x, y): changed += 1
			print("WINTER_MOVING_ROOF: frame=", frame, " samples=", samples, " changed=", changed)
			check(samples > 70 and changed == 0, "moving opaque car stays clear through wind: " + str(frame))
		frames.append("data:image/jpeg;base64," + Marshalls.raw_to_base64(root.get_texture().get_image().save_jpg_to_buffer(0.92)))
		if frame == 60: check(root.get_texture().get_image().save_png(OUT + "/driving.png") == OK, "actual moving-car wind screenshot")
	var output := FileAccess.open(OUT + "/driving-motion.html", FileAccess.WRITE)
	output.store_string("<!doctype html><meta charset='utf-8'><title>Winter soft wind driving review</title><style>body{background:#172129;color:#edf1f3;font:16px system-ui;max-width:1100px;margin:32px auto}img{width:100%;height:auto}button{padding:10px;margin:12px 0}</style><h1>Winter soft wind driving review</h1><p>Actual Godot render and canonical driving fixture · normal camera · 4 seconds at 30 fps · restored soft shape at 24 m/s</p><img id='view'><button id='toggle'>Pause</button><script>const frames=" + JSON.stringify(frames) + ";let frame=0,playing=true;const view=document.getElementById('view'),button=document.getElementById('toggle');view.src=frames[0];button.onclick=()=>{playing=!playing;button.textContent=playing?'Pause':'Play'};setInterval(()=>{if(playing){frame=(frame+1)%frames.length;view.src=frames[frame]}},1000/30)</script>")
	output.close()
	game.paused = true
	game.sim = original_sim
	game.previous_position = previous
	game.previous_heading = game.sim.state.heading
	game.frame = DriveFrame.new()
	game.call("_process", 0.0)
	game.car.transform = car_pose
	game.camera.transform = camera_pose
	fx.present(0.0, game.sim.state.position, 1.0, false, false)
	root.size = Vector2i(1280, 720)
