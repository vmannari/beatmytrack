extends "res://tests/test_electric_powered_drift.gd"

const CHARACTER_OUTPUT: String = "res://../docs/evidence/electric-driving-character-2026-10-26"

func keyboard_pulse(config: HandlingConfig) -> Dictionary:
	var sim := VehicleSimulation.new(config)
	sim.state.velocity=Vector2(0,50.0/3.6)
	var input := DriverInput.new()
	input.single_pedal=config.single_pedal
	var samples: Array=[]
	var peak_slip: float=0.0
	for tick: int in range(144):
		var pedal: bool=tick<36 or tick>=72
		Input.action_press(&"accelerate",1.0 if pedal else 0.0)
		Input.action_press(&"steer_right",1.0 if tick>=24 and tick<108 else 0.0)
		sim.step(input.sample())
		peak_slip=maxf(peak_slip,rad_to_deg(absf(sim.state.slip_angle())))
		if tick in [23,35,47,59,71,83,107,143]:
			samples.append({"tick":tick+1,"speed_kph":sim.state.velocity.length()*3.6,"heading":rad_to_deg(sim.state.heading),"slip":rad_to_deg(absf(sim.state.slip_angle()))})
	input.clear()
	return {"samples":samples,"peak_slip":peak_slip,"end_position":[sim.state.position.x,sim.state.position.y]}

func input_phase(config: HandlingConfig) -> Dictionary:
	var sim := VehicleSimulation.new(config)
	sim.state.velocity=Vector2(0,30.0/3.6)
	var lock_tick: int=0
	var hundred: float=0.0
	for tick: int in range(24):
		sim.step(DriveFrame.sample(1,config.coast_pedal if config.single_pedal else 0,0))
		if lock_tick==0 and sim.state.steering>=0.95: lock_tick=tick+1
		if tick==11: hundred=rad_to_deg(atan2(sim.state.velocity.x,sim.state.velocity.y))
	var response: Dictionary={"lock_ms":lock_tick/120.0*1000.0,"course_100ms":hundred,"course_200ms":rad_to_deg(atan2(sim.state.velocity.x,sim.state.velocity.y)),"heading_200ms":rad_to_deg(sim.state.heading)}
	return response

func run() -> void:
	var current: HandlingConfig=load(CHARACTER_OUTPUT+"/before/game__resources__cars__electric.tres") as HandlingConfig
	var candidates: Dictionary={"compact":VehicleCatalog.config("compact"),"electric16":current}
	for label: String in ["lift_only","weighted","connected"]:
		var config: HandlingConfig=current.duplicate() as HandlingConfig
		config.regeneration=12.0
		if label=="weighted":
			config.steering_rate=9.0
			config.rotational_inertia=600.0
			config.lateral_response=22.0
			config.launch_lateral_response_scale=0.30
			config.power_lateral_response_scale=0.70
		if label=="connected":
			config.steering_rate=10.0
			config.rotational_inertia=500.0
			config.lateral_response=26.0
			config.launch_lateral_response_scale=0.20
			config.power_lateral_response_scale=0.60
		candidates[label]=config
	for label: String in candidates:
		metrics[label]={"keyboard_pulse":keyboard_pulse(candidates[label]),"phase":input_phase(candidates[label])}
		print("CHARACTER ",label," ",JSON.stringify(metrics[label]))
	var file := FileAccess.open(CHARACTER_OUTPUT+"/candidate-comparison.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(metrics,"\t"))
	file.close()
	quit()
