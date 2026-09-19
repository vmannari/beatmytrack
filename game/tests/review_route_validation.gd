extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var library := TrackLibrary.new()
	for document: Dictionary in library.list_documents():
		if document.get("pieces",[]).is_empty(): continue
		var track: NativeTrack = TrackCompiler.compile(document)
		for offset: float in [-8.0,-6.0,-4.0,0.0,4.0,6.0,8.0]:
			var path := PackedVector2Array()
			var offroad: int = 0
			for i: int in range(track.route.size()):
				var incoming: Vector2 = (track.route[i]-track.route[posmod(i-1,track.route.size())]).normalized()
				var outgoing: Vector2 = (track.route[(i+1)%track.route.size()]-track.route[i]).normalized()
				var normal: Vector2 = (incoming+outgoing).normalized().orthogonal()
				var point: Vector2 = track.route[i]+normal*offset
				path.append(point)
				if track.cell_at(point) not in [0,2,5]: offroad += 1
			path.append(path[0])
			path.append(path[0]+track.finish_forward*5.0)
			var session := TrackSession.new(120,1)
			var route_hint: int = 0
			for i: int in range(path.size()-1):
				var steps: int = maxi(1,ceili(path[i].distance_to(path[i+1])/0.2))
				for j: int in range(steps):
					var previous: Vector2 = path[i].lerp(path[i+1],float(j)/steps)
					var current: Vector2 = path[i].lerp(path[i+1],float(j+1)/steps)
					var cuts: int = session.shortcut_count
					route_hint = track.nearest_route(current,route_hint)
					session.advance(track,previous,current,route_hint)
					if session.shortcut_count > cuts: print("OWNER_CUT name=",document.name," side=",offset," point=",current," route=",i," depth=",session.shortcut_distance," bend_turn=",(track.route[i]-track.route[posmod(i-6,track.route.size())]).angle_to(track.route[(i+6)%track.route.size()]-track.route[i]))
			print("OWNER_LINE track=",document.name," offset=",offset," finished=",session.finished," cuts=",session.shortcut_count," offroad_samples=",offroad,"/",track.route.size()," progress=",session.route_distance," length=",track.route_length," finish_offset=",path[0]-track.finish_center," finish_forward=",track.finish_forward)
	quit()
