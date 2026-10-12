extends "res://tests/test_checkpoint_bridge_layers.gd"
## Drive every vehicle through the affected Over and under exits on ordinary lanes.

func run() -> void:
	check(RaceRules.KEY == "standing-5-road-gates-v19","current ordered gate geometry has its own pinned rules key")
	var document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/over_and_under.json"))
	var track: NativeTrack = TrackCompiler.compile(document)
	_check_layers(track)
	var reverse: Dictionary = document.duplicate(true)
	reverse.start_line.heading = fposmod(float(reverse.start_line.heading)+180.0,360.0)
	var reverse_track: NativeTrack = TrackCompiler.compile(reverse)
	_check_layers(reverse_track)
	var reverse_bridge: Dictionary = track.creator_bridges[1].duplicate(true)
	var axis: Vector2 = Vector2.RIGHT.rotated(deg_to_rad(float(reverse_bridge.heading)))
	var end: Vector2 = Vector2(reverse_bridge.position[0],reverse_bridge.position[1])+axis*float(reverse_bridge.length)
	reverse_bridge.position = [end.x,end.y]
	reverse_bridge.heading = fposmod(float(reverse_bridge.heading)+180.0,360.0)
	for vehicle_id: String in VehicleCatalog.IDS:
		for speed: float in [30.0,60.0,90.0,120.0,160.0,200.0]:
			for phase: int in range(8):
				for lateral: float in [-2.0,-1.0,0.0,1.0,2.0]:
					_exit_lane(track,12,track.creator_bridges[0],speed,float(phase)/8.0,lateral,vehicle_id)
					_exit_lane(reverse_track,16,reverse_bridge,speed,float(phase)/8.0,lateral,vehicle_id)
		print("EXIT_VEHICLE_DONE ",vehicle_id)
	print("BRIDGE_EXIT_TESTS: ",checks," checks, ",failures," failures")
	quit(0 if failures == 0 else 1)

func _exit_lane(track: NativeTrack, gate: int, bridge: Dictionary, speed: float, phase: float, lateral: float, vehicle_id: String) -> void:
	var session := TrackSession.new(120,1)
	session._configure(track)
	session.next_checkpoint = gate
	var forward: Vector2 = Vector2.RIGHT.rotated(deg_to_rad(float(bridge.heading)))
	var end: Vector2 = Vector2(bridge.position[0],bridge.position[1])+forward*float(bridge.length)
	var sim := VehicleSimulation.new(VehicleCatalog.config(vehicle_id))
	sim.reset(end-forward*(3.0+phase*speed/3.6/120.0)+forward.orthogonal()*lateral,atan2(forward.x,forward.y))
	sim.state.route_index = track.nearest_route(sim.state.position)
	sim.state.track_elevated = true
	sim.state.velocity = forward*speed/3.6
	var on_road: bool = true
	var warned: bool = false
	for tick: int in range(240):
		var before: Vector2 = sim.state.position
		var previous_layer: int = int(sim.state.track_elevated)
		sim.step(DriveFrame.new(),track)
		session.advance(track,before,sim.state.position,sim.state.route_index,sim.state.track_elevated,previous_layer)
		on_road = on_road and track.cell_at(sim.state.position,sim.state.track_elevated) in [0,5]
		warned = warned or session.missed_checkpoint >= 0
		if session.next_checkpoint > gate or warned: break
	check(session.next_checkpoint > gate and not warned and on_road and sim.state.collision_count == 0,"actual exit %s stays on road and accepts %s seeded %s km/h phase %s lane %s" % [gate,vehicle_id,speed,phase,lateral])
