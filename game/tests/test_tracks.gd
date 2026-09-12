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
	_check_soft_surfaces()
	_check_ramp_recovery()
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


func _check_soft_surfaces() -> void:
	var track := NativeTrack.new()
	track.cell_size = 0.25
	track.grid_width = 160
	track.grid_height = 160
	track.half_extent = Vector2(20,20)
	track.cells.resize(25600)
	track.deck_cells.resize(25600)
	track.deck_cells.fill(-1)
	track.route = PackedVector2Array([Vector2(-15,0),Vector2(15,0),Vector2(15,15),Vector2(-15,15)])
	var config := HandlingConfig.new()
	var reference_speed: float = 0.0
	for kind: int in [0,1,2,5,6,7]:
		track.cells.fill(kind)
		var sim := VehicleSimulation.new(config)
		sim.reset(Vector2(-8,0), PI * 0.5)
		sim.state.velocity = Vector2(20,0)
		for tick: int in range(60): sim.step(DriveFrame.new(), track)
		if kind == 0: reference_speed = sim.state.velocity.x
		else:
			check(sim.state.velocity.x < reference_speed and sim.state.velocity.x > 0.0, "surface %d slows without reversing travel" % kind)
			check(sim.state.collision_count == 0 and sim.state.position.x > -8.0, "surface %d permits forward movement without bouncing" % kind)
		if kind in [1,7]:
			var powered := VehicleSimulation.new(config)
			powered.reset(Vector2(-8,0), PI * 0.5)
			powered.state.velocity = Vector2(20,0)
			var throttle := DriveFrame.new()
			throttle.throttle = 255
			for tick: int in range(60): powered.step(throttle, track)
			check(powered.state.velocity.x < 19.0 and powered.state.velocity.x > 0.0 and powered.state.collision_count == 0, "surface %d reduces entry speed even at full throttle" % kind)
			print("POWERED_SURFACE %d: 72 -> %.2f km/h in 0.5s" % [kind,powered.state.velocity.x * 3.6])
			powered.reset(Vector2.ZERO, PI * 0.5)
			for tick: int in range(120): powered.step(throttle, track)
			check(powered.state.velocity.x > 1.0 and powered.state.collision_count == 0, "surface %d allows accelerating away from rest" % kind)
		if kind == 7:
			print("ROUGH_RESULT: 0.5s coasting from 72 km/h: asphalt %.2f, rough %.2f km/h; contacts %d" % [reference_speed*3.6,sim.state.velocity.x*3.6,sim.state.collision_count])
			check(reference_speed - sim.state.velocity.x > 3.5, "rough patch has a meaningful speed penalty")
			var stopped := VehicleSimulation.new(config)
			stopped.reset(Vector2.ZERO)
			for tick: int in range(120): stopped.step(DriveFrame.new(), track)
			check(stopped.state.velocity == Vector2.ZERO, "rough surface cannot propel a stopped car")
			var reverse := VehicleSimulation.new(config)
			reverse.reset(Vector2.ZERO, PI * 0.5)
			reverse.state.velocity = Vector2(-6,0)
			for tick: int in range(60): reverse.step(DriveFrame.new(), track)
			check(reverse.state.velocity.x < 0.0 and reverse.state.velocity.x > -6.0 and reverse.state.collision_count == 0, "rough surface slows reverse without bouncing or changing direction")
	# A finite six-metre rough patch: prove actual entry and exit as well as the
	# uniform-surface speed test above. Traversal is not a minimum-speed rule.
	track.cells.fill(0)
	for y: int in range(track.grid_height):
		for x: int in range(68,92): track.cells[y * track.grid_width + x] = 7
	var crossing := VehicleSimulation.new(config)
	crossing.reset(Vector2(-8,0), PI * 0.5)
	crossing.state.velocity = Vector2(20,0)
	for tick: int in range(120): crossing.step(DriveFrame.new(), track)
	check(crossing.state.position.x > 3.0 and crossing.state.velocity.x > 0.0 and crossing.state.velocity.x < 18.0 and crossing.state.collision_count == 0, "car enters and exits six-metre rough patch with speed loss and no bounce")
	track.cells.fill(0)
	for y: int in range(track.grid_height): track.cells[y * track.grid_width + 80] = 3
	check(track.collision_normal(Vector2(-1,0), config.collision_radius, false) != Vector2.ZERO, "deep water remains impassable")


