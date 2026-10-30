extends "res://tests/test_electric_power.gd"

const AUTHORITY_OUTPUT: String = "res://../docs/evidence/electric-tighter-held-steering-2026-10-26"

func keyboard_corner(config: HandlingConfig, kph: float, direction: float, radius: float = 6.0, width: float = 10.0) -> Dictionary:
	var sim := VehicleSimulation.new(config)
	sim.state.velocity=Vector2(0,kph/3.6)
	var driver := DriverInput.new()
	driver.single_pedal=true
	var integral: float=0.0
	var worst_error: float=0.0
	var released: bool=false
	var turn_ticks: int=0
	var frames: Array=[]
	for tick: int in range(720):
		var speed: float=sim.state.velocity.length()
		var course: float=atan2(sim.state.velocity.x*direction,sim.state.velocity.y)
		if course>=deg_to_rad(87.0) and not released:
			released=true
			turn_ticks=tick
		var error: float=kph/3.6-speed
		integral=clampf(integral+error*VehicleSimulation.STEP*4.0,-5.0,8.0)
		var drag: float=(config.rolling_resistance+config.drag*speed*speed)/config.mass
		var power: float=config.engine_force/config.mass*(1.0-0.45*speed/config.maximum_speed)
		var pedal: float=config.accelerator_for_acceleration(error*5.0+integral+drag,power)
		Input.action_press(&"accelerate",pedal)
		Input.action_press(&"steer_right" if direction>0 else &"steer_left",0.0 if released else 1.0)
		var frame: DriveFrame=driver.sample()
		frames.append(frame.packed())
		sim.step(frame)
		var x: float=sim.state.position.x*direction
		var y: float=sim.state.position.y
		var lane_error: float=absf(Vector2(x-radius,y).length()-radius) if x<=radius else absf(y-radius)
		worst_error=maxf(worst_error,lane_error)
		if released and x>=radius+8.0: break
	driver.clear()
	var replay := VehicleSimulation.new(config)
	replay.state.velocity=Vector2(0,kph/3.6)
	for packed: Array in frames:
		replay.step(DriveFrame.sample(float(packed[0])/127.0,float(packed[1])/255.0,float(packed[2])/255.0))
	return {"released":released,"turn_seconds":turn_ticks/120.0,"maximum_lane_error":worst_error,"body_within_10m_lane":worst_error+config.collision_radius<=width*0.5+0.02,"exit_degrees":rad_to_deg(atan2(sim.state.velocity.x*direction,sim.state.velocity.y)),"exit_x":sim.state.position.x*direction,"replay_exact":replay.state.snapshot()==sim.state.snapshot()}

func run() -> void:
	var config: HandlingConfig=VehicleCatalog.config("electric")
	metrics.keyboard_corners={}
	for kph: float in [20.0,30.0]:
		for direction: float in [-1.0,1.0]:
			var result: Dictionary=keyboard_corner(config,kph,direction)
			metrics.keyboard_corners[str(kph)+"/"+str(direction)]=result
			check(result.released and result.turn_seconds<=(2.8 if kph==20 else 2.2),"keyboard completes a standard right-angle turn promptly: "+str(kph)+"/"+str(direction))
			check(result.body_within_10m_lane,"full car stays within a 10m-wide, 6m-radius 90-degree bend: "+str(kph)+"/"+str(direction))
			check(result.exit_x>=14 and absf(result.exit_degrees-90.0)<7.0,"keyboard press/release exits the bend aligned and moving: "+str(kph)+"/"+str(direction))
			check(result.replay_exact,"keyboard corner inputs replay exactly")
	metrics.tight_corners={}
	for kph: float in [20.0,30.0]:
		for direction: float in [-1.0,1.0]:
			var result: Dictionary=keyboard_corner(config,kph,direction,4.0,8.0)
			metrics.tight_corners[str(kph)+"/"+str(direction)]=result
			check(result.released and result.turn_seconds<=(1.6 if kph==20 else 1.3),"tight 90-degree keyboard turn responds promptly: "+str(kph)+"/"+str(direction))
			check(result.body_within_10m_lane,"configured collision envelope fits an unchanged 8m-wide, 4m-radius bend: "+str(kph)+"/"+str(direction))
			check(result.exit_x>=12 and absf(result.exit_degrees-90.0)<7.0,"tight keyboard corner exits aligned and moving: "+str(kph)+"/"+str(direction))
			check(result.replay_exact,"tight corner replays exactly")
	var file := FileAccess.open(AUTHORITY_OUTPUT+"/keyboard-corners.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"metrics":metrics},"\t"))
	file.close()
	print("ELECTRIC_CORNER_AUTHORITY: %d checks, %d failures " % [checks,failures],JSON.stringify(metrics))
	quit(1 if failures else 0)
