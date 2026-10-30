extends SceneTree

const PRESETS = preload("res://tests/fixtures/volt_turn_reference/presets.gd")
var failures: int = 0
var checks: int = 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + label)

func measure(config: HandlingConfig, kmh: float, steer: float) -> Dictionary:
	var sim := VehicleSimulation.new(config)
	var replay := VehicleSimulation.new(config)
	sim.state.velocity = Vector2(0, kmh / 3.6)
	replay.state.velocity = sim.state.velocity
	var peak_slip: float = 0.0
	var finite: bool = true
	for tick: int in range(120):
		var frame := DriveFrame.sample(steer, 0.65, 0.0)
		sim.step(frame)
		replay.step(frame)
		peak_slip = maxf(peak_slip, absf(sim.state.slip_angle()))
		finite = finite and is_finite(sim.state.position.x) and is_finite(sim.state.position.y) and is_finite(sim.state.heading)
	var path: float = rad_to_deg(atan2(sim.state.velocity.x, sim.state.velocity.y))
	var speed: float = sim.state.velocity.length() * 3.6
	for tick: int in range(240):
		var frame := DriveFrame.sample(0.0, 0.65, 0.0)
		sim.step(frame)
		replay.step(frame)
		finite = finite and is_finite(sim.state.position.x) and is_finite(sim.state.position.y) and is_finite(sim.state.heading)
	return {"path":path, "peak":rad_to_deg(peak_slip), "speed":speed, "recovery":rad_to_deg(absf(sim.state.slip_angle())), "yaw":absf(sim.state.yaw_rate), "finite":finite, "replay":sim.state.snapshot() == replay.state.snapshot()}

func run() -> void:
	var reference: HandlingConfig = (load("res://tests/fixtures/volt_turn_reference/electric_26.tres") as HandlingConfig).duplicate()
	for property: String in {"steering_rate":10.0,"lateral_grip":70.0,"lateral_response":19.0,"power_lateral_response_scale":0.22,"countersteer_assistance":0.9,"grip_recovery":6.5}:
		reference.set(property, {"steering_rate":10.0,"lateral_grip":70.0,"lateral_response":19.0,"power_lateral_response_scale":0.22,"countersteer_assistance":0.9,"grip_recovery":6.5}[property])
	reference.profile_name += " / Slide"
	reference.version += "-test-4"
	check(PRESETS.config("electric", 0).snapshot() == reference.snapshot(), "original Slide snapshot and identity remain exact")
	check(PRESETS.names("electric") == ["Slide (reference)","Turn 1","Turn 2","Turn 3","Turn 4","Turn 5"], "reference and five named alternatives")
	var reference_snapshot: Dictionary = reference.snapshot()
	var metrics: Array = []
	for index: int in range(6):
		var config: HandlingConfig = PRESETS.config("electric", index)
		var snapshot: Dictionary = config.snapshot()
		if index > 0:
			for key: String in ["lateral_grip", "low_speed_turn_acceleration", "profile_name", "version"]:
				snapshot.erase(key)
			var unchanged: Dictionary = reference_snapshot.duplicate()
			for key: String in ["lateral_grip", "low_speed_turn_acceleration", "profile_name", "version"]: unchanged.erase(key)
			check(snapshot == unchanged, "candidate %d changes only grip, radius envelope and identity" % index)
		var candidate_metrics: Array = []
		for kmh: float in [50.0,100.0,140.0,180.0]:
			for input: float in [0.7,1.0]:
				var right: Dictionary = measure(config,kmh,input)
				var left: Dictionary = measure(config,kmh,-input)
				check(right.finite and left.finite and right.replay and left.replay, "finite deterministic candidate %d speed %.0f steer %.1f" % [index,kmh,input])
				check(absf(right.path + left.path) < 0.01 and absf(right.peak - left.peak) < 0.01, "mirrored steering candidate %d speed %.0f steer %.1f" % [index,kmh,input])
				check(right.recovery < 2.0 and right.yaw < 0.1 and left.recovery < 2.0 and left.yaw < 0.1, "released recovery candidate %d speed %.0f steer %.1f" % [index,kmh,input])
				check(right.peak < 45.0 and right.speed >= kmh * 0.80, "bounded slide and retained speed candidate %d speed %.0f steer %.1f" % [index,kmh,input])
				if index > 0 and kmh >= 100.0:
					var old: Dictionary = metrics[0][candidate_metrics.size()]
					check(right.path > old.path + 1.0, "more travel-direction change than reference candidate %d speed %.0f steer %.1f" % [index,kmh,input])
				if kmh == 50.0 and input == 1.0:
					check(right.peak > 20.0, "powered drift retained candidate %d" % index)
				candidate_metrics.append(right)
		metrics.append(candidate_metrics)
	# Long held corners followed by opposite steering exercise a different path
	# from the short release samples above, including high-speed entry.
	var stress_metrics: Array = []
	for index: int in range(6):
		var config: HandlingConfig = PRESETS.config("electric", index)
		for kmh: float in [50.0, 100.0, 140.0, 180.0]:
			for side: float in [-1.0, 1.0]:
				var sim := VehicleSimulation.new(config)
				sim.state.velocity = Vector2(0.0, kmh / 3.6)
				var peak: float = 0.0
				var finite: bool = true
				for tick: int in range(720):
					var steer: float = side if tick < 360 else -side if tick < 480 else 0.0
					sim.step(DriveFrame.sample(steer, 1.0, 0.0))
					peak = maxf(peak, absf(sim.state.slip_angle()))
					finite = finite and is_finite(sim.state.position.x) and is_finite(sim.state.position.y) and is_finite(sim.state.heading)
				var last_slip: float = rad_to_deg(absf(sim.state.slip_angle()))
				stress_metrics.append([index,kmh,side,rad_to_deg(peak),last_slip,sim.state.velocity.length()*3.6])
				check(finite and rad_to_deg(peak) < 60.0, "sustained full power stays finite and bounded candidate %d speed %.0f side %.0f" % [index,kmh,side])
				check(last_slip < 2.0 and absf(sim.state.yaw_rate) < 0.1, "countersteer and release recover candidate %d speed %.0f side %.0f" % [index,kmh,side])
	print("VOLT_TURN_METRICS ",JSON.stringify(metrics))
	print("VOLT_TURN_STRESS ",JSON.stringify(stress_metrics))
	print("VOLT_TURN_TEST ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
