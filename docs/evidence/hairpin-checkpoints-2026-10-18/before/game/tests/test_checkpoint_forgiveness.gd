extends "res://tests/test_star_gate_tolerance.gd"
var notices: int = 0

func drive_path(session: TrackSession, track: NativeTrack, path: PackedVector2Array) -> void:
	for i: int in range(path.size()-1):
		var steps: int = maxi(1,ceili(path[i].distance_to(path[i+1])/0.2))
		for step: int in range(steps):
			var a: Vector2 = path[i].lerp(path[i+1],float(step)/steps)
			var b: Vector2 = path[i].lerp(path[i+1],float(step+1)/steps)
			session.advance(track,a,b,track.nearest_route(b),false)
			if session.missed_checkpoint >= 0: notices += 1

func cut_path(track: NativeTrack, begin: float, skipped: float) -> PackedVector2Array:
	var path := PackedVector2Array()
	for i: int in range(track.route.size()):
		if track.route_cumulative[i] < begin: path.append(track.route[i])
	path.append(track._race_route_point(begin)); path.append(track._race_route_point(begin+skipped))
	for i: int in range(track.route.size()):
		if track.route_cumulative[i] > begin+skipped: path.append(track.route[i])
	path.append(track.route[0]); path.append(track.route[1])
	return path

func run() -> void:
	var baseline: bool = "--baseline" in OS.get_cmdline_user_args()
	var doc: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/star_spline_lap.json"))
	var report: Array = []
	for reverse: bool in [false,true]:
		var source: Dictionary = doc.duplicate(true)
		if reverse: source.start_line.heading = fposmod(float(source.start_line.heading)+180.0,360.0)
		var track: NativeTrack = TrackCompiler.compile(source)
		var configured := TrackSession.new(120,1); configured._configure(track)
		print("FORGIVENESS_GATES reverse=",reverse," count=",configured.checkpoint_count())
		if not baseline:
			track._race_gates["rules_key"] = "standing-5-road-gates-v21"
			var fresh := TrackSession.new(120,1); fresh._configure(track)
			check(track._race_gates.rules_key == RaceRules.KEY and fresh._centers == configured._centers,"old strict gate preparation is fenced by the new rules key")
		for offset: float in [-7.0,-6.75,-6.5,-6.0,-5.5,-5.0,-4.5,-4.0,-3.0,0.0,3.0,4.0,4.5,5.0,5.5,6.0,6.5,6.75,7.0]:
			var path: PackedVector2Array = edge_lane(track,offset)
			var session := TrackSession.new(120,1); notices = 0
			drive_path(session,track,path)
			print("FORGIVENESS_LANE reverse=",reverse," offset=",offset," finished=",session.finished," notices=",notices)
			if not baseline: check(session.finished and notices == 0,"ordinary edge excursion passes without a return or false warning %s/%s" % [reverse,offset])
			report.append({"reverse":reverse,"offset":offset,"finished":session.finished,"notices":notices})
		if not baseline:
			for cut: Vector2i in ([Vector2i(92,160),Vector2i(96,160)] if not reverse else [Vector2i(148,160),Vector2i(144,160)]):
				var session := TrackSession.new(120,1); notices = 0
				drive_path(session,track,cut_path(track,cut.x,cut.y))
				check(not session.finished and session.missed_checkpoint >= 0,"multi-corner shortcut remains blocked")
				var full: PackedVector2Array = track.route.duplicate(); full.append(full[0]); full.append(full[1])
				drive_path(session,track,full)
				check(session.finished and is_equal_approx(session.race_time_seconds(),session.lap_times[0]),"return recovers the lap with no automatic time penalty")
	var file := FileAccess.open("res://../docs/evidence/checkpoint-forgiveness-2026-10-16/"+("baseline" if baseline else "final")+"-lanes.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t")); file.close()
	print("CHECKPOINT_FORGIVENESS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
