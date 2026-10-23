extends "res://tests/test_checkpoint_rules.gd"
const TASK_START = preload("res://../docs/evidence/knot-checkpoints-2026-10-18/before/session_without_class.gd")
## Retained-track reproductions: notice timing, legal approaches and unchanged gates.
const EVIDENCE := "res://../docs/evidence/checkpoint-notice-2026-10-17/"
var report: Array = []
var previous: GDScript
var previous_corridor: GDScript

func before_session(track: NativeTrack):
	var session = previous.new(120,1)
	session._notice_test_corridor = previous_corridor
	session._configure(track)
	return session

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: "+message)

func walk(session, track: NativeTrack, path: PackedVector2Array, state: Dictionary) -> void:
	for i: int in range(path.size()-1):
		var steps: int = maxi(1,ceili(path[i].distance_to(path[i+1])/0.2))
		for step: int in range(steps):
			var a: Vector2 = path[i].lerp(path[i+1],float(step)/steps)
			var b: Vector2 = path[i].lerp(path[i+1],float(step+1)/steps)
			state.hint = track.nearest_route(b,int(state.hint))
			var old_layer: int = int(state.layer)
			state.layer = CreatorBridges.layer_at(track.creator_bridges,b,bool(state.layer)) if not track.creator_bridges.is_empty() else track.elevated_at(b,int(state.hint))
			session.advance(track,a,b,int(state.hint),bool(state.layer),old_layer)
			state.distance += a.distance_to(b)
			if session.missed_checkpoint >= 0 and not state.has("notice"):
				state.notice = {"distance":state.distance,"gate":session.missed_checkpoint,"point":[b.x,b.y],"progress":session.last_progress,"offset":session._notice_offset(track,session.last_progress) if session.next_checkpoint < session.checkpoint_count() else 0.0}

func path_between(track: NativeTrack, begin: float, end: float) -> PackedVector2Array:
	var start: float = track.route_progress(track.finish_center)
	var path := PackedVector2Array([track._race_route_point(start+begin)])
	var distances: Array[float] = []
	for i: int in range(track.route.size()):
		var distance: float = fposmod(track.route_cumulative[i]-start,track.route_length)
		if distance > begin and distance < end: distances.append(distance)
	distances.sort()
	for distance: float in distances: path.append(track._race_route_point(start+distance))
	path.append(track._race_route_point(start+end))
	return path

