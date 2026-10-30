extends SceneTree
## Compare the accepted candidate against the complete task-start config, not
## against the mutable experimental preset table.

var checks: int = 0
var failures: int = 0
const PRIOR_PRESETS = preload("res://tests/fixtures/volt_turn_reference/presets.gd")

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + message)

func run() -> void:
	var original: HandlingConfig = load("res://../docs/evidence/forklift-agile-locked-2026-10-30/before/forklift.tres")
	var expected: HandlingConfig = original.duplicate() as HandlingConfig
	check(PRIOR_PRESETS.LABELS[1] == "Agile", "independent retained preset fixture identifies the chosen option")
	for property: String in PRIOR_PRESETS.TUNING.forklift[1]:
		expected.set(property, PRIOR_PRESETS.TUNING.forklift[1][property])
	var actual: HandlingConfig = VehicleCatalog.config("forklift")
	check(original.version == "forklift-4", "frozen source is the previous production configuration")
	check(actual.version != original.version, "changed canonical handling has a new identity")
	var old_values: Dictionary = expected.snapshot()
	var new_values: Dictionary = actual.snapshot()
	old_values.erase("version")
	new_values.erase("version")
	check(new_values == old_values, "every handling field matches the previous Agile candidate")
	check(actual.rear_steering and actual.maximum_speed == original.maximum_speed and actual.engine_force == original.engine_force and actual.braking_force == original.braking_force, "forklift drive layout, power, speed and brakes remain intact")
	for initial_speed: float in [0.0, 8.0, 18.0]:
		var chosen := VehicleSimulation.new(expected)
		var production := VehicleSimulation.new(actual)
		chosen.state.velocity = Vector2(0, initial_speed)
		production.state.velocity = chosen.state.velocity
		var exact: bool = true
		for tick: int in range(1200):
			var steering: float = sin(float(tick) * 0.019) if tick < 900 else 0.0
			var throttle: float = 0.72 if tick < 600 else 0.15 if tick < 900 else 0.0
			var brake: float = 0.3 if tick >= 600 and tick < 900 else 0.0
			var frame: DriveFrame = DriveFrame.sample(steering, throttle, brake)
			chosen.step(frame)
			production.step(frame)
			if chosen.state.snapshot() != production.state.snapshot():
				exact = false
				break
		check(exact, "Agile and canonical simulation remain exact over mixed inputs from %.0f m/s" % initial_speed)
	print("FORKLIFT_AGILE_LOCKED: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
