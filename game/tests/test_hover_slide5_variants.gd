extends SceneTree

const PRESETS = preload("res://tests/fixtures/hover_slide51_reference/presets.gd")
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(description)

func _run() -> void:
	var baseline: HandlingConfig = load("res://tests/fixtures/hover_slide51_reference/hovercraft.tres")
	var old_slide := baseline.duplicate() as HandlingConfig
	old_slide.steering_rate = 19.0
	old_slide.maximum_yaw_rate = 2.7
	old_slide.thrust_lateral_damping = 1.0
	old_slide.lateral_response = 0.28
	old_slide.profile_name += " / Slide 5"
	old_slide.version += "-hover-slide-5"
	check(PRESETS.config("hovercraft", 0).snapshot() == old_slide.snapshot(), "Reference must preserve Slide 5 exactly")
	check(PRESETS.config("hovercraft", -1).snapshot() == baseline.snapshot(), "Current handling must remain exact")
	check(PRESETS.names("hovercraft") == ["Slide 5 (reference)", "Slide 5.1", "Slide 5.2", "Slide 5.3", "Slide 5.4", "Slide 5.5"], "Hovercraft must expose reference and five slide options")
	var expected_damping: Array[float] = [1.0, 0.9, 0.8, 0.7, 0.6, 0.5]
	for index: int in range(6):
		var config: HandlingConfig = PRESETS.config("hovercraft", index)
		var actual: Dictionary = config.snapshot()
		var reference: Dictionary = old_slide.snapshot()
		for field: String in ["version", "profile_name", "thrust_lateral_damping"]:
			actual.erase(field)
			reference.erase(field)
		check(actual == reference and is_equal_approx(config.thrust_lateral_damping, expected_damping[index]), "Slide %d differs only in powered lateral damping" % (index + 1))
	for speed: float in [10.0, 15.0, 22.0]:
		var previous_peak: float = -1.0
		for index: int in range(6):
			var config: HandlingConfig = PRESETS.config("hovercraft", index)
			var right := VehicleSimulation.new(config)
			var left := VehicleSimulation.new(config)
			var repeat := VehicleSimulation.new(config)
			for sim: VehicleSimulation in [right, left, repeat]: sim.state.velocity = Vector2(0.0, speed)
			var peak: float = 0.0
			for tick: int in range(600):
				var steer: float = 0.7 if tick < 120 else 0.0
				right.step(DriveFrame.sample(steer, 0.65, 0.0))
				left.step(DriveFrame.sample(-steer, 0.65, 0.0))
				repeat.step(DriveFrame.sample(steer, 0.65, 0.0))
				peak = maxf(peak, absf(right.state.slip_angle()))
			check(right.state.snapshot() == repeat.state.snapshot(), "Slide %d replay at %.0f m/s" % [index + 1, speed])
			check(is_finite(right.state.position.x) and is_finite(right.state.position.y) and is_finite(right.state.heading), "Slide %d finite at %.0f m/s" % [index + 1, speed])
			check(absf(right.state.position.x + left.state.position.x) < 0.001 and absf(right.state.position.y - left.state.position.y) < 0.001, "Slide %d mirrored at %.0f m/s" % [index + 1, speed])
			check(absf(right.state.slip_angle()) < deg_to_rad(5.0) and absf(right.state.yaw_rate) < 0.1, "Slide %d recovers at %.0f m/s" % [index + 1, speed])
			check(peak > previous_peak + deg_to_rad(0.5), "Slide %d has progressively more slip at %.0f m/s" % [index + 1, speed])
			previous_peak = peak
			print("HOVER_SLIDE_METRIC speed=%.1f preset=%d peak_deg=%.3f recovery_deg=%.3f" % [speed, index + 1, rad_to_deg(peak), rad_to_deg(absf(right.state.slip_angle()))])
	print("HOVER_SLIDE5_VARIANTS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
