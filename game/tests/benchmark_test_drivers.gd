extends "res://backend/runner.gd"
## Headless, canonical five-lap corpus benchmark; never writes player data.
func run() -> void:
	var destination: String = "res://../build/driver-benchmark.json"
	if not OS.get_environment("BMT_DRIVER_REPORT").is_empty(): destination = OS.get_environment("BMT_DRIVER_REPORT")
	var selected: String = OS.get_environment("BMT_DRIVER_NAMES")
	var skill_text: String = OS.get_environment("BMT_DRIVER_SKILL")
	var benchmark_skill: float = clampf(skill_text.to_float(),0.0,1.0) if not skill_text.is_empty() else 0.5
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): destination = arg.trim_prefix("--report=")
		if arg.begins_with("--names="): selected = arg.trim_prefix("--names=")
	var corpus: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://../backend/bmt_backend/lab_tracks.json"))
	var results: Array = []
	for document: Dictionary in corpus.documents:
		if not selected.is_empty() and document.name not in selected.split(","): continue
		var compiled: Dictionary = compile_track(document)
		if compiled.has("error"):
			results.append({"name":document.name,"error":compiled.error}); continue
		var track: NativeTrack = compiled.track
		var sim: VehicleSimulation = initial_simulation(track,"compact")
		var traits: Dictionary = {"version":"test-driver-1","seed":27,"skill":benchmark_skill,"consistency":1.0,"aggression":0.5,"learning":0.5,"strengths":{}}
		var driver := ProfiledRouteDriver.new(traits,str(document.theme),track.content_hash,0)
		var session := TrackSession.new(VehicleSimulation.TICK_RATE,RaceRules.LAPS)
		var gate: int = -1
		var progressed: int = 0
		var began: int = Time.get_ticks_usec()
		var trace: Array = []
		var frames: Array = []
		for tick: int in range(MAX_FRAMES):
			var frame: DriveFrame = driver.sample(sim.state,track,sim.config,session)
			if OS.get_environment("BMT_DRIVER_REPLAYS") == "1": frames.append(frame.packed())
			var before: Vector2 = sim.state.position
			var layer: int = int(sim.state.track_elevated)
			sim.step(frame,track)
			session.advance(track,before,sim.state.position,sim.state.route_index,sim.state.track_elevated,layer)
			var current: int = session.next_checkpoint+session.completed_laps*10000
			if gate != current: gate = current; progressed = tick
			if tick % 12 == 0:
				var progress: float = driver.trajectory.project(sim.state.position,track.route_progress(sim.state.position,sim.state.route_index))
				trace.append([tick,sim.state.position.x,sim.state.position.y,sim.state.velocity.length(),session.completed_laps,session.missed_checkpoint,progress,driver.trajectory.at(progress).speed,frame.steer,frame.throttle,frame.brake])
			if session.finished or tick-progressed > 3600: break
		var row: Dictionary = {"name":document.name,"finished":session.finished,"ticks":session.elapsed_ticks,"laps":session.completed_laps,"lap_seconds":session.lap_times,"collisions":sim.state.collision_count,"wall_ms":(Time.get_ticks_usec()-began)/1000.0,"controller":driver.VERSION,"profile":traits,"manifest":compiled.manifest,"trace":trace}
		row.tracking = {"rms_m":sqrt(driver.lateral_error_sum/maxi(1,driver.tracking_samples)),"max_m":driver.max_lateral_error,"fallback_ticks":driver.fallback_ticks,"updates":driver.mpc.updates}
		if driver.trajectory != null:
			row.reference = {"lap_seconds":driver.trajectory.reference_seconds,"blocked":driver.trajectory.blocked_samples,"strategy":driver.trajectory.strategy,"pilot_candidates":driver.trajectory.pilot_candidates,"curvature_before":driver.trajectory.curvature_before,"curvature_after":driver.trajectory.curvature_after,"points":[]}
			for i: int in range(driver.trajectory.points.size()): row.reference.points.append([driver.trajectory.cumulative[i],driver.trajectory.points[i].x,driver.trajectory.points[i].y,driver.trajectory.speeds[i],driver.trajectory.curvature[i],driver.trajectory.layers[i]])
		results.append(row)
		if not frames.is_empty():
			row.document = document
			row.replay = {"schema":REPLAY_SCHEMA,"frames":frames}
		print("DRIVER %s finished=%s ticks=%d laps=%d collisions=%d wall_ms=%.1f" % [row.name,row.finished,row.ticks,row.laps,row.collisions,row.wall_ms])
	var file := FileAccess.open(destination,FileAccess.WRITE)
	if file == null: push_error("Cannot write benchmark"); quit(1); return
	file.store_string(JSON.stringify({"results":results},"\t"))
	file.close()
	quit(0)
