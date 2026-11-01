extends SceneTree
## Native game screenshots using synthetic, valid selectable liveries.

var output: String = ""

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	OS.set_environment("BMT_API_URL", "")
	output = OS.get_environment("BMT_WEBSITE_GAMEPLAY_OUTPUT")
	if output.is_empty():
		push_error("BMT_WEBSITE_GAMEPLAY_OUTPUT is required")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)
	var document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(output.path_join("blind-spot-track.json")))
	if document.get("id", "") != "track_183e0afb5090a6eb" or document.get("name", "").to_lower() != "blind spot":
		push_error("Unexpected track document")
		quit(1)
		return
	print("BLIND_SPOT_TRACK: ", document.id, " ", document.name, " ", document.theme, " points=", document.points.size(), " pieces=", document.pieces.size())
	var errors: Array[String] = TrackDocument.validate(document)
	if not errors.is_empty():
		push_error("Track validation: " + str(errors))
		quit(1)
		return
	var game: Node = load("res://core/game.tscn").instantiate()
	game.initial_track = TrackCompiler.compile(document)
	game.production_mode = true
	game.handling_test_enabled = false
	game.vehicle_id = "compact"
	root.add_child(game)
	while not game.preparation_complete:
		await process_frame
	game.set_physics_process(false)
	game.set_process(false)
	game.countdown_ticks = 0
	game.race_cues.hide()
	# Drive the actual simulation for four seconds. The captured HUD therefore
	# reflects a real elapsed race and speed rather than a staged velocity.
	game.ai_enabled = true
	for tick: int in range(480):
		game._physics_process(1.0 / 120.0)
	game.ai_enabled = false
	if game.sim.state.tick != 480:
		push_error("The race did not advance exactly 480 physics ticks")
		quit(1)
		return
	# These are existing player-selectable camera options, not a custom zoom.
	game.set_camera_speed_zoom(false)
	game.previous_position = game.sim.state.position
	game.previous_heading = game.sim.state.heading
	for frame: int in range(40):
		game._process(1.0 / 60.0)
	for id: String in ["rally_blocks", "endurance"]:
		var index: int = LiveryCatalog.pattern_index(id)
		if index < 0:
			push_error("Missing livery " + id)
			quit(1)
			return
		var definition: Dictionary = LiveryCatalog.patterns[index]
		var livery: Dictionary = VehicleLivery.defaults("compact")
		livery.pattern = id
		for slot: int in range(3):
			livery.colors[VehicleLivery.SLOTS[slot]] = definition.colours[slot]
		livery.stickers.hood.id = "crest"
		livery.stickers.roof.id = "checker"
		if not VehicleLivery.valid(livery):
			push_error("Invalid livery " + id)
			quit(1)
			return
		game.car.apply_livery(livery)
		if game.car.livery != livery or game.car.graphics.bindings.is_empty():
			push_error("The gameplay car did not bind the requested livery " + id)
			quit(1)
			return
		for camera_mode: String in ["overhead", "follow_car"]:
			# Other noninteractive windows can make Windows send focus-out. Clear
			# the resulting pause before drawing this isolated capture.
			if game.paused:
				game.toggle_pause(false)
			game._preparation_backgrounded = false
			game.set_camera_mode(camera_mode)
			game._process(0.0)
			for frame: int in range(15):
				await process_frame
			if game.paused:
				game.toggle_pause(false)
			game._preparation_backgrounded = false
			game._process(0.0)
			await RenderingServer.frame_post_draw
			if game.paused or game.hud.pause_menu.visible:
				push_error("A focus event paused the capture")
				quit(1)
				return
			var destination: String = output.path_join("driven-" + id + "-" + camera_mode + ".png")
			if root.get_texture().get_image().save_png(destination) != OK:
				push_error("Could not save " + destination)
				quit(1)
				return
			print("WEBSITE_GAMEPLAY_CAPTURE: ", id, " ", camera_mode, " tick=", game.sim.state.tick, " ", destination)
	game.queue_free()
	for frame: int in range(20):
		await process_frame
	var soundtrack: Node = root.get_node_or_null("AudioWorld")
	if soundtrack != null:
		soundtrack.queue_free()
	for frame: int in range(10):
		await process_frame
	quit(0)
