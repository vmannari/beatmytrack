extends SceneTree

func _initialize() -> void: run.call_deferred()

func run() -> void:
	root.size = Vector2i(1280,720)
	var doc: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/star_spline_lap.json"))
	var track: NativeTrack = TrackCompiler.compile(doc)
	var session := TrackSession.new(120,5); session._configure(track)
	var target := Vector2(-8.392641,-2.314985)
	var nearest: float = INF
	for index: int in range(session.checkpoint_count()):
		if session._centers[index].distance_squared_to(target) < nearest:
			nearest = session._centers[index].distance_squared_to(target); session.next_checkpoint = index
	var game: Node = load("res://core/game.tscn").instantiate()
	game.initial_track = track; game.production_mode = true; root.add_child(game)
	game.set_physics_process(false); game.paused = true; game.countdown_ticks = 0; game.race_cues.hide()
	var location := Vector2(6.0,-2.0)
	game.sim.state.position = location; game.sim.state.heading = PI*0.25
	game.sim.state.route_index = track.nearest_route(location)
	game.previous_position = location; game.previous_heading = game.sim.state.heading
	game.camera.follow(location,Vector2.ZERO,game.sim.state.heading,0.0,true)
	var marker := CheckpointMarker.new(); game.checkpoint_marker.get_parent().add_child(marker)
	session.missed_checkpoint = session.next_checkpoint
	marker.present(session,track,game.bridge_presentation)
	for frame: int in range(6): await process_frame
	await RenderingServer.frame_post_draw
	var output: String = "res://../docs/evidence/checkpoint-forgiveness-2026-10-16/"+RenderingServer.get_current_rendering_method()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	var saved: bool = root.get_texture().get_image().save_png(output.path_join("final.png")) == OK
	game.queue_free(); await process_frame
	print("FORGIVING_CAPTURE: ",saved)
	quit(0 if saved else 1)
