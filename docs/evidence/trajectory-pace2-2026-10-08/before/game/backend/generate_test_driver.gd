extends "res://backend/runner.gd"
## Offline operator tool. Not reachable through runner's service operations.
func run() -> void:
	var input_path: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--input="): input_path = arg.trim_prefix("--input=")
		if arg.begins_with("--output="): output_path = arg.trim_prefix("--output=")
	if output_path.is_empty() or input_path.is_empty(): quit(3); return
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(input_path))
	if not value is Dictionary or not value.get("document") is Dictionary or not value.get("traits") is Dictionary:
		respond({},"Malformed test driver request"); return
	var traits: Dictionary = value.traits
	if not traits.has_all(["version","seed","skill","consistency","aggression","learning","strengths"]) or traits.version != "test-driver-1" or not traits.strengths is Dictionary:
		respond({},"Unsupported driver profile"); return
	for key: String in ["seed","skill","consistency","aggression","learning"]:
		if not number(traits[key]): respond({},"Malformed driver trait"); return
	for strength: Variant in traits.strengths.values():
		if not number(strength): respond({},"Malformed track strength"); return
	var vehicle: String = str(value.get("vehicle_id","compact"))
	if vehicle not in VehicleCatalog.IDS: respond({},"Unknown vehicle"); return
	var attempt: int = int(value.get("attempt",0))
	var pace_scale: float = float(value.get("pace_scale",1.0))
	if attempt < 0 or attempt > 100 or not is_finite(pace_scale) or pace_scale < 0.6 or pace_scale > 2.0:
		respond({},"Invalid attempt or calibration"); return
	var compiled: Dictionary = compile_track(value.document)
	if compiled.has("error"): respond({},compiled.error); return
	var track: NativeTrack = compiled.track
	var sim: VehicleSimulation = initial_simulation(track,vehicle)
	var driver := ProfiledRouteDriver.new(traits,str(value.document.theme),track.content_hash,attempt,pace_scale)
	driver.obstacle_detours = bool(value.get("obstacle_detours",false))
	var trajectory_started: int = Time.get_ticks_usec()
	driver.trajectory = RacingTrajectory.new()
	var cache_hit: bool = value.get("trajectory") is Dictionary and driver.trajectory.restore(value.trajectory,track,sim.config)
	if not cache_hit: driver.trajectory = TrajectoryPlanner.prepare(track,sim.config)
	var trajectory_ms: float = (Time.get_ticks_usec()-trajectory_started)/1000.0
	if value.get("trajectory_output") is String:
		var trajectory_file := FileAccess.open(value.trajectory_output,FileAccess.WRITE)
		if trajectory_file == null: respond({},"Cannot save derived trajectory"); return
		trajectory_file.store_string(JSON.stringify(driver.trajectory.serialize()))
		trajectory_file.close()
	var session := TrackSession.new(VehicleSimulation.TICK_RATE,RaceRules.LAPS)
	var frames: Array = []
	var last_gate: int = -1
	var last_lap: int = -1
	var progress_tick: int = 0
	var control_usec: int = 0
	var control_max_usec: int = 0
	var telemetry: Array = []
	for tick: int in range(MAX_FRAMES):
		var control_started: int = Time.get_ticks_usec() if (driver.tick+1)%TrajectoryMPC.UPDATE_TICKS == 1 else 0
		var frame: DriveFrame = driver.sample(sim.state,track,sim.config,session)
		if control_started > 0:
			var duration: int = Time.get_ticks_usec()-control_started
			control_usec += duration; control_max_usec = maxi(control_max_usec,duration)
			var progress: float = driver.trajectory.project(sim.state.position,track.route_progress(sim.state.position,sim.state.route_index))
			var reference: Dictionary = driver.trajectory.at(progress)
			telemetry.append([tick,progress,sim.state.position.x,sim.state.position.y,sim.state.velocity.length(),reference.speed,sim.state.position.distance_to(reference.point),frame.steer,frame.throttle,frame.brake,session.completed_laps])
		frames.append(frame.packed())
		var before: Vector2 = sim.state.position
		var layer: int = int(sim.state.track_elevated)
		sim.step(frame,track)
		session.advance(track,before,sim.state.position,sim.state.route_index,sim.state.track_elevated,layer)
		if session.next_checkpoint != last_gate or session.completed_laps != last_lap:
			last_gate = session.next_checkpoint; last_lap = session.completed_laps; progress_tick = tick
		if session.finished: break
		if tick-progress_tick > 3600:
			respond({},"Driver stalled at gate %d on lap %d (position %s, route %d, target %s, direction %s, heading %.3f, missed %d)" % [session.next_checkpoint,session.completed_laps+1,sim.state.position,sim.state.route_index,session.checkpoint_road_center(track),session.checkpoint_direction(track),sim.state.heading,session.missed_checkpoint]); return
	if not session.finished: respond({},"Driver did not finish all five laps"); return
	respond({"replay":{"schema":REPLAY_SCHEMA,"frames":frames},"vehicle_id":vehicle,
		"time_ticks":session.elapsed_ticks,"lap_ticks":session.lap_times.map(func(seconds: float) -> int: return roundi(seconds*VehicleSimulation.TICK_RATE)),
		"mistakes":driver.mistakes,"profile_version":traits.version,"controller_version":ProfiledRouteDriver.VERSION+("/detour" if driver.obstacle_detours else ""),"manifest":compiled.manifest,
		"telemetry":{"columns":["tick","s_m","x_m","y_m","actual_v_mps","reference_v_mps","line_error_m","steer","throttle","brake","lap"],"samples":telemetry},
		"diagnostics":{"trajectory_version":RacingTrajectory.VERSION,"mpc_version":TrajectoryMPC.VERSION,"cache_hit":cache_hit,"planning_ms":trajectory_ms,"reference_lap_seconds":driver.trajectory.reference_seconds,"blocked_samples":driver.trajectory.blocked_samples,"tracking_rms_m":sqrt(driver.lateral_error_sum/maxi(1,driver.tracking_samples)),"tracking_max_m":driver.max_lateral_error,"mpc_updates":driver.mpc.updates,"mean_update_ms":control_usec/1000.0/maxi(1,driver.mpc.updates),"max_update_ms":control_max_usec/1000.0,"fallback_ticks":driver.fallback_ticks,"collisions":sim.state.collision_count}})
