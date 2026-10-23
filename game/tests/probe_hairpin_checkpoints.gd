extends "res://tests/test_star_gate_tolerance.gd"
const OUTPUT := "res://../docs/evidence/hairpin-checkpoints-2026-10-18/"

func run() -> void:
	var doc: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/star_spline_lap.json"))
	var report: Array = []
	for reverse: bool in [false,true]:
		var source: Dictionary = doc.duplicate(true)
		if reverse: source.start_line.heading = fposmod(float(source.start_line.heading)+180.0,360.0)
		var track: NativeTrack = TrackCompiler.compile(source)
		var configured := TrackSession.new(120,1); configured._configure(track)
		print("HAIRPIN_CORNERS reverse=",reverse," ",configured._road_corners(track))
		if not reverse:
			for offset: float in [-7.0,-6.0,-5.0,-4.0,0.0,4.0,5.0,6.0,7.0]:
				var lane: PackedVector2Array = edge_lane(track,offset)
				var values: Array = []
				for gate: int in range(configured.checkpoint_count()):
					if not (absf(configured._progress[gate]-45.9019) < 0.01 or absf(configured._progress[gate]-112.8582) < 0.01 or absf(configured._progress[gate]-156.7212) < 0.01): continue
					var nearest: float = INF
					for i: int in range(lane.size()-1):
						var fraction: float = configured._crossing(gate,lane[i],lane[i+1])
						if fraction < 0.0: continue
						var point: Vector2 = lane[i].lerp(lane[i+1],fraction)
						var lateral: float = (point-configured._centers[gate]).dot(configured._directions[gate].orthogonal())
						if absf(lateral) < absf(nearest): nearest = lateral
					values.append([configured._progress[gate],nearest])
				print("HAIRPIN_LANE offset=",offset," ",values)
		var cuts: Array = []
		for cut: Vector2 in ([Vector2(36,88),Vector2(104,88),Vector2(112,84),Vector2(156,32)] if not reverse else [Vector2(208,88),Vector2(276,88)]):
			var path := PackedVector2Array()
			for i: int in range(track.route.size()):
				if track.route_cumulative[i] < cut.x: path.append(track.route[i])
			path.append(track._race_route_point(cut.x)); path.append(track._race_route_point(cut.x+cut.y))
			for i: int in range(track.route.size()):
				if track.route_cumulative[i] > cut.x+cut.y: path.append(track.route[i])
			path.append(track.route[0]); path.append(track.route[1])
			var session := TrackSession.new(120,1)
			drive_path(session,track,path)
			var crossed: Array = []
			var a: Vector2 = track._race_route_point(cut.x)
			var b: Vector2 = track._race_route_point(cut.x+cut.y)
			for gate: int in range(configured.checkpoint_count()):
				var f: float = configured._crossing(gate,a,b)
				if f >= 0.0 and configured._inside(gate,a.lerp(b,f)): crossed.append({"gate":gate,"progress":configured._progress[gate],"lateral":(a.lerp(b,f)-configured._centers[gate]).dot(configured._directions[gate].orthogonal())})
			cuts.append({"begin":cut.x,"skipped":cut.y,"finished":session.finished,"missed":session.missed_checkpoint,"saving":cut.y-a.distance_to(b),"crossed":crossed,"a":[a.x,a.y],"b":[b.x,b.y]})
			print("HAIRPIN_CUT reverse=",reverse," ",cuts[-1])
		var gates: Array = []
		for gate: int in range(configured.checkpoint_count()):
			gates.append({"center":[configured._centers[gate].x,configured._centers[gate].y],"direction":[configured._directions[gate].x,configured._directions[gate].y],"widths":[configured._widths[gate].x,configured._widths[gate].y],"progress":configured._progress[gate]})
		var route: Array = []
		for p: Vector2 in track.route: route.append([p.x,p.y])
		report.append({"reverse":reverse,"cuts":cuts,"gates":gates,"route":route})
	var file := FileAccess.open(OUTPUT+("baseline" if "--baseline" in OS.get_cmdline_user_args() else "candidate")+".json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t")); file.close()
	quit()
