extends SceneTree

# Keep DriveFrame's native-track class graph alive through engine teardown.
const _NATIVE_TRACK = preload("res://track/native_track.gd")

const REFERENCE = preload("res://tests/fixtures/hover_slide51_reference/presets.gd")
const PRESETS = preload("res://vehicle/handling_test_presets.gd")
var checks: int = 0
var failures: int = 0

func _initialize() -> void: run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func run() -> void:
	var current := VehicleCatalog.config("hovercraft")
	var reference: HandlingConfig = REFERENCE.config("hovercraft", 1)
	var actual: Dictionary = current.snapshot()
	var expected: Dictionary = reference.snapshot()
	for field: String in ["version", "profile_name"]:
		actual.erase(field)
		expected.erase(field)
	check(actual == expected, "Production Hover matches the entire selected Slide 5.1 configuration")
	check(current.version == "hovercraft-5" and current.profile_name == "Hovercraft", "Production has its own canonical identity")
	check(PRESETS.names("hovercraft").is_empty(), "Hover no longer has experiments")
	for index: int in range(-1, 7):
		check(PRESETS.config("hovercraft", index).snapshot() == current.snapshot(), "Stale preset index cannot alter Hover: %d" % index)
	for speed: float in [0.0, 10.0, 15.0, 22.0, 36.0]:
		for steer: float in [-1.0, -0.7, 0.0, 0.7, 1.0]:
			for throttle: float in [0.0, 0.65, 1.0]:
				var sim := VehicleSimulation.new(current)
				var replay := VehicleSimulation.new(current)
				var original := VehicleSimulation.new(reference)
				var resumed := VehicleSimulation.new(current)
				for vehicle: VehicleSimulation in [sim, replay, original]:
					vehicle.state.velocity = Vector2(0, speed)
				for tick: int in range(600):
					var frame := DriveFrame.sample(steer if tick < 120 else 0.0, throttle, 0.35 if tick >= 480 else 0.0)
					sim.step(frame)
					replay.step(frame)
					original.step(frame)
					if tick == 299: RewindHistory.restore(resumed.state, RewindHistory.pack_state(sim.state))
					elif tick > 299: resumed.step(frame)
					check(sim.state.snapshot() == original.state.snapshot(), "Exact Slide 5.1 path tick %d" % tick)
				check(sim.state.snapshot() == replay.state.snapshot(), "Exact replay")
				check(sim.state.snapshot() == resumed.state.snapshot(), "Exact resumed replay")
				check(is_finite(sim.state.position.x) and is_finite(sim.state.position.y), "Finite motion")
	print("HOVER_SLIDE51_LOCKED: %d checks, %d failures" % [checks, failures])
	print("HOVER_SLIDE51_HASH: ", JSON.stringify(current.snapshot(), "", true).sha256_text())
	quit(1 if failures else 0)
