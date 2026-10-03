extends "res://tests/test_bridge_entry_checkpoints.gd"
## Local diagnostic over immutable public documents; never part of shipping.

func run() -> void:
	var corpus: Array = JSON.parse_string(FileAccess.get_file_as_string("res://../build/bridge-exit-checkpoints-2026-10-03/tracks.json"))
	for record: Dictionary in corpus:
		for reverse: bool in [false,true]:
			var document: Dictionary = record.document.duplicate(true)
			if reverse: document.start_line.heading = fposmod(float(document.start_line.heading)+180.0,360.0)
			var track: NativeTrack = TrackCompiler.compile(document)
			for lateral: float in [-2.0,-1.0,0.0,1.0,2.0]:
				_offset_walk(track,lateral,"%s reverse=%s offset=%s" % [record.name,reverse,lateral])
		print("TRACK_PROBED ",record.name)
	print("BRIDGE_EXIT_PROBE: ",checks," checks, ",failures," failures")
	quit(0 if failures == 0 else 1)

func _point(track: NativeTrack, distance: float, lateral: float) -> Vector2:
	var point: Vector2 = track._race_route_point(distance)
	var direction: Vector2 = (track._race_route_point(distance+0.1)-track._race_route_point(distance-0.1)).normalized()
	return point+direction.orthogonal()*lateral

func _offset_walk(track: NativeTrack, lateral: float, label: String) -> void:
	var session := TrackSession.new(120,1)
	session._configure(track)
	var layer: bool = CreatorBridges.initial_layer(track.creator_bridges,track.finish_center,atan2(track.finish_forward.x,track.finish_forward.y))
	var previous: Vector2 = _point(track,session._start_progress+0.5,lateral)
	var hint: int = track.nearest_route(previous)
	var warned: bool = false
	var mismatch: bool = false
	var printed: bool = false
	for step: int in range(1,ceili((track.route_length+2.0)/0.25)+1):
		var point: Vector2 = _point(track,session._start_progress+minf(step*0.25,track.route_length+2.0)+0.5,lateral)
		hint = track.nearest_route(point,hint)
		var previous_layer: int = int(layer)
		for substep: int in range(1,maxi(1,ceili(previous.distance_to(point)/0.1))+1):
			var probe: Vector2 = previous.lerp(point,float(substep)/maxi(1,ceili(previous.distance_to(point)/0.1)))
			layer = track.collision_elevated_at(probe,hint,0.0,int(layer))
		var gate: int = session.next_checkpoint
		session.advance(track,previous,point,hint,layer,previous_layer)
		if gate < session.checkpoint_count():
			var fraction: float = session._crossing(gate,previous,point)
			if fraction >= 0.0 and session._inside(gate,previous.lerp(point,fraction)) and session.next_checkpoint == gate:
				mismatch = true
				if not printed:
					print("EXIT_REJECT ",label," gate=",gate," center=",session._centers[gate]," expected=",session._layers[gate]," before_layer=",previous_layer," after_layer=",layer," crossing_layer=",session._crossing_layer(track,previous,point,fraction,hint,layer,previous_layer)," point=",previous.lerp(point,fraction))
					printed = true
		warned = warned or session.missed_checkpoint >= 0
		previous = point
	check(session.finished and not mismatch and not warned,label+" completes every legal near-centre gate")
