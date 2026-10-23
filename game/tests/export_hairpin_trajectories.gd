extends "res://tests/test_star_checkpoint_consistency.gd"
## Offline before/after proof fixture, using the actual task-start rules22 source.
const ROOT := "res://../docs/evidence/hairpin-checkpoints-2026-10-18/"

func run() -> void:
	var corridor := GDScript.new()
	corridor.source_code = FileAccess.get_file_as_string(ROOT+"before/game/race/spline_gate_corridor.gd").replace("\r\n","\n").replace("class_name SplineGateCorridor\n","")
	check(corridor.reload() == OK,"frozen rules22 corridor loads")
	var previous := GDScript.new()
	previous.source_code = FileAccess.get_file_as_string(ROOT+"before/game/race/track_session.gd").replace("\r\n","\n").replace("class_name TrackSession\n","").replace("extends RefCounted\n","extends RefCounted\nvar frozen_corridor: GDScript\n").replace("SplineGateCorridor.select(self,track)","frozen_corridor.select(self,track)")
	check(previous.reload() == OK,"frozen rules22 session loads")
	var document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/star_spline_lap.json"))
	if "--restore-history" in OS.get_cmdline_user_args():
		restore_history(previous,corridor,document)
		return
	var rows: Array = []
	for reverse: bool in [false,true]:
		var doc: Dictionary = document.duplicate(true)
		if reverse: doc.start_line.heading = fposmod(float(doc.start_line.heading)+180.0,360.0)
		for cut: Vector2i in ([Vector2i(36,88),Vector2i(104,88),Vector2i(112,84),Vector2i(128,68),Vector2i(108,60)] if not reverse else [Vector2i(208,88),Vector2i(276,88),Vector2i(204,72),Vector2i(232,64)]):
			var track: NativeTrack = TrackCompiler.compile(doc)
			var old = previous.new(120,5); old.frozen_corridor = corridor; old._configure(track)
			var old_gates: Array = []
			for i: int in range(old._centers.size()): old_gates.append(coefficients(old._centers[i],old._directions[i],old._widths[i]))
			old_gates.append(coefficients(track.finish_center,track.finish_forward,Vector2.ONE*(track.finish_half_width+1.5)))
			var path := PackedVector2Array()
			for i: int in range(track.route.size()):
				if track.route_cumulative[i] < cut.x: path.append(track.route[i])
			path.append(track._race_route_point(cut.x)); path.append(track._race_route_point(cut.x+cut.y))
			for i: int in range(track.route.size()):
				if track.route_cumulative[i] > cut.x+cut.y: path.append(track.route[i])
			path.append(track.route[0]); path.append(track.route[1])
			var proof: Dictionary = trajectory(track,path,old)
			check(not proof.is_empty(),"rules22 accepted five laps of the reproduced cut %s/%s" % [reverse,cut])
			rows.append({"reverse":reverse,"begin":cut.x,"skipped":cut.y,"document":doc,"old_gates":old_gates,"trajectory":proof})
	var file := FileAccess.open(ROOT+"hairpin-trajectories.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(rows)); file.close()
	print("HAIRPIN_EXPORT: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func restore_history(previous: GDScript, corridor: GDScript, document: Dictionary) -> void:
	# Early exploratory runs of the old test wrote its old report location.
	# Recreate that report by actually executing the original rules22 again.
	var rows: Array = []
	for reverse: bool in [false,true]:
		var doc: Dictionary = document.duplicate(true)
		if reverse: doc.start_line.heading = fposmod(float(doc.start_line.heading)+180.0,360.0)
		var track: NativeTrack = TrackCompiler.compile(doc)
		for offset: float in [-7.0,-6.75,-6.5,-6.0,-5.5,-5.0,-4.5,-4.0,-3.0,0.0,3.0,4.0,4.5,5.0,5.5,6.0,6.5,6.75,7.0]:
			var session = previous.new(120,1); session.frozen_corridor = corridor
			var path: PackedVector2Array = edge_lane(track,offset)
			var notices_count: int = 0
			for i: int in range(path.size()-1):
				var steps: int = maxi(1,ceili(path[i].distance_to(path[i+1])/0.2))
				for step: int in range(steps):
					var a: Vector2 = path[i].lerp(path[i+1],float(step)/steps)
					var b: Vector2 = path[i].lerp(path[i+1],float(step+1)/steps)
					session.advance(track,a,b,track.nearest_route(b),false)
					if session.missed_checkpoint >= 0: notices_count += 1
			check(session.finished and notices_count == 0,"historical rules22 lane reproduces its original result")
			rows.append({"reverse":reverse,"offset":offset,"finished":session.finished,"notices":notices_count})
	if failures == 0:
		for path: String in [ROOT+"restored-rules22-lanes.json","res://../docs/evidence/checkpoint-forgiveness-2026-10-16/final-lanes.json"]:
			var file := FileAccess.open(path,FileAccess.WRITE); file.store_string(JSON.stringify(rows,"\t")); file.close()
	print("RESTORED_RULES22_HISTORY: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
