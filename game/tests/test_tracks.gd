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
		var session := TrackSession.new(120, 3)
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
		var replay_session := TrackSession.new(120, 3)
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
	_check_ramp_rail_tips()
	_check_rebound()
	_check_impact_turn()
	_check_wall_slide()
	_check_blocked_speed()
	_check_tire_dirt()
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
	var session := TrackSession.new(120, 3)
	session.advance(track, end, start, index)
	check(session.next_checkpoint == 0, track.identity + " reverse entry rejected")
	session.advance(track, gate.get_center(), gate.get_center(), index)
	check(session.next_checkpoint == 0, track.identity + " camping inside CP does not count")
	session.advance(track, start, end, index)
	check(session.next_checkpoint == 1 and session.completed_laps == 0, track.identity + " swept CP entry counts once, never a whole lap")
	var before_finish: Vector2 = track.finish_center - track.finish_forward
	var after_finish: Vector2 = track.finish_center + track.finish_forward
	session = TrackSession.new(120, 3)
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
	check(track.collision_normal(Vector2(-1,0), config.collision_radius, false) == Vector2.ZERO, "water is traversable under the surface override")


func _check_ramp_rail_tips() -> void:
	for name: String in ["1way", "66", "offroad"]:
		var track := NativeTrack.read("res://resources/tracks/slicks_" + name + "_test.json")
		# Isolate native upper rails from ground walls under the diagonal ends.
		# Full-track lap/layer/escape tests above retain all original geometry.
		track.cells.fill(0)
		var config := HandlingConfig.new()
		for direction: float in [-1.0,1.0]:
			var outward: Vector2 = track.bridge_axis * direction
			var tip := Vector2.ZERO
			var furthest: float = -INF
			for y: int in range(track.grid_height):
				for x: int in range(track.grid_width):
					if track.deck_cells[y * track.grid_width + x] != 4: continue
					var p := Vector2((x+0.5)*track.cell_size-track.half_extent.x, track.half_extent.y-(y+0.5)*track.cell_size)
					if p.dot(outward) > furthest:
						var candidate_face: Vector2 = p + outward * track.cell_size * 0.5
						var candidate_start: Vector2 = candidate_face + outward * (config.collision_radius + 0.5)
						if track.collision_normal(candidate_start, config.collision_radius, true) != Vector2.ZERO:
							continue
						tip = p
						furthest = p.dot(outward)
			check(furthest > -INF, name + " has a rail-tip fixture with an unobstructed approach and retreat")
			var face: Vector2 = tip + outward * track.cell_size * 0.5
			var start: Vector2 = face + outward * (config.collision_radius + 0.5)
			var destination: Vector2 = face + outward * (config.collision_radius * 0.5)
			var state := VehicleState.new()
			state.route_index = track.nearest_route(start)
			state.position = destination
			state.velocity = -outward * 10.0
			track.resolve(state, start, config)
			print("RAIL_TIP ",name," side=",direction," start=",start," destination=",destination," actual=",state.position," route=",state.route_index," contacts=",state.collision_count)
			check(state.collision_count == 1 and track.collision_normal(state.position, config.collision_radius, true) == Vector2.ZERO, name + " rail tip blocks the car footprint before its centre enters the deck")
			var blocked: Vector2 = state.position
			var contacts: int = state.collision_count
			state.position += outward * 0.1
			state.velocity = outward * 2.0
			track.resolve(state, blocked, config)
			check(state.position.distance_to(blocked) > 0.09 and state.collision_count == contacts, name + " rail-tip contact permits immediate retreat without repeated impacts")


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
	check(state.position.x < 0.0 and state.track_elevated and state.collision_count == 1, "ramp entry detects the already-overlapping upper rail before the centre enters the deck")
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


