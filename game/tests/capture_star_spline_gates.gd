extends SceneTree
## Diagnostic marker snapshots of actual old/new Star gate definitions.
var checks: int = 0
var failures: int = 0

func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; print("FAIL: ",label)

func run() -> void:
	root.size = Vector2i(1280,720)
	var doc: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/star_spline_lap.json"))
	var track: NativeTrack = TrackCompiler.compile(doc)
	var original := GDScript.new()
	original.source_code = FileAccess.get_file_as_string("res://../docs/evidence/star-spline-laps-2026-10-06/before/game/race/track_session.gd").replace("\r\n","\n").replace("class_name TrackSession\n","")
	check(original.reload() == OK,"original gate generator loads for the before image")
	var old: RefCounted = original.new(120,5); old.call("_configure",track)
	var current := TrackSession.new(120,5); current._configure(track)
	var reference := TrackSession.new(120,5)
	for key: String in ["_centers","_directions","_progress","_widths","_road_widths","_notice_reach","_route_hints","_layers","_start_progress","_finish_elevated"]:
		reference.set(key,old.get(key))
	reference.initialized = true
	var target: Vector2 = SplineRoad.points(doc.pieces[0])[1]
	var game: Node = load("res://core/game.tscn").instantiate()
	game.initial_track = track; game.production_mode = true
	root.add_child(game)
	game.set_physics_process(false); game.paused = true; game.countdown_ticks = 0; game.race_cues.hide()
	var marker := CheckpointMarker.new(); game.checkpoint_marker.get_parent().add_child(marker)
	var location: Vector2 = target+Vector2(7,-6)
	game.sim.state.position = location
	game.sim.state.heading = PI*0.25
	game.sim.state.route_index = track.nearest_route(location)
	game.previous_position = location; game.previous_heading = game.sim.state.heading
	game.camera.follow(location,Vector2.ZERO,game.sim.state.heading,0.0,true)
	var evidence: String = ProjectSettings.globalize_path("res://../docs/evidence/star-spline-laps-2026-10-06")
	DirAccess.make_dir_recursive_absolute(evidence)
	for previous: bool in [true,false]:
		var session: TrackSession = reference if previous else current
		var closest: float = INF
		for i: int in range(session.checkpoint_count()):
			var distance: float = session._centers[i].distance_to(target)
			if distance < closest: closest = distance; session.next_checkpoint = i
		session.missed_checkpoint = session.next_checkpoint
		marker.previous_gate = -2; marker.present(session,track,game.bridge_presentation)
		check(marker.visible,"diagnostic marker shows an actual configured gate")
		for frame: int in range(6): await process_frame
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			check(root.get_texture().get_image().save_png(evidence.path_join("before-first-corner.png" if previous else "after-first-corner.png")) == OK,"save actual gate screenshot")
	game.queue_free(); await process_frame
	print("STAR_GATE_CAPTURE: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
