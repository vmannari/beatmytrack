extends SceneTree
## Behaviour, cross-car records and full five-lap replay. Same engine/platform only.
var checks: int = 0
var failures: int = 0
var metrics: Dictionary = {}

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: " + description)

func _soil() -> NativeTrack:
	var track := NativeTrack.new()
	track.cell_size = 10.0
	track.grid_width = 100
	track.grid_height = 100
	track.half_extent = Vector2(500,500)
	track.cells.resize(10000)
	track.cells.fill(2)
	track.deck_cells.resize(10000)
	track.deck_cells.fill(-1)
	track.route = PackedVector2Array([Vector2(0,-400),Vector2(0,400)])
	return track

func _run() -> void:
	var soil: NativeTrack = _soil()
	var track: NativeTrack = NativeTrack.read("res://tests/fixtures/legacy_tracks/slicks_arto4_test.json")
	var keys: Array[String] = []
	var records := LocalRecords.new("user://car_tests_" + TrackLibrary.unique_id() + ".json")
	for id: String in VehicleCatalog.IDS:
		var config: HandlingConfig = VehicleCatalog.config(id)
		var key: String = records.key_for(track,config)
		check(key not in keys, id + " PB rules are distinct")
		keys.append(key)
		var straight := VehicleSimulation.new(config)
		var dirt := VehicleSimulation.new(config)
		var turn := VehicleSimulation.new(config)
		turn.state.velocity = Vector2(0,24)
		for tick: int in range(600):
			straight.step(DriveFrame.sample(0,1,0))
			dirt.step(DriveFrame.sample(0,1,0),soil)
			if tick < 24: turn.step(DriveFrame.sample(1,0.5,0))
		var brake := VehicleSimulation.new(config)
		brake.state.velocity = Vector2(0,30)
		for tick: int in range(600):
			brake.step(DriveFrame.sample(0,0,1))
			if brake.state.velocity.length() < 0.15: break
		metrics[id] = {"asphalt_5s_m":straight.state.position.y,"soil_5s_m":dirt.state.position.y,"turn_0_2s_deg":rad_to_deg(turn.state.heading),"brake_30_mps_m":brake.state.position.y}
		check(straight.state.velocity.length() <= config.maximum_speed, id + " respects speed cap")
		check(brake.state.velocity.length() < 0.15, id + " brakes to rest")
		# Mixed inputs exercise all dynamic branches across render batches.
		var sim := VehicleSimulation.new(config)
		var inputs: Array[Array] = []
		for tick: int in range(2400):
			var frame: DriveFrame = DriveFrame.sample(sin(tick*0.014)*0.8,1.0 if tick%480<340 else 0.0,0.6 if tick%480>=400 else 0.0)
			inputs.append(frame.packed())
			sim.step(frame,soil)
		var replay := VehicleSimulation.new(config)
		var decoded: Array = JSON.parse_string(JSON.stringify(inputs))
		for batch: int in range(0,2400,8):
			for i: int in range(batch,batch+8):
				var frame := DriveFrame.new()
				frame.steer = int(decoded[i][0])
				frame.throttle = int(decoded[i][1])
				frame.brake = int(decoded[i][2])
				replay.step(frame,soil)
		check(sim.state.snapshot() == replay.state.snapshot(), id + " mixed-input soil replay is exact")
		var visual := CarVisual.new()
		visual.vehicle_id = id
		root.add_child(visual)
		check(visual.front_wheels.size() == 2 and visual.body.get_child_count() > 10,id + " detailed model has steering wheels and body")
		visual.present(sim.state.position,sim.state.heading,sim.state,DriveFrame.new())
		visual.present_suspension(sim.state,0)
		var rolling := VehicleState.new()
		visual.present(Vector2.ZERO, 0.0, rolling, DriveFrame.new())
		check(visual.rolling_wheels.size() == 4,id + " all four tires can roll")
		rolling.tick = 1
		visual.present(Vector2(0,0.1), 0.0, rolling, DriveFrame.new())
		var spin: float = visual.rolling_wheels[0].rotation.x
		check(spin < 0.0 and is_equal_approx(spin,-0.1/visual.wheel_radii[0]),id + " forward travel rolls at tire radius")
		visual.present(Vector2(0,0.1), 0.0, rolling, DriveFrame.new())
		check(is_equal_approx(visual.rolling_wheels[0].rotation.x,spin),id + " repeated presentation stays still")
		rolling.tick = 2
		visual.present(Vector2.ZERO, 0.0, rolling, DriveFrame.new())
		check(is_zero_approx(visual.rolling_wheels[0].rotation.x),id + " reverse travel reverses spin")
		rolling.tick = 3
		rolling.steering = 0.5
		visual.present(Vector2(0,0.1), 0.0, rolling, DriveFrame.new())
		check(visual.front_wheels[0].rotation.y < 0.0 and visual.rolling_wheels[0].rotation.x < 0.0,id + " steering and rolling coexist")
		rolling.tick = 0
		visual.present(Vector2(100,100), 0.0, rolling, DriveFrame.new())
		check(is_zero_approx(visual.rolling_wheels[0].rotation.x),id + " restart resets wheel phase without teleport spin")
		visual.queue_free()
		await process_frame
	check(metrics.pickup.soil_5s_m > metrics.classic.soil_5s_m and metrics.pickup.soil_5s_m > metrics.formula.soil_5s_m and metrics.pickup.soil_5s_m > metrics.compact.soil_5s_m,"pickup leads loose-surface acceleration")
	check(metrics.pickup.turn_0_2s_deg < metrics.classic.turn_0_2s_deg and metrics.pickup.turn_0_2s_deg < metrics.formula.turn_0_2s_deg,"pickup rotates slower")
	check(metrics.pickup.brake_30_mps_m > metrics.classic.brake_30_mps_m and metrics.pickup.brake_30_mps_m > metrics.formula.brake_30_mps_m,"pickup has longer stopping distance")
	check(metrics.formula.asphalt_5s_m < metrics.classic.asphalt_5s_m,"classic beats Formula on long acceleration run")
	var classic: HandlingConfig = VehicleCatalog.config("classic")
	var control: HandlingConfig = classic.duplicate() as HandlingConfig
	control.lift_off_rotation = 0.0
	control.lift_off_grip_loss = 0.0
	var lift := VehicleSimulation.new(classic)
	var neutral := VehicleSimulation.new(control)
	lift.state.velocity = Vector2(0,28)
	neutral.state.velocity = Vector2(0,28)
	for tick: int in range(36):
		lift.step(DriveFrame.sample(0.75,0,0))
		neutral.step(DriveFrame.sample(0.75,0,0))
	check(lift.state.heading > neutral.state.heading+0.03 and absf(lift.state.slip_angle()) > absf(neutral.state.slip_angle()),"classic lift-off adds rear rotation and slip")
	for tick: int in range(180): lift.step(DriveFrame.sample(0,0.7,0))
	check(absf(lift.state.slip_angle()) < 0.03,"classic lift-off remains recoverable by unwinding and power")
	check(records.record(track,classic,100.0,[20.0,20.0,20.0,20.0,20.0]) == OK,"classic PB saved")
	check(records.best_for(track,VehicleCatalog.config("formula")) == 0.0,"classic PB never shown for Formula")
	records.settings.selected_car = "formula"
	check(records.save_records() == OK,"selection saves atomically")
	var reopened := LocalRecords.new(records.path)
	reopened.load_records()
	check(reopened.settings.get("selected_car") == "formula","selection survives reload")
	for suffix: String in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(records.path+suffix): DirAccess.remove_absolute(records.path+suffix)
	# Existing conservative route driver: completion/replay evidence, not optimal lap balance.
	for track_id: String in ["arto4", "hiekka", "ovaali3"]:
		for id: String in VehicleCatalog.IDS:
			if "--car=kart" in OS.get_cmdline_user_args() and id != "kart": continue
			await _laps(id,track_id)
	print("CAR_METRICS ",JSON.stringify(metrics))
	print("CAR_TESTS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func _laps(id: String, track_id: String) -> void:
	var track: NativeTrack = NativeTrack.read("res://tests/fixtures/legacy_tracks/slicks_"+track_id+"_test.json")
	var config: HandlingConfig = VehicleCatalog.config(id)
	var sim := VehicleSimulation.new(config)
	sim.reset(track.spawn,track.spawn_heading)
	sim.state.route_index = track.nearest_route(track.spawn)
	var driver := RouteDriver.new()
	var session := TrackSession.new(120,5)
	var frames: Array[Array] = []
	for tick: int in range(120*300):
		var previous: Vector2 = sim.state.position
		var frame: DriveFrame = driver.sample(sim.state,track,config)
		frames.append(frame.packed())
		sim.step(frame,track)
		session.advance(track,previous,sim.state.position,sim.state.route_index)
		if session.finished: break
	check(session.finished and session.completed_laps == 5,id+" completes five laps on "+track_id)
	var replay := VehicleSimulation.new(config)
	replay.reset(track.spawn,track.spawn_heading)
	replay.state.route_index = track.nearest_route(track.spawn)
	for packed: Array in frames:
		var frame := DriveFrame.new()
		frame.steer = packed[0]
		frame.throttle = packed[1]
		frame.brake = packed[2]
		replay.step(frame,track)
	check(sim.state.snapshot() == replay.state.snapshot(),id+" full lap replay matches on "+track_id)
	print("CAR_LAPS ",id," ",track_id," laps=",session.completed_laps," times=",session.lap_times," contacts=",sim.state.collision_count)
	await process_frame
