extends "res://tests/test_star_spline_laps.gd"

func run() -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://../build/catalog-road-review-2026-10-16/manifest.json"))
	for entry: Dictionary in manifest.entries:
		var doc: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(entry.path))
		var track: NativeTrack = TrackCompiler.compile(doc)
		var session := TrackSession.new(120,1); session._configure(track)
		var layer: bool = session._finish_elevated
		var path: PackedVector2Array = track.route.duplicate(); path.append(path[0]); path.append(path[1])
		for i: int in range(path.size()-1):
			var steps: int = maxi(1,ceili(path[i].distance_to(path[i+1])/0.25))
			for step: int in range(steps):
				var a: Vector2 = path[i].lerp(path[i+1],float(step)/steps)
				var b: Vector2 = path[i].lerp(path[i+1],float(step+1)/steps)
				var previous_layer: int = int(layer)
				var hint: int = track.nearest_route(b)
				layer = CreatorBridges.layer_at(track.creator_bridges,b,layer) if not track.creator_bridges.is_empty() else track.elevated_at(b,hint)
				session.advance(track,a,b,hint,layer,previous_layer)
		print("CATALOG_GATE_ROUTE name=",entry.name," finished=",session.finished," next=",session.next_checkpoint," gates=",session.checkpoint_count())
		check(session.finished,"cached catalog centreline completes ordered gates: "+str(entry.name))
	print("CATALOG_GATE_ROUTES: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
