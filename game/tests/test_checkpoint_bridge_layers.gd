extends SceneTree
## Real creator roads exercise gate acceptance with the canonical bridge layer.
var checks: int = 0
var failures: int = 0

func _initialize() -> void: call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: "+message)

func run() -> void:
	var document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/dust_cloud.json"))
	var track: NativeTrack = TrackCompiler.compile(document)
	check(track != null,"Dust cloud compiles")
	var session := TrackSession.new()
	session._configure(track)
	check(session._centers[8].distance_to(Vector2(1.712269,-24.83281)) < 0.01,"fixture retains the reported ninth gate")
	check(track.has_overhead_bridge(session._centers[8],false),"reported gate lies beneath a bridge edge")
	check(not session._layers[8],"parallel underpass gate belongs to the ground road")
	_check_layers(track)
	for reverse: bool in [false,true]:
		var directed: Dictionary = document.duplicate(true)
		if reverse: directed.start_line.heading = fposmod(float(directed.start_line.heading)+180.0,360.0)
		var oriented: NativeTrack = TrackCompiler.compile(directed)
		for spacing: float in [0.1,0.5,1.5]:
			_walk(oriented,spacing,5,"Dust cloud reverse=%s spacing=%s" % [reverse,spacing])
	var bridge: Dictionary = track.creator_bridges[0]
	var deck_start: Vector2 = Vector2(bridge.position[0],bridge.position[1])+Vector2.RIGHT.rotated(deg_to_rad(float(bridge.heading)))*float(bridge.length)*0.5
	var on_deck: Dictionary = document.duplicate(true)
	on_deck.start_line = {"position":[deck_start.x,deck_start.y],"heading":bridge.heading}
	var deck_track: NativeTrack = TrackCompiler.compile(on_deck)
	check(deck_track != null,"start line on the bridge compiles")
	var deck_session := TrackSession.new(120,1)
	deck_session._configure(deck_track)
	check(deck_session._finish_elevated,"bridge start/finish uses the simulation heading convention")
	_walk(deck_track,0.1,1,"Dust cloud bridge start")
	_check_layers(deck_track)
	var knit: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/knit_bridge_regression.json"))
	_walk(TrackCompiler.compile(knit),0.1,1,"Knit")
	_check_layers(TrackCompiler.compile(knit))
	_simulate(track,document)
	print("BRIDGE_CHECKPOINT_TESTS: ",checks," checks, ",failures," failures")
	quit(0 if failures == 0 else 1)

func _walk(track: NativeTrack, spacing: float, laps: int, label: String) -> void:
	var session := TrackSession.new(120,laps)
	session._configure(track)
	var layer: bool = CreatorBridges.initial_layer(track.creator_bridges,track.finish_center,atan2(track.finish_forward.x,track.finish_forward.y))
	# The compiler projects the finish onto the physical road; advance beyond
	# that small projection offset before/after the measured loop.
	var previous: Vector2 = track._race_route_point(session._start_progress+0.1)
	var hint: int = track.nearest_route(previous)
	var warned: bool = false
	for lap: int in range(laps):
		for step: int in range(1,ceili(track.route_length/spacing)+1):
			var point: Vector2 = track._race_route_point(session._start_progress+minf(step*spacing,track.route_length)+0.1)
			hint = track.nearest_route(point,hint)
			var previous_layer: int = int(layer)
			# Collision resolution subdivides motion before determining its layer.
			for substep: int in range(1,maxi(1,ceili(previous.distance_to(point)/0.2))+1):
				var probe: Vector2 = previous.lerp(point,float(substep)/maxi(1,ceili(previous.distance_to(point)/0.2)))
				layer = track.collision_elevated_at(probe,hint,0.0,1 if layer else 0)
			var gate: int = session.next_checkpoint
			if gate < session.checkpoint_count() and session._crossing(gate,previous,point) >= 0.0 and session._inside(gate,point) and session._layers[gate] != layer:
				print("LAYER_MISMATCH ",label," gate=",gate," center=",session._centers[gate]," expected=",session._layers[gate]," actual=",layer," crossing=",point)
			session.advance(track,previous,point,hint,layer,previous_layer)
			warned = warned or session.missed_checkpoint >= 0
			previous = point
		check(session.completed_laps == lap+1,label+" completes lap "+str(lap+1))
		if session.completed_laps != lap+1: print("BLOCKED ",label," gate=",session.next_checkpoint," total=",session.checkpoint_count()," finish=",track.finish_center," finish_layer=",session._finish_elevated," layer=",layer," end=",previous," signed_finish_distance=",(previous-track.finish_center).dot(track.finish_forward))
	check(session.finished and not warned,label+" finishes without missing a gate")

