extends SceneTree

var failures := 0
func _initialize() -> void: run.call_deferred()

func run() -> void:
	root.size = Vector2i(960, 540)
	root.content_scale_size = root.size
	var game: Node = load("res://core/game.tscn").instantiate()
	game.initial_track = TrackCompiler.compile(TrackDocument.create_default())
	game.vehicle_id = "kart"
	game.production_mode = true
	root.add_child(game)
	while not game.preparation_complete: await process_frame
	game.set_physics_process(false)
	game.countdown_ticks = 0
	game.race_cues.hide()
	for dimensions: Vector2i in [Vector2i(960, 540), Vector2i(1280, 720)]:
		root.size = dimensions
		root.content_scale_size = dimensions
		for frame: int in range(5): await process_frame
		if game.hud.handling_test_choice != null or game.attempt_practice or game.handling.version != "kart-12": failures += 1
		var output: String = OS.get_environment("BMT_KART_FINAL_CAPTURE")
		if not output.is_empty():
			DirAccess.make_dir_recursive_absolute(output)
			root.get_texture().get_image().save_png(output.path_join("kart-race-%dx%d.png" % [dimensions.x, dimensions.y]))
	game.queue_free()
	await process_frame
	print("KART_FINAL_CAPTURE: %d failures" % failures)
	quit(1 if failures else 0)
