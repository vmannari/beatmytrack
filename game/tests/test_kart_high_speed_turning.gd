extends SceneTree
## Compare actual velocity paths at matched speeds against the saved kart-5 tune.

const EVIDENCE: String = "res://../docs/evidence/kart-high-speed-turning-2026-10-28"
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ",label)

func circle(config: HandlingConfig, kph: float, steering: float) -> Dictionary:
	var speed: float = kph/3.6
	var sim := VehicleSimulation.new(config)
	sim.state.velocity = Vector2(0,speed)
	var frames: Array[DriveFrame] = []
	var integral: float = 0.0
	var distance: float = 0.0
	var angle: float = 0.0
	var minimum_speed: float = INF
	var maximum_speed: float = 0.0
	var peak_slip: float = 0.0
	for tick: int in range(120*45):
		var travel_speed: float = sim.state.velocity.length()
		var error: float = speed-travel_speed
		integral = clampf(integral+error*VehicleSimulation.STEP*4.0,-5.0,12.0)
		var drag: float = (config.rolling_resistance+config.drag*travel_speed*travel_speed)/config.mass
		var power: float = config.engine_force/config.mass*(1.0-0.45*travel_speed/config.maximum_speed)
		var frame := DriveFrame.sample(steering,clampf((error*5.0+integral+drag)/power,0,1),0)
		frames.append(frame)
		var position: Vector2 = sim.state.position
		var velocity: Vector2 = sim.state.velocity
		sim.step(frame)
		if tick >= 360:
			distance += sim.state.position.distance_to(position)
			angle += velocity.angle_to(sim.state.velocity)*-signf(steering)
			minimum_speed = minf(minimum_speed,sim.state.velocity.length())
			maximum_speed = maxf(maximum_speed,sim.state.velocity.length())
			peak_slip = maxf(peak_slip,absf(rad_to_deg(sim.state.slip_angle())))
		if angle >= TAU: break
	var final: Array = sim.state.snapshot()
	var recovery_ms: float = 0.0
	for tick: int in range(240):
		sim.step(DriveFrame.sample(0,0.5,0))
		if recovery_ms == 0.0 and absf(sim.state.slip_angle()) < 0.01 and absf(sim.state.yaw_rate) < 0.01:
			recovery_ms = (tick+1)*1000.0/120.0
	var replay := VehicleSimulation.new(config)
	replay.state.velocity = Vector2(0,speed)
	# Four canonical steps per presentation frame (30 Hz) must match 120 Hz.
	for start: int in range(0,frames.size(),4):
		for index: int in range(start,mini(start+4,frames.size())): replay.step(frames[index])
	return {"radius":distance/maxf(angle,0.00001),"angle":angle,"minimum_kph":minimum_speed*3.6,"maximum_kph":maximum_speed*3.6,"peak_slip_deg":peak_slip,"recovery_ms":recovery_ms,"replay_exact":final==replay.state.snapshot(),"ticks":frames.size()}

func run() -> void:
	var old: HandlingConfig = load("res://tests/fixtures/kart_high_speed_turning_before.tres")
	# This historical comparison is pinned to the tune it originally measured.
	var current: HandlingConfig = load("res://tests/fixtures/kart_realistic_turning_before.tres")
	var output: String = EVIDENCE
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--evidence-root="): output = arg.trim_prefix("--evidence-root=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	check(old.version == "kart-5" and current.version == "kart-6","distinct identity for high-speed cornering")
	check(current.lateral_grip == 80.0,"modest high-speed cornering grip increase")
	var before_fields: Dictionary = old.snapshot()
	var after_fields: Dictionary = current.snapshot()
	for field: String in ["version","lateral_grip"]:
		before_fields.erase(field)
		after_fields.erase(field)
	check(before_fields == after_fields,"only cornering grip and version change")
	var turns: Array[Dictionary] = []
	for kph: float in [10.0,20.0,30.0,40.0,60.0,80.0,100.0,120.0,140.0]:
		for steering: float in [0.45,1.0]:
			var before := circle(old,kph,steering)
			var after := circle(current,kph,steering)
			var mirror := circle(current,kph,-steering)
			var ratio: float = after.radius/before.radius
			var label: String = "%s km/h, steer %s" % [kph,steering]
			check(before.angle >= TAU and after.angle >= TAU,"complete actual circles: "+label)
			check(before.minimum_kph > kph*0.98 and after.minimum_kph > kph*0.98 and after.maximum_kph <= kph*1.02,"maintained matched speed: "+label)
			check(ratio >= 0.86 and ratio <= 1.002,"bounded tightening without wider turns: "+label)
			if kph <= 30: check(absf(ratio-1.0)<0.01,"low-speed turns stay within one percent: "+label)
			if kph >= 80 and steering == 1.0 or kph >= 100:
				check(ratio < 0.95,"high-speed radius at least five percent shorter: "+label)
			check(is_equal_approx(after.radius,mirror.radius),"left/right symmetry: "+label)
			check(after.replay_exact and mirror.replay_exact,"exact 120/30 Hz replay: "+label)
			check(after.peak_slip_deg < 12.0,"kart retains its planted cornering: "+label)
			check(after.recovery_ms > 0 and after.recovery_ms <= 350.0,"steering release settles quickly: "+label)
			turns.append({"kph":kph,"steering":steering,"before":before,"after":after,"radius_ratio":ratio})
	for mode: int in range(4):
		var before := VehicleSimulation.new(old)
		var after := VehicleSimulation.new(current)
		if mode == 1 or mode == 2:
			before.state.velocity = Vector2(0,old.maximum_speed)
			after.state.velocity = before.state.velocity
		var exact: bool = true
		for tick: int in range(3600):
			var frame := DriveFrame.sample(0,1 if mode == 0 else 0,1 if mode == 1 or mode == 3 else 0)
			before.step(frame)
			after.step(frame)
			exact = exact and before.state.snapshot() == after.state.snapshot()
		check(exact,"straight power/brake/lift/reverse stays tick-exact, mode="+str(mode))
		if mode == 0: check(absf(after.state.velocity.length()*3.6-140.0)<0.001,"140 km/h top speed retained")
	var track: NativeTrack = NativeTrack.read("res://tests/fixtures/legacy_tracks/slicks_arto4_test.json")
	var records := LocalRecords.new("user://kart_high_speed_identity.json")
	check(records.key_for(track,old) != records.key_for(track,current),"historical PB rules stay separate")
	var report: Dictionary = {"checks":checks,"failures":failures,"turns":turns,"handling_version":current.version,"config_hash":JSON.stringify(current.snapshot(),"",true).sha256_text(),"physics_version":VehicleSimulation.PHYSICS_VERSION}
	var file := FileAccess.open(output+"/turning.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	file.close()
	print("KART_HIGH_SPEED_TURNING: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
