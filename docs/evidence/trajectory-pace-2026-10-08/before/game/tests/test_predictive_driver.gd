extends "res://backend/runner.gd"
var checks: int = 0
var failures: int = 0
func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition: failures += 1; print("FAIL: "+label)

func run() -> void:
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://../backend/tests/fixtures/verified_oval.json"))
	var compiled: Dictionary = compile_track(fixture.document)
	if compiled.has("error"): push_error(compiled.error); quit(1); return
	var track: NativeTrack = compiled.track
	var config: HandlingConfig = VehicleCatalog.config("compact")
	var trajectory := RacingTrajectory.new()
	trajectory.build(track,config)
	check(trajectory.spacing <= 0.501,"half-metre trajectory sampling")
	check(trajectory.curvature_after < trajectory.curvature_before,"curvature surrogate reduced")
	check(trajectory.blocked_samples == 0,"oval has a feasible clearance corridor")
	for i: int in range(trajectory.points.size()):
		check(not track.overlaps_obstacle(trajectory.points[i],config.collision_radius,false),"reference footprint clears obstacles")
		check(is_finite(trajectory.speeds[i]) and trajectory.speeds[i] <= config.maximum_speed,"finite bounded reference speed")
		var j: int = (i+1)%trajectory.points.size()
		var ds: float = trajectory.points[i].distance_to(trajectory.points[j])
		var braking: float = minf(config.braking_force/config.mass,config.longitudinal_grip*trajectory.grips[i])*0.72
		check(trajectory.speeds[i]*trajectory.speeds[i] <= trajectory.speeds[j]*trajectory.speeds[j]+2.0*braking*ds+0.001,"cyclic braking including seam")
	var cached: Dictionary = JSON.parse_string(JSON.stringify(trajectory.serialize()))
	var restored := RacingTrajectory.new()
	check(restored.restore(cached,track,config),"round-trip cache loads")
	check(restored.points == trajectory.points and restored.speeds == trajectory.speeds and restored.curvature == trajectory.curvature,"cached control data is exact")
	if restored.curvature != trajectory.curvature:
		for i: int in range(trajectory.curvature.size()):
			if restored.curvature[i] != trajectory.curvature[i]: print("CACHE DIFFERENCE ",i," original=",trajectory.curvature[i]," cached=",restored.curvature[i]); break
	var changed: HandlingConfig = config.duplicate()
	changed.braking_force *= 0.9
	check(not restored.restore(cached,track,changed),"handling change invalidates cache")
	cached.key = "previous physics/rules"
	check(not restored.restore(cached,track,config),"stale canonical contract invalidates cache")
	cached = trajectory.serialize()
	cached.rows[0][4] = NAN
	check(not restored.restore(cached,track,config),"nonfinite derived data regenerates")
	_test_gradient(track,trajectory,config)
	for vehicle: String in VehicleCatalog.IDS: _drive_with_disturbance(track,vehicle)
	print("PREDICTIVE DRIVER: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func _test_gradient(track: NativeTrack, trajectory: RacingTrajectory, config: HandlingConfig) -> void:
	var sim: VehicleSimulation = initial_simulation(track,"compact")
	var progress: float = track.route_progress(sim.state.position,sim.state.route_index)
	var ref: Dictionary = trajectory.at(progress)
	sim.state.velocity = sim.state.forward()*12.0
	var mpc := TrajectoryMPC.new()
	mpc.control(sim.state,trajectory,progress,config,0.9,0.5)
	mpc._rollout(mpc.steering,mpc.acceleration,true)
	var gradient: Array[PackedFloat64Array] = mpc._gradient()
	for control: int in range(2):
		for i: int in [0,3,8,15]:
			var plus_u: PackedFloat64Array = mpc.steering.duplicate()
			var plus_a: PackedFloat64Array = mpc.acceleration.duplicate()
			var minus_u: PackedFloat64Array = mpc.steering.duplicate()
			var minus_a: PackedFloat64Array = mpc.acceleration.duplicate()
			var epsilon: float = 0.000001
			if control == 0: plus_u[i] += epsilon; minus_u[i] -= epsilon
			else: plus_a[i] += epsilon; minus_a[i] -= epsilon
			var numerical: float = (mpc._rollout(plus_u,plus_a,false)-mpc._rollout(minus_u,minus_a,false))/(2.0*epsilon)
			check(absf(numerical-gradient[control][i]) < 0.001*maxf(1.0,absf(numerical)),"MPC adjoint matches numerical derivative")
	check(ref.speed > 0.0,"positive reference speed")

func _drive_with_disturbance(track: NativeTrack, vehicle: String) -> void:
	var sim: VehicleSimulation = initial_simulation(track,vehicle)
	var traits: Dictionary = {"seed":7,"skill":0.7,"consistency":1.0,"aggression":0.5,"learning":0.5,"strengths":{}}
	var driver := ProfiledRouteDriver.new(traits,"pine",track.content_hash,0)
	var session := TrackSession.new(VehicleSimulation.TICK_RATE,5)
	var disturbed: bool = false
	var returned: bool = false
	for tick: int in range(30000):
		if tick == 1200:
			sim.state.position += sim.state.right()*1.1
			sim.state.heading = wrapf(sim.state.heading+0.12,-PI,PI)
			disturbed = true
		var frame: DriveFrame = driver.sample(sim.state,track,sim.config,session)
		if tick > 1250 and tick < 1700:
			var s: float = driver.trajectory.project(sim.state.position,track.route_progress(sim.state.position,sim.state.route_index))
			if sim.state.position.distance_to(driver.trajectory.at(s).point) < 0.5: returned = true
		var before: Vector2 = sim.state.position
		var layer: int = int(sim.state.track_elevated)
		sim.step(frame,track)
		session.advance(track,before,sim.state.position,sim.state.route_index,sim.state.track_elevated,layer)
		if session.finished: break
	check(disturbed and returned,vehicle+" physically recovers a lateral/heading disturbance within four seconds")
	check(session.finished and session.completed_laps == 5,vehicle+" completes all ordered five laps")
	check(sim.state.collision_count == 0,vehicle+" recovery avoids contacts")
	print("RECOVERY %s finished=%s ticks=%d contacts=%d" % [vehicle,session.finished,session.elapsed_ticks,sim.state.collision_count])
