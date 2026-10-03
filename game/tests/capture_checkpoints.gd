extends SceneTree
var failures: int = 0
var checks: int = 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func run() -> void:
	root.size = Vector2i(1280,720)
	var sharp_join: bool = "--screen=sharp-join" in OS.get_cmdline_user_args()
	var dust_cloud: bool = "--screen=dust-cloud" in OS.get_cmdline_user_args()
	var bridge_entry: bool = "--screen=bridge-entry" in OS.get_cmdline_user_args()
	var late_notice: bool = "--screen=late-notice" in OS.get_cmdline_user_args()
	var bridge_exit: bool = "--screen=bridge-exit" in OS.get_cmdline_user_args()
	var document: Dictionary
	if dust_cloud:
		document = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/dust_cloud.json"))
	elif bridge_entry or late_notice or bridge_exit:
		document = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/over_and_under.json"))
	else:
		document = TrackDocument.create_default()
	if sharp_join:
		document = JSON.parse_string(FileAccess.get_file_as_string("res://../build/sharp-join-fixture.json"))
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
	if bridge_exit:
		await capture_bridge_exit(game,session,track)
		game.free()
		print("BRIDGE_EXIT_CAPTURE: ",checks," checks, ",failures," failures")
		quit(0 if failures == 0 else 1)
		return
	# Pick a bend with a wide recovery extension for visual evidence.
	for index: int in range(session.checkpoint_count()):
		session.next_checkpoint = index
		if bridge_entry or late_notice:
			if index == (15 if late_notice else 13): break
			continue
		if dust_cloud:
			if index == 8: break
			continue
		if sharp_join:
			if session.checkpoint_road_center(track).distance_to(Vector2(30,-20)) < 0.1: break
			continue
		var extra: Vector2 = session.checkpoint_acceptance_spans(track)-session.checkpoint_road_spans(track)
		if maxf(extra.x,extra.y) > 6.0: break
	var selected_gate: int = session.next_checkpoint
	var road_center: Vector2 = session.checkpoint_road_center(track)
	var gate: Vector2 = session.checkpoint_position(track)
	var direction: Vector2 = session.checkpoint_direction(track)
	var side: Vector2 = direction.orthogonal()*(session.checkpoint_width(track)*0.5+5.0)
	if not late_notice:
		session.advance(track,gate+side-direction*5,gate+side+direction*5,track.nearest_route(gate))
		check(session.missed_checkpoint == selected_gate,"actual missed sweep creates checkpoint notice")
	game.sim.state.position = gate-direction*8
	game.sim.state.heading = atan2(direction.x,direction.y)
	if bridge_entry or late_notice:
		game.sim.reset(road_center+Vector2(0,0.01),PI)
		game.sim.state.velocity = Vector2(0,-120.0/3.6)
	game.sim.state.route_index = track.nearest_route(game.sim.state.position)
	game.sim.state.track_elevated = false if late_notice else session.checkpoint_elevated()
	game.previous_position = game.sim.state.position
	game.previous_heading = game.sim.state.heading
	game.camera.follow(game.sim.state.position,Vector2.ZERO,game.sim.state.heading,0.0,true)
	if late_notice:
		check(session.missed_checkpoint == -1,"the runtime begins without an injected missed notice")
		var before: Vector2 = game.sim.state.position
		game.paused = false
		game._physics_process(VehicleSimulation.STEP)
		game.paused = true
		game.race_cues.hide()
		check(not game.sim.state.track_elevated and session.next_checkpoint == selected_gate,"actual fast underpass cannot consume the deck gate")
		check(session.missed_checkpoint == selected_gate and game.sim.state.position.distance_to(before) < 0.5,"miss is detected within the first tick and less than half a metre")
		game.call("_process",0.0)
		check(game.hud.checkpoint_notice.visible,"the first presentation frame shows the newly detected miss")
	for i: int in range(12): await process_frame
	check(game.checkpoint_marker.visible,"missed gate gets a world marker")
	var minimap_properties: Array[StringName] = []
	for property: Dictionary in game.hud.road_map.get_property_list():
		minimap_properties.append(property.name)
	check(&"checkpoint" not in minimap_properties,"minimap has no waypoint marker state")
	var marker: CheckpointMarker = game.checkpoint_marker
	var notice: CheckpointNotice = game.hud.checkpoint_notice
	check(notice.visible and notice.label.visible,"missed checkpoint always shows its banner")
	var expected_bearing: Vector2 = (game.camera.unproject_position(marker.global_position)-game.camera.unproject_position(game.car.global_position)).normalized()
	check(notice.bearing.dot(expected_bearing) > 0.99,"live banner arrow points from the car towards the missed gate")
	check(marker.get_children().all(func(child: Node) -> bool: return not child is Label3D),"road marker has no floating checkpoint text")
	var road: Vector2 = session.checkpoint_road_spans(track)
	var accepted: Vector2 = session.checkpoint_acceptance_spans(track)
	check(is_equal_approx(marker.mesh.get_aabb().size.x,road.x+road.y),"dashed line spans road edges only")
	check(marker.road_quads.size() >= 2 and marker.chevrons.mesh != null,"road marker includes separated dashes and approach chevrons")
	check(is_equal_approx(marker.material_override.albedo_color.a,0.92),"road line keeps the reference amber readable")
	for side_index: int in range(2):
		var margin: MeshInstance3D = game.checkpoint_marker.margins[side_index]
		check(is_equal_approx(margin.mesh.size.x,accepted[side_index]-road[side_index]),"margin ends at actual acceptance boundary")
		check(margin.material_override.albedo_color.a < game.checkpoint_marker.material_override.albedo_color.a,"development margins are fainter")
		check(not margin.visible,"development acceptance margins are hidden in the styled marker")
	if dust_cloud:
		check(not session.checkpoint_elevated() and track.has_overhead_bridge(road_center,false),"reported gate is on the road beneath the bridge edge")
		check(is_equal_approx(game.checkpoint_marker.position.y,0.12),"underpass marker is drawn at ground height")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../build/checkpoint-late-notice-missed.png" if late_notice else "res://../build/checkpoint-bridge-entry-missed.png" if bridge_entry else "res://../build/checkpoint-missed.png")
	if not dust_cloud and not sharp_join and not bridge_entry and not late_notice:
		await bearing_cases(game,road_center)
		# Restore the actual driving view before accepting the missed gate.
		game.camera.follow(game.sim.state.position,Vector2.ZERO,game.sim.state.heading,0.0,true)
	var recovery_point: Vector2 = road_center-direction.orthogonal()*7.6 if sharp_join else road_center if dust_cloud else gate
	if late_notice:
		game.sim.reset(road_center+Vector2(0,0.01),PI)
		game.sim.state.velocity = Vector2(0,-120.0/3.6)
		game.sim.state.route_index = track.nearest_route(game.sim.state.position)
		game.sim.state.track_elevated = true
		game.paused = false
		game._physics_process(VehicleSimulation.STEP)
		game.paused = true
		game.race_cues.hide()
		check(not game.sim.state.track_elevated and session.next_checkpoint == selected_gate+1,"actual deck exit accepts the crossing before the layer changes")
	elif bridge_entry:
		game.paused = false
		game._physics_process(VehicleSimulation.STEP)
		game.paused = true
		game.race_cues.hide()
		check(game.sim.state.track_elevated,"actual fast recovery enters the upper ramp in this tick")
		check(session.next_checkpoint == 14,"runtime accepts the gate crossed before ramp entry")
	else:
		session.advance(track,recovery_point-direction*2,recovery_point+direction*2,0)
	if dust_cloud:
		game.sim.state.position = recovery_point+direction*2
		game.previous_position = game.sim.state.position
	for i: int in range(4): await process_frame
	check(not game.checkpoint_marker.visible and not game.hud.shortcut_notice_label.visible,"recovery clears world and HUD notices")
	if bridge_entry:
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://../build/checkpoint-bridge-entry-cleared.png")
	if late_notice:
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://../build/checkpoint-late-notice-cleared.png")
	check(not notice.visible,"recovery also clears the direction hint")
	if dust_cloud:
		check(session.next_checkpoint == 9,"ground-level driving accepts the reported gate")
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://../build/checkpoint-dust-cloud-cleared.png")
	if sharp_join:
		check(track.cell_at(recovery_point,false) in [0,5],"inner join recovery crosses the physical road")
		game.sim.state.position = recovery_point
		game.previous_position = recovery_point
		game.camera.follow(recovery_point,Vector2.ZERO,game.sim.state.heading,0.0,true)
		for i: int in range(4): await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://../build/checkpoint-sharp-join-cleared.png")
	game.restart()
	check(game.track_session.next_checkpoint == 0 and game.track_session.missed_checkpoint == -1,"restart clears checkpoint state")
	check(not game.checkpoint_marker.visible,"restart clears cached marker")
	check(not notice.visible,"restart clears cached banner and direction hint")
	game.track_session._configure(track)
	game.track_session.missed_checkpoint = 0
	game.track_session.finished = true
	game.call("_process",0.0)
	check(not marker.visible and not notice.visible,"finish suppresses any stale missed marker and warning")
	game.free()
	print("CHECKPOINT_CAPTURE: ",checks," checks, ",failures," failures")
	quit(0 if failures == 0 else 1)

