extends "res://tests/test_star_gate_tolerance.gd"
## Fixed route bypasses and real paved lines; no global strictness rollback.
const EVIDENCE := "res://../docs/evidence/hairpin-checkpoints-2026-10-18/"

func run() -> void:
	var document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/star_spline_lap.json"))
	var rows: Array = []
	for reverse: bool in [false,true]:
		var doc: Dictionary = document.duplicate(true)
		if reverse: doc.start_line.heading = fposmod(float(doc.start_line.heading)+180.0,360.0)
		var track: NativeTrack = TrackCompiler.compile(doc)
		var configured := TrackSession.new(120,1); configured._configure(track)
		# Ordinary straight-road recovery still permits two metres on either
		# side. Tightening a folded apex must not narrow the whole circuit.
		var ordinary: int = -1
		for gate: int in range(configured.checkpoint_count()):
			if absf(configured._progress[gate]-(267.0593 if not reverse else 133.5296)) < 0.01: ordinary = gate
		check(ordinary >= 0,"ordinary recovery control gate exists")
		if ordinary >= 0:
			for side: int in [-1,1]:
				var recovery := TrackSession.new(120,1); recovery._configure(track); recovery.next_checkpoint = ordinary
				var point: Vector2 = recovery._centers[ordinary]+recovery._directions[ordinary].orthogonal()*7.0*side
				recovery.advance(track,point-recovery._directions[ordinary],point+recovery._directions[ordinary],track.nearest_route(point),false)
				check(recovery.next_checkpoint > ordinary and recovery.missed_checkpoint < 0,"two-metre ordinary road recovery remains usable %s/%s" % [reverse,side])
		for offset: float in [-5.5,-5.25,-5.0,-4.5,-4.0,-3.0,0.0,3.0,4.0,4.5,5.0,5.25,5.5]:
			var session := TrackSession.new(120,1)
			var warned: bool = walk(session,track,edge_lane(track,offset))
			check(session.finished and not warned,"paved/kerb line stays clear %s/%s" % [reverse,offset])
		for cut: Vector2i in ([Vector2i(36,88),Vector2i(104,88),Vector2i(112,84),Vector2i(128,68),Vector2i(108,60)] if not reverse else [Vector2i(208,88),Vector2i(276,88),Vector2i(204,72),Vector2i(232,64)]):
			var path := PackedVector2Array()
			for i: int in range(track.route.size()):
				if track.route_cumulative[i] < cut.x: path.append(track.route[i])
			var a: Vector2 = track._race_route_point(cut.x)
			var b: Vector2 = track._race_route_point(cut.x+cut.y)
			path.append(a); path.append(b)
			for i: int in range(track.route.size()):
				if track.route_cumulative[i] > cut.x+cut.y: path.append(track.route[i])
			path.append(track.route[0]); path.append(track.route[1])
			var session := TrackSession.new(120,1)
			walk(session,track,path)
			check(not session.finished and session.missed_checkpoint >= 0,"whole hairpin bypass requires return %s/%s" % [reverse,cut])
			rows.append({"reverse":reverse,"begin":cut.x,"skipped":cut.y,"saving_m":cut.y-a.distance_to(b),"finished":session.finished,"missed":session.missed_checkpoint,"gates":session.checkpoint_count()})
			var full: PackedVector2Array = track.route.duplicate(); full.append(full[0]); full.append(full[1])
			walk(session,track,full)
			check(session.finished and session.missed_checkpoint == -1,"correct return recovers the lap %s/%s" % [reverse,cut])
			check(is_equal_approx(session.race_time_seconds(),session.lap_times[0]),"return has no added time penalty")
		# A prepared rules22 track must rebuild before accepting new attempts.
		track._race_gates.rules_key = "standing-5-road-gates-v22"
		var retained := TrackSession.new(120,1); retained._configure(track)
		check(track._race_gates.rules_key == RaceRules.KEY and retained._centers == configured._centers,"old gate cache is fenced by rules23")
	var file := FileAccess.open(EVIDENCE+"final-cuts.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(rows,"\t")); file.close()
	var original_track: NativeTrack = TrackCompiler.compile(document)
	real_edge_drive(document,original_track)
	print("HAIRPIN_CHECKPOINT_TESTS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func walk(session: TrackSession, track: NativeTrack, path: PackedVector2Array) -> bool:
	var warned: bool = false
	var hint: int = track.nearest_route(path[0])
	for i: int in range(path.size()-1):
		var count: int = maxi(1,ceili(path[i].distance_to(path[i+1])/0.2))
		for step: int in range(count):
			var a: Vector2 = path[i].lerp(path[i+1],float(step)/count)
			var b: Vector2 = path[i].lerp(path[i+1],float(step+1)/count)
			hint = track.nearest_route(b,hint)
			session.advance(track,a,b,hint,false)
			warned = warned or session.missed_checkpoint >= 0
	return warned
