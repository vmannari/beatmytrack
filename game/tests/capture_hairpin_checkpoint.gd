extends "res://tests/test_hairpin_checkpoints.gd"

func run() -> void:
	root.size = Vector2i(1280,720)
	var doc: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/star_spline_lap.json"))
	var track: NativeTrack = TrackCompiler.compile(doc)
	var path := PackedVector2Array()
	for i: int in range(track.route.size()):
		if track.route_cumulative[i] < 104.0: path.append(track.route[i])
	path.append(track._race_route_point(104.0)); path.append(track._race_route_point(192.0))
	var session := TrackSession.new(120,5)
	walk(session,track,path)
	check(session.missed_checkpoint >= 0,"actual hairpin bypass produces a return marker")
	var game: Node = load("res://core/game.tscn").instantiate()
	game.initial_track = track; game.production_mode = true; root.add_child(game)
	game.set_physics_process(false); game.paused = true; game.countdown_ticks = 0; game.race_cues.hide()
	var point: Vector2 = path[-1]
	var movement: Vector2 = path[-1]-path[-2]
	var heading: float = atan2(movement.x,movement.y)
	game.sim.state.position = point; game.sim.state.heading = heading; game.sim.state.route_index = track.nearest_route(point)
	game.previous_position = point; game.previous_heading = heading
	game.camera.follow(point,Vector2.ZERO,heading,0.0,true)
	game.track_session = session
	game.checkpoint_marker.present(session,track,game.bridge_presentation)
	game.hud.checkpoint_notice.present(game.checkpoint_marker,game.camera,game.camera.unproject_position(game.car.global_position))
	for frame: int in range(8): await process_frame
	await RenderingServer.frame_post_draw
	var directory: String = EVIDENCE+RenderingServer.get_current_rendering_method()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	check(root.get_texture().get_image().save_png(directory.path_join("hairpin-return.png")) == OK,"capture actual return notice")
	print("HAIRPIN_CAPTURE: ",checks," checks, ",failures," failures; missed=",session.missed_checkpoint)
	game.queue_free(); await process_frame
	quit(1 if failures else 0)
