extends "res://tests/test_star_gate_tolerance.gd"
## Physical road and kerbs are the minimum gate span, including folded apices.
const OUTPUT := "res://../build/checkpoint-road-coverage-2026-11-03/"

func run() -> void:
	var rows: Array = []
	for fixture: String in ["star_spline_lap","silmukka","dust_cloud","over_and_under","knot"]:
		for reverse: bool in [false,true]:
			var doc: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/"+fixture+".json"))
			if reverse and not doc.has("start_line"): continue
			if reverse: doc.start_line.heading = fposmod(float(doc.start_line.heading)+180.0,360.0)
			var track: NativeTrack = TrackCompiler.compile(doc)
			var session := TrackSession.new(120,1); session._configure(track)
			var support := preload("res://track/road_surface_height.gd").new(track)
			track._race_gates.rules_key = "standing-5-road-gates-v23"
			var fresh := TrackSession.new(120,1); fresh._configure(track)
			check(track._race_gates.rules_key == RaceRules.KEY and fresh._widths == session._widths and fresh._finish_widths == session._finish_widths,"rules23 gate cache rebuilds with complete road and finish coverage")
			for fraction: float in [-1.0,-0.75,0.75,1.0]:
				var path: PackedVector2Array = SplineGateCorridor.lane(track,fraction,false,true,0.5)
				var actual := TrackSession.new(120,1); drive_path(actual,track,path)
				print("WIDE_PROFILE reverse=",reverse," fraction=",fraction," offroad_samples=",offroad_samples(track,path)," finished=",actual.finished)
			for gate: int in range(session.checkpoint_count()+1):
				session.next_checkpoint = gate
				var center: Vector2 = session.checkpoint_road_center(track)
				var direction: Vector2 = session.checkpoint_direction(track)
				var road: Vector2 = session.checkpoint_road_spans(track)
				var acceptance: Vector2 = session.checkpoint_acceptance_spans(track)
				var normal: Vector2 = direction.orthogonal()
				for side: int in range(2):
					var sign_value: float = -1.0 if side == 0 else 1.0
					var span: float = 0.0
					# Deliberately independent of authored widths and production scan caps.
					while span < track.half_extent.length()*2.0:
						var point: Vector2 = center+normal*span*sign_value
						if not physical(track,support,point,session.checkpoint_elevated()): break
						span += 0.05
					var edge: float = maxf(0.0,span-0.05)
					check(road[side]+0.001 >= edge,"marker covers road/kerbs %s gate=%d side=%d edge=%.3f marker=%.3f" % [reverse,gate,side,edge,road[side]])
					check(acceptance[side]+0.001 >= edge,"acceptance covers road/kerbs %s gate=%d side=%d" % [reverse,gate,side])
					var crossing: Vector2 = center+normal*maxf(0.0,edge-0.02)*sign_value
					var actual := TrackSession.new(120,1); actual._configure(track); actual.next_checkpoint = gate
					actual.finish_armed = true; actual.route_distance = 20.0
					actual.advance(track,crossing-direction*0.01,crossing+direction*0.01,track.nearest_route(crossing),session.checkpoint_elevated())
					check(actual.finished if gate == session.checkpoint_count() else actual.next_checkpoint > gate,"outermost legal crossing consumes checkpoint %s/%d/%d" % [reverse,gate,side])
					rows.append({"fixture":fixture,"reverse":reverse,"gate":gate,"side":side,"edge":edge,"marker":road[side],"accepted":acceptance[side],"center":[center.x,center.y],"direction":[direction.x,direction.y]})
	var name: String = "baseline" if "--baseline" in OS.get_cmdline_user_args() else "final"
	var file := FileAccess.open(OUTPUT+name+"-coverage.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(rows,"\t")); file.close()
	print("CHECKPOINT_ROAD_COVERAGE: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func physical(track: NativeTrack, support: RefCounted, point: Vector2, elevated: bool) -> bool:
	if elevated:
		var x: int = floori((point.x+track.half_extent.x)/track.cell_size)
		var y: int = floori((track.half_extent.y-point.y)/track.cell_size)
		return x >= 0 and y >= 0 and x < track.grid_width and y < track.grid_height and track.deck_cells[y*track.grid_width+x] in [0,5]
	if track.cell_at(point) in [0,5] or track.kerbs.height_at(point) > 0.00001: return true
	# Independently sample the actual rendered support polygons, without the
	# production line-intersection/interval-merging algorithm.
	for index: int in support.floor_bins.get(Vector2i((point/8.0).floor()),[]):
		if Geometry2D.is_point_in_polygon(point,support.floors[index]): return true
	return false