func _check_rebound() -> void:
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
	var distances: Array[float] = []
	for legacy: bool in [true,false]:
		var config := HandlingConfig.new()
		if legacy: config.restitution = 0.12
		var sim := VehicleSimulation.new(config)
		sim.reset(Vector2(-4,0), PI * 0.5)
		sim.state.velocity = Vector2(20,0)
		var throttle := DriveFrame.new()
		throttle.throttle = 255
		for tick: int in range(120):
			sim.step(throttle, track)
			if sim.state.collision_count > 0: break
		var impact_position: Vector2 = sim.state.position
		var rebound_speed: float = -sim.state.velocity.x
		var separation: float = 0.0
		for tick: int in range(60):
			sim.step(throttle, track)
			separation = maxf(separation, impact_position.x - sim.state.position.x)
		distances.append(separation)
		if not legacy:
			print("BOUNCE_RESULT: powered head-on impact, rebound %.2f km/h, separation %.3f -> %.3f m" % [rebound_speed*3.6,distances[0],separation])
			# Owner requested another reduction after evaluating the 2.658 m rebound.
			check(separation > 0.5 and separation < 1.8 and separation > distances[0] * 2.0, "head-on recoil remains visible but is moderated under held throttle")
	var config := HandlingConfig.new()
	var glance := VehicleState.new()
	glance.velocity = Vector2(8,18)
	var energy: float = glance.velocity.length_squared()
	track._bounce(glance, Vector2.LEFT, config)
	check(glance.velocity.x < -2.0 and glance.velocity.y > 14.0 and glance.velocity.length_squared() < energy, "glancing collision rebounds and retains travel along the wall without adding energy")


func _check_tire_dirt() -> void:
	var config := HandlingConfig.new()
	var track := NativeTrack.new()
	track.cell_size = 0.25
	track.grid_width = 80
	track.grid_height = 800
	track.half_extent = Vector2(10,100)
	track.cells.resize(64000)
	track.deck_cells.resize(64000)
	track.deck_cells.fill(-1)
	track.route = PackedVector2Array([Vector2(0,-90),Vector2(0,90)])
	for kind: int in [1,2]:
		track.cells.fill(kind)
		var sim := VehicleSimulation.new(config)
		for tick: int in range(120): sim.step(DriveFrame.new(), track)
		check(sim.state.tire_dirt == 0.0, "stationary tires do not accumulate dirt on surface %d" % kind)
		sim.state.velocity = Vector2(0,20)
		for tick: int in range(60): sim.step(DriveFrame.new(), track)
		var short_exposure: float = sim.state.tire_dirt
		var expected: float = sim.state.position.y * (0.5 if kind == 1 else 1.0) / config.tire_pickup_distance
		check(short_exposure > 0.0 and is_equal_approx(short_exposure, expected), "surface %d pickup follows actual distance and material" % kind)
		for tick: int in range(60): sim.step(DriveFrame.new(), track)
		check(sim.state.tire_dirt > short_exposure and sim.state.tire_dirt <= 1.0, "longer exposure leaves more contamination")
		track.cells.fill(0)
		var before: float = sim.state.tire_dirt
		sim.step(DriveFrame.new(), track)
		check(sim.state.tire_dirt > 0.0 and sim.state.tire_dirt < before, "dirt persists onto asphalt and begins gradual cleaning")
		sim.state.velocity = Vector2.ZERO
		before = sim.state.tire_dirt
		for tick: int in range(600): sim.step(DriveFrame.new(), track)
		check(sim.state.tire_dirt == before, "waiting five seconds does not clean tires")
		sim.reset(Vector2.ZERO)
		check(sim.state.tire_dirt == 0.0, "restart clears contamination")
	for speed: float in [10.0,20.0,-20.0]:
		var sim := VehicleSimulation.new(config)
		sim.state.tire_dirt = 1.0
		var ticks: int = 0
		while sim.state.tire_dirt > 0.0 and ticks < 1200:
			# Controlled-speed fixture isolates distance from engine acceleration.
			sim.state.velocity = Vector2(0,speed)
			sim.step(DriveFrame.new())
			ticks += 1
		check(absf(absf(sim.state.position.y) - config.tire_clean_distance) < 0.2 and sim.state.tire_dirt == 0.0, "full coating cleans over 80 m independent of speed or reverse")
		print("TIRE_CLEAN speed=",speed," seconds=",ticks * VehicleSimulation.STEP," metres=",absf(sim.state.position.y))
	var clean := VehicleSimulation.new(config)
	var dirty := VehicleSimulation.new(config)
	clean.state.velocity = Vector2(8,20)
	dirty.state.velocity = clean.state.velocity
	dirty.state.tire_dirt = 1.0
	clean.step(DriveFrame.new())
	dirty.step(DriveFrame.new())
	check(dirty.state.velocity.x > clean.state.velocity.x, "dirty tires have less lateral grip on clean asphalt")
	clean.reset(Vector2.ZERO)
	dirty.reset(Vector2.ZERO)
	clean.state.velocity = Vector2(0,20)
	dirty.state.velocity = clean.state.velocity
	dirty.state.tire_dirt = 1.0
	var brake := DriveFrame.new()
	brake.brake = 255
	clean.step(brake)
	dirty.step(brake)
	check(dirty.state.velocity.y > clean.state.velocity.y, "dirty tires reduce braking traction on clean asphalt")
	var states: Array = []
	for repeat: int in range(2):
		var sim := VehicleSimulation.new(config)
		var throttle := DriveFrame.new()
		throttle.throttle = 255
		for tick: int in range(600):
			track.cells.fill(2 if tick < 120 else 0)
			sim.step(throttle, track)
		states.append(sim.state.snapshot())
	check(states[0] == states[1] and states[0].size() == 19 and states[0][14] == [] and states[0][15] == [0.0,0.0,0] and states[0][16] == [] and states[0][18] == [0.0,0.0,0.0,0.0,0.0,0.0], "exposure and recovery replay exactly with contamination in state snapshot")


