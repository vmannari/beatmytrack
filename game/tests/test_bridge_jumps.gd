extends SceneTree
const FLIGHT = preload("res://vehicle/bridge_flight.gd")
var checks: int = 0
var failures: int = 0
var measurements: Array = []
var evidence_dir: String = "res://../docs/evidence/bridge-jumps-2026-10-16"

func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--evidence-dir="): evidence_dir = argument.trim_prefix("--evidence-dir=")
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ",label)

func make_track(length: float = 32.0, angle: float = 0.0) -> NativeTrack:
	var doc: Dictionary = TrackDocument.create_blank()
	doc.pieces = [RoadPieces.create("bridge",Vector2(-length*0.5,0).rotated(deg_to_rad(angle)),angle,12)]
	doc.pieces[0].length = length
	doc.paint = [{"surface":0,"width":40.0,"shape":"square","points":[[-20,0],[20,0]]}]
	print("FIXTURE_VALIDATE: ",TrackDocument.validate(doc))
	return TrackCompiler.compile(doc)

func run() -> void:
	var track: NativeTrack = make_track()
	for id: String in VehicleCatalog.IDS:
		for reverse: bool in [false,true]:
			for speed: float in [3.0,12.0,24.0,36.0]:
				crossing(track,id,reverse,speed)
		crossing(track,id,true,24.0,true)
	edges()
	underpass(track)
	await scene_checks(track)
	var report := {"checks":checks,"failures":failures,"physics":VehicleSimulation.PHYSICS_VERSION,"crossings":measurements}
	var file := FileAccess.open(evidence_dir+"/measurements.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	print("BRIDGE_JUMP_TESTS: %d checks, %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)

func edges() -> void:
	for length: float in [24.0,48.0]:
		for angle: float in [0.0,37.0,90.0]:
			var track: NativeTrack = make_track(length,angle)
			var axis: Vector2 = Vector2.RIGHT.rotated(deg_to_rad(angle))
			for direction: float in [-1.0,1.0]:
				var sim := VehicleSimulation.new(VehicleCatalog.config("compact"))
				sim.reset(axis*(-length*0.5-3.0)*direction,atan2(axis.x*direction,axis.y*direction))
				sim.state.velocity = axis*36.0*direction
				sim.state.route_index = track.nearest_route(sim.state.position)
				var peak: float = 0.0
				for tick: int in range(240):
					sim.step(DriveFrame.new(),track)
					peak = maxf(peak,sim.state.jump_height)
					if sim.state.position.dot(axis)*direction > length*0.5+3.0: break
				check(peak > 0.04 and peak < 0.35 and sim.state.jump_height == 0.0,"short/long/oblique bridge has a visible bounded hop")
				check(sim.state.collision_count == 0,"oblique bridge retains clear driving lane")
				print("EDGE length=",length," angle=",angle," direction=",direction," peak=",peak)

func crossing(track: NativeTrack, id: String, reverse: bool, speed: float, backing: bool = false) -> void:
	var config: HandlingConfig = VehicleCatalog.config(id)
	# Isolate vertical support at fixed coast speed, using each real axle size.
	config.rolling_resistance = 0.0
	config.drag = 0.0
	config.maximum_speed = 60.0
	var direction: float = -1.0 if reverse else 1.0
	var sim := VehicleSimulation.new(config)
	var heading: float = PI*0.5 if backing else PI*0.5*direction
	sim.reset(Vector2(-20*direction,0),heading)
	sim.state.velocity = Vector2(speed*direction,0)
	sim.state.route_index = track.nearest_route(sim.state.position)
	var frames: Array = []
	var states: Array = []
	var branch: Dictionary = {}
	var branch_tick: int = 0
	var air_ticks: int = 0
	var landings: int = 0
	var peak: float = 0.0
	var arc_error: float = 0.0
	var clearance: float = INF
	for tick: int in range(ceili(45.0/speed*120.0)+180):
		var frame := DriveFrame.new()
		var before: VehicleState = sim.state
		var was_airborne: bool = before.bridge_airborne
		var old_velocity: Vector2 = before.velocity
		var old_vertical: float = before.jump_velocity
		var old_gravity: float = before.bridge_gravity
		var old_height: float = FLIGHT.support(sim.bridge_elevation,before.position,before.heading,before.route_index,before.track_elevated,config.wheelbase)+before.jump_height if sim.bridge_elevation != null else 0.0
		sim.step(frame,track)
		var floor_height: float = FLIGHT.support(sim.bridge_elevation,sim.state.position,sim.state.heading,sim.state.route_index,sim.state.track_elevated,config.wheelbase)
		clearance = minf(clearance,sim.state.jump_height)
		if was_airborne and sim.state.bridge_airborne:
			arc_error = maxf(arc_error,absf(floor_height+sim.state.jump_height-(old_height+(old_vertical-old_gravity/120.0)/120.0)))
			if tick % 30 == 0: check(sim.state.velocity == old_velocity,"air pedals and steering supply no traction")
		if was_airborne and not sim.state.bridge_airborne: landings += 1
		if sim.state.bridge_airborne:
			air_ticks += 1
			peak = maxf(peak,sim.state.jump_height)
			if branch.is_empty() and air_ticks > 8:
				branch = RewindHistory.properties(sim.state)
				branch_tick = tick+1
		frames.append([frame.throttle,frame.brake,frame.steer,frame.handbrake])
		states.append(sim.state.snapshot())
		if sim.state.position.x*direction > 24.0 and not sim.state.bridge_airborne: break
	var label: String = "%s reverse=%s speed=%s backing=%s" % [id,reverse,speed,backing]
	check(peak == 0.0 if speed == 3.0 else peak > 0.01,label+" slow planted / fast release")
	check(clearance >= 0.0 and arc_error < 0.000001,label+" ballistic world height and solid landing")
	check(not sim.state.bridge_airborne and sim.state.jump_height == 0.0,label+" settles on the road")
	check(sim.state.collision_count == 0,label+" clear deck is collision free")
	check(peak < 0.35,label+" visible short hop stays below 35 cm")
	var replay := VehicleSimulation.new(config)
	replay.reset(Vector2(-20*direction,0),heading)
	replay.state.velocity = Vector2(speed*direction,0)
	replay.state.route_index = track.nearest_route(replay.state.position)
	var decoded: Array = JSON.parse_string(JSON.stringify(frames))
	var exact: bool = true
	for tick: int in range(decoded.size()):
		replay.step(input_frame(decoded[tick]),track)
		if replay.state.snapshot() != states[tick]: exact = false; break
	check(exact,label+" JSON input replay exact every tick")
	if not branch.is_empty():
		var pedal := VehicleSimulation.new(config)
		var neutral := VehicleSimulation.new(config)
		RewindHistory.restore(pedal.state,branch)
		RewindHistory.restore(neutral.state,branch)
		pedal.step(input_frame([255,255,127,255]),track)
		neutral.step(DriveFrame.new(),track)
		check(pedal.state.position == neutral.state.position and pedal.state.velocity == neutral.state.velocity and pedal.state.heading == neutral.state.heading,"air controls supply no traction or steering force")
		RewindHistory.restore(replay.state,branch)
		for tick: int in range(branch_tick,decoded.size()): replay.step(input_frame(decoded[tick]),track)
		check(replay.state.snapshot() == sim.state.snapshot(),label+" midflight rewind exact")
		replay.reset(Vector2.ZERO)
		check(not replay.state.bridge_airborne and replay.state.jump_height == 0.0,label+" reset clears flight")
	measurements.append({"car":id,"reverse":reverse,"backing":backing,"speed":speed,"peak_gap":peak,"air_ticks":air_ticks,"landings":landings,"arc_error":arc_error})
	print(label," peak=",peak," airtime=",air_ticks/120.0," landings=",landings)

