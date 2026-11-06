extends SceneTree

var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var old: HandlingConfig = load("res://../docs/evidence/volt-slow-steering-2026-11-06/before/electric.tres")
	var current: HandlingConfig = VehicleCatalog.config("electric")
	var expected: HandlingConfig = old.duplicate()
	expected.version = "electric-29"
	expected.low_speed_steering_scale = 0.75
	check(current.snapshot() == expected.snapshot(), "only version and low-speed lock change")
	for speed: float in [1.0, 2.0, 3.0, -1.0, -2.0, -3.0]:
		for steer: float in [0.35, 0.65, 1.0]:
			var a := VehicleSimulation.new(old)
			var b := VehicleSimulation.new(current)
			var mirror := VehicleSimulation.new(current)
			a.state.velocity = Vector2(0, speed)
			b.state.velocity = a.state.velocity
			mirror.state.velocity = a.state.velocity
			for tick: int in range(24):
				a.step(DriveFrame.sample(steer, 0.24, 0))
				b.step(DriveFrame.sample(steer, 0.24, 0))
				mirror.step(DriveFrame.sample(-steer, 0.24, 0))
			var ratio := absf(b.state.heading / a.state.heading)
			check(ratio < 0.9 and ratio > 0.45, "modest slow-speed reduction %s/%s: %s" % [speed, steer, ratio])
			check(is_equal_approx(b.state.heading, -mirror.state.heading), "symmetric left/right")
			print("ONSET ", speed, " ", steer, " ratio=", ratio)
	for speed: float in [8.0, 10.0, 20.0, 40.0, 52.0]:
		for steer: float in [-1.0, -0.35, 0.0, 0.35, 1.0]:
			for pedal: float in [0.0, 0.24, 1.0]:
				var a := VehicleSimulation.new(old)
				var b := VehicleSimulation.new(current)
				a.state.velocity = Vector2(0, speed)
				b.state.velocity = a.state.velocity
				a.step(DriveFrame.sample(steer, pedal, 0))
				b.step(DriveFrame.sample(steer, pedal, 0))
				check(a.state.snapshot() == b.state.snapshot(), "normal-speed step exact")
	for direction: float in [-1.0, 1.0]:
		var a := VehicleSimulation.new(old)
		var b := VehicleSimulation.new(current)
		for tick: int in range(2400):
			var frame := DriveFrame.sample(0, direction if tick < 1200 else 0.0, 0)
			a.step(frame)
			b.step(frame)
			check(a.state.snapshot() == b.state.snapshot(), "straight power/coast remains exact")
	var replay := VehicleSimulation.new(current)
	var live := VehicleSimulation.new(current)
	for tick: int in range(3600):
		var frame := DriveFrame.sample(sin(tick * 0.027), 0.65 if tick % 600 < 450 else 0.0, 0)
		replay.step(frame)
		live.step(frame)
		check(replay.state.snapshot() == live.state.snapshot(), "replay exact")
	print("VOLT_CONFIG_HASH ", JSON.stringify(current.snapshot(), "", true).sha256_text())
	print("VOLT_SLOW_STEERING: ", checks, " checks, ", failures, " failures")
	quit(1 if failures else 0)
