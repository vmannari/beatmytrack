extends "res://tests/test_electric_over_under.gd"

const NORMAL_OUTPUT: String = "res://../docs/evidence/electric-driving-character-2026-10-26"
const IDS: Array[String] = ["storm_freight","storm_switchyard","storm_timber","storm_quarry","storm_floodgate"]

func run() -> void:
	metrics.tracks={}
	for id: String in IDS:
		var source: String="res://resources/storm_tracks/"+id+".json"
		var document: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(source))
		var track: NativeTrack=TrackCompiler.compile(document)
		check(track!=null,"normal production track compiles: "+id)
		if track==null: continue
		var config: HandlingConfig=VehicleCatalog.config("electric")
		var sim: VehicleSimulation=initial_vehicle(config,track)
		var session := TrackSession.new(120,1)
		var driver := RouteDriver.new()
		var frames: Array=[]
		for tick: int in range(120*300):
			var frame: DriveFrame=driver.sample(sim.state,track,config)
			frames.append(frame.packed())
			var before: Vector2=sim.state.position
			var layer: int=int(sim.state.track_elevated)
			sim.step(frame,track)
			session.advance(track,before,sim.state.position,sim.state.route_index,sim.state.track_elevated,layer)
			if session.finished: break
		check(session.finished and session.completed_laps==1,"ordinary electric lap finishes with ordered gates: "+id)
		check(sim.state.collision_count==0,"normal track lap has zero contacts: "+id)
		var replay: VehicleSimulation=initial_vehicle(config,track)
		for packed: Array in frames:
			replay.step(DriveFrame.sample(float(packed[0])/127.0,float(packed[1])/255.0,float(packed[2])/255.0),track)
		check(replay.state.snapshot()==sim.state.snapshot(),"normal track lap replays exactly: "+id)
		metrics.tracks[id]={"name":document.name,"laps":session.completed_laps,"contacts":sim.state.collision_count,"ticks":frames.size(),"lap_times":session.lap_times}
		print("NORMAL_TRACK ",id," ",JSON.stringify(metrics.tracks[id]))
	var file := FileAccess.open(NORMAL_OUTPUT+"/normal-tracks.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"metrics":metrics},"\t"))
	file.close()
	print("ELECTRIC_NORMAL_TRACKS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
