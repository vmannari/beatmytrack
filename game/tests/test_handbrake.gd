extends SceneTree
const _NATIVE_TRACK = preload("res://track/native_track.gd")
var checks: int = 0
var failures: int = 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	test_half_turn_exit()
	test_pull_rotation()
	test_input_and_stopping()
	test_paths()
	test_correction_and_replay()
	await process_frame
	print("HANDBRAKE_TESTS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func test_input_and_stopping() -> void:
	for id: String in VehicleCatalog.IDS:
		for direction: float in [-1.0,1.0]:
			var sim := VehicleSimulation.new(VehicleCatalog.config(id))
			sim.state.velocity = Vector2(0,direction*18)
			for tick: int in range(1200): sim.step(DriveFrame.sample(0,1,0,1))
			check(sim.state.velocity.length() < 0.001 and sim.state.reverse_wait == 0,id+" rear braking alone stops in both directions without powered reverse")
		var parked := VehicleSimulation.new(VehicleCatalog.config(id))
		for tick: int in range(120): parked.step(DriveFrame.sample(1,1,0,1))
		check(parked.state.position == Vector2.ZERO and parked.state.heading == 0,id+" handbrake cannot launch or rotate at rest")
		var powered := VehicleSimulation.new(VehicleCatalog.config(id))
		var coast := VehicleSimulation.new(VehicleCatalog.config(id))
		powered.state.velocity = Vector2(0,18); coast.state.velocity = Vector2(0,18)
		for tick: int in range(36):
			powered.step(DriveFrame.sample(0.6,1,0,1)); coast.step(DriveFrame.sample(0.6,0,0,1))
		check(powered.state.snapshot() == coast.state.snapshot(),id+" clutch disconnects full rear lock from throttle")
		for tick: int in range(60): powered.step(DriveFrame.sample(0.6,0.7,0))
		check(powered.state.handbrake_pressure == 0,id+" released brake always clears even while steering and accelerating")
		var before: float = powered.state.velocity.length()
		for tick: int in range(120): powered.step(DriveFrame.sample(0,1,0))
		check(powered.state.velocity.length() > before and absf(powered.state.slip_angle()) < 0.06,id+" power and straightening produce a stable exit")

func path(id: String, speed: float, pull: int) -> Dictionary:
	var sim := VehicleSimulation.new(VehicleCatalog.config(id))
	sim.state.velocity = Vector2(0,speed)
	var distance: float = 0.0
	var peak: float = 0.0
	for tick: int in range(480):
		var before: Vector2 = sim.state.position
		sim.step(DriveFrame.sample(1,0.7,0,1 if tick < pull else 0))
		distance += sim.state.position.distance_to(before)
		peak = maxf(peak,absf(rad_to_deg(sim.state.slip_angle())))
		var turn: float = atan2(sim.state.velocity.x,sim.state.velocity.y)
		if turn >= deg_to_rad(170):
			return {"complete":true,"radius":distance/turn,"peak":peak,"speed":sim.state.velocity.length(),"time":(tick+1)/120.0}
	return {"complete":false}

func test_paths() -> void:
	for id: String in VehicleCatalog.IDS:
		var ordinary: Dictionary = path(id,18,0)
		var pull: Dictionary = path(id,18,24)
		check(ordinary.complete and pull.complete,id+" brief pull and powered release completes 170 degree hairpin")
		if ordinary.complete and pull.complete:
			check(float(pull.radius) < float(ordinary.radius)*0.75,id+" actual travel path is at least 25 percent tighter")
			check(float(pull.speed) > 5.0 and float(pull.peak) < 55.0,id+" brief pull retains usable momentum and avoids a broadside spin")
			print("RALLY_HAIRPIN %s ordinary=%s pull=%s" % [id,JSON.stringify(ordinary),JSON.stringify(pull)])
	var compact: Dictionary = path("compact",12,36)
	check(compact.complete and float(compact.radius) < 4.0,"compact slow hairpin stays tight with a longer deliberate pull")

func test_correction_and_replay() -> void:
	for id: String in VehicleCatalog.IDS:
		var right := VehicleSimulation.new(VehicleCatalog.config(id))
		var left := VehicleSimulation.new(VehicleCatalog.config(id))
		right.state.velocity = Vector2(0,18); left.state.velocity = Vector2(0,18)
		var energy_gain: float = 0.0
		for tick: int in range(24):
			var before: float = right.state.velocity.length_squared()
			right.step(DriveFrame.sample(1,0,0,1)); left.step(DriveFrame.sample(-1,0,0,1))
			energy_gain = maxf(energy_gain,right.state.velocity.length_squared()-before)
		check(energy_gain < 0.0001,id+" rear lock never adds translational energy")
		check(is_equal_approx(right.state.position.x,-left.state.position.x) and is_equal_approx(right.state.heading,-left.state.heading),id+" rear swing is left/right symmetric")
		var continued := VehicleSimulation.new(VehicleCatalog.config(id))
		var replay := VehicleSimulation.new(VehicleCatalog.config(id))
		RewindHistory.restore(continued.state,RewindHistory.properties(right.state))
		RewindHistory.restore(replay.state,RewindHistory.properties(right.state))
		for tick: int in range(24):
			var frame: DriveFrame = DriveFrame.sample(-0.5,0.7,0)
			right.step(frame); replay.step(frame)
			continued.step(DriveFrame.sample(1,0.7,0))
		check(right.state.yaw_rate < continued.state.yaw_rate,id+" countersteering reduces rotation during rear grip recovery")
		check(right.state.snapshot() == replay.state.snapshot(),id+" active rear-lock release restores exactly through rewind")
		for tick: int in range(180): right.step(DriveFrame.sample(0,0.7,0))
		check(absf(right.state.slip_angle()) < 0.06 and right.state.handbrake_pressure == 0,id+" countersteer then power stabilizes the car")
		RewindHistory.restore(replay.state,RewindHistory.properties(right.state))
		for tick: int in range(360):
			var frame: DriveFrame = DriveFrame.sample(sin(tick*0.07),0.5,0,0.6 if tick%60 < 12 else 0)
			var packed: Array = JSON.parse_string(JSON.stringify(frame.packed()))
			var decoded := DriveFrame.new()
			decoded.steer=int(packed[0]); decoded.throttle=int(packed[1]); decoded.brake=int(packed[2]); decoded.handbrake=int(packed[3]) if packed.size()==4 else 0
			right.step(frame); replay.step(decoded)
		check(right.state.snapshot() == replay.state.snapshot(),id+" partial rear braking replays exactly after JSON round trip")
		var coast := VehicleSimulation.new(VehicleCatalog.config(id))
		coast.state.velocity = Vector2(0,25)
		var coast_gain: float = 0.0
		for tick: int in range(360):
			var before: float = coast.state.velocity.length_squared()
			coast.step(DriveFrame.sample(sin(tick*0.07),0,0,1 if tick%60 < 18 else 0))
			coast_gain = maxf(coast_gain,coast.state.velocity.length_squared()-before)
		check(coast_gain < 0.0001,id+" repeated pulls and releases never create coasting energy")


func test_pull_rotation() -> void:
	for id: String in VehicleCatalog.IDS:
		for speed: float in [12.0,18.0,25.0,35.0]:
			for ticks: int in [24,36,60]:
				var sim := VehicleSimulation.new(VehicleCatalog.config(id))
				sim.state.velocity = Vector2(0,minf(speed,sim.config.maximum_speed))
				var rotation: float = 0.0
				var peak_slip: float = 0.0
				for tick: int in range(ticks):
					var before: float = sim.state.heading
					sim.step(DriveFrame.sample(1,0.7,0,1))
					rotation += angle_difference(before,sim.state.heading)
					peak_slip = maxf(peak_slip,absf(rad_to_deg(sim.state.slip_angle())))
				print("PULL_ROTATION %s speed=%.0f hold=%.2f heading=%.2f slip=%.2f" % [id,speed,ticks/120.0,rad_to_deg(rotation),peak_slip])
				check(rotation < deg_to_rad(105 if ticks == 60 else 65),id+" brief pull leaves time to release and correct before a half-turn")

				var peak_rotation: float = rotation
				for tick: int in range(90):
					var before: float = sim.state.heading
					sim.step(DriveFrame.sample(0,0.7,0))
					rotation += angle_difference(before,sim.state.heading)
					peak_rotation = maxf(peak_rotation,rotation)
				check(peak_rotation < deg_to_rad(145),id+" release and centering prevent residual near-half-turn rotation")


func test_half_turn_exit() -> void:
	for id: String in VehicleCatalog.IDS:
		var sim := VehicleSimulation.new(VehicleCatalog.config(id))
		sim.state.velocity = Vector2(0,minf(35.0,sim.config.maximum_speed))
		var rotation: float = 0.0
		for tick: int in range(240):
			var before: float = sim.state.heading
			sim.step(DriveFrame.sample(1,0.7,0,1))
			rotation += angle_difference(before,sim.state.heading)
			if rotation >= deg_to_rad(160): break
		var backwards: float = sim.state.velocity.dot(sim.state.forward())
		var retreat: float = 0.0
		var recovery_tick: int = -1
		for tick: int in range(120):
			sim.step(DriveFrame.sample(0,1,0))
			var longitudinal: float = sim.state.velocity.dot(sim.state.forward())
			retreat += maxf(0,-longitudinal) / 120.0
			if longitudinal >= 0 and recovery_tick < 0: recovery_tick = tick
		print("HALF_TURN_EXIT %s rotation=%.1f backward_start=%.2f reverse_distance=%.2f recovery=%.3f forward_end=%.2f" % [id,rad_to_deg(rotation),backwards,retreat,(recovery_tick+1)/120.0,sim.state.velocity.dot(sim.state.forward())])
		check(recovery_tick >= 0 and recovery_tick < 60,id+" released half-turn catches backward momentum within 0.5s")
		check(retreat < 1.5,id+" released half-turn does not become sustained reversing")

		check(sim.state.velocity.dot(sim.state.forward()) > 4.0,id+" held accelerator powers forward after backward slip is caught")

		var snapshot := VehicleSimulation.new(VehicleCatalog.config(id))
		snapshot.state.heading = deg_to_rad(170)
		snapshot.state.velocity = Vector2(0,12)
		snapshot.state.handbrake_pressure = 1.0
		var restored := VehicleSimulation.new(VehicleCatalog.config(id))
		RewindHistory.restore(restored.state,RewindHistory.properties(snapshot.state))
		var backwards_ticks: int = 0
		for tick: int in range(120):
			var frame: DriveFrame = DriveFrame.sample(0,1,0)
			snapshot.step(frame); restored.step(frame)
			if snapshot.state.velocity.dot(snapshot.state.forward()) < -0.15: backwards_ticks += 1
		check(backwards_ticks < 60 and snapshot.state.velocity.dot(snapshot.state.forward()) > 4.0,id+" near-180 snapshot catches backward slip then powers forward")
		check(snapshot.state.snapshot() == restored.state.snapshot(),id+" backward-catch transition restores exactly through rewind")
		var crawl := VehicleSimulation.new(VehicleCatalog.config(id))
		crawl.state.velocity = Vector2(0.1,-0.0001)
		crawl.state.yaw_rate = 0.5
		crawl.state.handbrake_pressure = 1.0
		crawl.step(DriveFrame.sample(0,1,0))
		check(crawl.state.velocity.dot(crawl.state.forward()) > 0.04,id+" rotating chassis at near-zero backward speed does not cancel forward throttle")