func _check_ramp_recovery() -> void:
	# Off-line entry can enable an upper rail while the car circle already
	# overlaps its end. Reproduce escape from that state on real native decks.
	for name: String in ["1way", "66", "offroad"]:
		var track := NativeTrack.read("res://resources/tracks/slicks_" + name + "_test.json")
		var config := HandlingConfig.new()
		var found: bool = false
		for y: int in range(track.grid_height):
			if found: break
			for x: int in range(track.grid_width):
				if track.deck_cells[y * track.grid_width + x] != 0: continue
				var point := Vector2((x + 0.5) * track.cell_size - track.half_extent.x, track.half_extent.y - (y + 0.5) * track.cell_size)
				var index: int = track.nearest_route(point)
				if not track.elevated_at(point, index): continue
				var normal: Vector2 = track.collision_normal(point, config.collision_radius, true)
				if normal == Vector2.ZERO: continue
				var clear: Vector2 = point + normal * config.collision_radius * 2.0
				if track.collision_normal(clear, config.collision_radius, true) != Vector2.ZERO: continue
				# Require an open exit on the lower road as well. Some rail ends
				# sit above a separate solid footprint; recovery must not cross it.
				var exit_open: bool = true
				for sample_index: int in range(25):
					var sample_point: Vector2 = point.lerp(clear, sample_index / 24.0)
					if track.collision_normal(sample_point, config.collision_radius, false) != Vector2.ZERO:
						exit_open = false
						break
				if not exit_open: continue
				var state := VehicleState.new()
				state.position = point + normal * 0.02
				state.velocity = normal * 2.0
				state.route_index = index
				state.track_elevated = true
				track.resolve(state, point, config)
				print("RAMP_ESCAPE ", name, " point=", point, " route=", index, " normal=", normal, " moved=", state.position.distance_to(point))
				check(state.position.distance_to(point) > 0.01, name + " overlapping ramp rail permits outward escape")
				state.position = point - normal * config.collision_radius * 3.0
				state.velocity = -normal * 20.0
				track.resolve(state, point, config)
				check(state.position.distance_to(point) < 0.001 and state.collision_count == 1, name + " overlap recovery cannot drive through the rail")
				var sim := VehicleSimulation.new(config)
				var heading: float = atan2(-normal.x, -normal.y)
				sim.reset(point, heading)
				sim.state.route_index = index
				sim.state.track_elevated = true
				var reverse := DriveFrame.new()
				reverse.brake = 255
				for tick: int in range(240):
					sim.step(reverse, track)
					if track.collision_normal(sim.state.position, config.collision_radius, true) == Vector2.ZERO and track.collision_normal(sim.state.position, config.collision_radius, sim.state.track_elevated) == Vector2.ZERO: break
				check(sim.state.position.distance_to(point) > 0.1 and track.collision_normal(sim.state.position, config.collision_radius, true) == Vector2.ZERO and track.collision_normal(sim.state.position, config.collision_radius, sim.state.track_elevated) == Vector2.ZERO and sim.state.collision_count == 0, name + " held brake engages reverse and fully clears the ramp rail")
				var replay := VehicleSimulation.new(config)
				replay.reset(point, heading)
				replay.state.route_index = index
				replay.state.track_elevated = true
				for batch: int in range(0, sim.state.tick, 8):
					for tick: int in range(batch, mini(batch + 8, sim.state.tick)): replay.step(reverse, track)
				check(replay.state.snapshot() == sim.state.snapshot(), name + " ramp escape replays exactly in batches of eight")
				print("RAMP_REVERSE ", name, " ticks=", sim.state.tick, " distance=", sim.state.position.distance_to(point), " contacts=", sim.state.collision_count)
				found = true
				break
		check(found, name + " native ramp overlap fixture found")
	_check_layer_entry()


func _check_layer_entry() -> void:
	var track := NativeTrack.new()
	track.cell_size = 0.25
	track.grid_width = 80
	track.grid_height = 80
	track.half_extent = Vector2(10,10)
	track.cells.resize(6400)
	track.deck_cells.resize(6400)
	track.deck_cells.fill(-1)
	track.bridge_axis = Vector2.RIGHT
	track.bridge_height = 3.2
	track.route = PackedVector2Array([Vector2(-5,3.5),Vector2(-1,3.5),Vector2(1,3.5),Vector2(5,3.5),Vector2(5,-5),Vector2(-5,-5)])
	for y: int in range(24,56):
		for x: int in range(40,80): track.deck_cells[y * 80 + x] = 4 if y == 24 else 0
	var config := HandlingConfig.new()
	var start := Vector2(-0.05,3.5)
	var state := VehicleState.new()
	state.position = Vector2(0.05,3.5)
	state.velocity = Vector2(4,0)
	state.route_index = 0
	track.resolve(state, start, config)
	check(state.position.x < 0.0 and not state.track_elevated and state.collision_count == 1, "ramp entry checks upper rail before committing the layer switch")
	var blocked: Vector2 = state.position
	state.position -= Vector2(0.05,0)
	state.velocity = Vector2(-2,0)
	track.resolve(state, blocked, config)
	check(state.position.x < blocked.x and state.collision_count == 1, "rejected ramp entry can immediately back away")
	track.bridge_height = 0.0
	track.deck_cells.fill(-1)
	for y: int in range(80):
		track.cells[y * 80 + 40] = 4
		track.cells[y * 80 + 50] = 4
	state = VehicleState.new()
	state.position = Vector2(1.3,0)
	state.velocity = Vector2(2,0)
	track.resolve(state, Vector2(1.05,0), config)
	check(state.position.x <= 2.5 - config.collision_radius and state.collision_count == 1, "escaping one overlap cannot enter a second barrier")
