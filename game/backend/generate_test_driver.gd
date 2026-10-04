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
	var session := TrackSession.new(VehicleSimulation.TICK_RATE,RaceRules.LAPS)
	var frames: Array = []
	var last_gate: int = -1
	var last_lap: int = -1
	var progress_tick: int = 0
	for tick: int in range(MAX_FRAMES):
		var frame: DriveFrame = driver.sample(sim.state,track,sim.config,session)
		frames.append(frame.packed())
		var before: Vector2 = sim.state.position
		var layer: int = int(sim.state.track_elevated)
		sim.step(frame,track)
		session.advance(track,before,sim.state.position,sim.state.route_index,sim.state.track_elevated,layer)
		if session.next_checkpoint != last_gate or session.completed_laps != last_lap:
			last_gate = session.next_checkpoint; last_lap = session.completed_laps; progress_tick = tick
		if session.finished: break
		if tick-progress_tick > 3600:
			respond({},"Driver stalled at gate %d on lap %d" % [session.next_checkpoint,session.completed_laps+1]); return
	if not session.finished: respond({},"Driver did not finish all five laps"); return
	respond({"replay":{"schema":REPLAY_SCHEMA,"frames":frames},"vehicle_id":vehicle,
		"time_ticks":session.elapsed_ticks,"lap_ticks":session.lap_times.map(func(seconds: float) -> int: return roundi(seconds*VehicleSimulation.TICK_RATE)),
		"mistakes":driver.mistakes,"profile_version":traits.version,"manifest":compiled.manifest})
