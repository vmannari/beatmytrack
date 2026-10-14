extends SceneTree
## Rendering/UV proof for the owner's road/bank and bridge-approach correction.
var checks: int = 0
var failures: int = 0

func _initialize() -> void: run.call_deferred()

func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures += 1; push_error(label)

func run() -> void:
	root.size = Vector2i(1600,900)
	var folder: String = "res://../docs/evidence/desert-winter-blend-2026-10-13/bridge/"
	var baseline: bool = false
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--folder="): folder = argument.trim_prefix("--folder=")
		if argument == "--before": baseline = true
	baseline = baseline or folder.contains("/before/")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	# Test rendered deck buffers, not only the shared phase function. Both
	# directions must agree with the actual ground road's signed transverse UV.
	var sampler := NativeTrackVisual.new()
	for heading: float in [0.0,180.0,37.0,217.0]:
		var span: Dictionary = RoadPieces.create("bridge",Vector2(9,-7),heading,12.0)
		span.length = 48.0
		var phase: Dictionary = {"desert_phase":17.3,"desert_sign":-1.0 if heading > 180.0 else 1.0,"desert_scale":0.97}
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		CreatorBridgeVisual.strip(tool,span,0.0,0.4,-6.0,6.0,0.025,Color.WHITE,phase)
		var mesh: ArrayMesh = tool.commit()
		var arrays: Array = mesh.surface_get_arrays(0)
		var points: PackedVector2Array = RoadPieces.samples(span)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		for i: int in range(vertices.size()):
			var p := Vector2(vertices[i].x,-vertices[i].z)
			var expected: Vector2 = preload("res://track/desert_road_union.gd").coordinates(sampler._sand_coordinates(p,points),phase)
			var difference: float = uvs[i].distance_to(expected)
			if not baseline: check(difference < 0.0001,"bridge deck UV agrees with ground at heading "+str(heading))
			else: print("BASELINE_DECK_UV_ERROR: ",heading," ",difference)
	sampler.free()
	var doc: Dictionary = TrackDocument.create_blank()
	doc.theme = "desert"
	doc.objects = []
	doc["automatic_scenery"] = false
	doc.pieces = []
	for entry: Array in [["straight",Vector2(-30,0),30.0],["bridge",Vector2.ZERO,48.0],["straight",Vector2(48,0),30.0]]:
		var piece: Dictionary = RoadPieces.create(entry[0],entry[1],0.0,12.0)
		piece.length = entry[2]
		doc.pieces.append(piece)
	var track: NativeTrack = TrackCompiler.compile(doc)
	check(track != null,"bridge approach fixture compiles")
	if track == null: quit(1); return
	var cells: PackedInt32Array = track.cells.duplicate()
	var hash_before: String = track.content_hash
	var visual := NativeTrackVisual.new()
	visual.cache_road_meshes = false
	root.add_child(visual)
	await visual.build(track,BridgePresentation.new(track))
	if not baseline:
		var deck: MeshInstance3D = visual.get_node("BridgeAsphalt")
		check(deck.material_override.shader.code.contains("diffuse_burley"),"desert deck and ground share diffuse lighting")
		var sampler_count := RegEx.new()
		sampler_count.compile("uniform sampler2D ")
		check(sampler_count.search_all(deck.material_override.shader.code).size() <= 8,"desert bridge stays within phone sampler budget")
		var arrays: Array = deck.mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var apron: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
		var mouths: int = 0
		var core: int = 0
		for i: int in range(vertices.size()):
			if absf(vertices[i].x) < 0.0001 or absf(vertices[i].x-48.0) < 0.0001:
				mouths += 1
				check(absf(apron[i].x-6.0) < 0.0001 and apron[i].y < 0.0001,"settled apron matches full ground blend at the bridge mouth")
			elif vertices[i].x >= 4.0 and vertices[i].x <= 44.0:
				core += 1
				check(apron[i].y > 0.9999,"bridge core remains compacted directional sand")
		check(mouths > 0 and core > 0,"deck exposes both mouths and the raised core")
	check(track.cells == cells and track.content_hash == hash_before,"cosmetic build preserves canonical surfaces/hash")
	if DisplayServer.get_name() != "headless":
		var environment := WorldEnvironment.new()
		environment.environment = Environment.new()
		var light := DirectionalLight3D.new()
		light.shadow_enabled = true
		TrackTheme.apply_lighting("desert",environment.environment,light)
		root.add_child(environment); root.add_child(light)
		var camera := Camera3D.new()
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = 22.0
		root.add_child(camera)
		camera.current = true
		for entry: Array in [["bank",Vector2(-16,3)],["entry",Vector2.ZERO],["exit",Vector2(48,0)]]:
			var focus: Vector3 = VisualGeometry.world(entry[1])
			camera.position = focus+Vector3(0,26,18)
			camera.look_at(focus)
			for frame: int in range(12): await RenderingServer.frame_post_draw
			var shot: Image = root.get_texture().get_image()
			check(shot.save_png(folder+str(entry[0])+".png") == OK,"approach/detail capture saved")
			if entry[0] != "bank":
				var maximum: float = 0.0
				for across: float in [-5.0,-3.0,-1.0,1.0,3.0,5.0]:
					var before := Vector2(float(entry[1].x)-0.12,across)
					var after := Vector2(float(entry[1].x)+0.12,across)
					var a: Vector2 = camera.unproject_position(VisualGeometry.world(before)+Vector3.UP*(CreatorBridges.height(track.creator_bridges[0],before)+0.025))
					var b: Vector2 = camera.unproject_position(VisualGeometry.world(after)+Vector3.UP*(CreatorBridges.height(track.creator_bridges[0],after)+0.025))
					var ca: Color = shot.get_pixel(roundi(a.x),roundi(a.y))
					var cb: Color = shot.get_pixel(roundi(b.x),roundi(b.y))
					maximum = maxf(maximum,Vector3(ca.r-cb.r,ca.g-cb.g,ca.b-cb.b).length())
					if not baseline: check(Vector3(ca.r-cb.r,ca.g-cb.g,ca.b-cb.b).length() < 0.035,"rendered bridge mouth has no hard pigment edge")
				print("DESERT_APPROACH_RGB_DELTA: ",entry[0]," ",maximum)
	visual.queue_free()
	await process_frame
	print("DESERT_BANK_BRIDGE_BLEND: ",checks," checks; ",failures," failures")
	quit(1 if failures else 0)