func _check_blocked_speed() -> void:
	var track := NativeTrack.new()
	track.cell_size = 0.25
	track.grid_width = 80
	track.grid_height = 800
	track.half_extent = Vector2(10,100)
	track.cells.resize(64000)
	track.deck_cells.resize(64000)
	track.deck_cells.fill(-1)
	track.route = PackedVector2Array([Vector2(-5,-90),Vector2(-5,90),Vector2(5,90),Vector2(5,-90)])
	for y: int in range(800): track.cells[y * 80 + 40] = 4
	var config := HandlingConfig.new()
	var throttle := DriveFrame.new()
	throttle.throttle = 255
	for angle: float in [0.0,15.0,45.0,75.0]:
		var sim := VehicleSimulation.new(config)
		sim.reset(Vector2(-config.collision_radius + 0.02,0), deg_to_rad(angle))
		var hidden_speed: float = 0.0
		var surge: float = 0.0
		var previous_travel_speed: float = 0.0
		for tick: int in range(360):
			var before: Vector2 = sim.state.position
			sim.step(throttle, track)
			# Measure travel along the wall. Outward recoil is an intentional
			# collision impulse, covered separately by the rebound tests.
			var travel_speed: float = absf(sim.state.position.y - before.y) / VehicleSimulation.STEP
			if travel_speed < 0.01: hidden_speed = maxf(hidden_speed, absf(sim.state.velocity.y))
			surge = maxf(surge, travel_speed - previous_travel_speed)
			previous_travel_speed = travel_speed
		print("BLOCKED_SPEED angle=",angle," hidden=",hidden_speed," surge=",surge," distance=",sim.state.position.y)
		check(hidden_speed < 0.25, "blocked wall scrape cannot store speed while position is stationary")
		check(surge < config.longitudinal_grip * VehicleSimulation.STEP + 0.1, "wall release cannot exceed one tick of normal acceleration")
		check(sim.state.position.y > 1.0, "slight initial wall overlap still permits powered tangential progress")


