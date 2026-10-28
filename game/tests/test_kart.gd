extends SceneTree
## Measured kart tradeoffs; same inputs and unchanged canonical simulation.
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ",label)

func _run() -> void:
	var kart: HandlingConfig = VehicleCatalog.config("kart")
	_check_top_speed(kart)
	_check_soil(kart)
	_check_edge(kart)
	_check_tighter_turn(kart)
	var compact: HandlingConfig = VehicleCatalog.config("compact")
	var formula: HandlingConfig = VehicleCatalog.config("formula")
	check(kart.track_width < compact.track_width and kart.wheelbase < compact.wheelbase,"kart has narrower track and shorter wheelbase")
	check(kart.maximum_speed < formula.maximum_speed,"kart speed cap below Formula")
	var metrics: Dictionary = {}
	for id: String in ["compact","formula","kart"]:
		var config: HandlingConfig = VehicleCatalog.config(id)
		var sim := VehicleSimulation.new(config)
		var ticks_to_20: int = 0
		for tick: int in range(1200):
			sim.step(DriveFrame.sample(0,1,0))
			if ticks_to_20 == 0 and sim.state.velocity.length() >= 20.0: ticks_to_20 = tick+1
		var turn := VehicleSimulation.new(config)
		turn.state.velocity = Vector2(0,10)
		for tick: int in range(60): turn.step(DriveFrame.sample(1,0,0))
		var radius: float = turn.state.velocity.length()/absf(turn.state.yaw_rate)
		var grip := VehicleSimulation.new(config)
		grip.state.velocity = Vector2(0,14)
		var peak_slip: float = 0.0
		for tick: int in range(180):
			grip.step(DriveFrame.sample(0.55,0.5,0))
			peak_slip = maxf(peak_slip,absf(grip.state.slip_angle()))
		metrics[id] = {"to_20_mps_s":ticks_to_20/120.0,"speed_10s_mps":sim.state.velocity.length(),"low_speed_radius_m":radius,"powered_bend_peak_slip_degrees":rad_to_deg(peak_slip)}
	check(metrics.kart.to_20_mps_s < metrics.compact.to_20_mps_s and metrics.kart.to_20_mps_s < metrics.formula.to_20_mps_s,"kart accelerates faster to 72 km/h")
	check(metrics.kart.low_speed_radius_m < metrics.compact.low_speed_radius_m*0.8 and metrics.kart.low_speed_radius_m < metrics.formula.low_speed_radius_m*0.8,"kart turns at least 20 percent tighter at low speed")
	check(metrics.kart.powered_bend_peak_slip_degrees < 12.0,"kart holds powered bend with little slip")
	check(metrics.kart.speed_10s_mps <= kart.maximum_speed and metrics.kart.speed_10s_mps < metrics.compact.speed_10s_mps,"long straight gives compact the advantage")
	var car := CarVisual.new()
	car.vehicle_id = "kart"
	root.add_child(car)
	check(car.front_wheels.size() == 2,"kart front wheels steer")
	var width: float = absf(car.front_wheels[0].position.x-car.front_wheels[1].position.x)*HandlingConfig.BODY_SCALE
	check(is_equal_approx(width,kart.track_width),"visible axle matches canonical width")
	check(is_equal_approx(absf(car.front_wheels[0].position.z)*2.0*HandlingConfig.BODY_SCALE,kart.wheelbase),"visible wheelbase matches canonical wheelbase")
	var state := VehicleState.new()
	state.steering = 0.5
	car.present(Vector2.ZERO,0,state,DriveFrame.new())
	check(car.front_wheels[0].rotation.y < 0.0,"steering animates in correct direction")
	car.present_suspension(state,0)
	state.tick = 1
	state.velocity = Vector2(0,0.15)
	car.present_suspension(state,0)
	check(absf(car.body.rotation.x) < 0.04,"stiff kart chassis has restrained pitch")
	car.queue_free()
	await process_frame
	var path: String = "user://kart_preference_"+TrackLibrary.unique_id()+".json"
	var records := LocalRecords.new(path)
	records.settings.selected_car = "kart"
	check(records.save_records() == OK,"kart preference accepted by persistence")
	var reopen := LocalRecords.new(path)
	reopen.load_records()
	check(reopen.settings.get("selected_car") == "kart","kart preference survives reload")
	DirAccess.remove_absolute(path)
	print("KART_METRICS ",JSON.stringify(metrics))
	print("KART_TESTS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func _check_top_speed(kart: HandlingConfig) -> void:
	check(absf(kart.maximum_speed*3.6-140.0) < 0.001,"kart has the owner-requested 140 km/h cap")
	check(kart.version == "kart-5","higher speed has a separate handling identity")
	var previous: HandlingConfig = kart.duplicate() as HandlingConfig
	previous.version = "kart-4"
	previous.maximum_speed = 30.0
	var values: Dictionary = kart.snapshot()
	var old_values: Dictionary = previous.snapshot()
	for key: String in ["version","maximum_speed"]:
		values.erase(key)
		old_values.erase(key)
	check(values == old_values,"top-speed tuning preserves every other handling field")
	var sim := VehicleSimulation.new(kart)
	var old := VehicleSimulation.new(previous)
	var replay := VehicleSimulation.new(kart)
	var launch_no_slower: bool = true
	var first_tick_equal: bool = false
	var exact_replay: bool = true
	var maximum: float = 0
	var to_target: int = 0
	for tick: int in range(3600):
		var frame: DriveFrame = DriveFrame.sample(0,1,0)
		old.step(frame)
		sim.step(frame)
		replay.step(frame)
		if tick == 0: first_tick_equal = sim.state.snapshot() == old.state.snapshot()
		if old.state.velocity.length() < 29.99: launch_no_slower = launch_no_slower and sim.state.velocity.length() >= old.state.velocity.length()
		exact_replay = exact_replay and sim.state.snapshot() == replay.state.snapshot()
		maximum = maxf(maximum,sim.state.velocity.length())
		if to_target == 0 and sim.state.velocity.length()*3.6 >= 139.99: to_target = tick+1
	check(first_tick_equal,"initial launch tick retains the original engine force")
	check(launch_no_slower,"higher cap preserves at least the previous launch acceleration")
	check(to_target > 0 and absf(maximum*3.6-140.0) < 0.001,"full throttle reaches and holds 140 km/h")
	check(maximum <= kart.maximum_speed,"sustained full throttle never exceeds the configured cap")
	check(exact_replay,"30 seconds at the new cap replays exactly")
	var brake_start: Vector2 = sim.state.position
	var stop_ticks: int = 0
	for tick: int in range(480):
		sim.step(DriveFrame.sample(0,0,1))
		if sim.state.velocity.length() < 0.15:
			stop_ticks = tick+1
			break
	check(stop_ticks > 0,"the existing brakes stop the kart from 140 km/h")
	var track: NativeTrack = NativeTrack.read("res://tests/fixtures/legacy_tracks/slicks_arto4_test.json")
	var records := LocalRecords.new("user://kart_speed_identity.json")
	check(records.key_for(track,kart) != records.key_for(track,previous),"new speed cannot merge with earlier kart PB rules")
	print("KART_TOP_SPEED ",JSON.stringify({"version":kart.version,"config_hash":JSON.stringify(kart.snapshot(),"",true).sha256_text(),"maximum_kmh":maximum*3.6,"to_140_s":to_target/120.0,"brake_stop_s":stop_ticks/120.0,"brake_distance_m":sim.state.position.distance_to(brake_start)}))

func _check_soil(kart: HandlingConfig) -> void:
	var previous: HandlingConfig = kart.duplicate() as HandlingConfig
	previous.soil_drag_multiplier = 3.0
	previous.wheel_soil_drag = false
	for kind: int in [0, 1, 2]:
		var track := NativeTrack.new()
		track.cell_size = 10.0
		track.grid_width = 100
		track.grid_height = 100
		track.half_extent = Vector2(500,500)
		track.cells.resize(10000)
		track.cells.fill(kind)
		track.deck_cells.resize(10000)
		track.deck_cells.fill(-1)
		track.route = PackedVector2Array([Vector2(0,-400),Vector2(0,400)])
		var before := VehicleSimulation.new(previous)
		var after := VehicleSimulation.new(kart)
		before.state.velocity = Vector2(0,30)
		after.state.velocity = Vector2(0,30)
		var asphalt_equal: bool = true
		for tick: int in range(120):
			before.step(DriveFrame.sample(0,1,0),track)
			after.step(DriveFrame.sample(0,1,0),track)
			asphalt_equal = asphalt_equal and before.state.snapshot() == after.state.snapshot()
		print("KART_SOIL_ENTRY kind=%d before_mps=%.3f after_mps=%.3f" % [kind,before.state.velocity.length(),after.state.velocity.length()])
		if kind == 0:
			check(asphalt_equal,"soil tuning leaves every asphalt entry tick unchanged")
		else:
			check(after.state.velocity.length() < before.state.velocity.length()*0.85,"kart slows at least 15 percent more after one second on surface %d" % kind)
			var escape := VehicleSimulation.new(kart)
			for tick: int in range(240): escape.step(DriveFrame.sample(0,1,0),track)
			check(escape.state.position.y > 10.0,"kart can accelerate out of surface %d from rest" % kind)


func _check_edge(kart: HandlingConfig) -> void:
	var track := NativeTrack.new()
	track.cell_size = 10.0
	track.grid_width = 100
	track.grid_height = 100
	track.half_extent = Vector2(500,500)
	track.cells.resize(10000)
	track.cells.fill(0)
	track.deck_cells.resize(10000)
	track.deck_cells.fill(-1)
	track.route = PackedVector2Array([Vector2(0,-400),Vector2(0,400)])
	# Only the quadrant x>=0, y<=0 is dirt: center remains on asphalt.
	for row: int in range(50,100):
		for col: int in range(50,100): track.cells[row*100+col] = 2
	var sim := VehicleSimulation.new(kart)
	for heading: float in [0.0, PI*0.5, PI, PI*1.5]:
		sim.reset(Vector2(-0.2,0.2),heading)
		check(track.tire_pickup(sim.state) == 0.0 and sim._wheel_soil_contact(track,0.0) == 1.0,"one wheel detects dirt with center on asphalt at heading %.2f" % heading)
	sim.reset(Vector2(-0.2,0.2))
	sim.state.velocity = Vector2(0,30)
	var clean := VehicleSimulation.new(kart)
	clean.reset(Vector2(-2,0.2))
	clean.state.velocity = Vector2(0,30)
	sim.step(DriveFrame.sample(0,1,0),track)
	clean.step(DriveFrame.sample(0,1,0),track)
	check(sim.state.velocity.length() < clean.state.velocity.length(),"single wheel dirt contact slows kart on first tick under throttle")
	# Parallel to the dirt boundary, the chassis stays on asphalt for the entire run.
	sim.reset(Vector2(-0.2,-100))
	sim.state.velocity = Vector2(0,30)
	var replay := VehicleSimulation.new(kart)
	replay.reset(sim.state.position)
	replay.state.velocity = sim.state.velocity
	for tick: int in range(120):
		sim.step(DriveFrame.sample(0,1,0),track)
		replay.step(DriveFrame.sample(0,1,0),track)
	check(sim.state.velocity.length() < 12.0,"road-edge clipping rapidly cuts speed and can pull the center into soil")
	check(sim.state.snapshot() == replay.state.snapshot(),"partial dirt contact replays exactly")
	print("KART_EDGE speed_after_1s_mps=",sim.state.velocity.length())
	sim.reset(Vector2(-2,-100))
	check(sim._wheel_soil_contact(track,0.0) == 0.0,"fully rejoining asphalt clears wheel soil resistance")
	track.deck_cells.fill(0)
	sim.reset(Vector2(-0.2,-100))
	sim.state.track_elevated = true
	check(sim._wheel_soil_contact(track,0.0) == 0.0,"asphalt bridge shields wheels from dirt below")


func _check_tighter_turn(kart: HandlingConfig) -> void:
	var previous: HandlingConfig = kart.duplicate() as HandlingConfig
	previous.steering_angle = 0.72
	previous.maximum_yaw_rate = 3.6
	for speed: float in [6.0,10.0]:
		for direction: float in [-1.0,1.0]:
			var radii: Array[float] = []
			for config: HandlingConfig in [previous,kart]:
				var sim := VehicleSimulation.new(config)
				sim.state.velocity = Vector2(0,speed)
				for tick: int in range(60): sim.step(DriveFrame.sample(direction,0,0))
				radii.append(sim.state.velocity.length()/absf(sim.state.yaw_rate))
			check(radii[1] < radii[0]*0.90,"kart turns at least 10 percent tighter at %.0f m/s in direction %.0f" % [speed,direction])
			print("KART_TURN speed=%.0f direction=%.0f before_radius=%.3f after_radius=%.3f" % [speed,direction,radii[0],radii[1]])
	var before := VehicleSimulation.new(previous)
	var after := VehicleSimulation.new(kart)
	var same: bool = true
	for tick: int in range(600):
		before.step(DriveFrame.sample(0,1,0))
		after.step(DriveFrame.sample(0,1,0))
		same = same and before.state.snapshot() == after.state.snapshot()
	check(same,"tighter steering preserves straight-line acceleration and speed")
