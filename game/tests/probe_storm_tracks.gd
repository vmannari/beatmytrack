extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
	for id: String in ["storm_freight","storm_quarry"]:
		var document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://resources/storm_tracks/"+id+".json"))
		var track: NativeTrack = TrackCompiler.compile(document)
		var config: HandlingConfig = VehicleCatalog.config("compact")
		var sim := VehicleSimulation.new(config)
		sim.reset(track.spawn,track.spawn_heading)
		sim.state.route_index = track.nearest_route(track.spawn)
		var driver := RouteDriver.new()
		var session := TrackSession.new(120,5)
		var distance: float = 0
		var previous_miss: int = -1
		var previous_index: int = 0
		for tick: int in range(22000):
			var before: Vector2 = sim.state.position
			sim.step(driver.sample(sim.state,track,config),track)
			distance += before.distance_to(sim.state.position)
			session.advance(track,before,sim.state.position,sim.state.route_index,sim.state.track_elevated)
			if session.missed_checkpoint!=previous_miss and session.missed_checkpoint>=0:
				print("STORM_MISS ",id," t=",tick/120.0," position=",sim.state.position," gate=",session.next_checkpoint," center=",session.checkpoint_road_center(track)," index=",sim.state.route_index)
			previous_miss = session.missed_checkpoint
			if previous_index>track.route.size()*.9 and sim.state.route_index<track.route.size()*.1:
				print("STORM_WRAP ",id," t=",tick/120.0," distance=",distance," next=",session.next_checkpoint," laps=",session.completed_laps)
			previous_index = sim.state.route_index
		print("STORM_PROBE ",id," distance=",distance," laps=",session.lap_times," gate=",session.next_checkpoint," center=",session.checkpoint_road_center(track))
	quit()