func run() -> void:
	var baseline: bool = "--baseline" in OS.get_cmdline_user_args()
	var entries: Array = [
		{"name":"Star","path":"res://tests/fixtures/star_spline_lap.json"},
		{"name":"Star reverse","path":"res://tests/fixtures/star_spline_lap.json","reverse":true},
		{"name":"Silmukka fixture","path":"res://tests/fixtures/silmukka.json"},
		{"name":"Dust cloud fixture","path":"res://tests/fixtures/dust_cloud.json"},
		{"name":"Over and under fixture","path":"res://tests/fixtures/over_and_under.json"}]
	if "--catalog" in OS.get_cmdline_user_args():
		var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://../build/catalog-road-review-2026-10-16/manifest.json"))
		entries.append_array(manifest.entries)
	previous_corridor = GDScript.new()
	previous_corridor.source_code = FileAccess.get_file_as_string(EVIDENCE+"before/game/race/spline_gate_corridor.gd").replace("\r\n","\n").replace("class_name SplineGateCorridor\n","")
	check(previous_corridor.reload() == OK,"task-start corridor loads")
	previous = GDScript.new()
	previous.source_code = FileAccess.get_file_as_string(EVIDENCE+"before/game/race/track_session.gd").replace("\r\n","\n").replace("class_name TrackSession\n","").replace("extends RefCounted\n","extends RefCounted\nvar _notice_test_corridor: GDScript\n").replace("SplineGateCorridor.select(self,track)","_notice_test_corridor.select(self,track)")
	check(previous.reload() == OK,"task-start session loads for exact gate comparison")
	for entry: Dictionary in entries:
		var doc: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(entry.path))
		if entry.get("reverse",false): doc.start_line.heading = fposmod(float(doc.start_line.heading)+180.0,360.0)
		var track: NativeTrack = TrackCompiler.compile(doc)
		var configured = before_session(track) if baseline else TASK_START.new(120,1)
		configured._configure(track)
		var prepared: Dictionary = track._race_gates
		track._race_gates = {}
		var old = before_session(track)
		track._race_gates = prepared
		if old._centers == configured._centers:
			for field: String in ["_centers","_directions","_widths","_road_widths","_progress","_layers"]:
				check(old.get(field) == configured.get(field),"unchanged ordinary gate acceptance %s/%s" % [entry.name,field])
		else:
			check(RaceRules.KEY == "standing-5-road-gates-v23" and configured._spline_corridor,"hairpin geometry changes use a separate rules version: "+str(entry.name))
		if not baseline:
			track._race_gates.erase("notice_version")
			var fresh := TASK_START.new(120,1); fresh._configure(track)
			check(track._race_gates.notice_version == 3 and fresh._centers == configured._centers,"retained rules22 cache rebuilds stale notices without changing gates: "+str(entry.name))
		var old_ahead_notices: int = 0
		var ahead_examples: Array = []
		for gate: int in range(1,configured.checkpoint_count()-3):
			var position: float = configured._start_progress+configured._progress[gate]-3.0
			if configured._progress[gate]-configured._progress[gate-1] < 4.0: continue
			var a: Vector2 = track._race_route_point(position-0.1)
			var b: Vector2 = track._race_route_point(position)
			if (b-configured._centers[gate]).dot(configured._directions[gate]) >= -0.1: continue
			var stale_hint: int = configured._route_hints[gate+3]
			var earlier = before_session(track); earlier.next_checkpoint = gate
			earlier.advance(track,a,b,stale_hint,configured._layers[gate])
			if earlier.missed_checkpoint >= 0:
				old_ahead_notices += 1
				ahead_examples.append({"gate":gate,"hint":stale_hint,"point":[b.x,b.y],"position":position})
			var recovered := TASK_START.new(120,1); recovered._configure(track); recovered.next_checkpoint = gate
			recovered.advance(track,a,b,stale_hint,configured._layers[gate])
			check(recovered.missed_checkpoint == -1,"stale future-branch hint cannot mark the gate ahead missed %s/%d" % [entry.name,gate])
		var clean = before_session(track) if baseline else TASK_START.new(120,1)
		var clean_state: Dictionary = {"hint":track.nearest_route(track.finish_center),"layer":configured._finish_elevated,"distance":0.0}
		var full: PackedVector2Array = path_between(track,0.1,track.route_length-0.001)
		full.append(track._race_route_point(configured._start_progress+0.2))
		walk(clean,track,full,clean_state)
		check(clean.finished and not clean_state.has("notice"),"full centreline has no premature warning: "+str(entry.name))
		var maximum: float = 0.0
		for reach: float in configured._notice_reach: maximum = maxf(maximum,reach)
		print("NOTICE_TRACK ",entry.name," gates=",configured.checkpoint_count()," max_reach=",maximum)
		var worst: Dictionary = {"delay":-1.0}
		var blocked: int = 0
		var wrong_layer_rejoins: int = 0
		var silent_cuts: int = 0
		for gate: int in range(configured.checkpoint_count()):
			var begin: float = configured._progress[gate]-12.0
			var end: float = minf(track.route_length-1.0,begin+48.0)
			if begin < 1.0 or end-begin < 40.0: continue
			var a: Vector2 = track._race_route_point(configured._start_progress+begin)
			var b: Vector2 = track._race_route_point(configured._start_progress+end)
			if a.distance_to(b) > end-begin-8.0: continue
			var session = before_session(track) if baseline else TASK_START.new(120,1)
			var state: Dictionary = {"hint":track.nearest_route(track.finish_center),"layer":configured._finish_elevated,"distance":0.0}
			walk(session,track,path_between(track,0.1,begin),state)
			if state.has("notice"): continue
			walk(session,track,PackedVector2Array([a,b]),state)
			var rejoin: float = state.distance
			var end_index: int = 0
			var wrapped: float = fposmod(configured._start_progress+end,track.route_length)
			while end_index+1 < track.route.size() and track.route_cumulative[end_index+1] <= wrapped: end_index += 1
			var correct_rejoin_layer: bool = bool(state.layer) == track.elevated_at(b,end_index)
			var remainder: PackedVector2Array = path_between(track,end,track.route_length-0.001)
			remainder.append(track._race_route_point(configured._start_progress+0.2))
			walk(session,track,remainder,state)
			if session.finished: continue
			blocked += 1
			if not correct_rejoin_layer: wrong_layer_rejoins += 1
			if not baseline: check(state.has("notice"),"blocked bypass has a notice %s/%d" % [entry.name,gate])
			if not state.has("notice"):
				silent_cuts += 1
				continue
			var delay: float = maxf(0.0,float(state.notice.distance)-rejoin)
			# At a crossing, stay quiet until the car has left the required
			# road's recovery corridor. Never trade a prompt notice for a
			# false miss on the road underneath or the earlier ground arm.
			var maximum_delay: float = 4.0 if configured._spline_corridor else 8.0
			if not baseline and correct_rejoin_layer: check(delay <= maximum_delay,"shortcut notice within %.0fm of road reentry %s/%d: %.2fm" % [maximum_delay,entry.name,gate,delay])
			if correct_rejoin_layer and delay > float(worst.delay): worst = {"delay":delay,"begin":begin,"end":end,"notice":state.notice,"rejoin_distance":rejoin}
		report.append({"name":entry.name,"maximum_reach":maximum,"blocked_cuts":blocked,"wrong_layer_rejoins":wrong_layer_rejoins,"silent_cuts":silent_cuts,"old_ahead_notices":old_ahead_notices,"ahead_examples":ahead_examples,"worst":worst,"prepared_bytes":var_to_bytes(track._race_gates).size()})
		print("NOTICE_WORST ",entry.name," ahead_false_before=",old_ahead_notices," ",worst)
	var scope: String = "catalog" if "--catalog" in OS.get_cmdline_user_args() else "fixtures"
	var file := FileAccess.open("res://../docs/evidence/hairpin-checkpoints-2026-10-18/"+("baseline" if baseline else "final")+"-"+scope+"-latency.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t")); file.close()
	print("CHECKPOINT_NOTICE_LATENCY: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
