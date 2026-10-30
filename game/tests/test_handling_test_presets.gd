extends SceneTree

const PRESETS = preload("res://vehicle/handling_test_presets.gd")

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

func run() -> void:
	var compact: HandlingConfig = VehicleCatalog.config("compact")
	check(PRESETS.names("compact").is_empty(), "Compact has no test choices")
	for index: int in range(-1, 5):
		check(PRESETS.config("compact", index).snapshot() == compact.snapshot(), "Compact remains exact %d" % index)
	var metrics: Dictionary = {}
	for vehicle: String in PRESETS.VEHICLES:
		var baseline: HandlingConfig = VehicleCatalog.config(vehicle)
		check(PRESETS.config(vehicle, -1).snapshot() == baseline.snapshot(), "%s baseline exact" % vehicle)
		var count: int = 6 if vehicle in ["kart", "hovercraft"] else 5
		check(PRESETS.names(vehicle).size() == count, "%s expected choices" % vehicle)
		var outcomes: Array[Vector2] = []
		var cases: Array = []
		for index: int in range(count):
			var config: HandlingConfig = PRESETS.config(vehicle, index)
			check(config.version != baseline.version, "%s %d distinct identity" % [vehicle, index])
			check(config.maximum_speed == baseline.maximum_speed and config.engine_force == baseline.engine_force and config.braking_force == baseline.braking_force, "%s %d unchanged powertrain" % [vehicle, index])
			var sim := VehicleSimulation.new(config)
			var replay := VehicleSimulation.new(config)
			var brake_probe := VehicleSimulation.new(config) if vehicle == "kart" else null
			sim.state.velocity = Vector2(0, minf(15.0, config.maximum_speed * 0.65))
			replay.state.velocity = sim.state.velocity
			if brake_probe != null: brake_probe.state.velocity = Vector2(0, 25.0)
			var peak_slip: float = 0.0
			for tick: int in range(600):
				var frame := DriveFrame.sample(0.7 if tick < 120 else 0.0, 0.65, 0.0)
				sim.step(frame)
				replay.step(frame)
				if brake_probe != null and tick < 120: brake_probe.step(DriveFrame.sample(0.7, 0.0, 0.35))
				peak_slip = maxf(peak_slip, absf(sim.state.slip_angle()))
				check(is_finite(sim.state.position.x) and is_finite(sim.state.position.y) and is_finite(sim.state.velocity.x) and is_finite(sim.state.velocity.y) and is_finite(sim.state.heading), "%s %d finite tick %d" % [vehicle, index, tick])
				if tick == 119: outcomes.append(brake_probe.state.position if brake_probe != null else sim.state.position)
			check(sim.state.snapshot() == replay.state.snapshot(), "%s %d deterministic replay" % [vehicle, index])
			check(absf(sim.state.slip_angle()) < deg_to_rad(5.0) and absf(sim.state.yaw_rate) < 0.1, "%s %d recovers after steering release" % [vehicle, index])
			cases.append({"turn_end": [outcomes[-1].x, outcomes[-1].y], "peak_slip_deg": rad_to_deg(peak_slip), "recovery_slip_deg": rad_to_deg(absf(sim.state.slip_angle()))})
		for left: int in range(outcomes.size()):
			for right: int in range(left + 1, outcomes.size()):
				check(outcomes[left].distance_to(outcomes[right]) > 0.01, "%s %d and %d distinguishable" % [vehicle, left, right])
		metrics[vehicle] = cases
	print("HANDLING_TEST_PRESET_METRICS ", JSON.stringify(metrics))
	for failure: String in failures: push_error(failure)
	print("HANDLING_TEST_PRESETS: %d failures" % failures.size())
	quit(0 if failures.is_empty() else 1)
