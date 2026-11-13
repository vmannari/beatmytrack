extends SceneTree

func _initialize() -> void:
	for scale: float in [0.6, 0.55, 0.52, 0.5]:
		for steer: float in [0.35, 0.5, 0.65, 1.0]:
			var config: HandlingConfig = VehicleCatalog.config("kart")
			config.high_speed_lateral_response_scale = scale
			var sim := VehicleSimulation.new(config)
			sim.state.velocity = Vector2(0, config.maximum_speed)
			var peak: float = 0.0
			for tick: int in range(1200):
				sim.step(DriveFrame.sample(steer, 1, 0))
				peak = maxf(peak, absf(rad_to_deg(sim.state.slip_angle())))
				if tick in [23, 59, 119, 239, 1199]:
					print("ONSET scale=", scale, " steer=", steer, " tick=", tick+1, " slip_deg=", absf(rad_to_deg(sim.state.slip_angle())), " speed_kph=", sim.state.velocity.length()*3.6)
			print("PEAK scale=", scale, " steer=", steer, " degrees=", peak)
		var control: HandlingConfig = VehicleCatalog.config("kart")
		control.high_speed_lateral_response_scale = scale
		control.turn_speed_reduction = 0.0
		var sim := VehicleSimulation.new(control)
		sim.state.velocity = Vector2(0, control.maximum_speed)
		for tick: int in range(1200): sim.step(DriveFrame.sample(1, 1, 0))
		print("UNLIMITED_CONTROL scale=", scale, " kph=", sim.state.velocity.length()*3.6)
	quit()
