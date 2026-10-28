extends "res://tests/test_forklift_clearance.gd"
## Actual velocity-path comparisons against the accepted forklift-3 tune.
const EVIDENCE: String = "res://../docs/evidence/forklift-high-speed-turning-2026-10-25"

func path_turn(original: HandlingConfig, speed: float, steering: float) -> Dictionary:
	var config := original.duplicate() as HandlingConfig
	config.maximum_speed = speed
	var sim := VehicleSimulation.new(config)
	sim.state.velocity = Vector2(0,speed)
	var distance: float = 0.0
	var course: float = 0.0
	var elapsed: float = 0.0
	var peak_slip: float = 0.0
	var points: Array = [[0.0,0.0]]
	var frames: Array[DriveFrame] = []
	for tick: int in range(360):
		var frame: DriveFrame = DriveFrame.sample(steering,1,0)
		frames.append(frame)
		var previous: Vector2 = sim.state.velocity
		var at: Vector2 = sim.state.position
		sim.step(frame)
		elapsed += VehicleSimulation.STEP
		distance += sim.state.position.distance_to(at)
		course += absf(previous.angle_to(sim.state.velocity))
		peak_slip = maxf(peak_slip,absf(rad_to_deg(sim.state.slip_angle())))
		if tick%4 == 0: points.append([sim.state.position.x,sim.state.position.y])
		if course>=PI*0.5: break
	var quarter_state: Array = sim.state.snapshot()
	var complete: bool = course>=PI*0.5
	var speed_at_turn: float = sim.state.velocity.length()
	for tick: int in range(240): sim.step(DriveFrame.sample(0,1,0))
	var recovered: bool = absf(sim.state.yaw_rate)<0.01 and absf(sim.state.slip_angle())<0.03
	var replay := VehicleSimulation.new(config)
	replay.state.velocity = Vector2(0,speed)
	for start: int in range(0,frames.size(),4):
		for index: int in range(start,mini(start+4,frames.size())): replay.step(frames[index])
	return {"complete":complete,"seconds":elapsed,"radius":distance/maxf(course,0.00001),"speed":speed_at_turn,"peak_slip_deg":peak_slip,"recovered":recovered,"exact_replay":quarter_state == replay.state.snapshot(),"points":points}

func _run() -> void:
	output = EVIDENCE
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	var old: HandlingConfig = load(EVIDENCE+"/before/game__resources__cars__forklift.tres")
	var current: HandlingConfig = VehicleCatalog.config("forklift")
	if "--probe" in OS.get_cmdline_user_args():
		var probes: Array = []
		for grip: float in [42.0,44.0,45.0,46.0]:
			var candidate := old.duplicate() as HandlingConfig
			candidate.lateral_grip = grip
			var cases: Array = []
			for speed: float in [8.0,14.0,18.5,current.maximum_speed]:
				var circle: Dictionary = _circle(candidate,speed,0.45)
				var turn: Dictionary = path_turn(candidate,speed,0.45)
				turn.erase("points")
				cases.append({"speed":speed,"circle":circle,"turn":turn})
			probes.append({"lateral_grip":grip,"cases":cases})
		var file := FileAccess.open(output+"/probes.json",FileAccess.WRITE)
		file.store_string(JSON.stringify(probes,"\t")); file.close()
		print("FORKLIFT_TURNING_PROBES ",JSON.stringify(probes))
		quit()
		return
	check(old.version == "forklift-3" and current.version == "forklift-4","high-speed tune gets a distinct version from the accepted baseline")
	var old_fields: Dictionary = old.snapshot()
	var new_fields: Dictionary = current.snapshot()
	old_fields.erase("version"); new_fields.erase("version")
	old_fields.erase("lateral_grip"); new_fields.erase("lateral_grip")
	check(old_fields == new_fields,"only cornering grip and version change; input, geometry, power and speed remain")
	var turns: Array = []
	for speed: float in [3.0,8.0,14.0,18.5,current.maximum_speed]:
		for steering: float in [-1.0,-0.45,0.45,1.0]:
			var baseline: Dictionary = _circle(old,speed,steering)
			var after: Dictionary = _circle(current,speed,steering)
			var label: String = "%s m/s, steering %s" % [speed,steering]
			var ratio: float = after.radius/baseline.radius
			if speed<=8.0: check(absf(ratio-1.0)<0.01,"low-speed turning stays within one percent: "+label)
			else: check(ratio>=0.90 and ratio<=(0.98 if speed<18.5 else 0.96),"actual radius is modestly tighter at driving speed, at least four percent above 66 km/h: "+label)
			check(after.speed>=baseline.speed*0.99,"tighter turn retains speed: "+label)
			check(after.recovered,"rear-steering settles after release: "+label)
			var entry: Dictionary = {"speed_cap":speed,"steering":steering,"before":baseline,"after":after,"radius_ratio":ratio}
			if speed>=14.0:
				var old_turn: Dictionary = path_turn(old,speed,steering)
				var new_turn: Dictionary = path_turn(current,speed,steering)
				check(old_turn.complete and new_turn.complete,"both real paths complete a quarter turn: "+label)
				check(new_turn.seconds<=old_turn.seconds,"actual travel direction completes the turn sooner: "+label)
				check(new_turn.peak_slip_deg<=old_turn.peak_slip_deg+1.5 and new_turn.peak_slip_deg<25.0,"high-speed tail swing stays close to the accepted tune: "+label)
				check(new_turn.exact_replay,"quarter-turn replay is exact at 120/30Hz batches: "+label)
				entry.quarter_before = old_turn; entry.quarter_after = new_turn
			turns.append(entry)
	var a := VehicleSimulation.new(old)
	var b := VehicleSimulation.new(current)
	var straight_exact: bool = true
	for tick: int in range(1800):
		var frame: DriveFrame = DriveFrame.sample(0,1 if tick<1200 else 0,0 if tick<1200 else 1)
		a.step(frame); b.step(frame)
		straight_exact = straight_exact and a.state.snapshot() == b.state.snapshot()
	check(straight_exact,"straight acceleration, 80 km/h cap and full braking remain tick-exact")
	var old_front := VehicleSimulation.new(old)
	var new_front := VehicleSimulation.new(current)
	for tick: int in range(1200):
		old_front.step(DriveFrame.sample(0,1,0)); new_front.step(DriveFrame.sample(0,1,0))
	check(absf(new_front.state.velocity.length()*3.6-80.0)<0.01,"actual top speed remains 80 km/h")
	measures = {"version":current.version,"config_hash":JSON.stringify(current.snapshot(),"",true).sha256_text(),"physics_version":VehicleSimulation.PHYSICS_VERSION,"turns":turns}
	var report := FileAccess.open(output+"/turning.json",FileAccess.WRITE)
	report.store_string(JSON.stringify({"checks":checks,"failures":failures,"measurements":measures},"\t")); report.close()
	print("FORKLIFT_HIGH_SPEED_TURNING: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
