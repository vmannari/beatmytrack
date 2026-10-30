extends "res://backend/runner.gd"
## UFO-inspired behavior contracts and exact replay preservation for old models.
const BEFORE = preload("res://tests/fixtures/hovercraft_ufo_before.tres")
const OUTPUT: String = "res://../docs/evidence/hovercraft-ufo-feel-2026-10-28/"
var checks: int = 0
var failures: int = 0
var metrics: Dictionary = {}

class LooseYard extends PlaygroundData:
	func surface_factors(_state: VehicleState) -> Vector2: return Vector2(0.1,8.0)
	func tire_pickup(_state: VehicleState) -> float: return 1.0
	func tire_fluids(_state: VehicleState) -> Vector2: return Vector2.ONE

func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ",label)

func moving(config: HandlingConfig, velocity: Vector2 = Vector2.ZERO, heading: float = 0.0) -> VehicleSimulation:
	var sim := VehicleSimulation.new(config)
	sim.state.velocity = velocity
	sim.state.heading = heading
	return sim

func advance(sim: VehicleSimulation, count: int, steer: float = 0.0, throttle: float = 0.0, brake: float = 0.0) -> void:
	for tick: int in range(count): sim.step(DriveFrame.sample(steer,throttle,brake))

func run() -> void:
	OS.set_environment("BMT_API_URL","")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var config: HandlingConfig = VehicleCatalog.config("hovercraft")
	check(config.version == "hovercraft-4" and config.vector_thrust and config.air_cushion,"dedicated versioned vector-thrust model")
	check(config.snapshot().vector_thrust and not BEFORE.snapshot().has("vector_thrust"),"new behavior is opt-in and historical handling hashes retain their shape")
	check(manifest().vehicles.hovercraft.config_hash == JSON.stringify(config.snapshot(),"",true).sha256_text(),"client and native worker pin the new tune")
	var comparison: Array = []
	for handling: HandlingConfig in [BEFORE,config]:
		var parked: VehicleSimulation = moving(handling)
		advance(parked,72,1)
		var slide: VehicleSimulation = moving(handling,Vector2(0,-12))
		advance(slide,30,0.7)
		comparison.append({"version":handling.version,"parked_heading_0_6s_degrees":rad_to_deg(parked.state.heading),"backward_drift_heading_0_25s_degrees":rad_to_deg(slide.state.heading)})
	check(comparison[1].parked_heading_0_6s_degrees > 70.0,"hull turns freely while stationary without a frantic full turn")
	check(comparison[1].backward_drift_heading_0_25s_degrees > 0.0,"right steering still turns right while drifting backwards")
	metrics.comparison = comparison
	var turn_times: Array = []
	for velocity: Vector2 in [Vector2.ZERO,Vector2(0,20),Vector2(0,-20),Vector2(20,0)]:
		var sim: VehicleSimulation = moving(config,velocity)
		var ticks: int = 0
		while sim.state.heading < PI*0.5 and ticks < 240:
			advance(sim,1,1)
			ticks += 1
		check(ticks < 100,"quick independent heading response: "+str(velocity))
		turn_times.append(ticks)
	check(turn_times.min() == turn_times.max(),"heading responds identically at rest and in all drift directions")
	metrics.ninety_degree_seconds = int(turn_times[0])/120.0
	var straight: VehicleSimulation = moving(config,Vector2(3,20))
	var spinning: VehicleSimulation = moving(config,Vector2(3,20))
	for tick: int in range(240):
		advance(straight,1)
		advance(spinning,1,1)
	check(straight.state.position == spinning.state.position and straight.state.velocity == spinning.state.velocity,"rotating the hull does not change unpowered world momentum or position")
	var drifting: VehicleSimulation = moving(config,Vector2(20,0))
	advance(drifting,120)
	check(drifting.state.velocity.x > 12.0 and drifting.state.velocity.y == 0.0,"a released craft retains a controlled clean drift")
	metrics.coast_one_second_mps = drifting.state.velocity.x
	var pushes: Array[Vector2] = []
	for velocity: Vector2 in [Vector2(0,20),Vector2(20,0),Vector2(0,-20)]:
		var coast: VehicleSimulation = moving(config,velocity)
		var powered: VehicleSimulation = moving(config,velocity)
		advance(coast,1)
		advance(powered,1,0,0.5)
		var push: Vector2 = powered.state.velocity-coast.state.velocity
		check(push.x <= 0.00001 and push.y > 0.08,"thrust adds pointed force and catches sideways drift: "+str(velocity))
		pushes.append(push)
	check(is_equal_approx(pushes[0].y,pushes[1].y) and is_equal_approx(pushes[1].y,pushes[2].y),"equal pedal gives equal forward thrust in forward, lateral and backward drift")
	var released_slide: VehicleSimulation = moving(config,Vector2(15,0))
	var caught_slide: VehicleSimulation = moving(config,Vector2(15,0))
	advance(released_slide,90)
	advance(caught_slide,90,0,1)
	check(caught_slide.state.velocity.x > 1.0 and caught_slide.state.velocity.x < released_slide.state.velocity.x*0.35,"power progressively catches the slide while coasting remains floaty")
	metrics.powered_side_speed_0_75s = caught_slide.state.velocity.x
	metrics.coasting_side_speed_0_75s = released_slide.state.velocity.x
	var corner: VehicleSimulation = moving(config,Vector2(0,20))
	advance(corner,84,1)
	var incoming: Vector2 = corner.state.velocity
	advance(corner,60,0,1)
	check(corner.state.velocity.x > 7.0 and corner.state.velocity.y > 2.0 and absf(corner.state.slip_angle()) > deg_to_rad(5.0),"point-and-push catches the old drift progressively while retaining some momentum lag")
	metrics.point_and_push = {"incoming_world_mps":str(incoming),"outgoing_world_mps":str(corner.state.velocity),"heading_degrees":rad_to_deg(corner.state.heading)}
	var stop: VehicleSimulation = moving(config,Vector2(15,20),PI*0.5)
	var stop_ticks: int = 0
	for tick: int in range(600):
		advance(stop,1,0,0,1)
		stop_ticks += 1
		if stop.state.velocity.length() < 0.15: break
	check(stop.state.velocity.length() < 0.15 and stop.state.velocity.x >= 0.0 and stop.state.velocity.y >= 0.0,"air brake stops the complete drift vector before reverse")
	metrics.diagonal_stop_seconds = stop_ticks/120.0
	var reversing: VehicleSimulation = moving(config)
	advance(reversing,30,0,0,1)
	check(reversing.state.velocity == Vector2.ZERO,"stopped reverse hold delay remains")
	advance(reversing,360,0,0,1)
	check(reversing.state.velocity.y < -4.0 and reversing.state.velocity.length() <= config.reverse_speed+0.00001,"reverse remains usable and bounded")
	var simultaneous: VehicleSimulation = moving(config)
	advance(simultaneous,240,0,1,1)
	check(simultaneous.state.velocity == Vector2.ZERO and simultaneous.state.reverse_wait == 0.0,"brake wins simultaneous pedals without arming reverse")
	var road := PlaygroundData.new()
	var soil := LooseYard.new()
	for ground: PlaygroundData in [road,soil]:
		ground.islands = []
		ground.half_extent = Vector2.ONE*10000.0
	var paved: VehicleSimulation = moving(config,Vector2(0,15))
	var loose: VehicleSimulation = moving(config,Vector2(0,15))
	for tick: int in range(480):
		var frame := DriveFrame.sample(sin(tick*0.017)*0.6,0.6,0)
		paved.step(frame,road)
		loose.step(frame,soil)
	check(paved.state.snapshot() == loose.state.snapshot(),"material grip and oil/water do not become wheel forces on the cushion")
	var top: VehicleSimulation = moving(config)
	advance(top,2400,0,1)
	check(absf(top.state.velocity.length()*3.6-130.0) < 0.01,"130 km/h cap remains attainable")
	var finite: bool = true
	var peak: float = 0.0
	for speed: float in [0.0,10.0,25.0,35.0]:
		for steer: float in [-1.0,-0.5,0.5,1.0]:
			for pedal: float in [0.0,0.5,1.0]:
				var sim: VehicleSimulation = moving(config,Vector2(0,speed))
				for tick: int in range(600):
					var previous: float = sim.state.velocity.length()
					advance(sim,1,steer,pedal)
					finite = finite and sim.state.velocity.is_finite() and is_finite(sim.state.heading) and sim.state.velocity.length() <= config.maximum_speed+0.00001
					if pedal == 0.0: finite = finite and sim.state.velocity.length() <= previous+0.00001
					peak = maxf(peak,sim.state.velocity.length())
				check(finite,"bounded five-second turn; steering alone cannot add energy: %s/%s/%s" % [speed,steer,pedal])
	metrics.peak_mps = peak
	_legacy_exact()
	_replay(config)
	var angular: VehicleSimulation = moving(config)
	advance(angular,20,1)
	var prior: float = angular.state.yaw_rate
	advance(angular,1)
	check(angular.state.yaw_rate > 0.1 and angular.state.yaw_rate >= prior*0.5,"release retains a short angular settling tail")
	advance(angular,120)
	check(absf(angular.state.yaw_rate) < 0.0001,"released turning settles promptly")
	var settle_test: VehicleSimulation = moving(config,Vector2(0,20))
	advance(settle_test,60,1)
	var released_heading: float = settle_test.state.heading
	advance(settle_test,120)
	var overshoot: float = absf(angle_difference(released_heading,settle_test.state.heading))
	check(rad_to_deg(overshoot) < 13.0,"short steering release tail prevents large overshoot")
	metrics.release_overshoot_degrees = rad_to_deg(overshoot)
	var file := FileAccess.open(OUTPUT+"report.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"metrics":metrics},"\t"))
	file.close()
	print("HOVERCRAFT_UFO: %d checks, %d failures; %s" % [checks,failures,JSON.stringify(metrics)])
	quit(1 if failures else 0)

func _legacy_exact() -> void:
	var old_script := GDScript.new()
	old_script.source_code = FileAccess.get_file_as_string("res://tests/fixtures/hovercraft_ufo_simulation_before.gd.txt").replace("\r\n","\n").replace("class_name VehicleSimulation\n","")
	check(old_script.reload() == OK,"actual task-start canonical source compiles independently")
	var profiles: Array[HandlingConfig] = [BEFORE,preload("res://tests/fixtures/hovercraft_power_turn_before.tres")]
	for id: String in ["compact","pickup","kart","forklift","electric"]: profiles.append(VehicleCatalog.config(id))
	var yard := PlaygroundData.new()
	for config: HandlingConfig in profiles:
		check(not config.vector_thrust and not config.snapshot().has("vector_thrust"),"other/historical profile omits the new capability: "+config.version)
		var original: RefCounted = old_script.new(config)
		var current := VehicleSimulation.new(config)
		var exact: bool = true
		for tick: int in range(2400):
			var frame := DriveFrame.sample(sin(tick*0.017)*0.75,1.0 if tick%600<400 else 0.0,0.7 if tick%600>450 else 0.0,0.5 if tick%700>650 else 0.0)
			original.step(frame,yard)
			current.step(frame,yard)
			exact = exact and original.state.snapshot() == current.state.snapshot()
		check(exact,"2400 task-start state comparisons including collisions remain exact: "+config.version)

func _replay(config: HandlingConfig) -> void:
	var original := VehicleSimulation.new(config)
	var replay := VehicleSimulation.new(config)
	var frames: Array = []
	var saved: Dictionary = {}
	var yard := PlaygroundData.new()
	for tick: int in range(3600):
		var frame := DriveFrame.sample(sin(tick*0.017)*0.7,1.0 if tick%480<320 else 0.0,0.8 if tick%480>390 else 0.0)
		frames.append(frame.packed())
		original.step(frame,yard)
		if tick == 1799: saved = RewindHistory.pack_state(original.state)
	var decoded: Array = JSON.parse_string(JSON.stringify(frames))
	for packed: Array in decoded: replay.step(unpack(packed),yard)
	check(replay.state.snapshot() == original.state.snapshot(),"3600 serialized UFO-style inputs replay exactly through collisions")
	RewindHistory.restore(replay.state,saved)
	for tick: int in range(1800,3600): replay.step(unpack(decoded[tick]),yard)
	check(replay.state.snapshot() == original.state.snapshot(),"UFO-style rewind continuation remains exact")

func unpack(packed: Array) -> DriveFrame:
	return DriveFrame.sample(float(packed[0])/127.0,float(packed[1])/255.0,float(packed[2])/255.0,float(packed[3])/255.0 if packed.size() > 3 else 0.0)