func _check_layers(track: NativeTrack) -> void:
	var session := TrackSession.new(120,1)
	session._configure(track)
	var elevated_gates: int = 0
	for index: int in range(session.checkpoint_count()):
		var center: Vector2 = session._centers[index]
		var direction: Vector2 = session._directions[index]
		var expected: bool = session._layers[index]
		elevated_gates += 1 if expected else 0
		session.next_checkpoint = index
		session.advance(track,center-direction*0.05,center+direction*0.05,track.nearest_route(center),not expected)
		check(session.next_checkpoint == index,"wrong layer rejects gate %s/%s" % [track.identity,index])
		session.advance(track,center-direction*0.05,center+direction*0.05,track.nearest_route(center),expected)
		check(session.next_checkpoint > index,"intended layer accepts gate %s/%s" % [track.identity,index])
	check(elevated_gates > 0,"real bridge gates retain layer protection "+track.identity)
	session.next_checkpoint = session.checkpoint_count()
	session.finish_armed = true
	session.advance(track,track.finish_center-track.finish_forward*0.05,track.finish_center+track.finish_forward*0.05,0,not session._finish_elevated)
	check(not session.finished,"wrong layer cannot finish "+track.identity)
	session.advance(track,track.finish_center-track.finish_forward*0.05,track.finish_center+track.finish_forward*0.05,0,session._finish_elevated)
	check(session.finished,"intended layer can finish "+track.identity)

func _simulate(track: NativeTrack, document: Dictionary, label: String = "Dust cloud", evidence_folder: String = "dust-cloud-checkpoints-2026-10-03") -> void:
	var sim := VehicleSimulation.new(VehicleCatalog.config("compact"))
	sim.reset(track.spawn,track.spawn_heading)
	var start_distance: float = (sim.state.position-track.finish_center).dot(track.finish_forward)
	sim.state.position -= track.finish_forward*maxf(0.0,start_distance+3.0)
	sim.state.route_index = track.nearest_route(sim.state.position)
	sim.state.track_elevated = track.elevated_at(sim.state.position,sim.state.route_index)
	var driver := RouteDriver.new()
	var session := TrackSession.new()
	var frames: Array = []
	var warned: bool = false
	for tick: int in range(60000):
		var frame: DriveFrame = driver.sample(sim.state,track,sim.config)
		frames.append(frame.packed())
		var before: Vector2 = sim.state.position
		var previous_layer: int = int(sim.state.track_elevated)
		sim.step(frame,track)
		session.advance(track,before,sim.state.position,sim.state.route_index,sim.state.track_elevated,previous_layer)
		warned = warned or session.missed_checkpoint >= 0
		if session.finished: break
	check(session.finished and session.completed_laps == 5,"actual compact simulation finishes five "+label+" laps")
	check(not warned,"actual compact simulation has no false missed-gate warning on "+label)
	print(label.to_upper().replace(" ","_")+"_RACE laps=",session.completed_laps," ticks=",session.elapsed_ticks," gate=",session.next_checkpoint," position=",sim.state.position)
	if session.finished:
		var folder: String = ProjectSettings.globalize_path("res://../build/"+evidence_folder)
		DirAccess.make_dir_recursive_absolute(folder)
		var file := FileAccess.open(folder.path_join("desktop-race.json"),FileAccess.WRITE)
		file.store_string(JSON.stringify({"document":document,"replay":{"schema":"bmt-replay-v1","frames":frames},"time_ticks":session.elapsed_ticks,"vehicle_id":"compact"}))
		file.close()
