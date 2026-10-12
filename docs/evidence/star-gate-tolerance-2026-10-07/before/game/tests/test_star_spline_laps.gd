extends SceneTree
## Exact read-only reproduction fixture of the owner's saved Star circuit.
var checks: int = 0
var failures: int = 0

func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; print("FAIL: ",label)

func drive_path(session: TrackSession, track: NativeTrack, path: PackedVector2Array) -> void:
	for i: int in range(path.size()-1):
		var steps: int = maxi(1,ceili(path[i].distance_to(path[i+1])/0.2))
		for step: int in range(steps):
			var a: Vector2 = path[i].lerp(path[i+1],float(step)/steps)
			var b: Vector2 = path[i].lerp(path[i+1],float(step+1)/steps)
			session.advance(track,a,b,track.nearest_route(b),false)

func trim_local_loops(path: PackedVector2Array) -> PackedVector2Array:
	var result := PackedVector2Array()
	for point: Vector2 in path:
		if result.size() >= 3:
			var travelled: float = 0.0
			for index: int in range(result.size()-3,-1,-1):
				travelled += result[index].distance_to(result[index+1])
				if travelled > 20.0: break
				var hit: Variant = Geometry2D.segment_intersects_segment(result[index],result[index+1],result[-1],point)
				if hit is Vector2 and hit.distance_to(point)>0.001:
					result.resize(index+1); result.append(hit); break
		result.append(point)
	return result

func offroad_samples(track: NativeTrack, path: PackedVector2Array) -> int:
	var result: int = 0
	for i: int in range(path.size()-1):
		var steps: int = maxi(1,ceili(path[i].distance_to(path[i+1])/0.2))
		for step: int in range(steps+1):
			if track.cell_at(path[i].lerp(path[i+1],float(step)/steps)) not in [0,5]: result += 1
	return result

func offset_lane(track: NativeTrack, offset: float) -> PackedVector2Array:
	var result := PackedVector2Array()
	for i: int in range(track.route.size()):
		var forward: Vector2 = (track.route[(i+1)%track.route.size()]-track.route[posmod(i-1,track.route.size())]).normalized()
		result.append(track.route[i]+forward.orthogonal()*offset)
	result.append(result[0]); result.append(result[1])
	return trim_local_loops(result)

func inside_driving(doc: Dictionary, track: NativeTrack, evidence: String) -> void:
	# The modified reference is input-generation guidance only. Every physics
	# tick and every scored gate uses the exact original compiled Star track.
	var guide: NativeTrack = NativeTrack.from_data(track.metadata.duplicate(true),track.content_hash)
	guide.route = offset_lane(track,3.0)
	guide.route.resize(guide.route.size()-2)
	guide._build_route_distance()
	var config: HandlingConfig = VehicleCatalog.config("compact")
	var sim := VehicleSimulation.new(config)
	sim.reset(track.spawn,track.spawn_heading)
	sim.state.position -= track.finish_forward*maxf(0.0,(sim.state.position-track.finish_center).dot(track.finish_forward)+3.0)
	sim.state.route_index = track.nearest_route(sim.state.position)
	var reference := VehicleState.new()
	var driver := RouteDriver.new()
	var session := TrackSession.new(120,5)
	var previous_rules := GDScript.new()
	previous_rules.source_code = FileAccess.get_file_as_string("res://../docs/evidence/star-spline-laps-2026-10-06/before/game/race/track_session.gd").replace("\r\n","\n").replace("class_name TrackSession\n","")
	check(previous_rules.reload() == OK,"original gate generator loads for the same-input regression")
	var old: RefCounted = previous_rules.new(120,5)
	var frames: Array = []
	for tick: int in range(60000):
		reference.position = sim.state.position; reference.velocity = sim.state.velocity
		reference.heading = sim.state.heading; reference.yaw_rate = sim.state.yaw_rate
		reference.route_index = guide.nearest_route(sim.state.position)
		var input: DriveFrame = driver.sample(reference,guide,config)
		frames.append(input.packed())
		var before: Vector2 = sim.state.position
		sim.step(input,track)
		session.advance(track,before,sim.state.position,sim.state.route_index,sim.state.track_elevated)
		old.call("advance",track,before,sim.state.position,sim.state.route_index,sim.state.track_elevated)
		if session.finished: break
	print("STAR_INSIDE_REAL_RACE new_laps=",session.completed_laps," old_laps=",old.get("completed_laps")," old_missed=",old.get("missed_checkpoint")," ticks=",sim.state.tick," contacts=",sim.state.collision_count)
	check(session.finished,"real compact completes five Star laps on the ordinary inside line")
	check(int(old.get("completed_laps")) == 0,"the exact same canonical car motion reproduces the old lap-completion failure")
	var proof: FileAccess = FileAccess.open(evidence.path_join("star-inside-five-lap-replay.json"),FileAccess.WRITE)
	if proof != null:
		proof.store_string(JSON.stringify({"document":doc,"replay":{"schema":"bmt-replay-v1","frames":frames},"vehicle_id":"compact","time_ticks":sim.state.tick,"rules_key":RaceRules.KEY},"",true)); proof.close()

