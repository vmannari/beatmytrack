extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/over_and_under.json"))
	var track: NativeTrack = TrackCompiler.compile(document)
	var sim := VehicleSimulation.new(VehicleCatalog.config("compact"))
	sim.reset(track.spawn,track.spawn_heading)
	sim.state.position -= track.finish_forward*maxf(0.0,(sim.state.position-track.finish_center).dot(track.finish_forward)+3.0)
	sim.state.route_index = track.nearest_route(sim.state.position)
	sim.state.track_elevated = track.elevated_at(sim.state.position,sim.state.route_index)
	var driver := RouteDriver.new()
	var session := TrackSession.new()
	session._configure(track)
	var script := GDScript.new()
	script.source_code = FileAccess.get_file_as_string("res://../docs/evidence/checkpoint-notice-2026-10-17/before/game/race/track_session.gd").replace("\r\n","\n").replace("class_name TrackSession\n","")
	script.reload()
	var old = script.new(); old._configure(track)
	for tick: int in range(60000):
		var frame: DriveFrame = driver.sample(sim.state,track,sim.config)
		var before: Vector2 = sim.state.position
		var layer: int = int(sim.state.track_elevated)
		sim.step(frame,track)
		session.advance(track,before,sim.state.position,sim.state.route_index,sim.state.track_elevated,layer)
		old.advance(track,before,sim.state.position,sim.state.route_index,sim.state.track_elevated,layer)
		if session.missed_checkpoint >= 0 and old.missed_checkpoint < 0:
			print("NEW_FALSE_NOTICE tick=",tick," gate=",session.next_checkpoint," position=",sim.state.position," hint=",sim.state.route_index," layer=",sim.state.track_elevated," progress=",session.last_progress," old_progress=",old.last_progress," center=",session._centers[session.next_checkpoint]," reach=",session._notice_reach[session.next_checkpoint])
			var candidates: Array = []
			for i: int in range(track.route.size()):
				var edge: Vector2 = track.route[(i+1)%track.route.size()]-track.route[i]
				var t: float = clampf((sim.state.position-track.route[i]).dot(edge)/edge.length_squared(),0.0,1.0)
				var distance: float = sim.state.position.distance_to(track.route[i]+edge*t)
				if distance < 3.0: candidates.append({"index":i,"distance":distance,"layer":track.elevated_at(sim.state.position,i),"progress":track.route_cumulative[i]+edge.length()*t})
			print("NEARBY_SEGMENTS ",candidates)
			break
		if session.finished: break
	quit()
