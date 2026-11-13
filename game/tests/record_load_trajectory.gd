extends "res://backend/runner.gd"
## Offline load-lab fixture; never used by race acceptance or shipping clients.

func _initialize() -> void: record.call_deferred()

func record() -> void:
	var source: String = ""
	var target: String = ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--fixture="): source = argument.trim_prefix("--fixture=")
		if argument.begins_with("--output="): target = argument.trim_prefix("--output=")
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(source))
	var compiled: Dictionary = compile_track(fixture.document)
	if compiled.has("error"):
		push_error(str(compiled.error)); quit(1); return
	var track: NativeTrack = compiled.track
	var simulation: VehicleSimulation = initial_simulation(track,"compact")
	var session := TrackSession.new()
	session._configure(track)
	var trace = preload("res://backend/race_proof.gd").new()
	trace.capture(simulation.state,session,true)
	for values: Array in fixture.replay.frames:
		var frame := DriveFrame.new()
		frame.steer = int(values[0]); frame.throttle = int(values[1]); frame.brake = int(values[2])
		frame.handbrake = int(values[3]) if values.size() >= 4 else 0
		var previous: Vector2 = simulation.state.position
		var layer: int = int(simulation.state.track_elevated)
		simulation.step(frame,track)
		session.advance(track,previous,simulation.state.position,simulation.state.route_index,simulation.state.track_elevated,layer)
		trace.capture(simulation.state,session)
		if session.finished: break
	var proof: Dictionary = trace.recording(session)
	if proof.is_empty():
		push_error("Recorded load fixture did not finish five laps"); quit(1); return
	var samples: Array = []
	for sample: Array in proof.samples: samples.append([sample[0],sample[1],sample[2],sample[6]])
	var replay: Dictionary = {"schema":"bmt-trajectory-v1","input_count":simulation.state.tick,
		"race_proof":{"schema":"bmt-race-path-v1","samples":samples}}
	var result: Dictionary = {"document":fixture.document,"replay":replay,"vehicle_id":"compact",
		"expected_manifest":compiled.manifest,"time_ticks":simulation.state.tick,
		"geometry":race_geometry(track,fixture.document,compiled.manifest)}
	var file := FileAccess.open(target,FileAccess.WRITE)
	if file == null: quit(1); return
	file.store_string(JSON.stringify(result)); file.close()
	print("LOAD_TRAJECTORY: %d ticks, %d samples" % [simulation.state.tick,samples.size()])
	quit(0)
