extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.size = Vector2i(960, 540)
	root.content_scale_size = root.size
	var game: Node = load("res://core/game.tscn").instantiate()
	game.initial_track = TrackCompiler.compile(TrackDocument.create_default())
	game.production_mode = true
	game.vehicle_id = "electric"
	root.add_child(game)
	while not game.preparation_complete: await process_frame
	game.set_physics_process(false)
	game.countdown_ticks = 0
	game.race_cues.hide()
	for frame: int in range(10): await process_frame
	var ok: bool = game.hud.handling_test_choice == null and game.handling.version == "electric-28" and not game.attempt_practice
	var output: String = OS.get_environment("BMT_VOLT_FINAL_CAPTURE")
	if not output.is_empty():
		DirAccess.make_dir_recursive_absolute(output)
		ok = root.get_texture().get_image().save_png(output.path_join("volt-final-race.png")) == OK and ok
	game.queue_free()
	await process_frame
	print("VOLT_FINAL_RACE: ", "passed" if ok else "failed")
	quit(0 if ok else 1)
