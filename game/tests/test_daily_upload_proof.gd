extends "res://backend/runner.gd"
## Real canonical paths for the two Daily finish boundaries, without network or saves.

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://../backend/tests/fixtures/verified_oval.json"))
	var document: Dictionary = fixture.document
	var track: NativeTrack = TrackCompiler.compile(document)
	var output: String = OS.get_environment("BMT_DAILY_PROOF_OUTPUT")
	var result: Dictionary = {"geometry":race_geometry(track,document,manifest()),"attempts":[]}
	for count: int in [2,10]:
		var simulation: VehicleSimulation = initial_simulation(track,"compact")
		var session := TrackSession.new(120,count)
		var trace = preload("res://backend/race_proof.gd").new()
		var driver := RouteDriver.new()
		trace.capture(simulation.state,session,true)
		for _tick: int in range(60000):
			var frame: DriveFrame = driver.sample(simulation.state,track,simulation.config)
			var previous: Vector2 = simulation.state.position
			var layer: int = int(simulation.state.track_elevated)
			simulation.step(frame,track)
			session.advance(track,previous,simulation.state.position,simulation.state.route_index,simulation.state.track_elevated,layer)
			trace.capture(simulation.state,session)
			if session.finished: break
		if not session.finished:
			push_error("Daily proof did not finish %d laps" % count)
			quit(1)
			return
		result.attempts.append({"count":count,"ticks":session.elapsed_ticks,"proof":trace.recording(session),
			"lap_ticks":preload("res://backend/backend_client.gd")._lap_tick_summary(session.lap_times,session.elapsed_ticks)})
	var file := FileAccess.open(output,FileAccess.WRITE)
	if file == null:
		push_error("Daily proof output unavailable")
		quit(1)
		return
	file.store_string(JSON.stringify(result))
	file.close()
	print("DAILY_UPLOAD_PROOF: two canonical attempts recorded (2 and 10 laps)")
	quit(0)
