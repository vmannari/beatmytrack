extends SceneTree
## One-pedal, rear-axle traction and replay acceptance, isolated from player saves.
var checks: int = 0
var failures: int = 0
var metrics: Dictionary = {}
const OUTPUT: String = "res://../docs/evidence/electric-refinement-2026-10-25"
var output: String = OUTPUT

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: "+label)

func moving(speed: float, handling: HandlingConfig = null) -> VehicleSimulation:
	var sim := VehicleSimulation.new(VehicleCatalog.config("electric") if handling == null else handling)
	sim.state.velocity = Vector2(0,speed)
	return sim

func advance(sim: VehicleSimulation, count: int, throttle: float = 0.0, brake: float = 0.0, steer: float = 0.0) -> void:
	for tick: int in range(count): sim.step(DriveFrame.sample(steer,throttle,brake))

func unpack(packed: Array) -> DriveFrame:
	return DriveFrame.sample(float(packed[0])/127,float(packed[1])/255,float(packed[2])/255,float(packed[3])/255 if packed.size()>3 else 0.0)

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--evidence-root="): output = argument.trim_prefix("--evidence-root=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	var config: HandlingConfig = VehicleCatalog.config("electric")
	check(config.vehicle_id == "electric" and config.rear_wheel_drive and config.regeneration > 0.0,"authored electric rear-drive identity")
	check(VehicleCatalog.IDS.size() == VehicleCatalog.NAMES.size() and VehicleCatalog.IDS.size() == VehicleCatalog.CLASSES.size() and VehicleCatalog.IDS.size() == VehicleCatalog.DESCRIPTIONS.size(),"catalogue arrays agree")
	check(config.snapshot().regeneration == 11.0 and config.snapshot().rear_wheel_drive and config.single_pedal,"competitive tune pins strict one-pedal capabilities")
	for speed: float in [0.01,0.14,1.0,10.0,20.0,48.0,-0.01,-0.14,-1.0,-7.0]:
		var lift: VehicleSimulation = moving(speed)
		var monotonic: bool = true
		var previous: float = absf(speed)
		var stopped_tick: int = 0
		for tick: int in range(1800):
			lift.step(DriveFrame.new())
			var current: float = lift.state.velocity.y
			monotonic = monotonic and absf(current) <= previous + 0.0000001 and current * speed >= 0.0
			previous = absf(current)
			if current == 0.0 and stopped_tick == 0: stopped_tick = tick + 1
		check(monotonic and lift.state.velocity == Vector2.ZERO,"lift stops without reversing or adding energy from "+str(speed))
		check(lift.state.reverse_wait == 0.0,"lift never arms reverse from "+str(speed))
		if speed == 20.0: metrics.lift_72_kph = {"seconds":stopped_tick / 120.0,"metres":lift.state.position.y}
	var full_lift: VehicleSimulation = moving(20.0)
	var partial_lift: VehicleSimulation = moving(20.0)
	var powered: VehicleSimulation = moving(20.0)
	advance(full_lift,120)
	advance(partial_lift,120,0.10)
	advance(powered,120,0.5)
	check(full_lift.state.velocity.y < partial_lift.state.velocity.y and partial_lift.state.velocity.y < 20.0 and powered.state.velocity.y > 20.0,"analogue accelerator progresses from regeneration through coast to drive")
	var selected_reverse: VehicleSimulation = moving(20.0)
	advance(selected_reverse,120,0,1)
	check(selected_reverse.state.snapshot() == full_lift.state.snapshot(),"D/R selector alone never supplies braking beyond released-pedal regeneration")
	var reverse: VehicleSimulation = moving(0)
	advance(reverse,120,1,1)
	check(reverse.state.velocity.y < -0.5,"selected Reverse uses the same accelerator")
	advance(reverse,360,0,1)
	check(reverse.state.velocity == Vector2.ZERO,"releasing the sole pedal stops in Reverse")
	advance(reverse,240,1)
	check(reverse.state.velocity.y > 10,"selected Drive accelerates forward after stopping")
	var launch: VehicleSimulation = moving(0)
	var launch_ticks: int = 0
	while launch.state.velocity.y < 20 and launch_ticks < 1200:
		advance(launch,1,1)
		launch_ticks += 1
	metrics.launch_72_kph_seconds = launch_ticks / 120.0
	check(launch_ticks < 240,"strong electric launch reaches 72 kph within two seconds")
	advance(launch,2400,1)
	check(launch.state.velocity.length() <= config.maximum_speed,"electric obeys speed cap")
	# Rear-axle torque is constrained separately from four-wheel friction braking.
	var all_wheels: HandlingConfig = config.duplicate() as HandlingConfig
	all_wheels.rear_wheel_drive = false
	var rear: VehicleSimulation = moving(0,config)
	var all: VehicleSimulation = moving(0,all_wheels)
	advance(rear,60,1)
	advance(all,60,1)
	check(rear.state.velocity.y < all.state.velocity.y,"rear motor uses the driven axle traction budget")
	var no_rotation: HandlingConfig = config.duplicate() as HandlingConfig
	no_rotation.throttle_rotation = 0.0
	var corner: VehicleSimulation = moving(22)
	var control: VehicleSimulation = moving(22,no_rotation)
	advance(corner,45,1,0,0.65)
	advance(control,45,1,0,0.65)
	check(corner.state.heading > control.state.heading,"rear torque adds bounded power rotation")
	# Rewind restores every canonical field; render batching cannot alter the inputs.
	var replay: VehicleSimulation = moving(0)
	var sim: VehicleSimulation = moving(0)
	var frames: Array[Array] = []
	var saved: Dictionary
	for tick: int in range(2400):
		var frame := DriveFrame.sample(sin(tick * 0.017)*0.7,1.0 if tick % 480 < 300 else 0.0,0.5 if tick % 480 > 400 else 0.0,1.0 if tick % 700 < 20 else 0.0)
		frames.append(frame.packed())
		sim.step(frame)
		if tick == 1199: saved = RewindHistory.pack_state(sim.state)
	for packed: Array in JSON.parse_string(JSON.stringify(frames)):
		replay.step(unpack(packed))
	check(replay.state.snapshot() == sim.state.snapshot(),"quantized JSON replay is exact")
	RewindHistory.restore(replay.state,saved)
	for tick: int in range(1200,2400): replay.step(unpack(frames[tick]))
	check(replay.state.snapshot() == sim.state.snapshot(),"electric rewind continuation is exact")
	# Compare every other car against this refinement's task-start integrator.
	var original := GDScript.new()
	original.source_code = FileAccess.get_file_as_string(OUTPUT+"/before/game__vehicle__vehicle_simulation.gd.txt").trim_prefix("\ufeff").replace("class_name VehicleSimulation","")
	check(original.reload() == OK,"load original integrator for equivalence")
	for id: String in ["compact","pickup","classic","formula","kart","forklift"]:
		var tune: HandlingConfig = VehicleCatalog.config(id)
		var legacy: RefCounted = original.new(tune)
		var current := VehicleSimulation.new(tune)
		var exact: bool = true
		for tick: int in range(2400):
			var frame := DriveFrame.sample(sin(tick*0.013)*0.8,1.0 if tick%400<280 else 0.0,0.8 if tick%400>340 else 0.0,1.0 if tick%600<20 else 0.0)
			legacy.step(frame)
			current.step(frame)
			exact = exact and legacy.state.snapshot() == current.state.snapshot()
		check(exact,id+" retains every original tick exactly")
		check(not tune.snapshot().has("regeneration") and not tune.snapshot().has("rear_wheel_drive"),id+" retains original tune fields")
	var visual := CarVisual.new()
	visual.vehicle_id = "electric"
	visual.livery = VehicleLivery.defaults("electric")
	root.add_child(visual)
	check(visual.front_wheels.size() == 2 and visual.rolling_wheels.size() == 4,"electric geometry retains steering and rolling wheels")
	check(LiveryCatalog.has_roof("electric") and not LiveryCatalog.projection("electric").is_empty(),"electric hood and roof support saved graphics")
	visual.present(Vector2.ZERO,0,moving(10).state,DriveFrame.new())
	check(visual.rear_braking,"regeneration illuminates brake lights")
	visual.present(Vector2.ZERO,0,moving(10).state,DriveFrame.sample(0,1,0))
	check(not visual.rear_braking,"powered driving clears brake lights")
	visual.present(Vector2.ZERO,0,moving(0).state,DriveFrame.new())
	check(not visual.rear_braking,"stationary motor does not leave brake lights stuck")
	visual.queue_free()
	var model := VehicleAudioModel.new()
	model.configure("electric",48)
	for tick: int in range(600): model.advance(moving(tick/600.0*48).state,DriveFrame.sample(0,1,0),1.0/60)
	check(model.shifts == 0 and model.gear == 1,"electric transmission stays single speed")
	var audio := VehicleAudio.new()
	root.add_child(audio)
	audio.configure("electric",config)
	for player: AudioStreamPlayer in audio.engine_load + audio.engine_coast: check(player.stream != null,"motor loop loads: "+player.name)
	audio.present(moving(0).state,DriveFrame.new(),null,0.1,false)
	check(audio.engine_envelope == 0.0,"electric motor is silent at rest")
	audio.queue_free()
	var result := FileAccess.open(output+"/handling.json",FileAccess.WRITE)
	result.store_string(JSON.stringify({"checks":checks,"failures":failures,"metrics":metrics},"\t"))
	result.close()
	await process_frame
	print("ELECTRIC_METRICS ",JSON.stringify(metrics))
	print("ELECTRIC_CAR: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
