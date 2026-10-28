extends SceneTree
## Actual narrow-bridge traversal, forged-fork ramp clearance and versioned speed tuning.
var checks: int = 0
var failures: int = 0
var measures: Dictionary = {}
var output: String = "res://../docs/evidence/forklift-clearance-2026-10-25"

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ",label)

func _track(angle: float) -> NativeTrack:
	var document: Dictionary = TrackDocument.create_blank()
	var start: Vector2 = Vector2(-16,0).rotated(deg_to_rad(angle))
	document.pieces = [RoadPieces.create("bridge",start,angle,6.0)]
	document.pieces[0].length = 32.0
	document.paint = [{"surface":0,"width":40.0,"shape":"square","points":[[-35,0],[35,0]]}]
	return TrackCompiler.compile(document)

func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--evidence-dir="): output = argument.trim_prefix("--evidence-dir=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	var config: HandlingConfig = VehicleCatalog.config("forklift")
	measures.handling_version = config.version
	measures.config_hash = JSON.stringify(config.snapshot(),"",true).sha256_text()
	var old: HandlingConfig = load("res://../docs/evidence/forklift-clearance-2026-10-25/before/game__resources__cars__forklift.tres")
	check(config.version != old.version and config.snapshot() != old.snapshot(),"changed handling has a distinct version and comparable rules")
	check(config.rear_steering and config.wheelbase == old.wheelbase and config.track_width == old.track_width,"rear steering and axle dimensions are preserved")
	check(absf(config.maximum_speed*3.6-80.0)<0.01,"Forklift top-speed setting is 80 km/h")
	check(config.collision_radius < old.collision_radius,"raised forks do not require the old oversized ground footprint")
	var straight := VehicleSimulation.new(config)
	for tick: int in range(1200): straight.step(DriveFrame.sample(0,1,0))
	measures.speed_kph = straight.state.velocity.length()*3.6
	check(absf(float(measures.speed_kph)-80.0)<0.01 and straight.state.velocity.length() <= config.maximum_speed,"actual powered top speed reaches 80 km/h and stays bounded")
	_check_turning(config,old)
	var crossings: Array[Dictionary] = []
	for angle: float in [0.0,37.0,90.0]:
		var track: NativeTrack = _track(angle)
		check(track != null,"real six-metre bridge compiles at "+str(angle))
		if track == null: continue
		for direction: float in [-1.0,1.0]:
			for offset: float in [-1.25,0.0,1.25]:
				for speed: float in [3.0,18.5,config.maximum_speed]:
					var result: Dictionary = _cross(track,config,angle,direction,offset,speed)
					crossings.append(result)
					check(result.finished and result.hits == 0,"clear bridge traverse angle=%s direction=%s offset=%s speed=%s" % [angle,direction,offset,speed])
					check(result.replay_exact,"bridge replay exact at 120/30 Hz batches")
		if angle == 0.0:
			var baseline: Dictionary = _cross(track,old,angle,1.0,1.25,18.5)
			measures.old_bridge = baseline
			check(not baseline.finished and baseline.hits > 0,"task-start footprint reproduces catching a clear bridge entry")
			var state := VehicleState.new()
			state.track_elevated = true
			state.position = Vector2(0,8)
			state.velocity = Vector2(0,12)
			track.resolve(state,Vector2.ZERO,config)
			check(state.collision_count > 0 and state.position.y < 3.0,"actual bridge rails still block the body")
			await _fork_clearance(track)
	measures.crossings = crossings
	var file := FileAccess.open(output.path_join("before.json" if "--before" in OS.get_cmdline_user_args() else "after.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"measurements":measures},"\t"))
	file.close()
	print("FORKLIFT_CLEARANCE_METRICS ",JSON.stringify(measures))
	print("FORKLIFT_CLEARANCE_TESTS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func _check_turning(config: HandlingConfig, old: HandlingConfig) -> void:
	var turns: Array[Dictionary] = []
	# Equal powered caps and corner-energy treatment isolate steering/grip.
	# Otherwise the old truck's sustained speed loss makes its low-speed circle
	# misleadingly smaller than the revised truck travelling at the requested speed.
	var comparison := old.duplicate() as HandlingConfig
	comparison.corner_energy_retention = config.corner_energy_retention
	for speed: float in [3.0,8.0,14.0,18.5,config.maximum_speed]:
		for input: float in [-1.0,-0.45,0.45,1.0]:
			var before: Dictionary = _circle(comparison,speed,input)
			var after: Dictionary = _circle(config,speed,input)
			check(after.radius < before.radius*0.85,"tighter actual turning path at %s m/s and %s input" % [speed,input])
			check(before.speed >= speed*0.85,"comparison control also sustains the requested speed")
			check(after.speed >= speed*0.85,"tightening is not caused by slowing to a crawl")
			check(after.recovered,"high-grip rear steering settles when released")
			turns.append({"speed_cap":speed,"input":input,"before_radius_m":before.radius,"before_actual_speed_mps":before.speed,"after_radius_m":after.radius,"actual_speed_mps":after.speed,"recovered":after.recovered})
	measures.turning_comparison_corner_energy_retention = comparison.corner_energy_retention
	measures.turns = turns

func _circle(original: HandlingConfig, speed: float, input: float) -> Dictionary:
	var config := original.duplicate() as HandlingConfig
	config.maximum_speed = speed
	var sim := VehicleSimulation.new(config)
	sim.state.velocity = Vector2(0,speed)
	var distance: float = 0.0
	var angle: float = 0.0
	var total_speed: float = 0.0
	for tick: int in range(720):
		var previous: Vector2 = sim.state.velocity
		var position: Vector2 = sim.state.position
		sim.step(DriveFrame.sample(input,1,0))
		if tick >= 480:
			distance += sim.state.position.distance_to(position)
			angle += absf(previous.angle_to(sim.state.velocity))
			total_speed += sim.state.velocity.length()
	for tick: int in range(240): sim.step(DriveFrame.sample(0,1,0))
	return {"radius":distance/maxf(angle,0.00001),"speed":total_speed/240.0,"recovered":absf(sim.state.yaw_rate)<0.01 and absf(sim.state.slip_angle())<0.03}

func _cross(track: NativeTrack, original: HandlingConfig, angle: float, direction: float, offset: float, speed: float) -> Dictionary:
	# Same controlled speed for old/new footprints, retaining real steering,
	# collision, bridge layers and propulsion. Only the speed cap is constrained.
	var config := original.duplicate() as HandlingConfig
	config.maximum_speed = speed
	var axis: Vector2 = Vector2.RIGHT.rotated(deg_to_rad(angle))
	var normal: Vector2 = axis.orthogonal()
	var sim := VehicleSimulation.new(config)
	sim.reset(axis*(-22.0*direction)+normal*offset,atan2(axis.x*direction,axis.y*direction))
	sim.state.velocity = axis*speed*direction
	sim.state.route_index = track.nearest_route(sim.state.position)
	var frame: DriveFrame = DriveFrame.sample(0,1,0)
	var steps: int = 0
	for tick: int in range(ceili(48.0/speed*120.0)+120):
		sim.step(frame,track)
		steps += 1
		if sim.state.position.dot(axis)*direction > 21.0 or sim.state.collision_count > 0: break
	var replay := VehicleSimulation.new(config)
	replay.reset(axis*(-22.0*direction)+normal*offset,atan2(axis.x*direction,axis.y*direction))
	replay.state.velocity = axis*speed*direction
	replay.state.route_index = track.nearest_route(replay.state.position)
	for batch: int in range(0,steps,4):
		for tick: int in range(batch,mini(batch+4,steps)): replay.step(frame,track)
	return {"angle":angle,"direction":direction,"offset":offset,"speed":speed,"finished":sim.state.position.dot(axis)*direction > 21.0,"hits":sim.state.collision_count,"replay_exact":sim.state.snapshot() == replay.state.snapshot()}

func _fork_clearance(track: NativeTrack) -> void:
	var bridge := BridgePresentation.new(track)
	var config: HandlingConfig = VehicleCatalog.config("forklift")
	for simple: bool in [false,true]:
		var car := CarVisual.new()
		car.vehicle_id = "forklift"; car.simple_model = simple; car.batch_parts = false
		root.add_child(car)
		var forks: Array[Node] = car.find_children("ForgedFork*","MeshInstance3D",true,false)
		check(forks.size() == 2,"both forged forks exist in detailed/racing model")
		var flat_min: float = INF
		for fork: MeshInstance3D in forks:
			for vertex: Vector3 in fork.mesh.get_faces(): flat_min = minf(flat_min,(fork.global_transform*vertex).y)
		check(flat_min >= 0.6,"raised fork undersides clear ordinary low obstacles")
		var clearance: float = INF
		for direction: float in [-1.0,1.0]:
			for u: float in [-2.0,-1.0,0.0,0.5,1.0,2.0,3.0,4.0,5.0]:
				var point := Vector2((-16.0+u)*direction,0)
				var heading: float = PI*0.5*direction
				var axle := Vector2(direction,0)*config.wheelbase*0.5
				var front: float = bridge.visual_height_at(point+axle,track.nearest_route(point+axle),1)
				var rear: float = bridge.visual_height_at(point-axle,track.nearest_route(point-axle),1)
				car.position = VisualGeometry.world(point)+Vector3.UP*(front+rear)*0.5
				car.rotation = Vector3(atan2(front-rear,config.wheelbase),-heading,0)
				for fork: MeshInstance3D in forks:
					for vertex: Vector3 in fork.mesh.get_faces():
						var world: Vector3 = fork.global_transform*vertex
						var sample := Vector2(world.x,-world.z)
						clearance = minf(clearance,world.y-bridge.visual_height_at(sample,track.nearest_route(sample),1))
		check(clearance >= 0.05,"actual fork geometry stays above both ascending bridge ramps")
		measures["racing" if simple else "detailed"] = {"underside_m":flat_min,"minimum_ramp_clearance_m":clearance}
		car.queue_free()
		await process_frame
