extends "res://backend/runner.gd"
## Compare the actual prior resource, including momentum and turn-in/settling.
const BEFORE = preload("res://tests/fixtures/hovercraft_power_turn_before.tres")
const OUTPUT: String = "res://../docs/evidence/hovercraft-power-turn-2026-10-28/"
var checks: int = 0
var failures: int = 0
var metrics: Dictionary = {}

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ",label)

func moving(config: HandlingConfig, speed: float) -> VehicleSimulation:
	var sim := VehicleSimulation.new(config)
	sim.state.velocity = Vector2(0,speed)
	return sim

func advance(sim: VehicleSimulation, count: int, steer: float = 0.0, throttle: float = 0.0, brake: float = 0.0) -> void:
	for tick: int in range(count): sim.step(DriveFrame.sample(steer,throttle,brake))

func run() -> void:
	OS.set_environment("BMT_API_URL","")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var after: HandlingConfig = VehicleCatalog.config("hovercraft")
	var baseline: Dictionary = BEFORE.snapshot()
	var current: Dictionary = after.snapshot()
	check(after.version == "hovercraft-2","new handling identity")
	for field: String in baseline:
		if field in ["version","maximum_yaw_rate","engine_force"]: continue
		check(baseline[field] == current[field],"preserved handling parameter: "+field)
	check(JSON.stringify(baseline,"",true).sha256_text() != JSON.stringify(current,"",true).sha256_text(),"new tune has a distinct record/replay identity")
	check(manifest().vehicles.hovercraft.config_hash == JSON.stringify(current,"",true).sha256_text(),"worker advertises the complete current tune")
	var samples: Array = []
	for config: HandlingConfig in [BEFORE,after]:
		var turn: VehicleSimulation = moving(config,20.0)
		advance(turn,60,0.6,0.5)
		var turn_rate: float = turn.state.yaw_rate
		var heading: float = turn.state.heading
		var slip: float = absf(turn.state.slip_angle())
		# A released rudder still has a finite unwind and angular settling time.
		advance(turn,12)
		var release_rate: float = turn.state.yaw_rate
		advance(turn,228)
		check(absf(turn.state.yaw_rate) < 0.001,"released rotation settles: "+config.version)
		check(release_rate > turn_rate*0.35,"release retains angular inertia: "+config.version)
		var thrust: VehicleSimulation = moving(config,0.0)
		advance(thrust,120,0,1)
		var one_second: float = thrust.state.velocity.length()
		var sixty_ticks: int = 120
		while thrust.state.velocity.length() < 60.0/3.6 and sixty_ticks < 2400:
			advance(thrust,1,0,1)
			sixty_ticks += 1
		advance(thrust,2400,0,1)
		check(thrust.state.velocity.length() <= config.maximum_speed and thrust.state.velocity.length() > 35.0,"130 km/h cap remains attainable and bounded: "+config.version)
		samples.append({"version":config.version,"heading_0_5s_degrees":rad_to_deg(heading),"yaw_0_5s_degrees_per_second":rad_to_deg(turn_rate),"slip_0_5s_degrees":rad_to_deg(slip),"release_0_1s_yaw":release_rate,"speed_1s_kph":one_second*3.6,"zero_to_60_seconds":sixty_ticks/120.0})
	check(samples[1].heading_0_5s_degrees > samples[0].heading_0_5s_degrees*1.30,"body turns at least 30% farther during the first half-second")
	check(samples[1].speed_1s_kph > samples[0].speed_1s_kph*1.25,"throttle supplies a materially stronger push")
	check(samples[1].zero_to_60_seconds < samples[0].zero_to_60_seconds*0.80,"0-60 acceleration improves by at least 20%")
	check(samples[1].slip_0_5s_degrees > 10.0,"turning still retains a visible cushion slide")
	metrics.comparison = samples
	var old_coast: VehicleSimulation = moving(BEFORE,20.0)
	var new_coast: VehicleSimulation = moving(after,20.0)
	old_coast.state.velocity.x = 10.0
	new_coast.state.velocity.x = 10.0
	advance(old_coast,60)
	advance(new_coast,60)
	check(new_coast.state.snapshot() == old_coast.state.snapshot(),"unpowered straight coasting and sideways momentum remain exactly unchanged")
	check(new_coast.state.velocity.x > 6.0,"more than 60% of sideways momentum remains after half a second")
	var angular: VehicleSimulation = moving(after,20.0)
	angular.state.yaw_rate = 1.0
	advance(angular,1)
	check(angular.state.yaw_rate > 0.9 and angular.state.yaw_rate < 1.0,"angular velocity decays rather than snapping to steering demand")
	var matrix: Array = []
	for speed: float in [0.0,5.0,15.0,25.0,35.0]:
		for steer: float in [-1.0,-0.5,0.5,1.0]:
			for throttle: float in [0.0,0.5,1.0]:
				var sim: VehicleSimulation = moving(after,speed)
				var bounded: bool = true
				for tick: int in range(120):
					var previous_speed: float = sim.state.velocity.length()
					advance(sim,1,steer,throttle)
					bounded = bounded and is_finite(sim.state.heading) and sim.state.velocity.is_finite() and sim.state.velocity.length() <= after.maximum_speed+0.00001
					if throttle == 0.0: bounded = bounded and sim.state.velocity.length() <= previous_speed+0.00001
				check(bounded,"finite bounded turn without unpowered energy gain: %s/%s/%s" % [speed,steer,throttle])
				matrix.append({"speed":speed,"steer":steer,"throttle":throttle,"slip_degrees":rad_to_deg(absf(sim.state.slip_angle())),"final_mps":sim.state.velocity.length()})
	metrics.turns = matrix
	var original := VehicleSimulation.new(after)
	var replay := VehicleSimulation.new(after)
	var frames: Array = []
	var saved: Dictionary = {}
	var yard := PlaygroundData.new()
	for tick: int in range(3600):
		var frame := DriveFrame.sample(sin(tick*0.017)*0.7,1.0 if tick%480<320 else 0.0,0.8 if tick%480>390 else 0.0)
		frames.append(frame.packed())
		original.step(frame,yard)
		if tick == 1799: saved = RewindHistory.pack_state(original.state)
	var decoded: Array = JSON.parse_string(JSON.stringify(frames))
	for packed: Array in decoded: replay.step(unpack(packed),yard)
	check(replay.state.snapshot() == original.state.snapshot(),"3600 serialized inputs replay exactly through collisions")
	RewindHistory.restore(replay.state,saved)
	for tick: int in range(1800,3600): replay.step(unpack(decoded[tick]),yard)
	check(replay.state.snapshot() == original.state.snapshot(),"rewind continuation remains exact")
	var file := FileAccess.open(OUTPUT+"report.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"metrics":metrics},"\t"))
	file.close()
	print("HOVERCRAFT_POWER_TURN: %d checks, %d failures; %s" % [checks,failures,JSON.stringify(samples)])
	quit(1 if failures else 0)

func unpack(packed: Array) -> DriveFrame:
	return DriveFrame.sample(float(packed[0])/127.0,float(packed[1])/255.0,float(packed[2])/255.0,float(packed[3])/255.0 if packed.size() > 3 else 0.0)