func capture_bridge_exit(game: Node, session: TrackSession, track: NativeTrack) -> void:
	var gate: int = 12
	var bridge: Dictionary = track.creator_bridges[0]
	var forward: Vector2 = Vector2.RIGHT.rotated(deg_to_rad(float(bridge.heading)))
	var end: Vector2 = Vector2(bridge.position[0],bridge.position[1])+forward*float(bridge.length)
	session.next_checkpoint = gate
	var corrected: Vector2 = session._directions[gate]
	var absolute: float = session._start_progress+session._progress[gate]
	var old_direction: Vector2 = (track._race_route_point(absolute+2.0)-track._race_route_point(absolute-2.0)).normalized()
	check(corrected.dot(forward) > 0.99999 and corrected.dot(old_direction) < 0.999,"gate now crosses the ramp squarely instead of following the early turn")
	game.sim.reset(end-forward*3.0-forward.orthogonal()*2.0,atan2(forward.x,forward.y))
	game.sim.state.route_index = track.nearest_route(game.sim.state.position)
	game.sim.state.track_elevated = true
	game.sim.state.velocity = forward*120.0/3.6
	var saved_state: Dictionary = RewindHistory.properties(game.sim.state)
	var saved_session: Dictionary = RewindHistory.properties(session,true)
	# Diagnostic baseline: reproduce the rejected lane with the old v16
	# tangent, then restore the real gate for the identical runtime approach.
	session._directions[gate] = old_direction
	game.paused = false
	for tick: int in range(60):
		game._physics_process(VehicleSimulation.STEP)
		if session.missed_checkpoint >= 0: break
	game.paused = true
	game.race_cues.hide()
	game.camera.follow(game.sim.state.position,Vector2.ZERO,game.sim.state.heading,0.0,true)
	for frame: int in range(4): await process_frame
	check(session.missed_checkpoint == gate and game.hud.checkpoint_notice.visible,"old tangent reproduces a false miss on the actual compact exit")
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("res://../build/checkpoint-first-exit-baseline.png") == OK,"save old-tangent diagnostic baseline")
	RewindHistory.restore(game.sim.state,saved_state)
	RewindHistory.restore(session,saved_session)
	session._directions[gate] = corrected
	game.online_frames.clear()
	game.rewind_history.entries.clear()
	var warned: bool = false
	var on_road: bool = true
	game.paused = false
	for tick: int in range(60):
		game._physics_process(VehicleSimulation.STEP)
		warned = warned or session.missed_checkpoint >= 0
		on_road = on_road and track.cell_at(game.sim.state.position,game.sim.state.track_elevated) in [0,5]
		if session.next_checkpoint > gate: break
	game.paused = true
	game.race_cues.hide()
	game.camera.follow(game.sim.state.position,Vector2.ZERO,game.sim.state.heading,0.0,true)
	for frame: int in range(4): await process_frame
	check(session.next_checkpoint == gate+1 and not warned and on_road and game.sim.state.collision_count == 0,"identical actual compact approach accepts the ground exit without a miss")
	check(not game.sim.state.track_elevated and not game.checkpoint_marker.visible and not game.hud.checkpoint_notice.visible,"ground crossing has no false marker or banner")
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("res://../build/checkpoint-first-exit-fixed.png") == OK,"save corrected actual bridge exit")

