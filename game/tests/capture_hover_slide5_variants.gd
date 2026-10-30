extends SceneTree

var failures := 0

func _initialize() -> void: call_deferred("run")

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		print("FAIL: " + message)

func mouse(viewport: Viewport, position: Vector2, down: bool) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = position
	motion.global_position = position
	viewport.push_input(motion)
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = position
	event.global_position = position
	event.pressed = down
	viewport.push_input(event)

func run() -> void:
	root.size = Vector2i(960,540)
	root.content_scale_size = Vector2i(960,540)
	var game: Node = load("res://core/game.tscn").instantiate()
	game.initial_track = TrackCompiler.compile(TrackDocument.create_default())
	game.production_mode = true
	game.vehicle_id = "hovercraft"
	root.add_child(game)
	while not game.preparation_complete: await process_frame
	game.set_physics_process(false)
	await process_frame
	check(not game.hud.handling_test_container.visible, "selector clears the countdown lights")
	game.countdown_ticks = 0
	game.race_cues.hide()
	for dimensions: Vector2i in [Vector2i(960,540), Vector2i(1280,720)]:
		root.size = dimensions
		root.content_scale_size = dimensions
		for i in range(5): await process_frame
		check(game.hud.handling_test_container.visible, "selector returns after countdown")
		var choice: OptionButton = game.hud.handling_test_choice
		var center: Vector2 = choice.get_global_rect().get_center()
		mouse(root,center,true)
		mouse(root,center,false)
		await process_frame
		var popup: PopupMenu = choice.get_popup()
		check(popup.visible, "mouse opens selector at " + str(dimensions))
		var output := OS.get_environment("BMT_HANDLING_TEST_CAPTURE")
		if not output.is_empty():
			DirAccess.make_dir_recursive_absolute(output)
			root.get_texture().get_image().save_png(output.path_join("race-open-%dx%d.png" % [dimensions.x,dimensions.y]))
		var selected_index := 6 if dimensions.x == 960 else 2
		# The popup is embedded in the root viewport. Its rows are 24 pixels
		# high with the current item first; choose the next test on each pass.
		var popup_point := Vector2(choice.get_global_rect().position.x + 60, choice.get_global_rect().end.y + 19 + 24 * selected_index)
		mouse(root,popup_point,true)
		mouse(root,popup_point,false)
		await process_frame
		check(game.handling_test_index == selected_index - 1 and game.attempt_practice, "mouse selects test and starts practice")
		popup.hide()
		game.countdown_ticks = 0
		game.race_cues.hide()
		for i in range(5): await process_frame
		if not output.is_empty(): root.get_texture().get_image().save_png(output.path_join("race-%dx%d.png" % [dimensions.x,dimensions.y]))
	game.queue_free()
	await process_frame
	print("HOVER_SLIDE5_RACE: %d failures" % failures)
	quit(1 if failures else 0)
