extends "res://backend/runner.gd"
## Opt-in private geometry diagnostic; local player poses are never shipped.
func run() -> void:
	var corpus: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://../backend/bmt_backend/lab_tracks.json"))
	var rows: Array = []
	for document: Dictionary in corpus.documents:
		if document.name not in ["Silmukka","Curvy"]: continue
		var recording: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://../.tools/pace2-human-"+str(document.name).to_lower()+"-poses.json"))
		var compiled: Dictionary = compile_track(document)
		var track: NativeTrack = compiled.track
		var sim: VehicleSimulation = initial_simulation(track,"compact")
		var count: int = clampi(ceili(track.route_length/RacingTrajectory.SPACING),16,RacingTrajectory.MAX_SAMPLES)
		var spacing: float = track.route_length/count
		var seeds := PackedVector2Array();seeds.resize(count)
		var samples: Array = []
		var hint: int = -1
		for pose: Array in recording.poses:
			var point := Vector2(pose[1],pose[2])
			hint = track.nearest_route(point,hint)
			var progress: float = track.route_progress(point,hint)
			samples.append([fposmod(progress,track.route_length),point])
		samples.sort_custom(func(a: Array,b: Array) -> bool: return a[0] < b[0])
		var first: Array = samples[0];var last: Array = samples[-1]
		samples.push_front([last[0]-track.route_length,last[1]])
		samples.append([first[0]+track.route_length,first[1]])
		var index: int = 0
		for i: int in range(count):
			var progress: float = i*spacing
			while index+1 < samples.size()-1 and samples[index+1][0] <= progress: index += 1
			var a: Array = samples[index];var b: Array = samples[index+1]
			seeds[i] = (a[1] as Vector2).lerp(b[1],clampf((progress-a[0])/maxf(0.000001,b[0]-a[0]),0.0,1.0))
		var trajectory := RacingTrajectory.new();trajectory.build(track,sim.config,"center",seeds)
		var traits: Dictionary = {"seed":27,"skill":1.0,"consistency":1.0,"aggression":0.5,"learning":0.5,"strengths":{}}
		var driver := ProfiledRouteDriver.new(traits,str(document.theme),track.content_hash,0);driver.trajectory = trajectory
		var session := TrackSession.new(VehicleSimulation.TICK_RATE,5)
		var frames: Array = []
		for tick: int in range(MAX_FRAMES):
			var frame: DriveFrame = driver.sample(sim.state,track,sim.config,session);frames.append(frame.packed())
			var before: Vector2 = sim.state.position;var layer: int = int(sim.state.track_elevated)
			sim.step(frame,track);session.advance(track,before,sim.state.position,sim.state.route_index,sim.state.track_elevated,layer)
			if session.finished or session.missed_checkpoint >= 0: break
		rows.append({"name":document.name,"finished":session.finished,"ticks":session.elapsed_ticks,"laps":session.lap_times,"contacts":sim.state.collision_count,"line_length":trajectory.length,"document":document,"replay":{"schema":REPLAY_SCHEMA,"frames":frames}})
		print("TEACHER %s finished=%s ticks=%d contacts=%d length=%.1f" % [document.name,session.finished,session.elapsed_ticks,sim.state.collision_count,trajectory.length])
	var file := FileAccess.open("res://../.tools/pace2-teacher-line-probe.json",FileAccess.WRITE);file.store_string(JSON.stringify(rows));file.close();quit(0)
