extends SceneTree

const PRESETS = preload("res://tests/fixtures/kart_final_reference/presets.gd")
const BEFORE = preload("res://tests/fixtures/kart_final_reference/brake_evolution.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ", message)

func measure(config: HandlingConfig, speed: float, steering: float, brake: float) -> Dictionary:
	var sim := VehicleSimulation.new(config)
	var replay := VehicleSimulation.new(config)
	sim.state.velocity = Vector2(0.0, speed)
	replay.state.velocity = sim.state.velocity
	var peak_slip := 0.0
	for tick: int in range(360):
		var frame := DriveFrame.sample(steering if tick < 60 else 0.0, 0.6 if tick >= 60 or brake == 0.0 else 0.0, brake if tick < 60 else 0.0)
		sim.step(frame)
		replay.step(frame)
		peak_slip = maxf(peak_slip, absf(sim.state.slip_angle()))
		if tick == 59:
			sim.set_meta("direction", atan2(sim.state.velocity.x, sim.state.velocity.y))
			sim.set_meta("position", sim.state.position)
			sim.set_meta("speed", sim.state.velocity.length())
	return {"direction": float(sim.get_meta("direction")), "position": sim.get_meta("position"), "turn_speed": float(sim.get_meta("speed")), "peak_slip": rad_to_deg(peak_slip), "end_slip": rad_to_deg(absf(sim.state.slip_angle())), "end_yaw": absf(sim.state.yaw_rate), "replay": sim.state.snapshot() == replay.state.snapshot()}

func run() -> void:
	check(PRESETS.names("kart") == ["Brake turn 5 (reference)", "Brake turn 5.1", "Brake turn 5.2", "Brake turn 5.3", "Brake turn 5.4", "Brake turn 5.5"], "reference and five options")
	var reference: HandlingConfig = PRESETS.config("kart", 0)
	check(reference.snapshot() == BEFORE.config("kart", 5).snapshot(), "preferred reference exactly preserved")
	var all_metrics: Array = []
	var reference_speed: float = 0.0
	var prior_powered: float = -INF
	var prior_braking: float = -INF
	for index: int in range(6):
		var config: HandlingConfig = PRESETS.config("kart", index)
		check(config.engine_force == reference.engine_force and config.braking_force == reference.braking_force and config.maximum_speed == reference.maximum_speed and config.brake_rotation == reference.brake_rotation and config.brake_grip_loss == reference.brake_grip_loss, "power and brake-turn character retained %d" % index)
		var powered: Dictionary = measure(config, 25.0, 0.7, 0.0)
		var braking: Dictionary = measure(config, 25.0, 0.7, 0.35)
		var mirror: Dictionary = measure(config, 25.0, -0.7, 0.35)
		if index == 0: reference_speed = powered.turn_speed
		else:
			check(powered.direction > prior_powered + 0.04, "powered travel turns more %d" % index)
			check(braking.direction > prior_braking + 0.002, "braking travel turns more %d" % index)
			check(powered.turn_speed >= reference_speed * 0.95, "powered corner retains at least 95 percent of reference speed %d" % index)
		prior_powered = powered.direction
		prior_braking = braking.direction
		check(powered.replay and braking.replay and mirror.replay, "exact replay %d" % index)
		check(absf(braking.direction + mirror.direction) < 0.0001, "left-right symmetry %d" % index)
		for sample: Dictionary in [powered, braking, mirror]:
			check(is_finite(sample.direction) and sample.peak_slip < 25.0 and sample.end_slip < 5.0 and sample.end_yaw < 0.1, "bounded and recovers %d" % index)
		for speed: float in [12.0, 20.0, 30.0]:
			for brake: float in [0.0, 0.35, 0.8]:
				var sample: Dictionary = measure(config, speed, 0.7, brake)
				check(sample.replay and is_finite(sample.direction) and sample.peak_slip < 25.0 and sample.end_slip < 5.0 and sample.end_yaw < 0.1, "bounded, recoverable replay at %.0f m/s brake %.2f mode %d" % [speed, brake, index])
		all_metrics.append({"powered_direction": powered.direction, "braking_direction": braking.direction, "powered_speed": powered.turn_speed, "braking_speed": braking.turn_speed, "peak_slip": maxf(powered.peak_slip, braking.peak_slip)})
	print("KART_TURN5_METRICS ", JSON.stringify(all_metrics))
	print("KART_TURN5: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
