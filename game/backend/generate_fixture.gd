extends "res://backend/runner.gd"
## Offline test tool only; the service never exposes this operation.
func run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output_path = arg.trim_prefix("--output=")
	if output_path.is_empty(): quit(3); return
	var doc: Dictionary = TrackDocument.create_blank()
	doc.id = "backend_oval"
	doc.name = "Backend test oval"
	doc["creator"] = "Backend tests"
	var position := Vector2(-28,-18)
	var heading: float = 0.0
	for kind: String in ["straight","hairpin","straight","hairpin"]:
		var piece: Dictionary = RoadPieces.create(kind,position,heading)
		piece.length = 56.0 if kind == "straight" else 0.0
		piece.radius = 18.0
		doc.pieces.append(piece)
		var pose: Dictionary = RoadPieces.end_pose(piece)
		position = pose.position; heading = pose.heading
	var automatic: Dictionary = RoadPieces.route_from_pieces(doc)
	if not automatic.ok: respond({},str(automatic.errors)); return
	doc = automatic.document
	doc["start_line"] = {"position":[0,-18],"heading":0}
	var compiled: Dictionary = compile_track(doc)
	if compiled.has("error"): respond({},compiled.error); return
	var track: NativeTrack = compiled.track
	var sim: VehicleSimulation = initial_simulation(track,"compact")
	var driver := RouteDriver.new()
	var session := TrackSession.new(VehicleSimulation.TICK_RATE,RaceRules.LAPS)
	var frames: Array = []
	for tick: int in range(32000):
		var frame: DriveFrame = driver.sample(sim.state,track,sim.config)
		frames.append(frame.packed())
		var before: Vector2 = sim.state.position
		sim.step(frame,track)
		session.advance(track,before,sim.state.position,sim.state.route_index)
		if session.finished: break
	if not session.finished: respond({},"Fixture did not finish"); return
	respond({"document":doc,"replay":{"schema":REPLAY_SCHEMA,"frames":frames},"vehicle_id":"compact","time_ticks":session.elapsed_ticks})
