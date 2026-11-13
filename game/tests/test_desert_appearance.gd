extends SceneTree
## Render the complete Desert world through synchronous, sliced and warm paths.
var checks: int = 0
var failures: int = 0
var folder: String = "res://../docs/evidence/desert-appearance-fix-2026-11-07/"
var rows: Array = []

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; print("FAIL: ", label)

static func document() -> Dictionary:
	var doc: Dictionary = TrackDocument.create_blank()
	doc.theme = "desert"; doc["automatic_scenery"] = false
	var point := Vector2(-28, -18)
	var heading: float = 0.0
	for kind: String in ["straight", "hairpin", "straight", "hairpin"]:
		var piece: Dictionary = RoadPieces.create(kind, point, heading)
		piece.length = 56.0 if kind == "straight" else 0.0; piece.radius = 18.0
		doc.pieces.append(piece)
		var pose: Dictionary = RoadPieces.end_pose(piece)
		point = pose.position; heading = pose.heading
	doc.objects = []
	for row: Array in [["egypt_pyramid",-38,0],["egypt_pyramid",38,0],["egypt_obelisk",0,0],["egypt_column",15,3],["egypt_wall",-15,3],["rock",0,26],["slate",8,26],["cliff",-8,26],["chevron",-20,-24],["braking_board",0,-24],["flag",20,-24],["gantry",0,18]]:
		doc.objects.append({"kind":row[0],"position":[row[1],row[2]],"rotation":0.0,"scale":1.0})
	var routed: Dictionary = RoadPieces.route_from_pieces(doc)
	return routed.document

func circuit() -> NativeTrack:
	var doc: Dictionary = document()
	check(TrackDocument.validate(doc).is_empty(),"valid authored Desert circuit")
	return TrackCompiler.compile(doc)

static func pixels(a: Image, b: Image) -> int:
	var first: PackedByteArray = a.get_data(); var second: PackedByteArray = b.get_data()
	var changed: int = 0
	for at: int in range(0,first.size(),4):
		if maxi(absi(int(first[at])-int(second[at])),maxi(absi(int(first[at+1])-int(second[at+1])),absi(int(first[at+2])-int(second[at+2])))) > 2: changed += 1
	return changed

func draw() -> Image:
	for frame: int in range(3):
		await process_frame
		RenderingServer.force_draw(false)
	return root.get_texture().get_image()

func run() -> void:
	var stage: String = "baseline"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--stage="): stage = argument.trim_prefix("--stage=")
	folder += stage+"/"+RenderingServer.get_current_rendering_method()+"/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	root.size = Vector2i(1280,720)
	NativeTrackVisual.ROAD_DISK_CACHE.directory = ""
	NativeTrackVisual.PREPARED_WORLDS.entries.clear()
	var track: NativeTrack = circuit()
	var canonical: PackedByteArray = var_to_bytes([track.cells,track.deck_cells,track.route,track.metadata,track.content_hash])
	var world := Node3D.new(); root.add_child(world)
	var environment := WorldEnvironment.new(); environment.environment = Environment.new(); world.add_child(environment)
	var light := DirectionalLight3D.new(); light.shadow_enabled = true; world.add_child(light)
	TrackTheme.apply_lighting("desert",environment.environment,light)
	var camera := Camera3D.new(); camera.projection = Camera3D.PROJECTION_ORTHOGONAL; world.add_child(camera)
	camera.current = true
	for pass_index: int in range(3):
		var visual := NativeTrackVisual.new()
		visual.cache_race_world = pass_index > 0
		visual.persist_road_meshes = false; visual.cache_road_meshes = false
		visual.preserve_relief_surfaces = true
		world.add_child(visual)
		await visual.build(track,BridgePresentation.new(track),pass_index > 0)
		check(visual.world_built,"world completes pass "+str(pass_index))
		var props: Array[MeshInstance3D] = []
		var roads: Array[ShaderMaterial] = []
		for child: Node in visual.get_children():
			if child is MeshInstance3D:
				if child.name.begins_with("EgyptianStonework"): props.append(child)
				var material: ShaderMaterial = child.material_override as ShaderMaterial
				if material != null and material.get_shader_parameter("asphalt_surface") == true and material.get_shader_parameter("edge_fringe") != true:
					roads.append(material)
		check(not props.is_empty(),"Egyptian scenery retained pass "+str(pass_index))
		check(not roads.is_empty(),"textured road material retained pass "+str(pass_index))
		for material: ShaderMaterial in roads:
			check(material.get_shader_parameter("desert_road_albedo") == NativeTrackVisual.DESERT_ROAD_ALBEDO,"approved road artwork bound pass "+str(pass_index))
		if DisplayServer.get_name() != "headless":
			for view: String in ["overview","road","pyramid"]:
				var target := Vector3.ZERO if view == "overview" else Vector3(0,0,18) if view == "road" else Vector3(-38,0,0)
				camera.size = 95.0 if view == "overview" else 24.0
				camera.position = target+Vector3(0,36,27); camera.look_at(target)
				var before: Image = await draw()
				before.save_png(folder+"pass%d-%s.png" % [pass_index,view])
				if view == "pyramid":
					for prop: MeshInstance3D in props: prop.hide()
					var after: Image = await draw()
					var count: int = pixels(before,after)
					check(count > 1000,"Egyptian props visibly drawn pass "+str(pass_index))
					rows.append({"pass":pass_index,"prop_pixels":count})
					for prop: MeshInstance3D in props: prop.show()
				if view == "road":
					var flat_image := Image.create(4,4,false,Image.FORMAT_RGBA8); flat_image.fill(Color(0.5,0.5,0.5))
					var flat := ImageTexture.create_from_image(flat_image)
					for material: ShaderMaterial in roads: material.set_shader_parameter("desert_road_albedo",flat)
					var after: Image = await draw()
					var count: int = pixels(before,after)
					check(count > 1000,"road artwork contributes visible pixels pass "+str(pass_index))
					rows.append({"pass":pass_index,"road_texture_pixels":count})
					for material: ShaderMaterial in roads: material.set_shader_parameter("desert_road_albedo",NativeTrackVisual.DESERT_ROAD_ALBEDO)
		visual.free()
		await process_frame
	check(canonical == var_to_bytes([track.cells,track.deck_cells,track.route,track.metadata,track.content_hash]),"presentation preserves canonical track data")
	world.free()
	FileAccess.open(folder+"report.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"rows":rows},"\t"))
	print("DESERT_APPEARANCE: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
