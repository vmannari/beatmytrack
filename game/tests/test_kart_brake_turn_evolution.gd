extends SceneTree

const PRESETS = preload("res://tests/fixtures/kart_final_reference/brake_evolution.gd")
const PREVIOUS = preload("res://tests/fixtures/kart_final_reference/earlier_refinements.gd")
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ", message)

func drive(config: HandlingConfig, speed: float, steer: float, brake: float) -> Dictionary:
	var sim := VehicleSimulation.new(config)
	var replay := VehicleSimulation.new(config)
	sim.state.velocity = Vector2(0, speed)
	replay.state.velocity = sim.state.velocity
	var peak: float = 0.0
	for tick: int in range(360):
		var input := DriveFrame.sample(steer if tick < 60 else 0.0, 0.0 if tick < 60 else 0.65, brake if tick < 60 else 0.0)
		sim.step(input)
		replay.step(input)
		peak = maxf(peak, absf(sim.state.slip_angle()))
		if tick == 59:
			var turn_heading: float = sim.state.heading
			sim.set_meta("turn_heading", turn_heading)
	return {"heading": float(sim.get_meta("turn_heading")), "peak_slip": rad_to_deg(peak), "end_slip": rad_to_deg(absf(sim.state.slip_angle())), "end_yaw": absf(sim.state.yaw_rate), "speed": sim.state.velocity.length(), "replay": sim.state.snapshot() == replay.state.snapshot()}

func run() -> void:
	check(PRESETS.names("kart") == ["Brake turn (reference)", "Brake turn 1", "Brake turn 2", "Brake turn 3", "Brake turn 4", "Brake turn 5"], "five alternatives and the reference")
	var reference: HandlingConfig = PRESETS.config("kart", 0)
	check(reference.snapshot() == PREVIOUS.config("kart", 3).snapshot(), "preferred Brake turn is unchanged including identity")
	var all_metrics: Array = []
	var previous_heading: float = -INF
	for index: int in range(6):
		var config: HandlingConfig = PRESETS.config("kart", index)
		check(config.engine_force == reference.engine_force and config.braking_force == reference.braking_force and config.maximum_speed == reference.maximum_speed, "power, brakes and speed retained %d" % index)
		if index > 0: check(config.version != reference.version, "new identity %d" % index)
		var metrics: Dictionary = drive(config, 25.0, 0.7, 0.35)
		var mirror: Dictionary = drive(config, 25.0, -0.7, 0.35)
		check(metrics.heading > previous_heading + 0.005, "braking rotation increases %d" % index)
		previous_heading = metrics.heading
		check(absf(metrics.heading + mirror.heading) < 0.0001, "mirrored rotation %d" % index)
		check(metrics.replay and mirror.replay, "deterministic replay %d" % index)
		check(metrics.end_slip < 5.0 and metrics.end_yaw < 0.1 and is_finite(metrics.speed), "settles after release %d" % index)
		for speed: float in [12.0, 20.0, 30.0]:
			for brake: float in [0.35, 0.8]:
				var sample: Dictionary = drive(config, speed, 0.7, brake)
				check(sample.replay and is_finite(sample.heading) and sample.peak_slip < 25.0 and sample.end_slip < 5.0 and sample.end_yaw < 0.1, "bounded and repeatable at %.0f m/s brake %.2f mode %d" % [speed, brake, index])
		all_metrics.append(metrics)
	print("KART_BRAKE_EVOLUTION_METRICS ", JSON.stringify(all_metrics))
	print("KART_BRAKE_EVOLUTION: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
