extends "res://tests/test_checkpoint_rules.gd"

func run() -> void:
	var doc: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/knot.json"))
	for reverse: bool in [false,true]:
		var directed: Dictionary = doc.duplicate(true)
		if reverse: directed.start_line.heading = fposmod(float(directed.start_line.heading)+180.0,360.0)
		var track: NativeTrack = TrackCompiler.compile(directed)
		var configured := TrackSession.new(120,1); configured._configure(track)
		print("KNOT_LAYOUT reverse=",reverse," length=",track.route_length," gates=",configured.checkpoint_count()," spline=",configured._spline_corridor)
		if not reverse:
			configured.next_checkpoint = 3
			var point := Vector2(52.32339,-24.88533)
			print("KNOT_DIAG target=",configured._progress[3]," previous=",configured._progress[2]," reach=",configured._notice_reach[3]," prev_reach=",configured._notice_reach[2]," hints=",configured._route_hints.slice(1,5))
			for i: int in range(track.route.size()):
				var edge: Vector2 = track.route[(i+1)%track.route.size()]-track.route[i]
				var t: float = clampf((point-track.route[i]).dot(edge)/edge.length_squared(),0.0,1.0)
				var distance: float = point.distance_to(track.route[i]+edge*t)
				if distance < 8.0: print("KNOT_SEG i=",i," distance=",distance," progress=",track.route_cumulative[i]+edge.length()*t," layer=",track.elevated_at(point,i)," width=",track.route_widths[i]," cumulative=",track.route_cumulative[i])
		for offset: float in [-4.0,-2.0,0.0,2.0,4.0]:
			var session := TrackSession.new(120,1); session._configure(track)
			var previous: Vector2 = lane_point(track,session._start_progress+0.1,offset)
			var hint: int = track.nearest_route(previous)
			var layer: bool = session._finish_elevated
			var notices: int = 0
			for step: int in range(1,ceili(track.route_length/0.2)+2):
				var point: Vector2 = lane_point(track,session._start_progress+step*0.2+0.1,offset)
				hint = track.nearest_route(point,hint)
				var previous_layer: int = int(layer)
				layer = CreatorBridges.layer_at(track.creator_bridges,point,layer)
				var old: int = session.missed_checkpoint
				session.advance(track,previous,point,hint,layer,previous_layer)
				if session.missed_checkpoint >= 0 and old < 0:
					notices += 1
					print("KNOT_NOTICE reverse=",reverse," lane=",offset," distance=",step*0.2," gate=",session.next_checkpoint," progress=",session.last_progress," from=",previous," to=",point," hint=",hint," layer=",layer," center=",session.checkpoint_road_center(track)," direction=",session.checkpoint_direction(track)," offset=",session._notice_offset(track,session.last_progress) if session.next_checkpoint < session.checkpoint_count() else 0)
				previous = point
			print("KNOT_LANE reverse=",reverse," lane=",offset," finished=",session.finished," notices=",notices," gate=",session.next_checkpoint)
		var sim := VehicleSimulation.new(VehicleCatalog.config("compact")); sim.reset(track.spawn,track.spawn_heading)
		var driver := RouteDriver.new(); var session := TrackSession.new(120,1)
		var notices: int = 0
		for tick: int in range(20000):
			var a: Vector2 = sim.state.position
			var previous_layer: int = int(sim.state.track_elevated)
			sim.step(driver.sample(sim.state,track,sim.config),track)
			var old: int = session.missed_checkpoint
			session.advance(track,a,sim.state.position,sim.state.route_index,sim.state.track_elevated,previous_layer)
			if session.missed_checkpoint >= 0 and old < 0:
				notices += 1
				print("KNOT_DRIVE_NOTICE reverse=",reverse," tick=",tick," gate=",session.next_checkpoint," progress=",session.last_progress," from=",a," to=",sim.state.position," hint=",sim.state.route_index," layer=",sim.state.track_elevated," center=",session.checkpoint_road_center(track)," direction=",session.checkpoint_direction(track))
			if session.finished: break
		print("KNOT_DRIVE reverse=",reverse," finished=",session.finished," notices=",notices," ticks=",session.elapsed_ticks," gate=",session.next_checkpoint)
	quit()

func lane_point(track: NativeTrack, progress: float, offset: float) -> Vector2:
	var tangent: Vector2 = (track._race_route_point(progress+0.5)-track._race_route_point(progress-0.5)).normalized()
	return track._race_route_point(progress)+tangent.orthogonal()*offset
