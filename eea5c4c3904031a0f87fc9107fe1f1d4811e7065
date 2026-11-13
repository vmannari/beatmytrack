extends "res://tests/test_checkpoint_rules.gd"
const OUTPUT := "res://../build/checkpoint-road-coverage-2026-11-03/"

func run() -> void:
	root.size = Vector2i(1600,1000)
	var doc: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/star_spline_lap.json"))
	var track: NativeTrack = TrackCompiler.compile(doc)
	var previous: RefCounted = load(OUTPUT+"control_session.gd").new(120,5)
	previous._configure(track)
	track._race_gates.clear()
	var session := TrackSession.new(120,5); session._configure(track)
	var game: Node = load("res://core/game.tscn").instantiate()
	game.initial_track = track; game.production_mode = true
	game.cooperative_preparation = true; game.paused = true
	root.add_child(game)
	while not game.preparation_complete: await process_frame
	game.set_physics_process(false); game.paused = true; game.countdown_ticks = 0; game.race_cues.hide()
	check(await game.world_render_preparation.prepare(draw_frame,func() -> bool: return is_instance_valid(game)),"complete the actual covered-world render preparation")
	var directory: String = OUTPUT+RenderingServer.get_current_rendering_method()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	var target := Vector2(8.275532,63.54075)
	for stage: String in ["before","after"]:
		var displayed := TrackSession.new(120,5); displayed._configure(track)
		if stage == "before":
			for field: String in ["_centers","_directions","_widths","_road_widths","_progress","_layers"]: displayed.set(field,previous.get(field).duplicate())
		var nearest: float = INF
		for gate: int in range(displayed.checkpoint_count()):
			var distance: float = displayed._centers[gate].distance_squared_to(target)
			if distance < nearest: nearest = distance; displayed.next_checkpoint = gate
		check(nearest < 0.001,"compare the same physical Star hairpin checkpoint")
		displayed.missed_checkpoint = displayed.next_checkpoint
		var direction: Vector2 = displayed.checkpoint_direction(track)
		var point: Vector2 = target-direction*8.0
		game.sim.state.position = point; game.sim.state.heading = atan2(direction.x,direction.y)
		game.sim.state.route_index = track.nearest_route(point)
		game.previous_position = point; game.previous_heading = game.sim.state.heading
		game.track_session = displayed
		game._paused_presentation_key.clear()
		game._process(0.0)
		game.set_process(false)
		game.camera.follow(target,Vector2.ZERO,0.0,0.0,true)
		game.checkpoint_marker.previous_gate = -2
		game.checkpoint_marker.present(displayed,track,game.bridge_presentation)
		game.hud.checkpoint_notice.present(game.checkpoint_marker,game.camera,game.camera.unproject_position(game.car.global_position))
		for frame: int in range(8): await process_frame
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(directory.path_join(stage+"-hairpin.png")) == OK,"save native "+stage+" checkpoint view")
		var widths: Vector2 = displayed.checkpoint_road_spans(track)
		check(absf(game.checkpoint_marker.road_span-widths.x-widths.y) < 0.001,"native marker uses the measured physical span")
		print("NATIVE_CHECKPOINT ",stage," center=",displayed.checkpoint_road_center(track)," spans=",widths)
	game.queue_free(); await process_frame
	print("CHECKPOINT_COVERAGE_CAPTURE: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func draw_frame() -> bool:
	await process_frame
	await RenderingServer.frame_post_draw
	return true
