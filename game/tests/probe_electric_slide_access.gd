extends "res://tests/probe_electric_character.gd"

const SLIDE_OUTPUT: String = "res://../docs/evidence/electric-slide-access-2026-10-27"

func slide_sample(config: HandlingConfig, kph: float, steer: float, pedal: float, duration: int = 180) -> Dictionary:
	var sim := VehicleSimulation.new(config)
	sim.state.velocity=Vector2(0,kph/3.6)
	var peak: float=0.0
	var onset: int=0
	var sliding_ticks: int=0
	var minimum_grip: float=1.0
	var frames: Array[DriveFrame]=[]
	for tick: int in range(duration):
		var frame := DriveFrame.sample(steer,pedal,0)
		frames.append(frame)
		sim.step(frame)
		var slip: float=absf(sim.state.slip_angle())
		peak=maxf(peak,rad_to_deg(slip))
		minimum_grip=minf(minimum_grip,sim.state.grip)
		if slip>config.slip_threshold and sim.state.velocity.length()>3.0:
			sliding_ticks+=1
			if onset==0: onset=tick+1
	var result: Dictionary={"peak":peak,"onset_ms":onset/120.0*1000.0,"sliding_ticks":sliding_ticks,"minimum_grip":minimum_grip,"end_kph":sim.state.velocity.length()*3.6}
	var recover: int=0
	for tick: int in range(240):
		var frame := DriveFrame.sample(0,config.coast_pedal,0)
		frames.append(frame)
		sim.step(frame)
		if recover==0 and absf(sim.state.slip_angle())<deg_to_rad(1.0) and absf(sim.state.yaw_rate)<0.1: recover=tick+1
	result.recovery_ms=recover/120.0*1000.0
	result.final_slip=rad_to_deg(absf(sim.state.slip_angle()))
	var replay := VehicleSimulation.new(config)
	replay.state.velocity=Vector2(0,kph/3.6)
	for frame: DriveFrame in frames: replay.step(frame)
	result.replay_exact=replay.state.snapshot()==sim.state.snapshot()
	return result

func stop_sample(config: HandlingConfig, kph: float) -> Dictionary:
	var sim := VehicleSimulation.new(config)
	sim.state.velocity=Vector2(0,kph/3.6)
	var first: float=0.0
	for tick: int in range(1200):
		sim.step(DriveFrame.sample(0,0,0))
		if tick==0: first=(kph/3.6-sim.state.velocity.y)*120.0
		if sim.state.velocity==Vector2.ZERO: return {"seconds":(tick+1)/120.0,"metres":sim.state.position.y,"first_deceleration":first}
	return {"seconds":10.0,"metres":sim.state.position.y,"first_deceleration":first}

func run() -> void:
	var old: HandlingConfig=load(SLIDE_OUTPUT+"/before/game__resources__cars__electric.tres") as HandlingConfig
	for scale: float in [0.70,0.45,0.35,0.30,0.25,0.20]:
		var config: HandlingConfig=old.duplicate() as HandlingConfig
		if scale!=0.70:
			config.regeneration=15.0
			config.power_lateral_response_scale=scale
			config.launch_lateral_response_scale=minf(0.18,scale)
		var cases: Dictionary={}
		for speed: float in [0.0,10.0,30.0,50.0,80.0,120.0,170.0]:
			for steering: float in [0.35,0.65,1.0]:
				cases[str(speed)+"/"+str(steering)]=slide_sample(config,speed,steering,1.0)
		metrics[str(scale)]={"cases":cases,"pulse":keyboard_pulse(config),"stop72":stop_sample(config,72.0),"stop190":stop_sample(config,190.0)}
	var file := FileAccess.open(SLIDE_OUTPUT+"/candidates.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(metrics,"\t"))
	file.close()
	print("SLIDE_ACCESS_PROBE: ",metrics.size()," candidates")
	quit()
