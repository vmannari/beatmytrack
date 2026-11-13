extends SceneTree

func _initialize() -> void:
	for scale: float in [1.0, 0.95, 0.9, 0.85, 0.8, 0.75]:
		for kph: float in [100.0, 120.0, 140.0]:
			var config: HandlingConfig = VehicleCatalog.config("kart")
			config.high_speed_lateral_response_scale = 1.0
			config.high_speed_lateral_grip_scale = scale
			var sim := VehicleSimulation.new(config)
			sim.state.velocity = Vector2(0, kph/3.6)
			var peak: float = 0.0
			for tick: int in range(1200):
				sim.step(DriveFrame.sample(0.65, 1, 0))
				peak = maxf(peak, absf(rad_to_deg(sim.state.slip_angle())))
				if tick in [35, 59, 119, 1199]:
					print("MOMENTUM scale=",scale," kph=",kph," tick=",tick+1," position=",sim.state.position," travel_deg=",rad_to_deg(atan2(sim.state.velocity.x,sim.state.velocity.y))," heading_deg=",rad_to_deg(sim.state.heading)," slip_deg=",rad_to_deg(sim.state.slip_angle())," speed_kph=",sim.state.velocity.length()*3.6)
			print("PEAK scale=",scale," kph=",kph," degrees=",peak)
	quit()
