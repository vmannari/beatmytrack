extends "res://backend/runner.gd"
## Offline five-lap canonical fixture, verified independently by the worker.
func run() -> void:
	output_path = "res://../docs/evidence/hovercraft-2026-10-28/five-lap-replay.json"
	var doc: Dictionary = TrackDocument.create_blank()
	doc.id = "hovercraft_oval"
	doc.name = "Hovercraft test oval"
	doc["creator"] = "Local tests"
	var position := Vector2(-28,-18)
	var heading: float = 0.0
	for kind: String in ["straight","hairpin","straight","hairpin"]:
		var piece: Dictionary = RoadPieces.create(kind,position,heading)
		piece.length = 56.0 if kind == "straight" else 0.0
		piece.radius = 18.0
		doc.pieces.append(piece)
		var pose: Dictionary = RoadPieces.end_pose(piece)
		position = pose.position
		heading = pose.heading
	var automatic: Dictionary = RoadPieces.route_from_pieces(doc)
	if not automatic.ok: respond({},str(automatic.errors)); return
	doc = automatic.document
	doc["start_line"] = {"position":[0,-18],"heading":0}
	var compiled: Dictionary = compile_track(doc)
	if compiled.has("error"): respond({},compiled.error); return
	var track: NativeTrack = compiled.track
	var sim: VehicleSimulation = initial_simulation(track,"hovercraft")
	var driver := RouteDriver.new()
	var session := TrackSession.new(VehicleSimulation.TICK_RATE,RaceRules.LAPS)
	var proof := preload("res://backend/race_proof.gd").new()
	proof.capture(sim.state,session,true)
	var frames: Array = []
	for tick: int in range(72000):
		var frame: DriveFrame = driver.sample(sim.state,track,sim.config)
		frames.append(frame.packed())
		var before: Vector2 = sim.state.position
		var previous_layer: int = int(sim.state.track_elevated)
		sim.step(frame,track)
		session.advance(track,before,sim.state.position,sim.state.route_index,sim.state.track_elevated,previous_layer)
		proof.capture(sim.state,session)
		if session.finished: break
	print("HOVERCRAFT_LAPS: ",session.completed_laps," ticks=",session.elapsed_ticks," contacts=",sim.state.collision_count)
	if not session.finished: respond({},"Hovercraft fixture did not finish"); return
	respond({"document":doc,"replay":{"schema":REPLAY_SCHEMA,"frames":frames,"race_proof":proof.recording(session)},"vehicle_id":"hovercraft","time_ticks":session.elapsed_ticks,"contacts":sim.state.collision_count})
