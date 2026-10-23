extends "res://tests/test_checkpoint_rules.gd"
## Published Knot: a diagonal underpass must not borrow the future bridge arm.
const EVIDENCE := "res://../docs/evidence/knot-checkpoints-2026-10-18/"
const FIXTURE := "res://tests/fixtures/knot.json"

func run() -> void:
	var document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	var track: NativeTrack = TrackCompiler.compile(document)
	var configured := TrackSession.new(120,1); configured._configure(track)
	var gate_fields: Array[String] = ["_centers","_directions","_widths","_road_widths","_progress","_layers"]
	var original: Dictionary = {}
	for field: String in gate_fields: original[field] = configured.get(field).duplicate()
	var point := Vector2(52.32339,-24.88533)
	configured.next_checkpoint = 3
	configured.advance(track,Vector2(52.40509,-24.91616),point,43,false,0)
	check(configured.next_checkpoint == 3 and configured.missed_checkpoint == -1,"actual forward tick590 keeps the fourth gate ahead quiet")
	check(configured.last_progress > 35.0 and configured.last_progress < 37.0,"notice projection stays on the ground approach instead of the future166m arm")
	check((configured._centers[3]-point).dot(configured._directions[3]) > 10.0,"reproduced warning gate is still more than10m ahead")
	check(track.elevated_at(point,43) and not configured._notice_layer_at(track,43,0.0),"branch continuity corrects the tangent-only bridge misclassification")
	var layer_bytes: int = configured._notice_route_layers.size()+configured._notice_layer_offsets.size()*4
	check(layer_bytes < 16*1024,"Knot's prepared notice layers fit within16KiB")
	track._race_gates.notice_version = 3
	track._race_gates.erase("_notice_route_layers"); track._race_gates.erase("_notice_layer_offsets")
	var rebuilt := TrackSession.new(120,1); rebuilt._configure(track)
	check(track._race_gates.notice_version == TrackSession.NOTICE_LAYOUT_VERSION,"old notice cache rebuilds before using its new fields")
	var cached := TrackSession.new(120,1); cached._configure(track)
	check(cached._notice_route_layers == rebuilt._notice_route_layers and cached._notice_layer_offsets == rebuilt._notice_layer_offsets,"fresh and retained sessions share the exact prepared layer states")
	for field: String in gate_fields:
		check(original[field] == rebuilt.get(field) and original[field] == cached.get(field),"cache refresh retains original gate acceptance: "+field)
	for reverse: bool in [false,true]:
		var directed: Dictionary = document.duplicate(true)
		if reverse: directed.start_line.heading = fposmod(float(directed.start_line.heading)+180.0,360.0)
		var oriented: NativeTrack = TrackCompiler.compile(directed)
		for offset: float in [-4.0,-2.0,0.0,2.0,4.0]:
			_walk(oriented,offset,reverse)
		_check_gate_recovery(oriented,reverse)
		if "--drive" in OS.get_cmdline_user_args(): _simulate(oriented,reverse)
	_sparse_bridge()
	if "--compare-before" in OS.get_cmdline_user_args(): _compare_before(track,gate_fields)
	print("KNOT_CHECKPOINT_TESTS: ",checks," checks, ",failures," failures; prepared_layer_bytes=",layer_bytes)
	quit(1 if failures else 0)

func lane_point(track: NativeTrack, progress: float, offset: float) -> Vector2:
	var tangent: Vector2 = (track._race_route_point(progress+0.5)-track._race_route_point(progress-0.5)).normalized()
	return track._race_route_point(progress)+tangent.orthogonal()*offset

func _walk(track: NativeTrack, offset: float, reverse: bool) -> void:
	var session := TrackSession.new(120,5); session._configure(track)
	var previous: Vector2 = lane_point(track,session._start_progress+0.1,offset)
	var hint: int = track.nearest_route(previous)
	var layer: bool = session._finish_elevated
	var warned: bool = false
	for lap: int in range(5):
		for step: int in range(1,ceili(track.route_length/0.2)+1):
			var point: Vector2 = lane_point(track,session._start_progress+minf(step*0.2,track.route_length)+0.1,offset)
			hint = track.nearest_route(point,hint)
			var previous_layer: int = int(layer)
			layer = CreatorBridges.layer_at(track.creator_bridges,point,layer)
			session.advance(track,previous,point,hint,layer,previous_layer)
			warned = warned or session.missed_checkpoint >= 0
			previous = point
		check(session.completed_laps == lap+1,"continuous Knot lane completes lap%d reverse=%s offset=%s" % [lap+1,reverse,offset])
	check(session.finished and not warned,"five-lap Knot lane stays quiet reverse=%s offset=%s" % [reverse,offset])

