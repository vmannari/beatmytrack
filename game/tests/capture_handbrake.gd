extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://../backend/tests/fixtures/verified_oval.json"))
	var game: Node = load("res://core/game.tscn").instantiate()
	game.initial_track = TrackCompiler.compile(fixture.document)
	game.production_mode = true
	root.add_child(game)
	game.set_physics_process(false)
	game.countdown_ticks = 0
	game.race_cues.visible = false
	var output: String = ProjectSettings.globalize_path("res://../docs/evidence/handbrake")
	DirAccess.make_dir_recursive_absolute(output)
	for dimensions: Vector2i in [Vector2i(1280,720),Vector2i(960,540)]:
		root.size = dimensions
		root.content_scale_size = dimensions
		game.hud.touch.layout = ControlLayout.preset()
		for held: bool in [false,true]:
			for i: int in range(5):
				if game.paused: game.toggle_pause()
				if held: game.driver.set_touch(99,&"handbrake")
				else: game.driver.release_touch(99)
				await process_frame
			await RenderingServer.frame_post_draw
			assert(root.get_texture().get_image().save_png(output+"/%dx%d-%s.png" % [dimensions.x,dimensions.y,"held" if held else "released"]) == OK)
	# Render the actual fresh canonical model in a scripted input diagnostic.
	root.size = Vector2i(1280,720)
	root.content_scale_size = Vector2i(1280,720)
	game.driver.clear()
	game.set_process(false)
	var start_point: Vector2 = game.sim.state.position
	var start_heading: float = game.sim.state.heading
	game.sim.reset(start_point,start_heading)
	game.sim.state.velocity = game.sim.state.forward()*18.0
	for tick: int in range(181):
		game.frame = DriveFrame.sample(1 if tick < 24 else (-0.5 if tick < 48 else 0),0.7,0,1 if tick < 24 else 0)
		game.sim.step(game.frame,game.yard)
		game.previous_position = game.sim.state.position
		game.previous_heading = game.sim.state.heading
		game.trails.sample(game.sim.state,game.frame,game.bridge_presentation,game.native_track)
		game._process(1.0/120.0)
		if tick in [0,23,47,180]:
			await process_frame
			await RenderingServer.frame_post_draw
			assert(root.get_texture().get_image().save_png(output+"/reset-%s-tick-%03d.png" % [VehicleSimulation.PHYSICS_VERSION.get_slice(".",1).pad_zeros(3),tick]) == OK)
	# Seed a deterministic just-completed hairpin snapshot to show the powered
	# exit correction; this is presentation evidence, not a scored race replay.
	game.trails.clear()
	game.sim.reset(start_point,start_heading+deg_to_rad(170))
	game.sim.state.velocity = Vector2(sin(start_heading),cos(start_heading))*12.0
	game.sim.state.handbrake_pressure = 1.0
	game.camera.follow(start_point,Vector2.ZERO,game.sim.state.heading,0.0,true)
	for tick: int in range(121):
		game.frame = DriveFrame.sample(0,1,0)
		game.sim.step(game.frame,game.yard)
		game.previous_position = game.sim.state.position
		game.previous_heading = game.sim.state.heading
		game._process(1.0/120.0)
		if tick in [0,120]:
			await process_frame
			await RenderingServer.frame_post_draw
			assert(root.get_texture().get_image().save_png(output+"/exit-%s-tick-%03d.png" % [VehicleSimulation.PHYSICS_VERSION.get_slice(".",1).pad_zeros(3),tick]) == OK)
	game.queue_free()
	await process_frame
	print("HANDBRAKE_CAPTURE: four control, four reset-maneuver and two seeded-exit captures saved")
	quit()
