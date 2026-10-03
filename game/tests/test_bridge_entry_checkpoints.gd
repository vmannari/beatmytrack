extends "res://tests/test_checkpoint_bridge_layers.gd"
## Swept checkpoint acceptance across ground/deck transitions at racing speed.

func run() -> void:
	var document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/over_and_under.json"))
	var track: NativeTrack = TrackCompiler.compile(document)
	var gates := TrackSession.new(120,1)
	gates._configure(track)
	for index: int in range(gates.checkpoint_count()):
		var center: Vector2 = gates._centers[index]
		for span: Dictionary in track.creator_bridges:
			var local: Vector2 = CreatorBridges.local_point(span,center)
			if absf(local.y) <= float(span.width)*0.5+1.0 and (absf(local.x) < 2.0 or absf(local.x-float(span.length)) < 2.0):
				print("RAMP_GATE index=",index," expected=",gates._layers[index]," point=",center," local=",local," length=",span.length)
	for reverse: bool in [false,true]:
		var directed: Dictionary = document.duplicate(true)
		if reverse: directed.start_line.heading = fposmod(float(directed.start_line.heading)+180.0,360.0)
		var oriented: NativeTrack = TrackCompiler.compile(directed)
		for speed: float in [30.0,60.0,90.0,120.0,160.0,200.0]:
			for phase: int in range(8):
				_fast_walk(oriented,speed,float(phase)/8.0,"Over and under reverse=%s speed=%s phase=%s" % [reverse,speed,phase])
	_check_layers(track)
	for vehicle_id: String in VehicleCatalog.IDS:
		_actual_transition(track,13,false,Vector2(0,-1),"entry",vehicle_id)
		_actual_transition(track,15,true,Vector2(0,-1),"exit",vehicle_id)
	_mixed_sweep()
	_simulate(track,document,"Over and under","bridge-entry-checkpoints-2026-10-03")
	print("BRIDGE_ENTRY_TESTS: ",checks," checks, ",failures," failures")
	quit(0 if failures == 0 else 1)

func _fast_walk(track: NativeTrack, speed: float, phase: float, label: String) -> void:
	var session := TrackSession.new(120,1)
	session._configure(track)
	var layer: bool = CreatorBridges.initial_layer(track.creator_bridges,track.finish_center,atan2(track.finish_forward.x,track.finish_forward.y))
	var spacing: float = speed/3.6/120.0
	var start: float = 0.5+phase*spacing
	var previous: Vector2 = track._race_route_point(session._start_progress+start)
	var hint: int = track.nearest_route(previous)
	var mismatch: bool = false
	var warned: bool = false
	for step: int in range(1,ceili(track.route_length/spacing)+1):
		var point: Vector2 = track._race_route_point(session._start_progress+minf(step*spacing,track.route_length)+start)
		hint = track.nearest_route(point,hint)
		var previous_layer: int = int(layer)
		var substeps: int = maxi(1,ceili(previous.distance_to(point)/(track.cell_size*0.45)))
		for substep: int in range(1,substeps+1):
			var probe: Vector2 = previous.lerp(point,float(substep)/substeps)
			layer = track.collision_elevated_at(probe,hint,0.0,1 if layer else 0)
		var gate: int = session.next_checkpoint
		session.advance(track,previous,point,hint,layer,previous_layer)
		warned = warned or session.missed_checkpoint >= 0
		if gate < session.checkpoint_count() and session._crossing(gate,previous,point) >= 0.0:
			if session._inside(gate,previous.lerp(point,session._crossing(gate,previous,point))) and session.next_checkpoint == gate:
				print("ENTRY_MISMATCH ",label," gate=",gate," center=",session._centers[gate]," expected=",session._layers[gate]," actual=",layer," from=",previous," to=",point)
				mismatch = true
		previous = point
	check(session.finished and not mismatch and not warned,label+" completes every bridge gate without a false warning")

