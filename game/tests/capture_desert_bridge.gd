extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	root.size = Vector2i(1440,900)
	var doc: Dictionary = TrackDocument.create_blank()
	doc.theme = "desert"
	var points: Array[Vector2] = [Vector2(-48,0),Vector2(-30,0),Vector2(30,0),Vector2(50,26),Vector2(0,42),Vector2(0,-42),Vector2(-50,-26)]
	for i: int in range(points.size()):
		var a: Vector2 = points[i]
		var b: Vector2 = points[(i+1)%points.size()]
		var piece: Dictionary = RoadPieces.create("bridge" if i == 1 else "straight",a,fposmod(rad_to_deg((b-a).angle()),360),14)
		piece.length = a.distance_to(b)
		doc.pieces.append(piece)
	var result: Dictionary = RoadPieces.route_from_pieces(doc)
	if not result.ok:
		push_error(str(result))
		quit(1)
		return
	var track: NativeTrack = TrackCompiler.compile(result.document)
	for span: Dictionary in track.creator_bridges:
		for sample: int in range(1001):
			var u: float = float(span.length)*sample/1000.0
			var point: Vector2 = Vector2(span.position[0],span.position[1])+Vector2(u,0).rotated(deg_to_rad(float(span.heading)))
			var height: float = CreatorBridges.height(span,point)
			if height >= CreatorBridges.UNDERPASS_CLEARANCE:
				assert(height+DesertBridgeVisual.underside(span,u) >= CreatorBridges.UNDERPASS_CLEARANCE-0.0001)
	var cells: PackedInt32Array = track.cells.duplicate()
	var game: Node = load("res://core/game.tscn").instantiate()
	game.set("initial_track",track)
	game.set("production_mode",true)
	root.add_child(game)
	game.set_physics_process(false)
	game.set("paused",true)
	game.set("countdown_ticks",0)
	game.get("race_cues").hide()
	var sim: VehicleSimulation = game.get("sim")
	sim.reset(Vector2.ZERO,PI*0.5)
	sim.state.track_elevated = true
	game.set("previous_position",Vector2.ZERO)
	var camera: FollowCamera = game.get("camera")
	camera.follow(Vector2.ZERO,Vector2.ZERO,PI*0.5,0.0,true)
	var folder: String = "res://../docs/evidence/desert-bridges/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	for frame: int in range(8):
		game.call("_process",0.016)
		await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(folder+"gameplay.png") == OK)
	# Wider inspection view is evidence only, never a gameplay camera change.
	game.set_process(false)
	camera.size = 48.0
	camera.position = Vector3(7,37,34)
	camera.look_at(Vector3(0,1.5,0))
	for frame: int in range(3): await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(folder+"overview.png") == OK)
	assert(cells == track.cells)
	print("DESERT_BRIDGE_CAPTURE: two views saved; collision cells preserved")
	game.queue_free()
	await process_frame
	quit()
