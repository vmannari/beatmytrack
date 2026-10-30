extends SceneTree

var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, description: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(description)

func run() -> void:
	var output: String = OS.get_environment("BMT_FORKLIFT_LOCK_CAPTURE")
	if not output.is_empty(): DirAccess.make_dir_recursive_absolute(output)
	for car_id: String in ["forklift", "pickup"]:
		root.size = Vector2i(960, 540)
		root.content_scale_size = root.size
		var game: Node = load("res://core/game.tscn").instantiate()
		game.initial_track = TrackCompiler.compile(TrackDocument.create_default())
		game.production_mode = true
		game.vehicle_id = car_id
		root.add_child(game)
		while not game.preparation_complete: await process_frame
		game.set_physics_process(false)
		game.countdown_ticks = 0
		game.race_cues.hide()
		for dimensions: Vector2i in [Vector2i(960, 540), Vector2i(1280, 720)]:
			root.size = dimensions
			root.content_scale_size = dimensions
			for frame: int in range(5): await process_frame
			if car_id == "forklift":
				check(game.hud.handling_test_choice == null, "forklift hides test selector at " + str(dimensions))
			else:
				check(game.hud.handling_test_choice != null and game.hud.handling_test_choice.is_visible_in_tree(), "pickup retains test selector at " + str(dimensions))
			if not output.is_empty():
				root.get_texture().get_image().save_png(output.path_join("%s-%dx%d.png" % [car_id, dimensions.x, dimensions.y]))
		game.queue_free()
		await process_frame
	print("FORKLIFT_LOCK_CAPTURE: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
