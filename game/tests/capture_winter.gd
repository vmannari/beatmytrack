extends SceneTree

var checks: int = 0
var failures: int = 0

func check(ok: bool, label: String = "capture saved") -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	root.size = Vector2i(1280,720)
	var document: Dictionary = TrackDocument.create_blank()
	document.theme = "winter"
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
	document = JSON.parse_string(JSON.stringify(document))
	var errors: Array[String] = TrackDocument.validate(document)
	if not errors.is_empty():
		push_error(str(errors))
		quit(1)
		return
	var track: NativeTrack = TrackCompiler.compile(document)
	var cells: PackedInt32Array = track.cells.duplicate()
	var banks: String = str(track.snow_banks.triangles)
	var game: Node = load("res://core/game.tscn").instantiate()
	game.set("initial_track",track)
	game.set("production_mode",true)
	root.add_child(game)
	game.set_physics_process(false)
	game.set("paused",true)
	(game.get("race_cues") as Control).hide()
	for frame: int in range(8):
		game.call("_process",0.0)
		await RenderingServer.frame_post_draw
	check(track.cells == cells and str(track.snow_banks.triangles) == banks,"presentation preserves canonical surfaces and contacts")
	check(NativeTrackVisual.WINTER_SNOW.get_image().has_mipmaps(),"snow has mipmaps")
	check(NativeTrackVisual.WINTER_ICE.get_image().has_mipmaps(),"ice has mipmaps")
	var ground: Node = game.get("track_ground")
	check(ground.get_node_or_null("WinterSnowBanks") != null,"snowbanks rendered")
	check(int(ground.get_meta("winter_clump_count",0)) > 0,"broken deposits generated")
	for child: Node in ground.get_children():
		if child is MeshInstance3D and child.material_override is ShaderMaterial:
			var material: ShaderMaterial = child.material_override
			if material.shader == NativeTrackVisual.CREATOR_ROAD_SHADER:
				check(not material.get_shader_parameter("road_marking"),"winter omits edge stripes")
	var folder: String = "res://../docs/evidence/winter-surfaces"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	check(root.get_texture().get_image().save_png(folder+"/driving.png") == OK)
	game.set_process(false)
	var camera: Camera3D = game.get("camera")
	var focus: Vector3 = Vector3(40,0,0)
	camera.position = focus+Vector3(0,20,15)
	camera.look_at(focus)
	camera.size = 29.0
	for frame: int in range(3): await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(folder+"/bend-detail.png") == OK)
	print("WINTER_CAPTURE: surfaces/contacts preserved, mipmaps, banks/clumps, no edge stripes, two captures PASS; clumps=",ground.get_meta("winter_clump_count"))
	game.queue_free()
	await process_frame
	print("WINTER_CHECKS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
