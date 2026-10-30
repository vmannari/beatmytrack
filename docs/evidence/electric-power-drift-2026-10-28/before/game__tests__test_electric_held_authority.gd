extends "res://tests/test_electric_turn_radius.gd"

const HELD_OUTPUT: String = "res://../docs/evidence/electric-tighter-held-steering-2026-10-26"

func powered_launch(config: HandlingConfig, steering: float, pedal: float) -> Dictionary:
	var sim := VehicleSimulation.new(config)
	var peak: float = 0.0
	for tick: int in range(120):
		sim.step(DriveFrame.sample(steering,pedal,0))
		peak=maxf(peak,rad_to_deg(absf(sim.state.slip_angle())))
	return {"peak_slip_degrees":peak,"speed":sim.state.velocity.length()}

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--evidence-root="): output=argument.trim_prefix("--evidence-root=")
	var old: HandlingConfig=load(HELD_OUTPUT+"/before/game__resources__cars__electric.tres") as HandlingConfig
	var current: HandlingConfig=VehicleCatalog.config("electric")
	check(old.version=="electric-14" and current.version=="electric-19","held steering has a new configuration identity")
	check(current.steering_rate>old.steering_rate and current.countersteering_rate>=old.countersteering_rate,"connected buildup retains immediate unwind and useful held lock")
	metrics.circles={}
	var last: float=0.0
	for kph: float in [5.0,10.0,20.0,30.0,40.0,60.0,90.0,140.0,190.0]:
		var before: Dictionary=held_circle(old,kph/3.6,1.0)
		var after: Dictionary=held_circle(current,kph/3.6,1.0)
		var mirror: Dictionary=held_circle(current,kph/3.6,-1.0)
		metrics.circles[str(kph)]={"before":before,"after":after}
		check(after.angle>=TAU and after.replay_exact,"held travel circle completes and replays exactly: "+str(kph))
		check(after.minimum_speed>kph/3.6*0.98,"circle keeps the requested speed: "+str(kph))
		check(after.radius<=before.radius*(0.80 if kph<=60 else 0.90),"sustained path is materially tighter than rejected electric-14: "+str(kph))
		check(after.radius>=last*0.995,"held circle widens progressively with speed: "+str(kph))
		check(is_equal_approx(after.radius,mirror.radius),"left/right steering stays symmetric: "+str(kph))
		last=after.radius
	metrics.launches={}
	for steer: float in [0.35,0.65,1.0]:
		for pedal: float in [0.65,1.0]:
			var launch: Dictionary=powered_launch(current,steer,pedal)
			metrics.launches[str(steer)+"/"+str(pedal)]=launch
			check(launch.peak_slip_degrees<24.0,"deliberate launch slide stays bounded with the stronger steering: "+str(steer)+"/"+str(pedal))
	var file := FileAccess.open(output+"/held-authority.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"metrics":metrics},"\t"))
	file.close()
	print("ELECTRIC_HELD_AUTHORITY: %d checks, %d failures " % [checks,failures],JSON.stringify(metrics))
	quit(1 if failures else 0)
