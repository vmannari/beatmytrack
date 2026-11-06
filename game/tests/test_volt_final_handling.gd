extends SceneTree

const OLD_PRESETS = preload("res://tests/fixtures/volt_turn_reference/presets.gd")
const PRESETS = preload("res://vehicle/handling_test_presets.gd")
var checks := 0
var failures := 0

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("FAIL: " + label)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var chosen: HandlingConfig = OLD_PRESETS.config("electric", 5)
	# The selected Turn 5 remains the reference, with the later approved
	# parking-speed correction independently covered by test_volt_slow_steering.
	chosen.low_speed_steering_scale = 0.75
	var final: HandlingConfig = VehicleCatalog.config("electric")
	var old_values: Dictionary = chosen.snapshot()
	var new_values: Dictionary = final.snapshot()
	check(final.version == "electric-29" and final.profile_name == "Volt", "final Volt has its own standard identity")
	check(final.winter_road_grip == 0.90, "winter road grip is reduced")
	old_values.erase("version")
	old_values.erase("profile_name")
	new_values.erase("version")
	new_values.erase("profile_name")
	new_values.erase("winter_road_grip")
	check(old_values == new_values, "physical fields match Turn 5 plus approved parking correction")
	check(PRESETS.names("electric").is_empty(), "final Volt offers no experimental choices")
	check(PRESETS.config("electric", 5).snapshot() == final.snapshot(), "direct test selection cannot replace final Volt")
	for start_speed: float in [0.0, 50.0, 100.0, 140.0, 180.0]:
		var before := VehicleSimulation.new(chosen)
		var after := VehicleSimulation.new(final)
		before.state.velocity = Vector2(0.0, start_speed / 3.6)
		after.state.velocity = before.state.velocity
		var exact := true
		for tick: int in range(1800):
			var steer: float = 0.7 if tick < 360 else -0.7 if tick < 720 else 0.0
			var frame := DriveFrame.sample(steer, 0.65 if tick < 1200 else 0.0, 0.0)
			before.step(frame)
			after.step(frame)
			exact = exact and before.state.snapshot() == after.state.snapshot()
		check(exact, "selected and final simulations match every tick at %.0f km/h" % start_speed)
	print("VOLT_FINAL_HASH ", JSON.stringify(final.snapshot(), "", true).sha256_text())
	print("VOLT_FINAL_HANDLING ", checks, " checks, ", failures, " failures")
	quit(1 if failures else 0)
