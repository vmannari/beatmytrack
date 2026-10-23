extends SceneTree
func _initialize() -> void: run.call_deferred()

func run() -> void:
	root.size = Vector2i(1280,720)
	var doc: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/silmukka.json"))
	var track: NativeTrack = TrackCompiler.compile(doc)
	var session := TrackSession.new(120,1); session._configure(track); session.next_checkpoint = 18
	var previous := GDScript.new()
	previous.source_code = FileAccess.get_file_as_string("res://../docs/evidence/checkpoint-notice-2026-10-17/before/game/race/track_session.gd").replace("\r\n","\n").replace("class_name TrackSession\n","")
	if previous.reload() != OK: quit(1); return
	var old = previous.new(120,1); old._configure(track); old.next_checkpoint = 18
	var a: Vector2 = track._race_route_point(240.008346791203)
	var b: Vector2 = track._race_route_point(240.108346791203)
	old.advance(track,a,b,290,session._layers[18])
	session.advance(track,a,b,290,session._layers[18])
	var game: Node = load("res://core/game.tscn").instantiate()
	game.initial_track = track; game.production_mode = true; root.add_child(game)
	game.set_physics_process(false); game.paused = true; game.countdown_ticks = 0; game.race_cues.hide()
	var heading: float = atan2((b-a).x,(b-a).y)
	game.sim.state.position = b; game.sim.state.heading = heading
	game.sim.state.route_index = track.nearest_route(b); game.sim.state.track_elevated = session._layers[18]
	game.previous_position = b; game.previous_heading = heading
	game.camera.follow(b,Vector2.ZERO,heading,0.0,true)
	game.track_session = session
	var output: String = "res://../docs/evidence/checkpoint-notice-2026-10-17/"+RenderingServer.get_current_rendering_method()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	var saved: bool = true
	for phase: String in ["before","after"]:
		session.missed_checkpoint = int(old.missed_checkpoint) if phase == "before" else -1
		game.checkpoint_marker.previous_gate = -2
		game.checkpoint_marker.present(session,track,game.bridge_presentation)
		game.hud.checkpoint_notice.present(game.checkpoint_marker,game.camera,game.camera.unproject_position(game.car.global_position))
		for frame: int in range(6): await process_frame
		await RenderingServer.frame_post_draw
		saved = root.get_texture().get_image().save_png(output.path_join(phase+"-ahead.png")) == OK and saved
	print("CHECKPOINT_NOTICE_CAPTURE before_missed=",old.missed_checkpoint," after_missed=",session.missed_checkpoint," gate_ahead=",(session._centers[18]-b).dot(session._directions[18])," saved=",saved)
	game.queue_free(); await process_frame
	quit(0 if saved and old.missed_checkpoint == 18 and session.missed_checkpoint == -1 else 1)
