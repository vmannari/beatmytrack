extends "res://tests/test_electric_power.gd"

const DRIFT_OUTPUT: String = "res://../docs/evidence/electric-driving-character-2026-10-26"
var task_start: GDScript

func powered_turn(config: HandlingConfig, speed: float, steer: float, pedal: float, previous: bool = false) -> Dictionary:
	var sim: RefCounted=task_start.new(config) if previous else VehicleSimulation.new(config)
	sim.state.velocity=Vector2(0,speed)
	var frames: Array=[]
	var peak: float=0.0
	for tick: int in range(120):
		var frame := DriveFrame.sample(steer,pedal,0)
		frames.append(frame.packed())
		sim.step(frame)
		peak=maxf(peak,rad_to_deg(absf(sim.state.slip_angle())))
	var result: Dictionary={"peak_slip":peak,"speed":sim.state.velocity.length(),"powered_slip":rad_to_deg(absf(sim.state.slip_angle()))}
	for tick: int in range(24):
		var frame := DriveFrame.sample(steer,0,0)
		frames.append(frame.packed())
		sim.step(frame)
	result.lifted_slip=rad_to_deg(absf(sim.state.slip_angle()))
	for tick: int in range(120):
		var frame := DriveFrame.sample(0,config.coast_pedal,0)
		frames.append(frame.packed())
		sim.step(frame)
	result.recovered_slip=rad_to_deg(absf(sim.state.slip_angle()))
	var replay: RefCounted=task_start.new(config) if previous else VehicleSimulation.new(config)
	replay.state.velocity=Vector2(0,speed)
	for packed: Array in frames:
		replay.step(DriveFrame.sample(float(packed[0])/127.0,float(packed[1])/255.0,float(packed[2])/255.0))
	result.replay_exact=replay.state.snapshot()==sim.state.snapshot()
	return result

func run() -> void:
	task_start=GDScript.new()
	task_start.source_code=FileAccess.get_file_as_string(DRIFT_OUTPUT+"/before/game__vehicle__vehicle_simulation.gd").replace("class_name VehicleSimulation","").trim_prefix("\ufeff")
	check(task_start.reload()==OK,"actual electric-15 physics compiles for comparison")
	var old: HandlingConfig=load(DRIFT_OUTPUT+"/before/game__resources__cars__electric.tres") as HandlingConfig
	var current: HandlingConfig=VehicleCatalog.config("electric")
	check(current.version=="electric-17" and VehicleSimulation.PHYSICS_VERSION=="arcade-planar-0.74","power drift has versioned handling and physics")
	for field: String in old.snapshot():
		if field in ["version","regeneration","steering_rate","rotational_inertia","lateral_response","launch_lateral_response_scale","power_lateral_response_scale"]: continue
		check(current.get(field)==old.get(field),"task-start configuration field remains exact: "+field)
	metrics.corners={}
	for speed: float in [0.0,5.0,10.0,20.0,30.0,40.0]:
		for steer: float in [0.35,0.65,1.0]:
			for pedal: float in [0.65,1.0]:
				var before: Dictionary=powered_turn(old,speed,steer,pedal,true)
				var after: Dictionary=powered_turn(current,speed,steer,pedal)
				var mirror: Dictionary=powered_turn(current,speed,-steer,pedal)
				var label: String=str(speed)+"/"+str(steer)+"/"+str(pedal)
				metrics.corners[label]={"before":before,"after":after}
				if speed>=10.0: check(after.peak_slip>=before.peak_slip*0.8 and after.peak_slip>1.0,"planted character retains useful power drift beyond launch speed: "+label)
				check(after.peak_slip<8.0,"powered slide retains the existing small-drift ceiling: "+label)
				check(after.speed>=before.speed*0.95,"powered slide retains forward traction: "+label)
				check(after.lifted_slip<after.peak_slip and after.recovered_slip<0.1,"lift and straightening settle the slide: "+label)
				check(is_equal_approx(after.peak_slip,mirror.peak_slip) and after.replay_exact,"left/right power drift is symmetric and replays exactly: "+label)
	# No new response in reverse, at light/neutral pedal or with straight wheels.
	for speed: float in [-7.0,3.0,10.0,24.0,40.0]:
		for pedal: float in [0.0,0.24,0.45,0.65,1.0]:
			for steer: float in [0.0,0.65]:
				if speed>0 and pedal>0.45 and steer!=0: continue
				var no_power: HandlingConfig=current.duplicate() as HandlingConfig
				no_power.power_lateral_response_scale=1.0
				var before: RefCounted=VehicleSimulation.new(no_power)
				var after := VehicleSimulation.new(current)
				before.state.velocity=Vector2(1,speed)
				before.state.steering=steer
				before.state.yaw_rate=0.3
				after.state.velocity=before.state.velocity
				after.state.steering=steer
				after.state.yaw_rate=0.3
				before.step(DriveFrame.sample(steer,pedal,0))
				after.step(DriveFrame.sample(steer,pedal,0))
				check(before.state.snapshot()==after.state.snapshot(),"power aid is absent outside accelerating turns: "+str(speed)+"/"+str(pedal)+"/"+str(steer))
	for id: String in VehicleCatalog.IDS:
		if id=="electric": continue
		var config: HandlingConfig=VehicleCatalog.config(id)
		var before: RefCounted=task_start.new(config)
		var after := VehicleSimulation.new(config)
		var exact: bool=not config.snapshot().has("power_lateral_response_scale")
		for tick: int in range(1200):
			var frame := DriveFrame.sample(sin(tick*0.02),1.0 if tick%240<150 else 0.0,0.7 if tick%240>200 else 0.0,1.0 if tick%120<10 else 0.0)
			before.step(frame)
			after.step(frame)
			exact=exact and before.state.snapshot()==after.state.snapshot()
		check(exact,"other car keeps task-start arithmetic and default snapshot identity: "+id)
	var file := FileAccess.open(DRIFT_OUTPUT+"/powered-drift.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"metrics":metrics},"\t"))
	file.close()
	print("ELECTRIC_POWERED_DRIFT: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