func _actual_transition(track: NativeTrack, gate: int, elevated: bool, direction: Vector2, label: String, vehicle_id: String) -> void:
	label = vehicle_id+" "+label
	for speed: float in [120.0,160.0,200.0]:
		var session := TrackSession.new(120,1)
		session._configure(track)
		session.next_checkpoint = gate
		var sim := VehicleSimulation.new(VehicleCatalog.config(vehicle_id))
		sim.reset(session._centers[gate]-direction*0.01,atan2(direction.x,direction.y))
		sim.state.route_index = track.nearest_route(sim.state.position)
		sim.state.track_elevated = elevated
		sim.state.velocity = direction*speed/3.6
		var history := RewindHistory.new()
		history.capture(sim.state,session,true)
		var saved: Dictionary = history.entries[0]
		var before: Vector2 = sim.state.position
		sim.step(DriveFrame.new(),track)
		# The kart caps at 108 km/h, so this exit's 0.266 m gap takes two
		# ticks. Its gate must still be accepted in the first (deck) tick.
		var kart_exit: bool = vehicle_id == "kart" and elevated
		check(sim.state.track_elevated == elevated if kart_exit else sim.state.track_elevated != elevated,"actual %s at seeded %s km/h has its expected ramp layer" % [label,speed])
		session.advance(track,before,sim.state.position,sim.state.route_index,sim.state.track_elevated,int(elevated))
		check(session.next_checkpoint > gate and session.missed_checkpoint == -1,"actual %s at %s km/h accepts the swept gate" % [label,speed])
		var expected_state: Array = sim.state.snapshot()
		var expected_progress: int = session.next_checkpoint
		RewindHistory.restore(sim.state,saved.state)
		RewindHistory.restore(session,saved.session)
		before = sim.state.position
		var restored_layer: int = int(sim.state.track_elevated)
		sim.step(DriveFrame.new(),track)
		session.advance(track,before,sim.state.position,sim.state.route_index,sim.state.track_elevated,restored_layer)
		check(sim.state.snapshot() == expected_state and session.next_checkpoint == expected_progress and session.elapsed_ticks == 1,"rewind reproduces %s gate acceptance at %s km/h" % [label,speed])
		if kart_exit:
			before = sim.state.position
			sim.step(DriveFrame.new(),track)
			session.advance(track,before,sim.state.position,sim.state.route_index,sim.state.track_elevated,1)
			check(not sim.state.track_elevated and session.next_checkpoint == expected_progress and session.missed_checkpoint == -1,"kart completes its exit in the next tick without a false miss")

func _mixed_sweep() -> void:
	var track := NativeTrack.new()
	track.route = PackedVector2Array([Vector2.ZERO,Vector2(60,0),Vector2(60,40),Vector2(0,40)])
	track.finish_forward = Vector2.RIGHT
	track.finish_half_width = 5.0
	track._build_route_distance()
	track.creator_bridges = [{"position":[10.0,0.0],"heading":0.0,"length":24.0,"width":10.0}]
	var session := TrackSession.new(120,1)
	session._configure(track)
	session._centers = PackedVector2Array([Vector2(9.9,0),Vector2(12,0)])
	session._directions = PackedVector2Array([Vector2.RIGHT,Vector2.RIGHT])
	session._layers.assign([false,true])
	session._widths.assign([Vector2(5,5),Vector2(5,5)])
	session._progress = PackedFloat32Array([9.9,12])
	session.advance(track,Vector2(9.5,0),Vector2(12.5,0),0,true,0)
	check(session.next_checkpoint == 2,"one sweep consumes ground and deck gates in order at their own layers")
	session.next_checkpoint = 0
	session.advance(track,Vector2(9.5,0),Vector2(12.5,0),0,false,0)
	check(session.next_checkpoint == 1,"a sweep that stays on the ground cannot consume the deck gate")
	for finish_layer: bool in [false,true]:
		session.next_checkpoint = 2
		session.finish_armed = true
		session._finish_elevated = finish_layer
		track.finish_center = Vector2(10.1 if finish_layer else 9.9,0)
		session.advance(track,Vector2(9.5,0),Vector2(10.5,0),0,true,0)
		check(session.completed_laps == 1,"start/finish checks the exact crossing layer %s" % finish_layer)
		session.finished = false
		session.completed_laps = 0
