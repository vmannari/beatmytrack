extends SceneTree

func _initialize() -> void:
	var kart: HandlingConfig = VehicleCatalog.config("kart")
	var previous: HandlingConfig = kart.duplicate() as HandlingConfig
	previous.version = "kart-11"
	previous.low_speed_steering_scale = 1.0
	var failures := 0
	for speed: float in [1.0, 3.0, 6.0, 10.0]:
		for direction: float in [-1.0, 1.0]:
			var now := VehicleSimulation.new(kart)
			var old := VehicleSimulation.new(previous)
			now.state.velocity = Vector2(0.0, speed)
			old.state.velocity = now.state.velocity
			for tick: int in range(12):
				var frame := DriveFrame.sample(direction, 0.0, 0.0)
				now.step(frame)
				old.step(frame)
			var ratio: float = absf(now.state.yaw_rate / old.state.yaw_rate)
			print("KART_LOW_SPEED ", speed, " ", direction, " yaw ratio ", ratio)
			if speed <= 3.0 and not (ratio > 0.65 and ratio < 0.9): failures += 1
			if speed == 6.0 and not (ratio > 0.8 and ratio < 1.0): failures += 1
			if speed == 10.0 and now.state.snapshot() != old.state.snapshot(): failures += 1
	print("KART_LOW_SPEED failures: ", failures)
	quit(1 if failures else 0)
