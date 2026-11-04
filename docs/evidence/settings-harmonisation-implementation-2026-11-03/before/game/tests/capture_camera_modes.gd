extends SceneTree
## Same actual world/car pose in all views, plus real delayed-turn frames.
var captures: int = 0
func _initialize() -> void: call_deferred("run")

func run() -> void:
	var output: String = ProjectSettings.globalize_path("res://../docs/evidence/camera-options-2026-10-03/speed-zoom")
	if not OS.get_environment("BMT_CAMERA_EVIDENCE").is_empty(): output = OS.get_environment("BMT_CAMERA_EVIDENCE")
	DirAccess.make_dir_recursive_absolute(output)
	var document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/over_and_under.json"))
	var game: Node = load("res://core/game.tscn").instantiate()
	game.initial_track = TrackCompiler.compile(document)
	game.production_mode = true
	root.add_child(game)
	game.set_physics_process(false)
	game.set_process(false)
	game.countdown_ticks = 0
	game.race_cues.hide()
	game.sim.state.velocity = game.sim.state.forward() * 22.0
	game.previous_position = game.sim.state.position
	game.previous_heading = game.sim.state.heading
	for frame: int in range(45): game._process(1.0 / 60.0)
	for dimensions: Vector2i in [Vector2i(1280, 720), Vector2i(960, 540), Vector2i(1600, 720)]:
		root.size = dimensions
		root.content_scale_size = dimensions
		for mode: String in CameraProfile.MODES:
			game.set_camera_mode(mode)
			game._process(0.0)
			await capture(output.path_join("%s-%dx%d.png" % [mode, dimensions.x, dimensions.y]))
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)
	game.set_camera_mode("follow_car")
	game.sim.state.heading += PI / 2.0
	game.previous_heading = game.sim.state.heading
	game.sim.state.velocity = game.sim.state.forward() * 22.0
	for frame: int in range(181):
		game._process(1.0 / 60.0)
		if frame in [0, 17, 59, 119, 179]: await capture(output.path_join("follow-turn-%03d.png" % (frame + 1)))
	game.set_camera_mode("look_ahead")
	game.sim.state.heading -= PI / 2.0
	game.previous_heading = game.sim.state.heading
	game.sim.state.velocity = game.sim.state.forward() * 22.0
	for frame: int in range(121):
		game._process(1.0 / 60.0)
		if frame in [0, 17, 59, 119]: await capture(output.path_join("look-ahead-turn-%03d.png" % (frame + 1)))
	game.toggle_pause()
	game.hud.pause_menu._settings()
	await capture(output.path_join("pause-camera-1280x720.png"))
	root.size = Vector2i(960, 540)
	root.content_scale_size = Vector2i(960, 540)
	await capture(output.path_join("pause-camera-960x540.png"))
	game.toggle_pause()
	# Compare the same fast car pose/speed, differing only in speed zoom.
	for dimensions: Vector2i in [Vector2i(1280, 720), Vector2i(960, 540)]:
		root.size = dimensions
		root.content_scale_size = dimensions
		for mode: String in CameraProfile.MODES:
			if dimensions.x == 960 and mode != "look_ahead": continue
			game.sim.state.velocity = game.sim.state.forward() * 55.0
			for amount: float in [0.0, 0.12, 0.30, 0.50]:
				game.set_camera_speed_zoom(true)
				game.set_camera_speed_zoom_strength(amount)
				game.set_camera_mode(mode)
				for frame: int in range(45): game._process(1.0 / 60.0)
				await capture(output.path_join("%s-fast-%02d-percent-%dx%d.png" % [mode, roundi(amount * 100.0), dimensions.x, dimensions.y]))
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)
	game.set_camera_speed_zoom(false)
	game.set_camera_speed_zoom_strength(CameraProfile.DEFAULT_SPEED_ZOOM_STRENGTH)
	game.set_camera_mode("look_ahead")
	game.set_camera_speed_zoom(true)
	for frame: int in range(121):
		game._process(1.0 / 60.0)
		if frame in [0, 29, 119]: await capture(output.path_join("zoom-ease-%03d.png" % (frame + 1)))
	game.queue_free()
	await process_frame
	print("CAMERA_CAPTURE: %d captures saved, including same-pose 0/12/30/50 percent zoom comparisons and easing frames" % captures)
	quit()

func capture(path: String) -> void:
	for frame: int in range(5): await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(path) == OK)
	captures += 1
