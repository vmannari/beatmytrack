extends "res://tests/test_star_spline_laps.gd"
## Bounded chord sweep; confirm deep candidates with the actual session too.

func accepts(configured: TrackSession, path: PackedVector2Array) -> bool:
	var gate: int = 0
	for i: int in range(path.size()-1):
		var consumed: float = -1.0
		while gate < configured.checkpoint_count():
			var fraction: float = configured._crossing(gate,path[i],path[i+1])
			if fraction < 0.0 or fraction < consumed-0.000001: break
			if not configured._inside(gate,path[i].lerp(path[i+1],fraction)): break
			consumed = fraction; gate += 1
	return gate == configured.checkpoint_count()

func run() -> void:
	var doc: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/star_spline_lap.json"))
	var report: Array = []
	for reverse: bool in [false,true]:
		var source: Dictionary = doc.duplicate(true)
		if reverse: source.start_line.heading = fposmod(float(source.start_line.heading)+180.0,360.0)
		var track: NativeTrack = TrackCompiler.compile(source)
		var configured := TrackSession.new(120,1); configured._configure(track)
		print("STAR_GEOMETRY reverse=",reverse," length=",track.route_length," gates=",configured.checkpoint_count())
		var cuts: Array = []
		var eligible: int = 0
		var deep: int = 0
		var deep_accepted: int = 0
		for begin: int in range(4,int(track.route_length)-12,4):
			for skipped: int in range(12,mini(164,int(track.route_length)-begin),4):
				var a: Vector2 = track._race_route_point(begin)
				var b: Vector2 = track._race_route_point(begin+skipped)
				var saving: float = skipped-a.distance_to(b)
				if saving < 3.0: continue
				eligible += 1
				var shallow: bool = shallow_excursion(track,PackedVector2Array([a,b]))
				if not shallow: deep += 1
				var shortcut := PackedVector2Array()
				for i: int in range(track.route.size()):
					if track.route_cumulative[i] < begin: shortcut.append(track.route[i])
				shortcut.append(a); shortcut.append(b)
				for i: int in range(track.route.size()):
					if track.route_cumulative[i] > begin+skipped: shortcut.append(track.route[i])
				shortcut.append(track.route[0]); shortcut.append(track.route[1])
				if accepts(configured,shortcut):
					if not shallow:
						var actual := TrackSession.new(120,1)
						drive_path(actual,track,shortcut)
						if actual.finished: deep_accepted += 1
					var offroad: int = offroad_samples(track,PackedVector2Array([a,b]))
					if offroad > 5: cuts.append({"begin":begin,"skipped":skipped,"saving":saving,"offroad_m":offroad*0.2,"shallow":shallow_excursion(track,PackedVector2Array([a,b])),"a":[a.x,a.y],"b":[b.x,b.y]})
		cuts.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a.saving > b.saving)
		print("ACCEPTED_CUTS reverse=",reverse," count=",cuts.size()," worst=",cuts.slice(0,12))
		check(deep_accepted == 0,"all sampled deep Star cuts are rejected")
		print("SWEEP reverse=",reverse," eligible=",eligible," deep=",deep," deep_accepted=",deep_accepted)
		report.append({"reverse":reverse,"eligible":eligible,"deep":deep,"deep_accepted":deep_accepted,"cuts":cuts})
	var file := FileAccess.open("res://../docs/evidence/star-checkpoint-consistency-2026-10-16/shortcut-sweep.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t")); file.close()
	quit(1 if failures else 0)
