extends SceneTree

const VerificationTrack = preload("res://backend/verification_track.gd")
var checks: int = 0
var failures: int = 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ", label)

func track_for(theme: String, kind: int, hazard: String = "") -> NativeTrack:
	var track := NativeTrack.new()
	track.cell_size = 10.0
	track.grid_width = 100
	track.grid_height = 100
	track.half_extent = Vector2(500, 500)
	track.cells.resize(10000)
	track.cells.fill(kind)
	track.deck_cells.resize(10000)
	track.deck_cells.fill(kind)
	track.route = PackedVector2Array([Vector2(0, -400), Vector2(0, 400)])
	track.metadata = {"theme": theme}
	if not hazard.is_empty():
		track.hazard_objects = [{"kind": hazard, "position": [0, 0], "rotation": 0, "scale": 2.0}]
	return track

func simulate(config: HandlingConfig, track: NativeTrack, elevated: bool = false) -> Array:
	var sim := VehicleSimulation.new(config)
	sim.state.velocity = Vector2(10, 15)
	sim.state.track_elevated = elevated
	for tick: int in range(60): sim.step(DriveFrame.new(), track)
	return sim.state.snapshot()

func _initialize() -> void:
	var volt: HandlingConfig = VehicleCatalog.config("electric")
	var prior: HandlingConfig = volt.duplicate() as HandlingConfig
	prior.winter_road_grip = 1.0
	check(is_equal_approx(volt.winter_road_grip, 0.9), "Volt winter grip is reduced ten percent")
	for car: String in VehicleCatalog.IDS:
		if car != "electric": check(VehicleCatalog.config(car).winter_road_grip == 1.0, car + " has neutral winter multiplier")
	for theme: String in ["pine", "winter"]:
		for kind: int in [0, 1, 2, 5, 6]:
			for elevated: bool in [false, true]:
				var track: NativeTrack = track_for(theme, kind)
				var result: Array = simulate(volt, track, elevated)
				var previous: Array = simulate(prior, track, elevated)
				var expected_change: bool = theme == "winter" and kind == 0
				check((result != previous) == expected_change, "winter road only: %s %d elevated=%s" % [theme, kind, elevated])
				var frozen: NativeTrack = VerificationTrack.frozen(track)
				check(result == simulate(volt, frozen, elevated), "canonical track parity: %s %d elevated=%s" % [theme, kind, elevated])
	for hazard: String in ["oil", "puddle"]:
		var track: NativeTrack = track_for("winter", 0, hazard)
		var state := VehicleState.new()
		check(track.surface_factors(state).x < NativeTrack.WINTER_ROAD_GRIP * 0.5, hazard + " still reduces surface grip")
		var result: Array = simulate(volt, track)
		check(result != simulate(prior, track), hazard + " retains Volt winter effect")
		check(result == simulate(volt, VerificationTrack.frozen(track)), hazard + " canonical track parity")
	# Compare all other cars against the same core with only the new adjustment
	# removed. This checks state, not just the default resource values.
	var source: String = FileAccess.get_file_as_string("res://vehicle/vehicle_simulation.gd").replace("\r\n", "\n")
	var adjustment: String = '\tif config.winter_road_grip != 1.0 and ground is NativeTrack and str(ground.metadata.get("theme", "pine")) == "winter" and ground.cell_at(state.position, state.track_elevated) == 0:\n\t\tsurface.x *= config.winter_road_grip\n'
	check(source.contains(adjustment), "control removes the winter adjustment")
	var control := GDScript.new()
	control.source_code = source.replace("class_name VehicleSimulation", "").replace(adjustment, "")
	check(control.reload() == OK, "unmodified-physics control compiles")
	for car: String in VehicleCatalog.IDS:
		if car == "electric": continue
		var config: HandlingConfig = VehicleCatalog.config(car)
		for theme: String in ["pine", "winter"]:
			var track: NativeTrack = track_for(theme, 0)
			var sim = control.new(config)
			sim.state.velocity = Vector2(10, 15)
			for tick: int in range(60): sim.step(DriveFrame.new(), track)
			check(sim.state.snapshot() == simulate(config, track), car + " matches original physics on " + theme)
	var winter: NativeTrack = track_for("winter", 0)
	var before := VehicleSimulation.new(prior)
	var after := VehicleSimulation.new(volt)
	before.state.velocity = Vector2(10, 15)
	after.state.velocity = Vector2(10, 15)
	for tick: int in range(60):
		before.step(DriveFrame.new(), winter)
		after.step(DriveFrame.new(), winter)
	print("VOLT_WINTER_METRIC slide_before=", before.state.position.x, " slide_after=", after.state.position.x)
	check(after.state.position.x > before.state.position.x, "lower winter grip lets Volt slide farther")
	print("VOLT_WINTER_GRIP: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
