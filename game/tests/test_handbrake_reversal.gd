extends SceneTree
## Reproduce the owner's rapid Compact steering reversal on Grass-biome asphalt.

var checks: int = 0
var failures: int = 0
var previous: GDScript
var output_folder: String = "res://../docs/evidence/handbrake-reversal-2026-10-14"

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ", label)

func road() -> NativeTrack:
	var track := NativeTrack.new()
	track.metadata = {"theme": "pine"} # Native ID displayed as Grass.
	track.cell_size = 10.0
	track.grid_width = 100
	track.grid_height = 100
	track.half_extent = Vector2(500, 500)
	track.cells.resize(10000)
	track.cells.fill(0)
	track.deck_cells.resize(10000)
	track.deck_cells.fill(-1)
	track.route = PackedVector2Array([Vector2(0, -400), Vector2(0, 400)])
	return track

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--folder="): output_folder = argument.trim_prefix("--folder=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_folder))
	previous = GDScript.new()
	previous.source_code = FileAccess.get_file_as_string("res://../docs/evidence/handbrake-reversal-2026-10-14/before/vehicle_simulation.gd.txt").replace("\r\n", "\n").replace("class_name VehicleSimulation\n", "")
	check(previous.reload() == OK, "exact pre-fix simulation loads")
	var ground: NativeTrack = road()
	for id: String in VehicleCatalog.IDS:
		var config: HandlingConfig = VehicleCatalog.config(id)
		for speed: float in [12.0, 18.0, 25.0, 35.0]:
			for pressure: float in [0.5, 1.0]:
				for coating: float in [0.0, 1.0]:
					reversal(config, speed, pressure, coating, ground)
		unchanged(config, ground)
		replays(config, ground)
	for profile: int in range(HandlingSelection.PROFILE_PATHS.size()):
		reversal(VehicleCatalog.config("compact", profile), 25.0, 1.0, 0.0, ground)
	await process_frame
	print("HANDBRAKE_REVERSAL_TESTS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func reversal(config: HandlingConfig, speed: float, pressure: float, coating: float, ground: NativeTrack) -> void:
	var right := VehicleSimulation.new(config)
	var left := VehicleSimulation.new(config)
	var old: RefCounted = previous.new(config)
	for sim: RefCounted in [right, left, old]:
		sim.state.velocity = Vector2(0, minf(speed, config.maximum_speed))
		sim.state.tire_dirt = coating
	for tick: int in range(36):
		right.step(DriveFrame.sample(-1, 0.7, 0), ground)
		left.step(DriveFrame.sample(1, 0.7, 0), ground)
		old.step(DriveFrame.sample(-1, 0.7, 0), ground)
	var inherited: float = right.state.yaw_rate
	var first: float = 0.0
	var catch_tick: int = -1
	var finite: bool = true
	var dissipative: bool = true
	var mirrored: bool = true
	var old_rotation: float = 0.0
	var rotation: float = 0.0
	var trace: Array = [{"tick": 0, "old": old.state.snapshot(), "current": right.state.snapshot()}]
	for tick: int in range(60):
		var before: float = right.state.velocity.length_squared()
		var heading: float = right.state.heading
		var old_heading: float = old.state.heading
		right.step(DriveFrame.sample(1, 0, 0, pressure), ground)
		left.step(DriveFrame.sample(-1, 0, 0, pressure), ground)
		old.step(DriveFrame.sample(1, 0, 0, pressure), ground)
		rotation += angle_difference(heading, right.state.heading)
		old_rotation += angle_difference(old_heading, old.state.heading)
		trace.append({"tick": tick + 1, "old": old.state.snapshot(), "current": right.state.snapshot()})
		if tick == 0: first = right.state.yaw_rate
		if right.state.yaw_rate > 0.0 and catch_tick < 0: catch_tick = tick
		finite = finite and right.state.position.is_finite() and right.state.velocity.is_finite() and absf(right.state.yaw_rate) <= 4.0
		dissipative = dissipative and right.state.velocity.length_squared() <= before + 0.0001
		mirrored = mirrored and right.state.position.is_equal_approx(Vector2(-left.state.position.x, left.state.position.y)) and is_equal_approx(right.state.heading, -left.state.heading) and is_equal_approx(right.state.yaw_rate, -left.state.yaw_rate)
	var label: String = "%s %s speed=%.0f pressure=%.1f coating=%.0f" % [config.vehicle_id, config.profile_name, speed, pressure, coating]
	if catch_tick < 0 or catch_tick >= 48 or right.state.yaw_rate <= 0.0:
		print("REVERSAL_DETAIL ", label, " catch=", catch_tick, " yaw=", right.state.yaw_rate, " slip=", rad_to_deg(right.state.slip_angle()), " speed=", right.state.velocity.length(), " longitudinal=", right.state.velocity.dot(right.state.forward()))
	check(inherited < 0.0 and first < 0.0, label + " retains the previous turn's initial angular momentum")
	check(catch_tick >= 0 and catch_tick < 48 and right.state.yaw_rate > 0.0, label + " catches and sustains the new steering direction within 0.4s")
	check(finite and dissipative, label + " stays bounded without adding translational energy")
	check(mirrored, label + " is symmetric for left/right reversals")
	if config.vehicle_id == "compact" and config.profile_name == "Original+" and speed == 25.0 and pressure == 1.0 and coating == 0.0:
		check(old.state.yaw_rate < -3.0, "pre-fix Compact reproduction keeps spinning against full right steering")
		print("OWNER_REVERSAL old_yaw=%.6f new_yaw=%.6f old_rotation=%.3f new_rotation=%.3f catch_seconds=%.3f" % [old.state.yaw_rate, right.state.yaw_rate, rad_to_deg(old_rotation), rad_to_deg(rotation), (catch_tick + 1) * VehicleSimulation.STEP])
		var output := FileAccess.open(output_folder+"/owner-trace.json", FileAccess.WRITE)
		check(output != null, "native owner-reproduction trace opens")
		if output != null:
			output.store_string(JSON.stringify({"physics": VehicleSimulation.PHYSICS_VERSION, "dt": VehicleSimulation.STEP, "case": label, "catch_tick": catch_tick + 1, "old_rotation": old_rotation, "rotation": rotation, "states": trace}, "\t"))

func unchanged(config: HandlingConfig, ground: NativeTrack) -> void:
	for direction: float in [-1.0, 1.0]:
		for pull: int in [0, 24, 60, 240]:
			var current := VehicleSimulation.new(config)
			var old: RefCounted = previous.new(config)
			current.state.velocity = Vector2(0, 18.0 * direction)
			old.state.velocity = current.state.velocity
			var exact: bool = true
			for tick: int in range(480):
				var frame: DriveFrame = DriveFrame.sample(sin(tick * 0.07) if pull == 0 else 1.0 if tick < pull else 0.0, 0.7, 0, 1.0 if tick < pull else 0.0)
				current.step(frame, ground)
				old.step(frame, ground)
				if exact and current.state.snapshot() != old.state.snapshot():
					print("UNCHANGED_DETAIL ", config.vehicle_id, " direction=", direction, " pull=", pull, " tick=", tick, " speed=", current.state.velocity.length(), " longitudinal=", current.state.velocity.dot(current.state.forward()), " yaw=", current.state.yaw_rate, " old_yaw=", old.state.yaw_rate)
				exact = exact and current.state.snapshot() == old.state.snapshot()
			check(exact, "%s ordinary driving/single pull remains exact direction=%.0f pull=%d" % [config.vehicle_id, direction, pull])

func replays(config: HandlingConfig, ground: NativeTrack) -> void:
	var current := VehicleSimulation.new(config)
	var replay := VehicleSimulation.new(config)
	current.state.velocity = Vector2(0, 25)
	replay.state.velocity = current.state.velocity
	var exact: bool = true
	var covered_rewind: bool = false
	for tick: int in range(720):
		var frame: DriveFrame = DriveFrame.sample(-1.0 if tick % 72 < 36 else 1.0, 0.7, 0, 1.0 if tick % 72 >= 36 else 0.0)
		var packed: Array = JSON.parse_string(JSON.stringify(frame.packed()))
		var decoded := DriveFrame.new()
		decoded.steer = int(packed[0]); decoded.throttle = int(packed[1]); decoded.brake = int(packed[2]); decoded.handbrake = int(packed[3]) if packed.size() > 3 else 0
		current.step(frame, ground)
		replay.step(decoded, ground)
		exact = exact and current.state.snapshot() == replay.state.snapshot()
		if tick == 42:
			covered_rewind = current.state.handbrake_pressure > 0.0 and current.state.steering * current.state.yaw_rate < 0.0
			RewindHistory.restore(replay.state, RewindHistory.properties(current.state))
	check(covered_rewind and exact, config.vehicle_id + " rapid reversals restore/replay exactly after JSON and active-countersteer rewind")
