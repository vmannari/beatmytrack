extends "res://tests/test_electric_power.gd"

const OVER_OUTPUT: String = "res://../docs/evidence/electric-tighter-held-steering-2026-10-26"
const SOURCE: String = "res://resources/cloud_tracks/ecde9782d147738d3ab50d94a4a14255dd1e79069d96823960c77c46a394c948.json"

func initial_vehicle(config: HandlingConfig, track: NativeTrack) -> VehicleSimulation:
	var sim := VehicleSimulation.new(config)
	sim.reset(track.spawn,track.spawn_heading)
	var distance: float=(sim.state.position-track.finish_center).dot(track.finish_forward)
	sim.state.position-=track.finish_forward*maxf(0.0,distance+3.0)
	sim.state.route_index=track.nearest_route(sim.state.position)
	sim.state.track_elevated=track.elevated_at(sim.state.position,sim.state.route_index)
	if CreatorBridges.at_any(track.creator_bridges,sim.state.position):
		sim.state.track_elevated=CreatorBridges.initial_layer(track.creator_bridges,sim.state.position,sim.state.heading)
	return sim

func run() -> void:
	var document: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(SOURCE))
	var fixture: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/over_and_under.json"))
	check(document.name=="Over and under" and document.id=="track_2428fcd33a076ea8","test uses the named cached Over and under track")
	check(JSON.stringify(document,"",true)==JSON.stringify(fixture,"",true),"cached track and retained bridge fixture are identical")
	var track: NativeTrack=TrackCompiler.compile(document)
	check(track!=null,"actual track compiles unchanged")
	if track==null: quit(1); return
	var config: HandlingConfig=VehicleCatalog.config("electric")
	var sim: VehicleSimulation=initial_vehicle(config,track)
	var driver := RouteDriver.new()
	var session := TrackSession.new(120,5)
	var frames: Array=[]
	var upper: int=0
	var lower: int=0
	for tick: int in range(120*600):
		var frame: DriveFrame=driver.sample(sim.state,track,config)
		frames.append(frame.packed())
		var before: Vector2=sim.state.position
		var layer: int=int(sim.state.track_elevated)
		sim.step(frame,track)
		session.advance(track,before,sim.state.position,sim.state.route_index,sim.state.track_elevated,layer)
		if sim.state.track_elevated: upper+=1
		else: lower+=1
		if session.finished: break
	check(session.finished and session.completed_laps==5,"electric completes all five ordered Over and under laps")
	check(sim.state.collision_count==0,"Over and under completes without rail/body contacts")
	check(upper>50 and lower>50,"race traverses both upper and lower bridge levels")
	var replay: VehicleSimulation=initial_vehicle(config,track)
	for packed: Array in frames:
		replay.step(DriveFrame.sample(float(packed[0])/127.0,float(packed[1])/255.0,float(packed[2])/255.0),track)
	check(replay.state.snapshot()==sim.state.snapshot(),"Over and under recorded input replays exactly")
	metrics={"laps":session.completed_laps,"lap_times":session.lap_times,"contacts":sim.state.collision_count,"upper_ticks":upper,"lower_ticks":lower,"inputs":frames.size(),"time_ticks":session.elapsed_ticks,"source":SOURCE}
	var file := FileAccess.open(OVER_OUTPUT+"/over-under.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"metrics":metrics},"\t"))
	file.close()
	if session.finished:
		var recording := FileAccess.open(OVER_OUTPUT+"/over-under-race.json",FileAccess.WRITE)
		recording.store_string(JSON.stringify({"ok":true,"result":{"document":document,"vehicle_id":"electric","time_ticks":session.elapsed_ticks,"replay":{"schema":"bmt-replay-v1","frames":frames}}}))
		recording.close()
	print("ELECTRIC_OVER_UNDER: %d checks, %d failures " % [checks,failures],JSON.stringify(metrics))
	quit(1 if failures else 0)
