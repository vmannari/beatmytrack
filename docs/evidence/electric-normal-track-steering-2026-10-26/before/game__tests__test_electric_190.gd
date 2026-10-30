extends "res://tests/test_electric_power.gd"

const SPEED_OUTPUT: String = "res://../docs/evidence/electric-usable-steering-2026-10-26"
const SPEED_BASELINE: String = "res://../docs/evidence/electric-190-2026-10-25"

func run() -> void:
	var old: HandlingConfig = load(SPEED_BASELINE+"/before/game__resources__cars__electric.tres") as HandlingConfig
	var current: HandlingConfig = VehicleCatalog.config("electric")
	check(old.version == "electric-10" and current.version == "electric-13","top-speed correction has a new handling identity")
	check(absf(current.maximum_speed*3.6-190.0)<0.001,"configured top speed is 190 km/h")
	for property: String in old.snapshot():
		if property in ["version","maximum_speed","steering_rate","countersteering_rate","steering_angle","low_speed_steering_scale","low_speed_steering_rate_scale","low_speed_turn_radius","low_speed_turn_acceleration"]: continue
		check(old.get(property)==current.get(property),"accepted field retained exactly: "+property)
	var sim := VehicleSimulation.new(current)
	var replay := VehicleSimulation.new(current)
	var old_sim := VehicleSimulation.new(old)
	var old_100: int = 0
	var new_100: int = 0
	var reached: int = 0
	var exact: bool = true
	for tick: int in range(1200):
		var frame := DriveFrame.sample(0,1,0)
		sim.step(frame)
		replay.step(frame)
		old_sim.step(frame)
		exact = exact and sim.state.snapshot()==replay.state.snapshot()
		if old_100==0 and old_sim.state.velocity.length()>=100.0/3.6: old_100=tick+1
		if new_100==0 and sim.state.velocity.length()>=100.0/3.6: new_100=tick+1
		if reached==0 and sim.state.velocity.length()>=190.0/3.6-0.001: reached=tick+1
	check(reached>0 and reached<1200,"sustained full throttle actually reaches 190 km/h")
	check(new_100>0 and old_100>0,"both actual tunes reach 100 km/h")
	var minimum_speed: float = INF
	var maximum_speed: float = 0.0
	for tick: int in range(3600):
		var frame := DriveFrame.sample(0,1,0)
		sim.step(frame)
		replay.step(frame)
		exact = exact and sim.state.snapshot()==replay.state.snapshot()
		minimum_speed = minf(minimum_speed,sim.state.velocity.length())
		maximum_speed = maxf(maximum_speed,sim.state.velocity.length())
	check(minimum_speed*3.6>189.99 and maximum_speed*3.6<190.001,"holds 190 for thirty seconds without exceeding the cap")
	var stop_start: Vector2 = sim.state.position
	var stopping_ticks: int = 0
	var monotonic: bool = true
	var speed: float = sim.state.velocity.length()
	while sim.state.velocity!=Vector2.ZERO and stopping_ticks<600:
		var frame := DriveFrame.sample(0,0,0)
		sim.step(frame)
		replay.step(frame)
		exact = exact and sim.state.snapshot()==replay.state.snapshot()
		monotonic = monotonic and sim.state.velocity.length()<=speed and sim.state.velocity.y>=0
		speed=sim.state.velocity.length()
		stopping_ticks+=1
	check(monotonic and sim.state.velocity==Vector2.ZERO,"release brakes monotonically from 190 without reversing")
	check(stopping_ticks/120.0<2.1 and sim.state.position.distance_to(stop_start)<55.0,"retained braking stops from 190 within measured safety bounds")
	for tick: int in range(600):
		var frame := DriveFrame.sample(1,0,0)
		sim.step(frame)
		replay.step(frame)
		exact = exact and sim.state.snapshot()==replay.state.snapshot()
	check(sim.state.velocity==Vector2.ZERO,"released pedal holds zero after the high-speed stop")
	check(exact,"launch, sustained cap, stop and hold replay tick-exactly")
	metrics={"old_100_seconds":old_100/120.0,"new_100_seconds":new_100/120.0,"reaches_190_seconds":reached/120.0,"hold_minimum_kph":minimum_speed*3.6,"hold_maximum_kph":maximum_speed*3.6,"stop_190_seconds":stopping_ticks/120.0,"stop_190_metres":sim.state.position.distance_to(stop_start)}
	var file := FileAccess.open(SPEED_OUTPUT+"/speed.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"metrics":metrics},"\t"))
	file.close()
	print("ELECTRIC_190: %d checks, %d failures " % [checks,failures],JSON.stringify(metrics))
	quit(1 if failures else 0)
