extends SceneTree
## Repeatable desert art evidence; fixture motion never advances race physics.

var checks: int = 0
var failures: int = 0
var folder: String

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var stage: String = OS.get_environment("BMT_DESERT_CAPTURE_STAGE")
	if stage.is_empty(): stage = "after"
	folder = "res://../docs/evidence/desert-hierarchy-2026-10-03/"+stage.validate_filename()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	var document: Dictionary = TrackDocument.create_blank()
	document.theme = "desert"
	var position := Vector2(-42,-12)
	var heading: float = 0.0
	for kind: String in ["straight","hairpin","straight","hairpin"]:
		var piece: Dictionary = RoadPieces.create(kind,position,heading)
		piece.length = 44.0 if kind == "straight" else 0.0
		piece.radius = 12.0
		piece.width = 10.0
		document.pieces.append(piece)
		var pose: Dictionary = RoadPieces.end_pose(piece)
		position = pose.position
		heading = pose.heading
	document = RoadPieces.route_from_pieces(document).document
	document.start_line = {"position":[-20.0,-12.0],"heading":0.0}
	document = JSON.parse_string(JSON.stringify(document))
	check(TrackDocument.validate(document).is_empty(),"desert corner fixture validates")
	await capture(TrackCompiler.compile(document),"hairpin",true)
	var saved: Dictionary = TrackLibrary.new().load_document("track_3e26605a8a90165e")
	if not saved.is_empty():
		await capture(TrackCompiler.compile(saved),"saved-circuit",false)
	else:
		print("Saved local desert circuit unavailable; authored fixture captured.")
	await capture_object_details()
	await check_mark_isolation(TrackCompiler.compile(document))
	print("DESERT_STYLE: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func capture(track: NativeTrack, name: String, hairpin: bool) -> void:
	root.size = Vector2i(1280,720)
	var cells: PackedInt32Array = track.cells.duplicate()
	var decks: PackedInt32Array = track.deck_cells.duplicate()
	var route: PackedVector2Array = track.route.duplicate()
	var race: Node = load("res://core/game.tscn").instantiate()
	race.set("initial_track",track)
	race.set("production_mode",true)
	root.add_child(race)
	race.set_physics_process(false)
	race.set("countdown_ticks",0)
	(race.get("race_cues") as Control).hide()
	var state: VehicleState = race.get("sim").state
	var index: int = int(track.route.size()*0.35)
	if hairpin:
		index = track.nearest_route(Vector2(12.8,-5.2))
	state.position = track.route[index]
	var direction: Vector2 = (track.route[(index+1)%track.route.size()]-state.position).normalized()
	state.heading = atan2(direction.x,direction.y)
	race.set("previous_position",state.position)
	race.set("previous_heading",state.heading)
	var camera: FollowCamera = race.get("camera")
	camera.set_mode("overhead")
	camera.speed_zoom_enabled = false
	camera.follow(state.position,Vector2.ZERO,state.heading,0.0,true)
	var trails: SkidTrails = race.get("trails")
	var frame := DriveFrame.sample(0.5,0.8,0.0)
	# Recorded geometry samples on the route; no fabricated/extrapolated HUD motion.
	for step: int in range(160):
		var mark_index: int = (index-40+step/4+track.route.size())%track.route.size()
		var mark := VehicleState.new()
		mark.position = track.route[mark_index].lerp(track.route[(mark_index+1)%track.route.size()],float(step%4)/4.0)
		var tangent: Vector2 = (track.route[(mark_index+1)%track.route.size()]-track.route[mark_index]).normalized()
		mark.heading = atan2(tangent.x,tangent.y)
		mark.velocity = tangent*14.0
		trails.sample(mark,frame,race.get("bridge_presentation"),track)
	for tick: int in range(12):
		if race.get("paused"): race.call("toggle_pause")
		await process_frame
	await RenderingServer.frame_post_draw
	await save(name+"-driving.png")
	root.size = Vector2i(960,540)
	for tick: int in range(4): await RenderingServer.frame_post_draw
	await save(name+"-compact.png")
	root.size = Vector2i(1280,720)
	if hairpin:
		race.set_process(false)
		var focus := Vector3(10,0,0)
		camera.position = focus+Vector3(0,30,22)
		camera.look_at(focus)
		camera.size = 35.0
		for tick: int in range(4): await RenderingServer.frame_post_draw
		await save(name+"-detail.png")
	var ground: NativeTrackVisual = race.get("track_ground")
	var cover: MeshInstance3D = ground.get_node_or_null("DesertLowCover")
	if cover != null:
		var arrays: Array = cover.mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var clear: bool = true
		for vertex: Vector3 in vertices:
			var point := Vector2(vertex.x,-vertex.z)
			clear = clear and track.cell_at(point) in [1,7] and not track.has_overhead_bridge(point,false)
		check(clear,"all desert scenery vertices clear canonical roads and bridge decks")
		check(ground.get_meta("desert_roadside_stones",0) > 0,"rough shoulders include actual pebble geometry")
		check(ground.get_meta("desert_large_stones",0) > 0 and ground.get_meta("desert_scrub",0) > 0,"desert scenery includes larger stones and sparse dry vegetation")
		print("DESERT_STYLE_COVER ",name," triangles=",vertices.size()/3," stones=",ground.get_meta("desert_stones",0)," roadside=",ground.get_meta("desert_roadside_stones",0)," larger=",ground.get_meta("desert_large_stones",0)," scrub=",ground.get_meta("desert_scrub",0))
	print("DESERT_STYLE_GEOMETRY ",name," clods=",ground.get_meta("desert_clod_count",0)," scenery=",ground.scenic_count)
	check(track.cells == cells and track.deck_cells == decks and track.route == route,"art leaves canonical road, deck and route data intact")
	race.queue_free()
	await process_frame

func save(name: String) -> void:
	check(root.get_texture().get_image().save_png(folder+"/"+name) == OK,"captured "+name)

func capture_object_details() -> void:
	# Separate model review, using the shipping builders, material and daylight.
	root.size = Vector2i(1280,720)
	var stage := Node3D.new()
	root.add_child(stage)
	var kit := NativeTrackVisual.new()
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	kit._desert_rock(tool,Vector3(-1.5,0,0),Vector3(0.48,0.27,0.31),0.3,938173,Color("b5b0a3").srgb_to_linear())
	kit._desert_rock(tool,Vector3(-0.2,0,0),Vector3(0.36,0.20,0.25),1.8,735811,Color("bfb9ab").srgb_to_linear())
	tool.generate_normals()
	var stone_mesh: ArrayMesh = tool.commit()
	var arrays: Array = stone_mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var normal_sum: float = 0.0
	var top_count: int = 0
	for i: int in range(vertices.size()):
		if vertices[i].y > 0.17:
			normal_sum += normals[i].y
			top_count += 1
	check(top_count > 0 and normal_sum/float(top_count) > 0.25,"weathered stone upper faces receive daylight with outward normals")
	print("DESERT_ROCK_TOP_NORMAL ",normal_sum/float(top_count))
	var material := VisualGeometry.material(Color.WHITE)
	material.vertex_color_use_as_albedo = true
	material.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var stones := MeshInstance3D.new()
	stones.mesh = stone_mesh
	stones.material_override = material
	stage.add_child(stones)
	var scrub_tool := SurfaceTool.new()
	scrub_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	kit._desert_scrub(scrub_tool,Vector3(1.2,0,0),1.36,1.2,286381)
	scrub_tool.generate_normals()
	var scrub := MeshInstance3D.new()
	scrub.mesh = scrub_tool.commit()
	scrub.material_override = material
	stage.add_child(scrub)
	var light := DirectionalLight3D.new()
	light.shadow_enabled = true
	light.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	light.directional_shadow_max_distance = 12.0
	stage.add_child(light)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	TrackTheme.apply_lighting("desert",environment.environment,light)
	stage.add_child(environment)
	var floor_material := VisualGeometry.material(Color("c5aa80").srgb_to_linear())
	floor_material.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT
	VisualGeometry.box(stage,Vector3(20,0.04,20),Vector3(0,-0.035,0),floor_material)
	var camera := Camera3D.new()
	stage.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 3.6
	camera.position = Vector3(0,4.5,3.3)
	camera.look_at(Vector3.ZERO)
	camera.current = true
	for tick: int in range(5): await RenderingServer.frame_post_draw
	await save("objects-model-detail.png")
	kit.free()
	stage.queue_free()
	await process_frame

func check_mark_isolation(track: NativeTrack) -> void:
	var trails := SkidTrails.new()
	root.add_child(trails)
	var state := VehicleState.new()
	state.position = track.spawn
	state.velocity = Vector2(0,12)
	trails.sample(state,DriveFrame.new(),null,track)
	trails.clear()
	trails._mark(Vector3.ZERO,Vector3(0,0,1),0.0,2,1.0)
	var desert: Color = trails.mark_colors[0]
	check(desert.r > 0.58 and desert.g > 0.44 and desert.b > 0.26 and desert.a <= 0.52,"desert grooves retain light dusty sand pigment and restrained opacity")
	trails.sample(state,DriveFrame.new())
	trails.clear()
	trails._mark(Vector3.ZERO,Vector3(0,0,1),0.0,2,1.0)
	check(trails.mark_colors[0].is_equal_approx(Color(0.68,0.53,0.32,0.52)),"leaving desert restores the existing dirt mark palette")
	var environment := Environment.new()
	var light := DirectionalLight3D.new()
	TrackTheme.apply_lighting("desert",environment,light)
	check(environment.ambient_light_color.r > environment.ambient_light_color.b,"desert open shade is warm")
	TrackTheme.apply_lighting("winter",environment,light)
	check(environment.ambient_light_color == Color("bac8ce") and light.light_color == Color("e7f2ff") and is_equal_approx(light.light_energy,1.0),"leaving desert restores the winter light rig")
	light.free()
	trails.queue_free()
	await process_frame
