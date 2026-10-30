extends "res://tests/probe_electric_slide_access.gd"

func run() -> void:
	var old: HandlingConfig=load(SLIDE_OUTPUT+"/before/game__resources__cars__electric.tres") as HandlingConfig
	var current: HandlingConfig=VehicleCatalog.config("electric")
	check(old.version=="electric-17" and current.version=="electric-18" and VehicleSimulation.PHYSICS_VERSION=="arcade-planar-0.75","slide onset and braking have a new canonical identity")
	var changed: Array[String]=["version","regeneration","launch_lateral_response_scale","power_lateral_response_scale","power_slide_full_pedal","slide_drive_loss"]
	for field: String in old.snapshot():
		if field in changed: continue
		check(current.get(field)==old.get(field),"retained electric field: "+field)
	metrics.turns={}
	for speed: float in [0.0,10.0,30.0,50.0,80.0,120.0,170.0]:
		for steer: float in [0.35,0.65,1.0]:
			for pedal: float in [0.55,0.65,0.8,1.0]:
				var before: Dictionary=slide_sample(old,speed,steer,pedal)
				var after: Dictionary=slide_sample(current,speed,steer,pedal)
				var mirror: Dictionary=slide_sample(current,speed,-steer,pedal)
				var label: String=str(speed)+"/"+str(steer)+"/"+str(pedal)
				metrics.turns[label]={"before":before,"after":after}
				check(after.peak>before.peak*1.2 and after.peak<26.0,"power develops a noticeable bounded slide: "+label)
				check(after.end_kph>speed and after.end_kph>=before.end_kph*0.78,"power slide retains useful acceleration: "+label)
				check(after.recovery_ms>0 and after.recovery_ms<=300 and after.final_slip<0.1,"straightening catches the slide within 300ms: "+label)
				check(after.replay_exact and is_equal_approx(after.peak,mirror.peak),"slide replays exactly and mirrors left/right: "+label)
				if steer==1.0 and pedal>=0.65 and speed<=80.0:
					check(before.sliding_ticks==0 and after.sliding_ticks>=60 and after.minimum_grip<before.minimum_grip,"moderate pedal and full lock sustain at least half a second of actual sliding: "+label)
					check(after.onset_ms>0 and after.onset_ms<=(850 if speed==0.0 else 600),"sliding starts promptly, including standstill launch: "+label)
	# The new pedal gate must build progressively, with no discontinuous kick.
	metrics.pedal_ramp=[]
	var last_peak: float=0.0
	for packed: int in range(115,167):
		var sample: Dictionary=slide_sample(current,50.0,0.65,float(packed)/255.0)
		check(sample.peak>=last_peak-0.01 and (last_peak==0.0 or absf(sample.peak-last_peak)<0.75),"quantized controller pedal develops the slide smoothly: "+str(packed))
		last_peak=sample.peak
		metrics.pedal_ramp.append(sample.peak)
	# Same tune with the old gate isolates the controller change from slide strength.
	var old_gate: HandlingConfig=current.duplicate() as HandlingConfig
	old_gate.power_slide_full_pedal=0.85
	metrics.controller={"old_gate":slide_sample(old_gate,50,1,0.65),"new_gate":slide_sample(current,50,1,0.65)}
	check(metrics.controller.new_gate.peak>metrics.controller.old_gate.peak*2.0,"moderate controller accelerator reaches the power slide substantially sooner")
	# Default field preserves old arithmetic and identities for all seven old profiles.
	var legacy := GDScript.new()
	legacy.source_code=FileAccess.get_file_as_string(SLIDE_OUTPUT+"/before/game__vehicle__vehicle_simulation.gd").replace("class_name VehicleSimulation","").trim_prefix("\ufeff")
	check(legacy.reload()==OK,"task-start canonical integrator compiles")
	for id: String in VehicleCatalog.IDS:
		var config: HandlingConfig=old if id=="electric" else VehicleCatalog.config(id)
		check(not config.snapshot().has("power_slide_full_pedal") and not config.snapshot().has("power_slide_high_speed_scale"),"default slide controls preserve old snapshot: "+id)
		var before: RefCounted=legacy.new(config)
		var after := VehicleSimulation.new(config)
		var exact: bool=true
		for tick: int in range(1200):
			var frame := DriveFrame.sample(sin(tick*0.02),1 if tick%240<150 else 0,0.7 if tick%240>200 else 0,1 if tick%120<10 else 0)
			before.step(frame)
			after.step(frame)
			exact=exact and before.state.snapshot()==after.state.snapshot()
		check(exact,"default gate retains all task-start canonical ticks: "+id)
	# Off-power and held-neutral geometry remain exact with regeneration matched.
	var neutral: HandlingConfig=old.duplicate() as HandlingConfig
	neutral.regeneration=current.regeneration
	for speed: float in [5.0,10.0,20.0,30.0,40.0,100.0,190.0]:
		for steer: float in [0.35,0.65,1.0]:
			var before := VehicleSimulation.new(neutral)
			var after := VehicleSimulation.new(current)
			before.state.velocity=Vector2(0,speed/3.6)
			after.state.velocity=before.state.velocity
			var exact: bool=true
			for tick: int in range(360):
				var frame := DriveFrame.sample(steer,current.coast_pedal,0)
				before.step(frame)
				after.step(frame)
				exact=exact and before.state.snapshot()==after.state.snapshot()
			check(exact,"neutral pedal keeps existing steering geometry and grip: "+str(speed)+"/"+str(steer))
	for reverse: bool in [false,true]:
		var before := VehicleSimulation.new(old)
		var after := VehicleSimulation.new(current)
		var exact: bool=true
		for tick: int in range(2400):
			var frame := DriveFrame.sample(0,1,1 if reverse else 0)
			before.step(frame)
			after.step(frame)
			exact=exact and before.state.snapshot()==after.state.snapshot()
		check(exact,"straight launch and powered cap remain tick exact, reverse="+str(reverse))
	metrics.braking={}
	for speed: float in [20.0,72.0,100.0,190.0,-25.2]:
		var before: Dictionary=stop_sample(old,speed)
		var after: Dictionary=stop_sample(current,speed)
		metrics.braking[str(speed)]={"before":before,"after":after}
		check(after.seconds<before.seconds*0.83 and absf(after.metres)<absf(before.metres)*0.83 and after.seconds>before.seconds*0.7,"braking is moderately stronger in both directions: "+str(speed))
	check(current.maximum_speed*3.6>189.999 and current.maximum_speed*3.6<190.001,"190km/h cap retained")
	var file := FileAccess.open("res://../build/re-audit-2026-10-27/electric-slide-access.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"metrics":metrics},"\t"))
	file.close()
	print("ELECTRIC_SLIDE_ACCESS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
