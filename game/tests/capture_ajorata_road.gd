extends SceneTree

func _initialize() -> void: run.call_deferred()

func settle() -> void:
	for i: int in range(20): await process_frame
	await RenderingServer.frame_post_draw

func run() -> void:
	root.size = Vector2i(1280,780)
	var phase: String = "before"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--phase="): phase = arg.trim_prefix("--phase=")
	var folder: String = ProjectSettings.globalize_path("res://../docs/evidence/ajorata-road-2026-10-16/"+RenderingServer.get_current_rendering_method()+"/"+phase)
	DirAccess.make_dir_recursive_absolute(folder)
	var doc: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/ajorata.json"))
	var game: Node = preload("res://core/game.tscn").instantiate()
	game.initial_track = TrackCompiler.compile(doc)
	game.production_mode = true
	root.add_child(game)
	game.set_physics_process(false)
	game.set_process(false)
	game.paused = true
	game.race_cues.hide()
	var camera: Camera3D = game.camera
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 120
	camera.position = Vector3(0,100,-3)
	camera.rotation_degrees = Vector3(-90,0,0)
	await settle()
	root.get_texture().get_image().save_png(folder+"/map.png")
	var poses: Array[Vector3] = [Vector3(-14,-41,0),Vector3(14,17,90),Vector3(-7,25,90),Vector3(8,-18,180)]
	for i: int in range(poses.size()):
		var pose: Vector3 = poses[i]
		game.sim.state.position = Vector2(pose.x,pose.y)
		game.previous_position = game.sim.state.position
		game.sim.state.heading = deg_to_rad(pose.z)
		game.previous_heading = game.sim.state.heading
		game._process(0.0)
		camera.follow(game.sim.state.position,Vector2.ZERO,game.sim.state.heading,0,true)
		await settle()
		root.get_texture().get_image().save_png(folder+"/pose-%d.png"%i)
	game.free()
	await process_frame
	print("AJORATA_CAPTURE ",phase," ",RenderingServer.get_current_rendering_method())
	quit()
