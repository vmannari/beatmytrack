extends "res://tests/test_star_gate_tolerance.gd"
var notices: int = 0

func drive_path(session: TrackSession, track: NativeTrack, path: PackedVector2Array) -> void:
	for i: int in range(path.size()-1):
		var count: int = maxi(1,ceili(path[i].distance_to(path[i+1])/0.2))
		for step: int in range(count):
			var a: Vector2 = path[i].lerp(path[i+1],float(step)/count)
			var b: Vector2 = path[i].lerp(path[i+1],float(step+1)/count)
			var was_missed: int = session.missed_checkpoint
			session.advance(track,a,b,track.nearest_route(b),false)
			if session.missed_checkpoint >= 0:
				if was_missed < 0:
					var gate: int = session.next_checkpoint
					print("NOTICE gate=",gate," point=",b," offset=",session._notice_offset(track,session.last_progress)," reach=",session._notice_reach[gate]," crossing=",session._crossing(gate,a,b)," later=",session._crossing(gate+1,a,b) if gate+1 < session.checkpoint_count() else -1)
				notices += 1

func run() -> void:
	var doc: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/star_spline_lap.json"))
	for reverse: bool in [false,true]:
		var source: Dictionary = doc.duplicate(true)
		if reverse: source.start_line.heading = fposmod(float(source.start_line.heading)+180.0,360.0)
		var track: NativeTrack = TrackCompiler.compile(source)
		var started: int = Time.get_ticks_usec()
		var configured := TrackSession.new(120,1); configured._configure(track)
		print("GATE_PREPARATION_US reverse=",reverse," cold=",Time.get_ticks_usec()-started," count=",configured.checkpoint_count())
		started = Time.get_ticks_usec()
		var retained := TrackSession.new(120,1); retained._configure(track)
		print("GATE_REUSE_US ",Time.get_ticks_usec()-started)
		check(retained._centers == configured._centers and retained._widths == configured._widths,"retained compiled-track gates match cold preparation")
		for offset: float in [-1.0,-0.75,0.75,1.0]:
			var boundary: PackedVector2Array = SplineGateCorridor.lane(track,offset)
			var session := TrackSession.new(120,1); notices = 0
			drive_path(session,track,boundary)
			check(session.finished and notices == 0,"variable-width lane completes without a false warning %s/%s" % [reverse,offset])
		for offset: float in [-4.0,-3.0,3.0,4.0]:
			var session := TrackSession.new(120,1); notices = 0
			drive_path(session,track,offset_lane(track,offset))
			check(session.finished and notices == 0,"road-edge approach through the start remains legal %s/%s" % [reverse,offset])
		for offset: float in [-6.0,-5.5,-5.0,-4.5,-4.0,-3.0,0.0,3.0,4.0,4.5,5.0,5.5,6.0]:
			var session := TrackSession.new(120,1)
			notices = 0
			drive_path(session,track,edge_lane(track,offset))
			print("LEGAL reverse=",reverse," offset=",offset," laps=",session.completed_laps," notices=",notices)
			check(session.finished and notices == 0,"legal lane completes without a false missed-checkpoint warning %s/%s" % [reverse,offset])
		for cut: Vector2i in ([Vector2i(92,160),Vector2i(96,160)] if not reverse else [Vector2i(148,160),Vector2i(144,160)]):
			var path := PackedVector2Array()
			for i: int in range(track.route.size()):
				if track.route_cumulative[i] < cut.x: path.append(track.route[i])
			path.append(track._race_route_point(cut.x)); path.append(track._race_route_point(cut.x+cut.y))
			for i: int in range(track.route.size()):
				if track.route_cumulative[i] > cut.x+cut.y: path.append(track.route[i])
			path.append(track.route[0]); path.append(track.route[1])
			var session := TrackSession.new(120,1); notices = 0
			drive_path(session,track,path)
			check(not session.finished and session.missed_checkpoint >= 0,"shortcut cannot complete a lap %s/%s" % [reverse,cut])
			check(is_equal_approx(session.race_time_seconds(),float(session.elapsed_ticks)/session.tick_rate),"a missed section requires return without automatic penalties")
			var full: PackedVector2Array = track.route.duplicate(); full.append(full[0]); full.append(full[1])
			drive_path(session,track,full)
			check(session.finished and session.missed_checkpoint == -1,"return through the required section recovers the lap")
		if not reverse: export_trajectories(track,source)
	print("STAR_CONSISTENCY_TESTS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func trajectory(track: NativeTrack, path: PackedVector2Array, score: RefCounted) -> Dictionary:
	var point: Vector2 = track.spawn-track.finish_forward*maxf(0.0,(track.spawn-track.finish_center).dot(track.finish_forward)+3.0)
	var samples: Array = [[0,point.x,point.y,0]]
	var tick: int = 0
	var lap: int = 0
	for circuit: int in range(5):
		for target: Vector2 in path:
			var from: Vector2 = point
			var steps: int = maxi(1,ceili(from.distance_to(target)/0.2))
			for step: int in range(1,steps+1):
				var next: Vector2 = from.lerp(target,float(step)/steps)
				score.call("advance",track,point,next,track.nearest_route(next),false)
				tick += 1; point = next
				if tick%6 == 0 or score.get("finished") or int(score.get("completed_laps")) > lap:
					samples.append([tick,point.x,point.y,0])
				lap = int(score.get("completed_laps"))
				if score.get("finished"):
					return {"ticks":tick,"proof":{"schema":"bmt-race-path-v1","samples":samples}}
	return {}

func export_trajectories(track: NativeTrack, doc: Dictionary) -> void:
	var original := GDScript.new()
	original.source_code = FileAccess.get_file_as_string("res://../docs/evidence/star-checkpoint-consistency-2026-10-16/before/game/race/track_session.gd").replace("\r\n","\n").replace("class_name TrackSession\n","")
	check(original.reload() == OK,"actual task-start rules load for the shortcut reproduction")
	var old: RefCounted = original.new(120,5); old.call("_configure",track)
	var path: PackedVector2Array = track.route.duplicate(); path.append(path[0]); path.append(path[1])
	var legal: Dictionary = trajectory(track,path,TrackSession.new(120,5))
	var cut := PackedVector2Array()
	for i: int in range(track.route.size()):
		if track.route_cumulative[i] < 92.0: cut.append(track.route[i])
	cut.append(track._race_route_point(92.0)); cut.append(track._race_route_point(252.0))
	for i: int in range(track.route.size()):
		if track.route_cumulative[i] > 252.0: cut.append(track.route[i])
	cut.append(track.route[0]); cut.append(track.route[1])
	var bypass: Dictionary = trajectory(track,cut,old)
	check(not legal.is_empty() and not bypass.is_empty(),"old rules reproduce five shortcut laps while current rules complete the full route")
	var old_gates: Array = []
	for i: int in range(old.get("_centers").size()):
		old_gates.append(coefficients(old.get("_centers")[i],old.get("_directions")[i],old.get("_widths")[i]))
	old_gates.append(coefficients(track.finish_center,track.finish_forward,Vector2.ONE*(track.finish_half_width+1.5)))
	var file := FileAccess.open("res://../docs/evidence/checkpoint-forgiveness-2026-10-16/trajectories.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"document":doc,"legal":legal,"old_shortcut":bypass,"old_gates":old_gates})); file.close()

func coefficients(center: Vector2, direction: Vector2, widths: Vector2) -> Array:
	var side: Vector2 = direction.orthogonal()
	return [direction.x,direction.y,-center.dot(direction),side.x,side.y,-center.dot(side),-widths.x,widths.y,0]