func input_frame(row: Array) -> DriveFrame:
	var frame := DriveFrame.new()
	frame.throttle = int(row[0]); frame.brake = int(row[1]); frame.steer = int(row[2]); frame.handbrake = int(row[3])
	return frame

func underpass(track: NativeTrack) -> void:
	var sim := VehicleSimulation.new(VehicleCatalog.config("compact"))
	sim.reset(Vector2(0,-9),0.0)
	sim.state.velocity = Vector2(0,24)
	var air: bool = false
	var upper: bool = false
	for tick: int in range(90):
		sim.step(DriveFrame.new(),track)
		air = air or sim.state.bridge_airborne
		upper = upper or sim.state.track_elevated
	check(not air and not upper and sim.state.collision_count == 0,"underpass remains ground with no false launch")
	var state := VehicleState.new()
	state.velocity = Vector2(-20,0); state.heading = PI*0.5; state.jump_velocity = 3.0
	check(FLIGHT.pitch(state) < 0.0,"reverse takeoff lifts the travel-facing end")

func scene_checks(track: NativeTrack) -> void:
	var game: Node = load("res://core/game.tscn").instantiate()
	game.initial_track = track
	root.size = Vector2i(1280,720)
	root.add_child(game)
	game.set_physics_process(false)
	game.countdown_ticks = 0
	game.sim.reset(Vector2(-20,0),PI*0.5)
	game.sim.state.velocity = Vector2(24,0)
	game.sim.state.route_index = track.nearest_route(game.sim.state.position)
	var captured: bool = false
	var seen: bool = false
	var peak: float = 0.0
	var landing_compression: float = 0.0
	for tick: int in range(400):
		game.sim.step(DriveFrame.new(),track)
		game.previous_position = game.sim.state.position
		game.previous_heading = game.sim.state.heading
		game._process(1.0/120.0)
		seen = seen or game.sim.state.bridge_airborne
		peak = maxf(peak,game.sim.state.jump_height)
		if seen and not game.sim.state.bridge_airborne: landing_compression = minf(landing_compression,game.car.suspension_speed.x)
		if not captured and game.sim.state.jump_height > 0.18:
			var before: Array = game.sim.state.snapshot()
			var pose: Transform3D = game.car.transform
			game._process(0.0)
			check(game.sim.state.snapshot() == before and game.car.transform == pose,"duplicate draw freezes canonical flight and displayed pose")
			if DisplayServer.get_name() != "headless":
				await process_frame
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png(evidence_dir+"/jump-%s.png" % RenderingServer.get_current_rendering_method())
			captured = true
	check(game.sim.bridge_elevation == game.bridge_presentation,"race shares prepared immutable support")
	check(seen and peak > 0.10 and peak < 0.35 and landing_compression < -0.05,"real game visibly hops and compresses on landing")
	check(game.car.ramp_lift == 0.0,"real game has no extra cosmetic flight")
	game.queue_free()
	await process_frame