func _check_gate_recovery(track: NativeTrack, reverse: bool) -> void:
	var session := TrackSession.new(120,1); session._configure(track)
	for gate: int in range(session.checkpoint_count()):
		var center: Vector2 = session._centers[gate]
		var direction: Vector2 = session._directions[gate]
		var hint: int = session._route_hints[gate]
		session.next_checkpoint = gate; session.missed_checkpoint = -1
		session.advance(track,center-direction*0.05,center+direction*0.05,hint,not session._layers[gate])
		check(session.next_checkpoint == gate and session.missed_checkpoint == gate,"wrong-layer Knot gate still warns reverse=%s gate=%d" % [reverse,gate])
		session.advance(track,center-direction*0.05,center+direction*0.05,hint,session._layers[gate])
		check(session.next_checkpoint > gate and session.missed_checkpoint == -1,"Knot gate recovery clears the warning reverse=%s gate=%d" % [reverse,gate])

func _sparse_bridge() -> void:
	# Long fixture edges must retain deck entry even when both vertices are
	# outside the bridge; per-vertex booleans alone cannot represent that.
	var track := fixture()
	track.creator_bridges = [{"position":[10.0,0.0],"heading":0.0,"length":20.0,"width":8.0}]
	var session := TrackSession.new(120,1); session._configure(track)
	check(not session._notice_layer_at(track,0,0.1),"sparse road is ground before the ramp")
	check(session._notice_layer_at(track,0,0.5),"sparse road retains its deck between ground vertices")
	check(not session._notice_layer_at(track,0,0.9),"sparse road returns to ground after the ramp")

func _compare_before(track: NativeTrack, fields: Array[String]) -> void:
	var script := GDScript.new()
	script.source_code = FileAccess.get_file_as_string(EVIDENCE+"before/track_session.gd").replace("\r\n","\n").replace("class_name TrackSession\n","")
	check(script.reload() == OK,"saved task-start session loads")
	var old = script.new(120,1); old._configure(track); old.next_checkpoint = 3
	old.advance(track,Vector2(52.40509,-24.91616),Vector2(52.32339,-24.88533),43,false,0)
	check(old.missed_checkpoint == 3 and old.last_progress > 166.0,"saved original reproduces the future-gate warning")
	var current := TrackSession.new(120,1); current._configure(track)
	for field: String in fields: check(old.get(field) == current.get(field),"task-start gate acceptance remains exact: "+field)

func _simulate(track: NativeTrack, reverse: bool) -> void:
	var config: HandlingConfig = VehicleCatalog.config("compact")
	var sim := VehicleSimulation.new(config); sim.reset(track.spawn,track.spawn_heading)
	var driver := RouteDriver.new(); var session := TrackSession.new(120,5)
	var warned: bool = false
	var frames: Array = []
	for tick: int in range(60000):
		var frame: DriveFrame = driver.sample(sim.state,track,config); frames.append(frame.packed())
		var before: Vector2 = sim.state.position
		var previous_layer: int = int(sim.state.track_elevated)
		sim.step(frame,track)
		session.advance(track,before,sim.state.position,sim.state.route_index,sim.state.track_elevated,previous_layer)
		warned = warned or session.missed_checkpoint >= 0
		if session.finished: break
	check(session.finished and session.completed_laps == 5 and not warned,"physical Compact completes five quiet Knot laps reverse=%s" % reverse)
	var replay := VehicleSimulation.new(config); replay.reset(track.spawn,track.spawn_heading)
	var scored := TrackSession.new(120,5)
	for values: Array in JSON.parse_string(JSON.stringify(frames)):
		var input := DriveFrame.new(); input.steer = int(values[0]); input.throttle = int(values[1]); input.brake = int(values[2])
		var before: Vector2 = replay.state.position
		var previous_layer: int = int(replay.state.track_elevated)
		replay.step(input,track)
		scored.advance(track,before,replay.state.position,replay.state.route_index,replay.state.track_elevated,previous_layer)
	check(replay.state.snapshot() == sim.state.snapshot() and scored.lap_times == session.lap_times,"quantized Knot replay preserves exact state and laps reverse=%s" % reverse)
	print("KNOT_RACE reverse=",reverse," laps=",session.completed_laps," ticks=",session.elapsed_ticks," collisions=",sim.state.collision_count," warned=",warned)
