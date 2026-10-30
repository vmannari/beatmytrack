extends SceneTree

const BEFORE = preload("res://tests/fixtures/kart_final_reference/presets.gd")
const TESTS = preload("res://vehicle/handling_test_presets.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ", description)

func run() -> void:
	var accepted: HandlingConfig = BEFORE.config("kart", 5)
	var final: HandlingConfig = VehicleCatalog.config("kart")
	check(final.version == "kart-11", "new canonical handling identity")
	# Preserve the selected dry setup as a historical control for the later
	# winter-grip and high-speed cornering changes.
	var selected: HandlingConfig = final.duplicate() as HandlingConfig
	selected.version = "kart-9"
	selected.turn_speed_reduction = 0.0
	var expected: Dictionary = accepted.snapshot()
	var actual: Dictionary = selected.snapshot()
	for key: String in ["profile_name", "version"]:
		expected.erase(key)
		actual.erase(key)
	actual.erase("winter_lateral_grip") # Later winter-only tuning does not change the selected dry setup.
	check(actual == expected, "all physical fields match selected Brake turn 5.5")
	check(TESTS.names("kart").is_empty(), "kart has no test choices")
	for index: int in range(-1, 6): check(TESTS.config("kart", index).snapshot() == final.snapshot(), "kart rejects preset %d" % index)
	var first := VehicleSimulation.new(accepted)
	var second := VehicleSimulation.new(selected)
	for tick: int in range(3600):
		var steer: float = sin(float(tick) * 0.013) * 0.7
		var brake: float = 0.45 if tick % 600 >= 300 and tick % 600 < 360 else 0.0
		var input := DriveFrame.sample(steer, 0.0 if brake > 0 else 0.65, brake)
		first.step(input)
		second.step(input)
		check(first.state.snapshot() == second.state.snapshot(), "exact selected-versus-final state at tick %d" % tick)
	var game: Node = load("res://core/game.tscn").instantiate()
	game.initial_track = NativeTrack.read("res://resources/tracks/ellipse.json")
	game.vehicle_id = "kart"
	game.production_mode = true
	root.add_child(game)
	while not game.preparation_complete: await process_frame
	game.set_physics_process(false)
	check(game.handling.snapshot() == final.snapshot() and game.sim.config.snapshot() == final.snapshot(), "actual race installs final handling")
	check(game.hud.handling_test_choice == null and not game.attempt_practice, "ordinary kart race has no selector and is eligible for results")
	game.select_handling_test(5)
	check(game.handling.snapshot() == final.snapshot() and not game.attempt_practice, "direct preset selection cannot alter the final race")
	print("KART_FINAL_HASH ", JSON.stringify(final.snapshot(), "", true).sha256_text())
	game.queue_free()
	await process_frame
	print("KART_FINAL: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
