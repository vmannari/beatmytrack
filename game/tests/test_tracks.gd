extends SceneTree

var failures: int = 0
var checks: int = 0
var driver := RouteDriver.new()


func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		print("FAIL: " + description)


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	for name: String in ["freeway", "1way", "66", "offroad"]:
		var track := NativeTrack.read("res://resources/tracks/slicks_" + name + "_test.json")
		check(track != null and track.route.size() > 20, name + " loads")
		var config: HandlingConfig = load("res://resources/balanced.tres")
		var sim := VehicleSimulation.new(config)
		sim.reset(track.spawn, track.spawn_heading)
		sim.state.route_index = track.nearest_route(track.spawn)
		check(track.collision_normal(track.spawn, config.collision_radius, false) == Vector2.ZERO, name + " spawn has collision clearance")
		var session := TrackSession.new()
		var bridge := BridgePresentation.new(track)
		var previous_height: float = 0.0
		var maximum_height_step: float = 0.0
		var ramp_ticks: int = 0
		var lower_height: float = 0.0
		var first_ramp_tick: int = 0
		var elevated_ticks: int = 0
		var underpass_ticks: int = 0
		var frames: Array[Array] = []
		for tick: int in range(120 * 240):
			var previous: Vector2 = sim.state.position
			var input: DriveFrame = driver.sample(sim.state, track, config)
			frames.append(input.packed())
			sim.step(input, track)
			session.advance(track, previous, sim.state.position, sim.state.route_index)
			var axle: Vector2 = sim.state.forward() * config.wheelbase * 0.5
			var height: float = (bridge.height_at(sim.state.position + axle, sim.state.route_index) + bridge.height_at(sim.state.position - axle, sim.state.route_index)) * 0.5
			maximum_height_step = maxf(maximum_height_step, absf(height - previous_height))
			previous_height = height
			if first_ramp_tick == 0 and height > 1.1 and height < 1.3:
				first_ramp_tick = sim.state.tick
			if height > 0.1 and height < track.bridge_height - 0.1: ramp_ticks += 1
			if sim.state.track_elevated: elevated_ticks += 1
			var cell: Vector2 = (sim.state.position + track.half_extent) / track.cell_size
			var x: int = clampi(floori(cell.x), 0, track.grid_width - 1)
			var y: int = clampi(floori((track.half_extent.y - sim.state.position.y) / track.cell_size), 0, track.grid_height - 1)
			if track.deck_cells[y * track.grid_width + x] >= 0 and not sim.state.track_elevated:
				underpass_ticks += 1
				lower_height = maxf(lower_height, height)
			if session.finished: break
		print("TRACK_RESULT ", name, " laps=", session.completed_laps, " next_cp=", session.next_checkpoint, " times=", session.lap_times, " collisions=", sim.state.collision_count, " elevated_ticks=", elevated_ticks, " underpass_ticks=", underpass_ticks)
		check(session.finished, name + " AI completes three ordered laps")
		check(sim.state.collision_count == 0, name + " conservative AI avoids barriers")
		if track.bridge_height > 0:
			check(elevated_ticks > 0 and underpass_ticks > 0, name + " both crossing branches retain their layers")
			print("RAMP_RESULT ", name, " intermediate_ticks=", ramp_ticks, " maximum_height_step=", maximum_height_step, " lower_height=", lower_height, " capture_tick=", first_ramp_tick)
			check(ramp_ticks > 100, name + " climbs and descends through intermediate ramp heights")
			check(maximum_height_step < 0.15, name + " no vertical teleport during complete driven laps")
			check(lower_height == 0.0, name + " lower passage stays at ground height")
		var replay := VehicleSimulation.new(config)
		replay.reset(track.spawn, track.spawn_heading)
		replay.state.route_index = track.nearest_route(track.spawn)
		var replay_session := TrackSession.new()
		var packed_frames: Array = JSON.parse_string(JSON.stringify(frames))
		for batch_start: int in range(0, packed_frames.size(), 8):
			for i: int in range(batch_start, mini(batch_start + 8, packed_frames.size())):
				var f := DriveFrame.new()
				f.steer = int(packed_frames[i][0]); f.throttle = int(packed_frames[i][1]); f.brake = int(packed_frames[i][2])
				var from: Vector2 = replay.state.position
				replay.step(f, track)
				replay_session.advance(track, from, replay.state.position, replay.state.route_index)
		check(replay.state.snapshot() == sim.state.snapshot() and replay_session.lap_times == session.lap_times, name + " exact full three-lap JSON replay in batches of eight")
		var frozen_time: int = session.elapsed_ticks
		session.advance(track, track.spawn, track.spawn + Vector2.ONE, 0)
		check(session.completed_laps == 3 and session.elapsed_ticks == frozen_time, name + " finish freezes at exactly three laps")
		_check_gates(track)
	_check_collision()
	var rect := Rect2(0,0,2,10)
	check(is_equal_approx(TrackSession.entry_fraction(rect, Vector2(-10,5), Vector2(10,5)), 0.5), "swept high-speed gate")
	check(TrackSession.entry_fraction(rect, Vector2(-10,15), Vector2(10,15)) < 0, "gate miss rejected")
	print("TRACK_TESTS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _check_gates(track: NativeTrack) -> void:
	var gate: Rect2 = track.checkpoints[0]
	var index: int = track.nearest_route(gate.get_center())
	var tangent: Vector2 = (track.route[(index + 1) % track.route.size()] - track.route[index]).normalized()
	var start: Vector2 = gate.get_center() - tangent * 30
	var end: Vector2 = gate.get_center() + tangent * 30
	var session := TrackSession.new()
	session.advance(track, end, start, index)
	check(session.next_checkpoint == 0, track.identity + " reverse entry rejected")
	session.advance(track, gate.get_center(), gate.get_center(), index)
	check(session.next_checkpoint == 0, track.identity + " camping inside CP does not count")
	session.advance(track, start, end, index)
	check(session.next_checkpoint == 1 and session.completed_laps == 0, track.identity + " swept CP entry counts once, never a whole lap")
	var before_finish: Vector2 = track.finish_center - track.finish_forward
	var after_finish: Vector2 = track.finish_center + track.finish_forward
	session = TrackSession.new()
	session.advance(track, before_finish, after_finish, track.nearest_route(track.finish_center))
	check(session.completed_laps == 0, track.identity + " finish without ordered checkpoints rejected")


func _check_collision() -> void:
	var track := NativeTrack.new()
	track.cell_size = 0.25
	track.grid_width = 80
	track.grid_height = 80
	track.half_extent = Vector2(10,10)
	track.cells.resize(6400)
	track.deck_cells.resize(6400)
	track.deck_cells.fill(-1)
	track.route = PackedVector2Array([Vector2(-5,0),Vector2(5,0),Vector2(5,5),Vector2(-5,5)])
	for y: int in range(80): track.cells[y * 80 + 40] = 4
	var config := HandlingConfig.new()
	var state := VehicleState.new()
	state.position = Vector2(8,0)
	state.velocity = Vector2(100,0)
	track.resolve(state, Vector2(-8,0), config)
	check(state.position.x < -config.collision_radius and state.collision_count == 1 and state.velocity.x < 0, "swept circle cannot tunnel through quarter-metre barrier")
	track.cells.fill(0)
	for y: int in range(80): track.deck_cells[y * 80 + 40] = 4
	check(track.collision_normal(Vector2(-1,0), 1.55, true) != Vector2.ZERO and track.collision_normal(Vector2(-1,0), 1.55, false) == Vector2.ZERO, "bridge rail blocks upper layer while lower road remains open")
	state.position = Vector2(-5,0)
	track.cells.fill(1)
	check(track.surface_factors(state).x < 1 and track.surface_factors(state).y > 0, "grass uses reduced grip and additional resistance")
