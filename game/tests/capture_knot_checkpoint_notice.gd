extends SceneTree

func _initialize() -> void: run.call_deferred()

func run() -> void:
	root.size = Vector2i(1280,720)
	var document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/knot.json"))
	var track: NativeTrack = TrackCompiler.compile(document)
	var previous := GDScript.new()
	previous.source_code = FileAccess.get_file_as_string("res://../docs/evidence/knot-checkpoints-2026-10-18/before/track_session.gd").replace("\r\n","\n").replace("class_name TrackSession\n","")
	if previous.reload() != OK: quit(1); return
	var old = previous.new(120,1); old._configure(track); old.next_checkpoint = 3
	var current := TrackSession.new(120,1); current._configure(track); current.next_checkpoint = 3
	var a := Vector2(52.40509,-24.91616)
	var b := Vector2(52.32339,-24.88533)
	old.advance(track,a,b,43,false,0)
	current.advance(track,a,b,43,false,0)
	var corrected_miss: int = current.missed_checkpoint
	var game: Node = load("res://core/game.tscn").instantiate()
	game.initial_track = track; game.production_mode = true; root.add_child(game)
	game.set_physics_process(false); game.paused = true; game.countdown_ticks = 0; game.race_cues.hide()
	var heading: float = atan2((b-a).x,(b-a).y)
	game.sim.state.position = b; game.sim.state.heading = heading
	game.sim.state.route_index = 43; game.sim.state.track_elevated = false
	game.previous_position = b; game.previous_heading = heading
	game.camera.follow(b,Vector2.ZERO,heading,0.0,true)
	game.track_session = current
	var output: String = "res://../docs/evidence/knot-checkpoints-2026-10-18/"+RenderingServer.get_current_rendering_method()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	var saved: bool = true
	for phase: String in ["before","after"]:
		current.missed_checkpoint = int(old.missed_checkpoint) if phase == "before" else corrected_miss
		game.checkpoint_marker.previous_gate = -2
		game.checkpoint_marker.present(current,track,game.bridge_presentation)
		game.hud.checkpoint_notice.present(game.checkpoint_marker,game.camera,game.camera.unproject_position(game.car.global_position))
		for frame: int in range(8): await process_frame
		await RenderingServer.frame_post_draw
		saved = root.get_texture().get_image().save_png(output.path_join(phase+".png")) == OK and saved
	print("KNOT_NOTICE_CAPTURE before=",old.missed_checkpoint," after=",corrected_miss," gate_ahead_m=",(current._centers[3]-b).dot(current._directions[3])," saved=",saved)
	game.queue_free(); await process_frame
	quit(0 if saved and old.missed_checkpoint == 3 and corrected_miss == -1 else 1)
