extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://../backend/tests/fixtures/verified_oval.json"))
	var game: Node = load("res://core/game.tscn").instantiate()
	game.initial_track = TrackCompiler.compile(fixture.document)
	game.production_mode = true
	root.add_child(game)
	game.set_physics_process(false)
	root.size = Vector2i(1280,720)
	root.content_scale_size = root.size
	var output: String = ProjectSettings.globalize_path("res://../docs/evidence/launch-start-2026-10-03")
	DirAccess.make_dir_recursive_absolute(output)
	for reaction: int in [-1,12,26,42,60]:
		game.restart()
		for tick: int in range(360):
			if reaction == -1: game.driver.set_touch(91,&"accelerate")
			game._physics_process(1.0/120)
			if tick == 300 and reaction == -1:
				await process_frame
				await RenderingServer.frame_post_draw
				assert(root.get_texture().get_image().save_png(output+"/red-lights-held.png") == OK)
		for tick: int in range(80):
			if tick >= reaction: game.driver.set_touch(91,&"accelerate")
			game._physics_process(1.0/120)
		await process_frame
		await RenderingServer.frame_post_draw
		assert(root.get_texture().get_image().save_png(output+"/launch-%d.png" % reaction) == OK)
	game.queue_free()
	await process_frame
	quit()
