extends SceneTree
## Desktop review artifact. Uses shipping thumbnail and gameplay builders.
func _initialize() -> void: call_deferred("run")

func run() -> void:
	var audit := SurfaceTool.new()
	audit.begin(Mesh.PRIMITIVE_TRIANGLES)
	var kit := NativeTrackVisual.new()
	CreatorPropVisual._crown(audit,kit,Vector3.ZERO,Vector3.ONE,0,Color.WHITE)
	audit.generate_normals()
	var arrays: Array = audit.commit().surface_get_arrays(0)
	if arrays[Mesh.ARRAY_NORMAL][6].y < 0.5:
		push_error("Canopy top normals must face outwards for the contour pass")
		kit.free()
		quit(1)
		return
	kit.free()
	root.size = Vector2i(1560,1080)
	root.content_scale_size = root.size
	var backdrop := ColorRect.new()
	backdrop.color = Color("131f25")
	backdrop.size = Vector2(1560,1080)
	root.add_child(backdrop)
	var index: int = 0
	for asset: Array in CreatorCatalog.ASSETS:
		for kind: String in asset[3]:
			var button: Button = ObjectThumbnail.make(kind,CreatorCatalog.label(kind),false,func() -> void: pass)
			backdrop.add_child(button)
			button.position = Vector2(20+(index%7)*220,20+(index/7)*174)
			button.scale = Vector2(2,2)
			index += 1
	for frame: int in range(5): await RenderingServer.frame_post_draw
	var error: Error = root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../build/object-models.png"))
	if error != OK: push_error(error_string(error)); quit(1); return
	backdrop.queue_free()
	await process_frame
	var document: Dictionary = TrackDocument.create_blank()
	var position := Vector2(-28,-18)
	var heading: float = 0
	for kind: String in ["straight","hairpin","straight","hairpin"]:
		var piece: Dictionary = RoadPieces.create(kind,position,heading)
		piece.length = 56.0 if kind == "straight" else 0.0
		piece.radius = 18.0
		document.pieces.append(piece)
		var pose: Dictionary = RoadPieces.end_pose(piece)
		position = pose.position; heading = pose.heading
	document["start_line"] = {"position":[0,-18],"heading":0}
	document = RoadPieces.route_from_pieces(document).document
	document.name = "Object model review"
	document.objects = []
	var kinds: Array[String] = ["tree","broadleaf","rock","boulder","slate","barrier"]
	for i: int in range(kinds.size()):
		document.objects.append({"kind":kinds[i],"position":[-12+(i%6)*6,-8+(i/6)*7],"rotation":0})
	document.objects.append({"kind":"cliff","position":[4,3],"rotation":0,"scale":2.0})
	var track: NativeTrack = TrackCompiler.compile(document)
	if track == null:
		push_error(str(TrackDocument.validate(document)))
		quit(1)
		return
	var cells: PackedInt32Array = track.cells.duplicate()
	var game: Node = load("res://core/game.tscn").instantiate()
	game.set("initial_track",track)
	game.set("production_mode",true)
	root.add_child(game)
	game.set_physics_process(false)
	game.set("paused",true)
	for frame: int in range(5):
		game.call("_process",0.1)
		await RenderingServer.frame_post_draw
	error = root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../build/object-models-gameplay.png"))
	if track.cells != cells: push_error("Rendering mutated collision cells"); quit(1); return
	print("OBJECT_MODEL_CAPTURE: %d variants; gameplay cells preserved; %s" % [index,error_string(error)])
	game.queue_free()
	await process_frame
	# Separate model-review view keeps the full cliff and reference car visible.
	var stage := Node3D.new()
	root.add_child(stage)
	var cliff_track := NativeTrack.new()
	cliff_track.metadata = {"creator_document":{"objects":[
		{"kind":"cliff","position":[0,4],"rotation":0,"scale":2.0},
		{"kind":"boulder","position":[-7,-4],"rotation":20},
		{"kind":"rock","position":[-3,-4],"rotation":0},
		{"kind":"slate","position":[6,-4],"rotation":0}]}}
	var cliff_kit := NativeTrackVisual.new()
	stage.add_child(cliff_kit)
	cliff_kit._build_placed_objects(cliff_track)
	var car := CarVisual.new()
	stage.add_child(car)
	car.position = Vector3(1,0,7)
	VisualGeometry.box(stage,Vector3(60,0.1,60),Vector3(0,-0.1,0),VisualGeometry.material(Color("566044")))
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-48,-28,0)
	light.light_color = Color("fff1d8")
	light.shadow_enabled = true
	light.shadow_bias = 0.15
	light.shadow_normal_bias = 2.0
	stage.add_child(light)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("202e35")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("bac8ce")
	environment.environment.ambient_light_energy = 0.35
	stage.add_child(environment)
	var camera := Camera3D.new()
	stage.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 22.0
	camera.look_at_from_position(Vector3(19,17,27),Vector3(0,2,0))
	camera.current = true
	for frame: int in range(4): await RenderingServer.frame_post_draw
	error = root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../build/object-models-cliff.png"))
	print("CLIFF_MODEL_CAPTURE: ",error_string(error))
	stage.queue_free()
	await process_frame
	quit(0 if error == OK else 1)