func bearing_cases(game: Node, road_center: Vector2) -> void:
	game.set_process(false)
	var marker: CheckpointMarker = game.checkpoint_marker
	var notice: CheckpointNotice = game.hud.checkpoint_notice
	var camera: Camera3D = game.camera
	var output: String = "res://../docs/evidence/missed-checkpoint-2026-10-03"
	for extent: Vector2i in [Vector2i(1280,720),Vector2i(960,540),Vector2i(1600,720)]:
		root.size = extent
		for i: int in range(3): await process_frame
		game.camera.follow(road_center,Vector2.ZERO,0.0,0.0,true)
		game.call("_process",0.0)
		notice.present(marker,camera,camera.unproject_position(game.car.global_position))
		check(root.get_visible_rect().has_point(camera.unproject_position(marker.global_position)) and notice.visible,"visible gate retains banner at %s" % extent)
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(output+"/onscreen-%dx%d.png" % [extent.x,extent.y]) == OK,"save on-screen evidence")
		var center: Vector2 = camera.get_viewport().get_visible_rect().size*0.5
		for bearing: Vector2 in [Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN,Vector2(-1,-1).normalized(),Vector2(1,1).normalized()]:
			var projected: Vector2 = camera.unproject_position(marker.global_position)
			var destination: Vector2 = center+bearing*center.length()*2.0
			var move: Vector3 = camera.project_position(projected,20)-camera.project_position(destination,20)
			camera.global_position += move
			notice.present(marker,camera)
			check(not root.get_visible_rect().has_point(camera.unproject_position(marker.global_position)) and notice.visible and notice.label.visible,"off-screen gate retains warning at %s towards %s" % [extent,bearing])
			check(notice.bearing.dot(bearing) > 0.99,"direction hint points towards the projected checkpoint")
			check(Rect2(Vector2.ZERO,notice.size).encloses(notice.banner_rect.grow_individual(6,8,12,8)),"banner and its only direction arrow fit the viewport")
			check(notice.label.get_global_rect().position.y > game.hud.lap_timer.get_global_rect().end.y,"warning clears the race and lap clocks")
			await RenderingServer.frame_post_draw
			if bearing == Vector2.LEFT:
				check(root.get_texture().get_image().save_png(output+"/offscreen-%dx%d.png" % [extent.x,extent.y]) == OK,"save off-screen evidence")
			# Returning to view keeps the warning until the gate is recovered.
			camera.global_position -= move
			notice.present(marker,camera)
			check(notice.visible,"returning gate retains the banner and its direction arrow")
		# Keep one road-line end visible with the centre outside the viewport.
		var projected_center: Vector2 = camera.unproject_position(marker.global_position)
		var longest := Vector2.ZERO
		for quad: PackedVector3Array in marker.road_quads:
			for point: Vector3 in quad:
				var offset: Vector2 = camera.unproject_position(marker.to_global(point))-projected_center
				if offset.length_squared() > longest.length_squared(): longest = offset
		var axis: int = 0 if absf(longest.x) > absf(longest.y) else 1
		var target: Vector2 = center
		target[axis] = -absf(longest[axis])*0.35 if longest[axis] > 0.0 else center[axis]*2.0+absf(longest[axis])*0.35
		var partial_move: Vector3 = camera.project_position(projected_center,20)-camera.project_position(target,20)
		camera.global_position += partial_move
		notice.present(marker,camera)
		check(not root.get_visible_rect().has_point(camera.unproject_position(marker.global_position)),"partial visibility case has an off-screen gate centre")
		check(notice.visible,"a partially visible dashed-line retains the warning")
		camera.global_position -= partial_move
		var saved_position: Vector3 = camera.global_position
		camera.global_position = marker.global_position-camera.global_basis.z*30+camera.global_basis.x*20
		notice.present(marker,camera)
		check(camera.is_position_behind(marker.global_position) and notice.visible,"a gate behind the camera gets a warning")
		check(notice.bearing.x < -0.99,"orthographic behind-camera hint retains the correct left bearing")
		camera.global_position = saved_position
	root.size = Vector2i(1280,720)
	for i: int in range(3): await process_frame
	game.set_process(true)