func _check_wall_slide() -> void:
	var track := NativeTrack.new()
	track.cell_size = 0.25
	track.grid_width = 80
	track.grid_height = 800
	track.half_extent = Vector2(10,100)
	track.cells.resize(64000)
	track.deck_cells.resize(64000)
	track.deck_cells.fill(-1)
	track.route = PackedVector2Array([Vector2(-5,-90),Vector2(-5,90),Vector2(5,90),Vector2(5,-90)])
	for y: int in range(800): track.cells[y * 80 + 40] = 4
	var config := HandlingConfig.new()
	var throttle := DriveFrame.new()
	throttle.throttle = 255
	for direction: float in [-1.0,1.0]:
		var sim := VehicleSimulation.new(config)
		var initial: float = PI * 0.5 - direction * PI * 0.25
		sim.reset(Vector2(-config.collision_radius - 0.002,0), initial)
		var clear: bool = true
		for tick: int in range(360):
			sim.step(throttle, track)
			clear = clear and sim.state.position.x <= -config.collision_radius
		print("WALL_SLIDE direction=",direction," distance=",absf(sim.state.position.y)," angle=",rad_to_deg(acos(clampf(absf(sim.state.forward().y),0,1))))
		check(clear, "powered wall sliding never enters the barrier")
		check(sim.state.position.y * direction > 5.0, "car starts from rest and keeps moving along the wall under throttle")
		check(absf(sim.state.forward().x) < sin(deg_to_rad(15.0)), "sustained rubbing gradually aligns the nose parallel in either direction")
		var replay := VehicleSimulation.new(config)
		replay.reset(Vector2(-config.collision_radius - 0.002,0), initial)
		for tick: int in range(360): replay.step(throttle, track)
		check(replay.state.snapshot() == sim.state.snapshot(), "wall slide and alignment replay exactly")


func _check_impact_turn() -> void:
	var config := HandlingConfig.new()
	var ground := PlaygroundData.new()
	var turns: Array[float] = []
	for side: float in [-1.0,1.0]:
		var sim := VehicleSimulation.new(config)
		var initial_heading: float = side * PI * 0.25
		sim.reset(Vector2.ZERO, initial_heading)
		sim.state.velocity = sim.state.forward() * 20.0
		var before_energy: float = config.mass * sim.state.velocity.length_squared()
		ground._bounce(sim.state, Vector2(-side,0), config)
		var after_energy: float = config.mass * sim.state.velocity.length_squared() + config.rotational_inertia * sim.state.yaw_rate * sim.state.yaw_rate
		check(after_energy < before_energy and absf(sim.state.yaw_rate) <= config.maximum_yaw_rate, "angled impact turn is bounded and loses total kinetic energy")
		check(sim.state.yaw_rate * side < 0.0, "angled impact turns the nose away from the wall")
		for tick: int in range(24): sim.step(DriveFrame.new())
		var turn: float = sim.state.heading - initial_heading
		turns.append(turn)
		check(absf(turn) > deg_to_rad(5.0) and absf(turn) < deg_to_rad(20.0), "impact rotates actual car heading visibly over the following 0.2 seconds")
		print("IMPACT_TURN side=", side, " heading_change_degrees=", rad_to_deg(turn))
	check(is_equal_approx(turns[0], -turns[1]), "left and right impacts have mirrored turning response")
	var centered := VehicleState.new()
	centered.velocity = Vector2(0,20)
	ground._bounce(centered, Vector2(0,-1), config)
	check(centered.yaw_rate == 0.0 and centered.heading == 0.0 and centered.velocity.y < 0.0 and centered.collision_count == 1, "centered head-on collision rebounds without arbitrary spin")
	var outgoing := VehicleState.new()
	outgoing.velocity = Vector2(-10,0)
	ground._bounce(outgoing, Vector2.LEFT, config)
	check(outgoing.yaw_rate == 0.0 and outgoing.collision_count == 0, "moving away from a wall does not add collision rotation")
	var recoil := VehicleSimulation.new(config)
	recoil.reset(Vector2.ZERO)
	recoil.state.velocity = Vector2(0,-12)
	var brake := DriveFrame.new()
	brake.brake = 255
	recoil.step(brake)
	check(recoil.state.velocity.y < -11.0 and recoil.state.velocity.y > -12.0, "reverse pedal does not clip, accelerate or sustain hard-impact recoil")
	var powered_reverse := VehicleSimulation.new(config)
	for tick: int in range(1200): powered_reverse.step(brake)
	check(powered_reverse.state.velocity.y >= -config.reverse_speed and powered_reverse.state.velocity.y < -config.reverse_speed + 0.1, "powered reverse still respects its normal speed limit")
