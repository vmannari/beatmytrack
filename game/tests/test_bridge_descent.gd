extends "res://tests/test_bridge_jumps.gd"
const BEFORE = preload("res://tests/fixtures/bridge_descent_simulation_065.gd")
const OUT: String = "res://../docs/evidence/bridge-descent-2026-10-17"
var descents: Array = []

class ObservedAudio extends VehicleAudio:
	var emitted: Array[Dictionary] = []
	func _event(clip: String, amplitude: float, pitch: float = 1.0, _debris: bool = false) -> void:
		emitted.append({"clip":clip,"gain":amplitude,"pitch":pitch})

func run() -> void:
	if "--probe-pause" in OS.get_cmdline_user_args():
		probe_pause()
		quit(0 if failures == 0 else 1)
		return
	var track: NativeTrack = make_track()
	for id: String in VehicleCatalog.IDS:
		for direction: float in [-1.0,1.0]:
			for speed: float in [3.0,12.0,24.0,36.0]: descend(track,id,direction,speed)
			entry_unchanged(track,id,direction)
	for length: float in [24.0,48.0]:
		for angle: float in [0.0,37.0,90.0]:
			var oriented: NativeTrack = make_track(length,angle)
			for direction: float in [-1.0,1.0]:
				for speed: float in [24.0,36.0]: descend(oriented,"compact",direction,speed)
	underpass(track)
	hazard_after_descent()
	await native_scene(track)
	var report := {"checks":checks,"failures":failures,"physics":VehicleSimulation.PHYSICS_VERSION,"descents":descents}
	FileAccess.open(OUT+"/measurements-%s.json" % RenderingServer.get_current_rendering_method(),FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("BRIDGE_DESCENT_TESTS: %d checks, %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)

func probe_pause() -> void:
	var original := GDScript.new()
	original.source_code = FileAccess.get_file_as_string(OUT+"/before/game__vehicle__vehicle_audio.gd").replace("\r\n","\n").replace("class_name VehicleAudio\n","")
	check(original.reload() == OK,"original audio compiles for isolated pause comparison")
	var results: Array = []
	var track: NativeTrack = make_track()
	for audio in [original.new(),VehicleAudio.new()]:
		root.add_child(audio); audio.configure("compact",VehicleCatalog.config("compact"))
		var state := VehicleState.new(); state.velocity = Vector2(6,20)
		var frame: DriveFrame = DriveFrame.sample(0,1,0)
		audio.present(state,frame,track,0.1,false)
		state.jump_height = 1.0; audio.present(state,frame,track,0.1,false)
		state.jump_height = 0.0; audio.present(state,frame,track,0.1,true)
		audio.collision(Vector2(15,0)); audio.present(state,frame,track,0.1,true)
		results.append(audio.engine_load[0].stream_paused)
		audio.free()
	check(results[0] == results[1],"headless pause observer matches original audio")
	print("PAUSE_BASELINE before=",results[0]," after=",results[1]," checks=",checks," failures=",failures)

func hazard_after_descent() -> void:
	var state := VehicleState.new()
	state.position = Vector2(3.1,0); state.velocity = Vector2(14,0)
	state.bridge_descending = true; state.bridge_landing_speed = 5.0
	TrackHazards.launch(state,Vector2(2.9,0),[{"kind":"jump","position":[0,0],"rotation":0}])
	check(state.jump_height > 0.0 and not state.bridge_descending and state.bridge_landing_speed == 0.0,"later jump hazard restores its original landing feedback")

func descend(track: NativeTrack, id: String, direction: float, speed: float) -> void:
	var axis: Vector2 = Vector2.RIGHT.rotated(deg_to_rad(float(track.creator_bridges[0].heading)))
	var config: HandlingConfig = VehicleCatalog.config(id)
	config.rolling_resistance = 0.0; config.drag = 0.0; config.maximum_speed = 60.0
	var sim := VehicleSimulation.new(config)
	var baseline = BEFORE.new(config)
	for value in [sim,baseline]:
		value.reset(Vector2.ZERO,atan2(axis.x*direction,axis.y*direction))
		value.state.velocity = axis*speed*direction
		value.state.track_elevated = true
		value.state.route_index = track.nearest_route(value.state.position)
		value.state.jump_cooldown = 24 # Entry must not hide a separate short-span exit.
	var snapshots: Array = []
	var branch: Dictionary = {}
	var branch_tick: int = -1
	var peak: float = 0.0
	var old_peak: float = 0.0
	var air_ticks: int = 0
	var releases: int = 0
	var arc_error: float = 0.0
	var upward_impulse: bool = false
	for tick: int in range(ceili((float(track.creator_bridges[0].length)*0.5+5.0)/speed*120.0)+120):
		var was_air: bool = sim.state.bridge_airborne
		var height: float = FLIGHT.support(sim.bridge_elevation,sim.state.position,sim.state.heading,sim.state.route_index,sim.state.track_elevated,config.wheelbase)+sim.state.jump_height if sim.bridge_elevation != null else 0.0
		var vertical: float = sim.state.jump_velocity
		var gravity: float = sim.state.bridge_gravity
		sim.step(DriveFrame.new(),track)
		baseline.step(DriveFrame.new(),track)
		old_peak = maxf(old_peak,baseline.state.jump_height)
		peak = maxf(peak,sim.state.jump_height)
		if not was_air and sim.state.bridge_airborne:
			releases += 1
			upward_impulse = upward_impulse or sim.state.jump_velocity > 0.0
		if sim.state.bridge_airborne:
			air_ticks += 1
			if was_air:
				var current: float = FLIGHT.support(sim.bridge_elevation,sim.state.position,sim.state.heading,sim.state.route_index,sim.state.track_elevated,config.wheelbase)+sim.state.jump_height
				arc_error = maxf(arc_error,absf(current-height-(vertical-gravity/120.0)/120.0))
			if branch.is_empty(): branch = RewindHistory.properties(sim.state); branch_tick = tick+1
		snapshots.append(sim.state.snapshot())
		if sim.state.position.dot(axis)*direction > float(track.creator_bridges[0].length)*0.5+3.0 and not sim.state.bridge_airborne: break
	var label: String = "%s length=%s angle=%s direction=%s speed=%s" % [id,track.creator_bridges[0].length,track.creator_bridges[0].heading,direction,speed]
	check(old_peak == 0.0,label+" original downhill glue reproduced")
	check(peak == 0.0 if speed == 3.0 else peak > 0.02 if speed >= 24.0 else peak >= 0.0,label+" slow planted / fast visible downhill release")
	check(peak < 0.30 and air_ticks <= 42,label+" shallow arc and short airtime")
	check(releases <= 1 and not upward_impulse,label+" one tangent release, no upward kick")
	check(arc_error < 0.000001,label+" constant-acceleration world arc")
	check(not sim.state.bridge_airborne and sim.state.jump_height == 0.0 and sim.state.collision_count == 0,label+" solid clear landing")
	var replay := VehicleSimulation.new(config)
	replay.reset(Vector2.ZERO,atan2(axis.x*direction,axis.y*direction)); replay.state.velocity = axis*speed*direction
	replay.state.track_elevated = true; replay.state.route_index = track.nearest_route(Vector2.ZERO); replay.state.jump_cooldown = 24
	var exact: bool = true
	var decoded: Array = JSON.parse_string(JSON.stringify(DriveFrame.new().packed()))
	for tick: int in range(snapshots.size()):
		var frame := DriveFrame.new(); frame.steer = int(decoded[0]); frame.throttle = int(decoded[1]); frame.brake = int(decoded[2])
		replay.step(frame,track)
		if replay.state.snapshot() != snapshots[tick]: exact = false; break
	check(exact,label+" JSON replay exact every tick")
	if not branch.is_empty():
		RewindHistory.restore(replay.state,branch)
		for tick: int in range(branch_tick,snapshots.size()): replay.step(DriveFrame.new(),track)
		check(replay.state.snapshot() == sim.state.snapshot(),label+" downhill rewind exact")
		var neutral := VehicleSimulation.new(config); RewindHistory.restore(neutral.state,branch)
		var pedal := VehicleSimulation.new(config); RewindHistory.restore(pedal.state,branch)
		neutral.step(DriveFrame.new(),track); pedal.step(input_frame([255,255,127,255]),track)
		check(neutral.state.position == pedal.state.position and neutral.state.velocity == pedal.state.velocity and neutral.state.heading == pedal.state.heading,label+" no airborne tyre forces")
		pedal.reset(Vector2.ZERO)
		check(not pedal.state.bridge_airborne and not pedal.state.bridge_descending and pedal.state.bridge_gravity == FLIGHT.GRAVITY,label+" reset clears fitted flight state")
	descents.append({"label":label,"before_peak":old_peak,"peak":peak,"air_ticks":air_ticks,"releases":releases,"arc_error":arc_error})
	print("DESCENT ",label," peak=",peak," air_s=",air_ticks/120.0," releases=",releases)

func entry_unchanged(track: NativeTrack, id: String, direction: float) -> void:
	var config: HandlingConfig = VehicleCatalog.config(id)
	var sim := VehicleSimulation.new(config)
	var baseline = BEFORE.new(config)
	for value in [sim,baseline]:
		value.reset(Vector2(-20*direction,0),PI*0.5*direction)
		value.state.velocity = Vector2(24*direction,0)
		value.state.route_index = track.nearest_route(value.state.position)
	var exact: bool = true
	for tick: int in range(240):
		sim.step(DriveFrame.new(),track); baseline.step(DriveFrame.new(),track)
		if sim.state.snapshot() != baseline.state.snapshot(): exact = false; break
		if sim.state.position.x*direction >= 0.0: break
	check(exact,id+" entry snapshots remain exact in each direction")

func native_scene(track: NativeTrack) -> void:
	var game: Node = load("res://core/game.tscn").instantiate()
	game.initial_track = track; root.size = Vector2i(1280,720); root.add_child(game)
	game.set_physics_process(false); game.countdown_ticks = 0
	game.sim.reset(Vector2.ZERO,PI*0.5); game.sim.state.velocity = Vector2(24,0)
	game.sim.state.track_elevated = true; game.sim.state.route_index = track.nearest_route(Vector2.ZERO)
	var peak: float = 0.0
	var best: Dictionary = {}
	var last_air: Dictionary = {}
	var landing: Dictionary = {}
	for tick: int in range(180):
		var was_air: bool = game.sim.state.bridge_airborne
		game.sim.step(DriveFrame.new(),track)
		if game.sim.state.bridge_airborne: last_air = RewindHistory.properties(game.sim.state)
		elif was_air: landing = RewindHistory.properties(game.sim.state)
		if game.sim.state.bridge_descending and game.sim.state.jump_height > peak:
			peak = game.sim.state.jump_height; best = RewindHistory.properties(game.sim.state)
	check(peak > 0.02 and peak < 0.30,"actual game downhill hop is visible and restrained")
	if not landing.is_empty():
		var state := VehicleState.new()
		RewindHistory.restore(state,last_air)
		game.car.last_tick = -1
		game.car.present_suspension(state,0.0)
		var audio := ObservedAudio.new(); audio.use_windows_impacts = false
		game.add_child(audio); audio.configure("compact",game.handling,game.car)
		audio.present(state,DriveFrame.new(),track,1.0/120.0,false)
		RewindHistory.restore(state,landing)
		game.car.present_suspension(state,0.0)
		audio.present(state,DriveFrame.new(),track,1.0/120.0,false)
		check(state.bridge_landing_speed < -float(last_air.jump_velocity),"landing responds to deck-relative speed, not world fall speed")
		var cues: Array = audio.emitted.filter(func(event: Dictionary) -> bool: return event.clip == "chassis" and is_equal_approx(float(event.pitch),0.76))
		var expected: float = lerpf(0.15,0.55,clampf(minf(state.bridge_landing_speed,2.5)/10.0,0.0,1.0))
		check(cues.size() == 1 and is_equal_approx(float(cues[0].gain),expected) if state.bridge_landing_speed > 0.5 else cues.is_empty(),"downhill landing audio uses actual contact strength")
		check(game.car.spark_cursor == 0,"supported downhill landing adds no hard-impact sparks")
		print("LANDING world_speed=",-float(last_air.jump_velocity)," contact_speed=",state.bridge_landing_speed)
		audio.free()
	if not best.is_empty():
		var baseline = BEFORE.new(game.handling)
		baseline.reset(Vector2.ZERO,PI*0.5); baseline.state.velocity = Vector2(24,0)
		baseline.state.track_elevated = true; baseline.state.route_index = track.nearest_route(Vector2.ZERO)
		while baseline.state.position.x < Vector2(best.position).x: baseline.step(DriveFrame.new(),track)
		for mode: String in ["before","after"]:
			RewindHistory.restore(game.sim.state,RewindHistory.properties(baseline.state) if mode == "before" else best)
			game.previous_position = game.sim.state.position; game.previous_heading = game.sim.state.heading
			game._process(0.0)
			var snapshot: Array = game.sim.state.snapshot(); var pose: Transform3D = game.car.transform
			game._process(0.0)
			check(game.sim.state.snapshot() == snapshot and game.car.transform == pose,"paused downhill presentation is stable")
			if DisplayServer.get_name() != "headless":
				await process_frame; await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png(OUT+"/%s-%s.png" % [mode,RenderingServer.get_current_rendering_method()])
	game.queue_free(); await process_frame
