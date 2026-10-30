extends SceneTree

# Preserve the original five-mode regression against the historical definitions.
const PRESETS = preload("res://tests/fixtures/kart_final_reference/earlier_refinements.gd")
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ", description)

func maneuver(config: HandlingConfig, speed: float, steering: float, gas: float, brake: float, ticks: int) -> Dictionary:
	var sim := VehicleSimulation.new(config)
	sim.state.velocity = Vector2(0, speed)
	var peak_slip: float = 0.0
	for tick: int in range(ticks):
		sim.step(DriveFrame.sample(steering, gas, brake))
		peak_slip = maxf(peak_slip, absf(sim.state.slip_angle()))
	return {"heading": sim.state.heading, "speed": sim.state.velocity.length(), "slip": rad_to_deg(peak_slip), "steering": sim.state.steering}

func run() -> void:
	var baseline: HandlingConfig = load("res://tests/fixtures/kart_final_reference/kart7.tres")
	var names: Array[String] = PRESETS.names("kart")
	check(names == ["Quick", "Tight", "Flow", "Brake turn", "Playful"], "only five new kart options")
	check(PRESETS.config("kart", -1).snapshot() == baseline.snapshot(), "current handling remains the exact reference")
	var configs: Array[HandlingConfig] = [baseline]
	for index: int in range(5):
		var config: HandlingConfig = PRESETS.config("kart", index)
		configs.append(config)
		check(config.version != baseline.version and config.vehicle_id == "kart", "test has separate kart identity")
		check(config.engine_force == baseline.engine_force and config.braking_force == baseline.braking_force and config.maximum_speed == baseline.maximum_speed, "power, braking and speed limit retained")
		check(maneuver(config, 0.0, 0.0, 1.0, 0.0, 240) == maneuver(baseline, 0.0, 0.0, 1.0, 0.0, 240), "straight acceleration matches reference")
	var measurements: Array = []
	for config: HandlingConfig in configs:
		measurements.append({"response": maneuver(config, 15.0, 1.0, 0.5, 0.0, 3), "fast_turn": maneuver(config, 30.0, 0.7, 0.5, 0.0, 90), "turn": maneuver(config, 15.0, 0.7, 0.65, 0.0, 120), "braking": maneuver(config, 25.0, 0.7, 0.0, 0.35, 60)})
	check(measurements[1].response.steering > measurements[0].response.steering * 1.20, "Quick builds steering faster")
	check(angle_difference(measurements[0].turn.heading, measurements[2].turn.heading) > 0.06, "Tight rotates further in a powered bend")
	check(measurements[3].turn.speed > measurements[0].turn.speed + 0.05, "Flow retains more speed in the sampled bend")
	check(measurements[4].braking.heading > measurements[0].braking.heading + 0.025, "Brake turn adds rotation while braking")
	check(measurements[5].turn.slip > measurements[0].turn.slip + 1.0 and measurements[5].turn.slip < 12.0, "Playful adds a bounded amount of slide")
	print("KART_REFINEMENT_METRICS ", JSON.stringify(measurements))
	print("KART_REFINEMENT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
