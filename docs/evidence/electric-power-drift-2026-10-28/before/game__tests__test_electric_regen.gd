extends SceneTree
## Release braking and exact unchanged power, independent of player saves.
const _NATIVE_TRACK = preload("res://track/native_track.gd")
const OUTPUT: String = "res://../docs/evidence/electric-regen-2026-10-27"
var output: String = OUTPUT
var checks: int = 0
var failures: int = 0

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: "+label)

func stopping(config: HandlingConfig, speed: float) -> Dictionary:
	var sim := VehicleSimulation.new(config)
	sim.state.velocity = Vector2(0,speed)
	var driver := DriverInput.new()
	driver.single_pedal = true
	driver.reverse_selected = speed < 0
	driver.set_touch(0,&"accelerate")
	driver.release_touch(0)
	var frame: DriveFrame = driver.sample()
	var ticks: int = 0
	var first: float = 0
	var previous: float = absf(speed)
	var monotonic: bool = true
	while sim.state.velocity != Vector2.ZERO and ticks < 1200:
		sim.step(frame)
		var after: float = sim.state.velocity.length()
		if ticks == 0: first = (absf(speed)-after)*120.0
		monotonic = monotonic and after <= previous and sim.state.velocity.y*speed >= 0
		previous = after
		ticks += 1
	var stopped: bool = sim.state.velocity == Vector2.ZERO
	var position: Vector2 = sim.state.position
	for idle: int in range(600): sim.step(frame)
	return {"seconds":ticks/120.0,"metres":absf(position.y),"first_deceleration":first,
		"monotonic":monotonic,"stopped":stopped,
		"holds":sim.state.velocity==Vector2.ZERO and sim.state.position==position and sim.state.reverse_wait==0.0}

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--evidence-root="): output = argument.trim_prefix("--evidence-root=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	var old: HandlingConfig = load(OUTPUT+"/before/game__resources__cars__electric.tres") as HandlingConfig
	var current: HandlingConfig = VehicleCatalog.config("electric")
	check(old.version=="electric-18" and current.version=="electric-19","regen change has its own Electric handling identity")
	check(current.regeneration==20.0 and VehicleSimulation.PHYSICS_VERSION=="arcade-planar-0.75","stronger regen retains the shared physics identity")
	var old_fields: Dictionary = old.snapshot()
	var new_fields: Dictionary = current.snapshot()
	check(old_fields.size()==new_fields.size(),"regen adds no configuration fields")
	for field: String in old_fields:
		if field in ["version","regeneration"]: continue
		check(old_fields[field]==new_fields[field],"all other Electric settings stay exact: "+field)
	var metrics: Dictionary = {"stops":{},"electric":{"handling_version":current.version,"config_hash":JSON.stringify(new_fields,"",true).sha256_text()}}
	for speed: float in [0.001,0.14,1.0,7.0,20.0,100.0/3.6,current.maximum_speed,-0.001,-0.14,-1.0,-7.0]:
		var before: Dictionary = stopping(old,speed)
		var after: Dictionary = stopping(current,speed)
		metrics.stops[str(speed)] = {"before":before,"after":after}
		check(after.monotonic and after.stopped and after.holds,"touch release stops and holds without creep or reverse: "+str(speed))
		if absf(speed)>=7.0:
			check(after.seconds<=before.seconds*0.78 and after.metres<=before.metres*0.78,"release shortens time and distance by at least 22%: "+str(speed))
	check(metrics.stops["20.0"].after.seconds>=0.95 and metrics.stops["20.0"].after.seconds<=1.05 and metrics.stops["20.0"].after.metres>=9.5 and metrics.stops["20.0"].after.metres<=10.2,"72km/h lift stops in about one second and ten metres")
	check(metrics.stops["20.0"].after.first_deceleration>=20.0 and metrics.stops["20.0"].after.first_deceleration<21.0,"full regen acts on the first released-pedal tick")
	var previous: float = -1.0
	for pedal: int in range(62):
		var sim := VehicleSimulation.new(current)
		sim.state.velocity = Vector2(0,20)
		sim.step(DriveFrame.sample(0,pedal/255.0,0))
		check(sim.state.velocity.y>previous,"quantized pedal smoothly reduces regen toward coast: "+str(pedal))
		previous = sim.state.velocity.y
	for direction: int in [0,1]:
		var before := VehicleSimulation.new(old)
		var after := VehicleSimulation.new(current)
		var replay := VehicleSimulation.new(current)
		var restored := VehicleSimulation.new(current)
		var exact_power: bool = true
		var exact_replay: bool = true
		for tick: int in range(2400):
			var powered := DriveFrame.sample(sin(tick*0.02)*0.65,0.3+0.7*absf(sin(tick*0.007)),direction)
			before.step(powered)
			after.step(powered)
			exact_power = exact_power and before.state.snapshot()==after.state.snapshot()
			var mixed := DriveFrame.sample(sin(tick*0.02)*0.65,1 if tick%240<150 else 0,direction)
			replay.step(mixed)
			restored.step(mixed)
			exact_replay = exact_replay and replay.state.snapshot()==restored.state.snapshot()
		check(exact_power,"powered steering/acceleration stays tick-exact, D/R="+str(direction))
		check(exact_replay,"regen and powered turns replay exactly, D/R="+str(direction))
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(OUTPUT+"/before/backend__tests__fixtures__verified_oval.json"))
	for id: String in VehicleCatalog.IDS:
		if id=="electric": continue
		var config: HandlingConfig = VehicleCatalog.config(id)
		check(JSON.stringify(config.snapshot(),"",true).sha256_text()==fixture.expected_manifest.vehicles[id].config_hash,"other car identity stays exact: "+id)
	var file := FileAccess.open(output+"/regen.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"metrics":metrics},"\t"))
	file.close()
	print("ELECTRIC_REGEN: %d checks, %d failures %s" % [checks,failures,JSON.stringify(metrics)])
	quit.call_deferred(1 if failures else 0)