func run() -> void:
	var doc: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/star_spline_lap.json"))
	check(TrackDocument.validate(doc).is_empty(),"actual saved Star document validates")
	var track: NativeTrack = TrackCompiler.compile(doc)
	check(track != null,"Star compiles with the pinned canonical compiler")
	if track == null: quit(1); return
	var chain: Dictionary = RoadPieces.connected_route(doc.pieces)
	check(chain.ok,"Star spline pieces form one closed connected circuit")
	var session := TrackSession.new(120,5)
	session._configure(track)
	var corners: Array[Dictionary] = session._road_corners(track)
	print("STAR_GEOMETRY route_length=",track.route_length," route_points=",track.route.size()," physical_points=",chain.points.size()," gates=",session.checkpoint_count()," corners=",corners.size()," finish=",track.finish_center)
	for i: int in range(session.checkpoint_count()): print("STAR_GATE ",i," distance=",session._progress[i]," center=",session._centers[i]," direction=",session._directions[i]," spans=",session._widths[i])
	var route: PackedVector2Array = track.route.duplicate()
	route.append(route[0]); route.append(route[1])
	for lap: int in range(5):
		drive_path(session,track,route)
		print("STAR_ROUTE_LAP ",lap+1," accepted=",session.completed_laps," next=",session.next_checkpoint," missed=",session.missed_checkpoint)
		check(session.completed_laps == lap+1,"following the compiled Star centreline completes an ordered lap")
	var physical: Dictionary = CreatorStartLine.route_from_start(chain.points,chain.widths,doc.start_line)
	var physical_path: PackedVector2Array = physical.points.duplicate()
	physical_path.append(physical_path[0]); physical_path.append(physical_path[1])
	var exact := TrackSession.new(120,5)
	for lap: int in range(5):
		drive_path(exact,track,physical_path)
		print("STAR_PHYSICAL_LAP ",lap+1," accepted=",exact.completed_laps," next=",exact.next_checkpoint," missed=",exact.missed_checkpoint)
		check(exact.completed_laps == lap+1,"following the physical spline centreline completes an ordered lap")
	for side: float in [-1.0,1.0]:
		for offset: float in [1.0,2.0,3.0,4.0]:
			var lane := PackedVector2Array()
			var off_road: int = 0
			for i: int in range(track.route.size()):
				var forward: Vector2 = (track.route[(i+1)%track.route.size()]-track.route[posmod(i-1,track.route.size())]).normalized()
				var point: Vector2 = track.route[i]+forward.orthogonal()*offset*side
				lane.append(point)
				if track.cell_at(point) not in [0,5]: off_road += 1
			lane.append(lane[0]); lane.append(lane[1])
			var line := TrackSession.new(120,1)
			drive_path(line,track,lane)
			print("STAR_OFFSET side=",side," offset=",offset," offroad_vertices=",off_road," laps=",line.completed_laps," next=",line.next_checkpoint," missed=",line.missed_checkpoint)
			var trimmed: PackedVector2Array = trim_local_loops(lane)
			var inside := TrackSession.new(120,1)
			drive_path(inside,track,trimmed)
			print("STAR_CLEAN_OFFSET side=",side," offset=",offset," offroad_samples=",offroad_samples(track,trimmed)," removed_points=",lane.size()-trimmed.size()," laps=",inside.completed_laps," next=",inside.next_checkpoint," missed=",inside.missed_checkpoint)
			check(offroad_samples(track,trimmed) == 0,"the smooth inside-line reproduction stays on the actual road throughout")
			check(inside.completed_laps == 1,"smooth on-road offset line completes Star without backtracking through offset folds")
	var skipped: int = 0
	for corner: Dictionary in corners:
		var distance: float = corner.distance
		if distance < 24.0 or distance > track.route_length-24.0: continue
		var shortcut := PackedVector2Array()
		for i: int in range(track.route.size()):
			if track.route_cumulative[i] < distance-22.0: shortcut.append(track.route[i])
		shortcut.append(track._race_route_point(distance-22.0))
		shortcut.append(track._race_route_point(distance+22.0))
		for i: int in range(track.route.size()):
			if track.route_cumulative[i] > distance+22.0: shortcut.append(track.route[i])
		shortcut.append(track.route[0]); shortcut.append(track.route[1])
		if offroad_samples(track,shortcut) == 0: continue # Entirely paved inside lines remain legitimate.
		var cut := TrackSession.new(120,1)
		drive_path(cut,track,shortcut)
		print("STAR_BYPASS distance=",distance," offroad=",offroad_samples(track,shortcut)," laps=",cut.completed_laps," next=",cut.next_checkpoint)
		check(cut.completed_laps == 0 and not cut.finished,"cutting a whole Star corner through the infield still blocks the finish")
		check(cut.penalty_seconds == 0.0,"missed corner requires returning, with no automatic time penalty")
		skipped += 1
	check(skipped >= 4,"shortcut regression exercises multiple genuine infield cuts")
	var reversed_doc: Dictionary = doc.duplicate(true)
	reversed_doc.start_line.heading = fposmod(float(reversed_doc.start_line.heading)+180.0,360.0)
	var reversed_track: NativeTrack = TrackCompiler.compile(reversed_doc)
	check(reversed_track != null,"opposite start-line direction compiles the same Star roads")
	if reversed_track != null:
		for offset: float in [-3.0,0.0,3.0]:
			var reverse_lane: PackedVector2Array = offset_lane(reversed_track,offset)
			var reverse_session := TrackSession.new(120,1)
			drive_path(reverse_session,reversed_track,reverse_lane)
			check(offroad_samples(reversed_track,reverse_lane) == 0 and reverse_session.finished,"Star centre/inside lanes also complete with the start line reversed")
	var config: HandlingConfig = VehicleCatalog.config("compact")
	var sim := VehicleSimulation.new(config)
	sim.reset(track.spawn,track.spawn_heading)
	var start_distance: float = (sim.state.position-track.finish_center).dot(track.finish_forward)
	sim.state.position -= track.finish_forward*maxf(0.0,start_distance+3.0)
	sim.state.route_index = track.nearest_route(sim.state.position)
	var race := TrackSession.new(120,5)
	var driver := RouteDriver.new()
	var frames: Array = []
	for tick: int in range(60000):
		var input: DriveFrame = driver.sample(sim.state,track,config)
		frames.append(input.packed())
		var previous: Vector2 = sim.state.position
		sim.step(input,track)
		race.advance(track,previous,sim.state.position,sim.state.route_index,sim.state.track_elevated)
		if race.finished: break
	print("STAR_CANONICAL_RACE laps=",race.completed_laps," next=",race.next_checkpoint," missed=",race.missed_checkpoint," ticks=",sim.state.tick," contacts=",sim.state.collision_count)
	check(race.finished,"real compact driver completes five Star laps")
	var replay := VehicleSimulation.new(config)
	replay.reset(track.spawn,track.spawn_heading)
	replay.state.position -= track.finish_forward*maxf(0.0,(replay.state.position-track.finish_center).dot(track.finish_forward)+3.0)
	replay.state.route_index = track.nearest_route(replay.state.position)
	var replay_session := TrackSession.new(120,5)
	for values: Array in JSON.parse_string(JSON.stringify(frames)):
		var input := DriveFrame.new(); input.steer = int(values[0]); input.throttle = int(values[1]); input.brake = int(values[2])
		var previous: Vector2 = replay.state.position
		replay.step(input,track)
		replay_session.advance(track,previous,replay.state.position,replay.state.route_index,replay.state.track_elevated)
	check(replay.state.snapshot() == sim.state.snapshot() and replay_session.lap_times == race.lap_times,"Star's complete five-lap recording and timing replay exactly")
	var evidence: String = ProjectSettings.globalize_path("res://../docs/evidence/star-spline-laps-2026-10-06")
	DirAccess.make_dir_recursive_absolute(evidence)
	var proof: FileAccess = FileAccess.open(evidence.path_join("star-five-lap-replay.json"),FileAccess.WRITE)
	if proof != null:
		proof.store_string(JSON.stringify({"document":doc,"replay":{"schema":"bmt-replay-v1","frames":frames},"vehicle_id":"compact","time_ticks":sim.state.tick,"rules_key":RaceRules.KEY},"",true)); proof.close()
	inside_driving(doc,track,evidence)
	print("STAR_SPLINE_LAP_TESTS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
