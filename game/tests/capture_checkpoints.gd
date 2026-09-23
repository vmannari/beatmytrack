extends SceneTree
var failures: int = 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func run() -> void:
	root.size = Vector2i(1280,720)
	var document: Dictionary = TrackLibrary.new().load_document("track_acf29166cceaaa42")
	var track: NativeTrack = TrackCompiler.compile(document)
	var game: Node = load("res://core/game.tscn").instantiate()
	game.initial_track = track
	game.production_mode = true
	root.add_child(game)
	game.set_physics_process(false)
	game.paused = true
	game.countdown_ticks = 0
	game.race_cues.visible = false
	var session: TrackSession = game.track_session
	session.advance(track,track.spawn,track.spawn,0)
	# Pick a bend with a wide recovery extension for visual evidence.
	for index: int in range(session.checkpoint_count()):
		session.next_checkpoint = index
		var extra: Vector2 = session.checkpoint_acceptance_spans(track)-session.checkpoint_road_spans(track)
		if maxf(extra.x,extra.y) > 6.0: break
	var selected_gate: int = session.next_checkpoint
	var gate: Vector2 = session.checkpoint_position(track)
	var direction: Vector2 = session.checkpoint_direction(track)
	var side: Vector2 = direction.orthogonal()*(session.checkpoint_width(track)*0.5+5.0)
	session.advance(track,gate+side-direction*5,gate+side+direction*5,0)
	check(session.missed_checkpoint == selected_gate,"actual missed sweep creates checkpoint notice")
	game.sim.state.position = gate-direction*8
	game.sim.state.heading = atan2(direction.x,direction.y)
	game.previous_position = game.sim.state.position
	game.previous_heading = game.sim.state.heading
	game.camera.follow(game.sim.state.position,Vector2.ZERO,game.sim.state.heading,0.0,true)
	for i: int in range(12): await process_frame
	check(game.checkpoint_marker.visible,"missed gate gets a world marker")
	var minimap_properties: Array[StringName] = []
	for property: Dictionary in game.hud.road_map.get_property_list():
		minimap_properties.append(property.name)
	check(&"checkpoint" not in minimap_properties,"minimap has no waypoint marker state")
	check(game.hud.shortcut_notice_label.visible and game.hud.shortcut_notice_label.text == "Missed checkpoint","persistent return notice")
	check(game.checkpoint_marker.label.text == "Missed checkpoint","world label has no checkpoint number")
	var road: Vector2 = session.checkpoint_road_spans(track)
	var accepted: Vector2 = session.checkpoint_acceptance_spans(track)
	check(is_equal_approx(game.checkpoint_marker.mesh.size.x,road.x+road.y),"main line spans road edges only")
	check(is_equal_approx(game.checkpoint_marker.material_override.albedo_color.a,0.65),"road line is translucent")
	for side_index: int in range(2):
		var margin: MeshInstance3D = game.checkpoint_marker.margins[side_index]
		check(is_equal_approx(margin.mesh.size.x,accepted[side_index]-road[side_index]),"margin ends at actual acceptance boundary")
		check(margin.material_override.albedo_color.a < game.checkpoint_marker.material_override.albedo_color.a,"development margins are fainter")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../build/checkpoint-missed.png")
	session.advance(track,gate-direction*2,gate+direction*2,0)
	for i: int in range(4): await process_frame
	check(not game.checkpoint_marker.visible and not game.hud.shortcut_notice_label.visible,"recovery clears world and HUD notices")
	game.restart()
	check(game.track_session.next_checkpoint == 0 and game.track_session.missed_checkpoint == -1,"restart clears checkpoint state")
	check(not game.checkpoint_marker.visible,"restart clears cached marker")
	game.free()
	print("CHECKPOINT_CAPTURE: 14 checks, ",failures," failures")
	quit(0 if failures == 0 else 1)
