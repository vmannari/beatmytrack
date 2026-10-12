extends "res://backend/runner.gd"
const RaceProof = preload("res://backend/race_proof.gd")
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	call_deferred("test_all")

func expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func test_all() -> void:
	var fixture_path: String = ""
	var proof_path: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--fixture="): fixture_path = arg.trim_prefix("--fixture=")
		if arg.begins_with("--proof-output="): proof_path = arg.trim_prefix("--proof-output=")
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(fixture_path))
	var original: NativeTrack = TrackCompiler.compile(fixture.document)
	var fast: NativeTrack = VerificationTrack.frozen(original)
	var sim: VehicleSimulation = initial_simulation(original,"compact")
	var accelerated: VehicleSimulation = initial_simulation(fast,"compact")
	var session := TrackSession.new()
	var trace = RaceProof.new()
	session._configure(original)
	trace.capture(sim.state,session,true)
	var frame := DriveFrame.new()
	for values: Array in fixture.replay.frames:
		frame.steer = int(values[0]); frame.throttle = int(values[1]); frame.brake = int(values[2])
		frame.handbrake = int(values[3]) if values.size() >= 4 else 0
		var previous: Vector2 = sim.state.position
		var layer: int = int(sim.state.track_elevated)
		sim.step(frame,original)
		accelerated.step(frame,fast)
		expect(RewindHistory.properties(sim.state) == RewindHistory.properties(accelerated.state),"Immutable query acceleration changed canonical state at %d" % sim.state.tick)
		session.advance(original,previous,sim.state.position,sim.state.route_index,sim.state.track_elevated,layer)
		trace.capture(sim.state,session)
	var proof: Dictionary = trace.recording(session)
	expect(not proof.is_empty(),"Five-lap fixture must produce sparse evidence")
	var initial: VehicleSimulation = initial_simulation(fast,"compact")
	var descriptor: Dictionary = race_geometry(fast,fixture.document,manifest())
	expect(descriptor.gates.size() == session.checkpoint_count()+1,"Static geometry includes every gate and the finish")
	expect(descriptor.start == [initial.state.position.x,initial.state.position.y,int(initial.state.track_elevated)],"Static standing start matches the actual game start")
	# Tile boundaries, exterior cells, wet shores, variable radii and both layers.
	original.cells[10*original.grid_width+10] = 3
	original.cells[11*original.grid_width+11] = 6
	original.cells[15*original.grid_width+15] = 4
	original.deck_cells[16*original.grid_width+16] = 4
	fast = VerificationTrack.frozen(original)
	for y: int in range(-1,24):
		for x: int in range(-1,24):
			var point := Vector2((x+0.51)*original.cell_size-original.half_extent.x,original.half_extent.y-(y+0.49)*original.cell_size)
			expect(original.water_depth(point) == fast.water_depth(point),"Dry/wet shoreline acceleration must remain exact")
			for radius: float in [0.1,0.88,2.5]:
				for elevated: bool in [false,true]:
					expect(original._contact(point,radius,elevated) == fast._contact(point,radius,elevated),"Collision occupancy shortcut must remain exact")
	for hint: int in range(original.route.size()):
		expect(original.nearest_route(original.route[hint],hint) == fast.nearest_route(original.route[hint],hint),"Route tie order must remain exact")
	if not proof_path.is_empty():
		var file := FileAccess.open(proof_path,FileAccess.WRITE)
		file.store_string(JSON.stringify(proof)); file.close()
	print("LIGHTWEIGHT_VERIFIER: %d checks, %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)
