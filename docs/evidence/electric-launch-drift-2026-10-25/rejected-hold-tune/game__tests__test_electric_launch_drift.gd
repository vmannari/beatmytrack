extends "res://tests/test_electric_power.gd"

const LAUNCH_OUTPUT: String = "res://../docs/evidence/electric-launch-drift-2026-10-25"
var preceding_simulation: GDScript

func launch_turn(config: HandlingConfig, steer: float, pedal: float, previous: bool = false) -> Dictionary:
	var sim: RefCounted = preceding_simulation.new(config) if previous else VehicleSimulation.new(config)
	var peak_slip: float = 0.0
	var launch_slip: float = 0.0
	var peak_yaw: float = 0.0
	var samples: Array = []
	var early_heading: float = 0.0
	for tick: int in range(120):
		sim.step(DriveFrame.sample(steer,pedal,0))
		var slip_degrees: float = rad_to_deg(absf(sim.state.slip_angle()))
		peak_slip = maxf(peak_slip,slip_degrees)
		if sim.state.velocity.length() < 4.0: launch_slip = maxf(launch_slip,slip_degrees)
		peak_yaw = maxf(peak_yaw,absf(sim.state.yaw_rate))
		if tick == 23: early_heading = absf(sim.state.heading)
		if tick % 12 == 11:
			samples.append({"tick":tick+1,"speed":sim.state.velocity.length(),"slip_degrees":slip_degrees,"heading":sim.state.heading})
	var end_heading: float = absf(sim.state.heading)
	var end_speed: float = sim.state.velocity.length()
	for tick: int in range(120): sim.step(DriveFrame.sample(0,config.coast_pedal,0))
	return {"early_heading":early_heading,"peak_slip":peak_slip,"launch_slip":launch_slip,"peak_yaw":peak_yaw,"heading":end_heading,"speed":end_speed,"recovered_slip":rad_to_deg(absf(sim.state.slip_angle())),"samples":samples}

func run() -> void:
	preceding_simulation = GDScript.new()
	preceding_simulation.source_code = FileAccess.get_file_as_string(LAUNCH_OUTPUT+"/before/game__vehicle__vehicle_simulation.gd").replace("class_name VehicleSimulation","").trim_prefix("\ufeff")
	check(preceding_simulation.reload() == OK,"task-start physics compiles")
	var old: HandlingConfig = load(LAUNCH_OUTPUT+"/before/game__resources__cars__electric.tres") as HandlingConfig
	var current: HandlingConfig = VehicleCatalog.config("electric")
	var no_drift: HandlingConfig = current.duplicate() as HandlingConfig
	no_drift.launch_lateral_response_scale = 1.0
	check(old.version == "electric-8" and current.version == "electric-9" and VehicleSimulation.PHYSICS_VERSION == "arcade-planar-0.71","new tune and shared physics are versioned")
	metrics.launches = {}
	for steer: float in [0.35,0.65,1.0]:
		for pedal: float in [0.65,1.0]:
			var before: Dictionary = launch_turn(old,steer,pedal,true)
			var after: Dictionary = launch_turn(current,steer,pedal)
			var baseline: Dictionary = launch_turn(no_drift,steer,pedal)
			var mirror: Dictionary = launch_turn(current,-steer,pedal)
			metrics.launches[str(steer)+"/"+str(pedal)] = {"before":before,"after":after,"without_drift":baseline}
			check(after.early_heading < before.early_heading*0.85,"launch nose rotation is calmer: "+str(steer)+"/"+str(pedal))
			check(after.launch_slip > baseline.launch_slip*1.05,"powered launch retains more sideways momentum: "+str(steer)+"/"+str(pedal))
			if steer >= 0.65:
				check(after.launch_slip > before.launch_slip*1.3,"more launch slip than rejected electric-8: "+str(steer)+"/"+str(pedal))
			check(after.launch_slip < 8.0 and after.peak_slip < 25.0,"small launch drift stays bounded: "+str(steer)+"/"+str(pedal))
			check(after.recovered_slip < 0.1,"straightening restores grip: "+str(steer)+"/"+str(pedal))
			check(is_equal_approx(after.launch_slip,mirror.launch_slip) and is_equal_approx(after.speed,mirror.speed),"launch slip is left/right symmetric")
	# The launch aid is opt-in, forward-only, and absent at neutral pedal or above 8 m/s.
	for speed: float in [-7.0,-3.0,0.0,3.0,7.0,8.0,12.0,24.0]:
		for pedal: float in [0.0,0.25,1.0]:
			for steer: float in [-1.0,0.0,1.0]:
				if speed >= 0 and speed < 8 and pedal > 0.35 and steer != 0: continue
				var before := VehicleSimulation.new(no_drift)
				var after := VehicleSimulation.new(current)
				before.state.velocity = Vector2(0,speed)
				before.state.steering = steer
				before.state.yaw_rate = steer*0.3
				before.state.heading = 0.2
				after.state.velocity = before.state.velocity
				after.state.steering = before.state.steering
				after.state.yaw_rate = before.state.yaw_rate
				after.state.heading = before.state.heading
				before.step(DriveFrame.sample(steer,pedal,0))
				after.step(DriveFrame.sample(steer,pedal,0))
				check(before.state.snapshot() == after.state.snapshot(),"launch aid inactive outside powered forward turn: "+str(speed)+"/"+str(pedal)+"/"+str(steer))
	# Exact replay includes accelerating turn, countersteering, straightening and release.
	var first := VehicleSimulation.new(current)
	var replay := VehicleSimulation.new(current)
	var exact: bool = true
	for tick: int in range(600):
		var frame := DriveFrame.sample(0.8 if tick<90 else -0.6 if tick<150 else 0.0,1.0 if tick<180 else 0.0,0)
		first.step(frame)
		replay.step(frame)
		exact = exact and first.state.snapshot() == replay.state.snapshot()
	check(exact,"launch drift and recovery replay exactly")
	var file := FileAccess.open(LAUNCH_OUTPUT+"/launch-drift.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"metrics":metrics},"\t"))
	file.close()
	print("ELECTRIC_LAUNCH_DRIFT: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
