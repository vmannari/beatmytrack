extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	root.size = Vector2i(1280,720)
	var folder: String = "res://../docs/evidence/worn-start-lines-2026-10-05"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	for biome: String in TrackTheme.IDS:
		var document: Dictionary = TrackDocument.create_blank()
		document.theme = biome
		var position := Vector2(-28,-18)
		var heading: float = 0.0
		for kind: String in ["straight","hairpin","straight","hairpin"]:
			var piece: Dictionary = RoadPieces.create(kind,position,heading)
			piece.length = 56.0 if kind == "straight" else 0.0
			piece.radius = 18.0
			document.pieces.append(piece)
			var pose: Dictionary = RoadPieces.end_pose(piece)
			position = pose.position
			heading = pose.heading
		document = RoadPieces.route_from_pieces(document).document
		document.start_line = {"position":[0.0,-18.0],"heading":0.0}
		if biome == "night_city":
			document.objects.append({"kind":"light","position":[0.0,-23.0],"rotation":0.0,"scale":1.0})
		document = JSON.parse_string(JSON.stringify(document))
		var track: NativeTrack = TrackCompiler.compile(document)
		var race: Node = load("res://core/game.tscn").instantiate()
		race.initial_track = track
		race.production_mode = true
		root.add_child(race)
		race.set_physics_process(false)
		race.paused = true
		race.race_cues.hide()
		race.set_process(false)
		var camera: Camera3D = race.camera
		var focus: Vector3 = VisualGeometry.world(track.finish_center)
		camera.position = focus+Vector3(0,18,12)
		camera.look_at(focus)
		camera.size = 15.0
		for frame: int in range(6): await RenderingServer.frame_post_draw
		var result: Error = root.get_texture().get_image().save_png(folder+"/"+biome+".png")
		if result != OK:
			quit(1)
			return
		print("CAPTURE: "+biome)
		race.queue_free()
		await process_frame
	quit(0)
