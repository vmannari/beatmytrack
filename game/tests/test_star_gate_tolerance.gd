extends "res://tests/test_star_spline_laps.gd"
## Road-edge driving at steep bends must not demand an artificial gate loop.

func edge_lane(track: NativeTrack, offset: float) -> PackedVector2Array:
	var result := PackedVector2Array()
	for i: int in range(track.route.size()):
		var forward: Vector2 = (track.route[(i+1)%track.route.size()]-track.route[posmod(i-1,track.route.size())]).normalized()
		# Rejoin the independently bounded start/finish corridor.
		var distance: float = minf(track.route_cumulative[i],track.route_length-track.route_cumulative[i])
		result.append(track.route[i]+forward.orthogonal()*offset*smoothstep(0.0,12.0,distance))
	result.append(result[0]); result.append(result[1])
	return trim_local_loops(result)

func run() -> void:
	var doc: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/star_spline_lap.json"))
	var track: NativeTrack = TrackCompiler.compile(doc)
	check(track != null,"original Star compiles")
	if track == null: quit(1); return
	var old_rules := GDScript.new()
	old_rules.source_code = FileAccess.get_file_as_string("res://../docs/evidence/star-gate-tolerance-2026-10-07/before/game/race/track_session.gd").replace("\r\n","\n").replace("class_name TrackSession\n","")
	check(old_rules.reload() == OK,"actual task-start rules19 load for comparison")
	for reverse: bool in [false,true]:
		var current: NativeTrack = track
		if reverse:
			var reversed_doc: Dictionary = doc.duplicate(true)
			reversed_doc.start_line.heading = fposmod(float(reversed_doc.start_line.heading)+180.0,360.0)
			current = TrackCompiler.compile(reversed_doc)
		for offset: float in [-6.0,-5.5,-5.0,-4.5,0.0,4.5,5.0,5.5,6.0]:
			var path: PackedVector2Array = edge_lane(current,offset)
			var session := TrackSession.new(120,5)
			for lap: int in range(5): drive_path(session,current,path)
			print("STAR_EDGE reverse=",reverse," offset=",offset," offroad=",offroad_samples(current,path)," laps=",session.completed_laps," next=",session.next_checkpoint," missed=",session.missed_checkpoint)
			check(session.finished and session.completed_laps == 5,"five ordered road-edge laps in either direction offset "+str(offset))
			check(session.penalty_seconds == 0.0,"edge recovery has no automatic penalty")
			if absf(offset) <= 5.5:
				check(offroad_samples(current,path) == 0,"near-edge lane stays entirely on real road/kerbs")
			else:
				check(shallow_excursion(current,path),"wheel-off-road line remains within one metre of the paved area")
			if not reverse and offset == -5.5:
				var previous: RefCounted = old_rules.new(120,1)
				for i: int in range(path.size()-1):
					var count: int = maxi(1,ceili(path[i].distance_to(path[i+1])/0.2))
					for step: int in range(count):
						var a: Vector2 = path[i].lerp(path[i+1],float(step)/count)
						var b: Vector2 = path[i].lerp(path[i+1],float(step+1)/count)
						previous.call("advance",current,a,b,current.nearest_route(b),false)
				check(int(previous.get("completed_laps")) == 0 and int(previous.get("missed_checkpoint")) == 9,"identical entirely paved line reproduces the original gate9 miss")
		shortcut_checks(current)
	gate_span_checks(track)
	real_edge_drive(doc,track)
	print("STAR_GATE_TOLERANCE_TESTS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func shortcut_checks(track: NativeTrack) -> void:
	var configured := TrackSession.new(120,1); configured._configure(track)
	var tested: int = 0
	for corner: Dictionary in configured._road_corners(track):
		var distance: float = corner.distance
		if distance < 24.0 or distance > track.route_length-24.0: continue
		var shortcut := PackedVector2Array()
		for i: int in range(track.route.size()):
			if track.route_cumulative[i] < distance-22.0: shortcut.append(track.route[i])
		shortcut.append(track._race_route_point(distance-22.0)); shortcut.append(track._race_route_point(distance+22.0))
		for i: int in range(track.route.size()):
			if track.route_cumulative[i] > distance+22.0: shortcut.append(track.route[i])
		shortcut.append(track.route[0]); shortcut.append(track.route[1])
		if shallow_excursion(track,shortcut): continue
		var session := TrackSession.new(120,1); drive_path(session,track,shortcut)
		print("STAR_INFIELD distance=",distance," offroad=",offroad_samples(track,shortcut)," shallow=",shallow_excursion(track,shortcut)," finished=",session.finished)
		check(not session.finished and session.missed_checkpoint >= 0,"large infield cuts still require the missed bend")
		check(session.penalty_seconds == 0.0,"shortcut requires returning with no automatic time penalty")
		var full := track.route.duplicate(); full.append(full[0]); full.append(full[1])
		drive_path(session,track,full)
		check(session.finished and session.missed_checkpoint == -1,"returning through required gates recovers a missed corner")
		tested += 1
	check(tested >= 6,"test deep infield cuts at multiple Star corners in both directions")

func gate_span_checks(track: NativeTrack) -> void:
	var session := TrackSession.new(120,1); session._configure(track)
	check(session.checkpoint_count() == 19,"same nineteen mandatory gates, with no skipped checkpoint credit")
	for gate: int in range(session.checkpoint_count()):
		session.next_checkpoint = gate
		var normal: Vector2 = session._directions[gate].orthogonal()
		var center: Vector2 = session._centers[gate]
		var half: float = session.checkpoint_width(track)*0.5
		var marker: Vector2 = session.checkpoint_position(track)
		check(session._inside(gate,marker-normal*(half-0.01)) and session._inside(gate,marker+normal*(half-0.01)),"visible marker endpoints agree with the actual accepted span")
		for side: int in [-1,1]:
			var width: float = session._widths[gate].x if side < 0 else session._widths[gate].y
			check(not session._inside(gate,center+normal*(width+0.1)*side),"acceptance remains bounded past each edge")

func real_edge_drive(doc: Dictionary, track: NativeTrack) -> void:
	var guide: NativeTrack = NativeTrack.from_data(track.metadata.duplicate(true),track.content_hash)
	guide.route = edge_lane(track,-5.5); guide.route.resize(guide.route.size()-2); guide._build_route_distance()
	var config: HandlingConfig = VehicleCatalog.config("compact")
	var sim := VehicleSimulation.new(config); sim.reset(track.spawn,track.spawn_heading)
	sim.state.position -= track.finish_forward*maxf(0.0,(sim.state.position-track.finish_center).dot(track.finish_forward)+3.0)
	sim.state.route_index = track.nearest_route(sim.state.position)
	var reference := VehicleState.new(); var driver := RouteDriver.new(); var session := TrackSession.new(120,5)
	var frames: Array = []
	for tick: int in range(90000):
		reference.position = sim.state.position; reference.velocity = sim.state.velocity
		reference.heading = sim.state.heading; reference.yaw_rate = sim.state.yaw_rate
		reference.route_index = guide.nearest_route(sim.state.position)
		var input: DriveFrame = driver.sample(reference,guide,config); frames.append(input.packed())
		var before: Vector2 = sim.state.position; sim.step(input,track)
		session.advance(track,before,sim.state.position,sim.state.route_index,sim.state.track_elevated)
		if session.finished: break
	print("STAR_REAL_EDGE_RACE laps=",session.completed_laps," ticks=",sim.state.tick," collisions=",sim.state.collision_count," next=",session.next_checkpoint)
	check(session.finished,"real compact completes five edge-guided laps on unchanged original Star geometry")
	var replay := VehicleSimulation.new(config); replay.reset(track.spawn,track.spawn_heading)
	replay.state.position -= track.finish_forward*maxf(0.0,(replay.state.position-track.finish_center).dot(track.finish_forward)+3.0)
	replay.state.route_index = track.nearest_route(replay.state.position)
	var scored := TrackSession.new(120,5)
	for values: Array in JSON.parse_string(JSON.stringify(frames)):
		var input := DriveFrame.new(); input.steer = int(values[0]); input.throttle = int(values[1]); input.brake = int(values[2])
		var before: Vector2 = replay.state.position; replay.step(input,track)
		scored.advance(track,before,replay.state.position,replay.state.route_index,replay.state.track_elevated)
	check(replay.state.snapshot() == sim.state.snapshot() and scored.lap_times == session.lap_times,"complete quantized edge-driving recording replays exactly")
	var evidence: String = ProjectSettings.globalize_path("res://../docs/evidence/star-gate-tolerance-2026-10-07")
	var proof: FileAccess = FileAccess.open(evidence.path_join("star-edge-five-lap-replay.json"),FileAccess.WRITE)
	check(proof != null,"save full canonical edge-driving evidence")
	if proof != null:
		proof.store_string(JSON.stringify({"document":doc,"replay":{"schema":"bmt-replay-v1","frames":frames},"vehicle_id":"compact","time_ticks":sim.state.tick,"rules_key":RaceRules.KEY},"",true)); proof.close()
