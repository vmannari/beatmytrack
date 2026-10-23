extends SceneTree
## The shipping fort in the actual Winter world, with preserved pre-correction art.
const BASE: String = "res://../docs/evidence/snow-castle-fit-2026-10-19"
var checks: int = 0
var failures: int = 0
var old: GDScript

func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; print("FAIL: ",label)

func source_mesh(kind: String, original: bool, center: Vector3 = Vector3.ZERO) -> ArrayMesh:
	var tool := SurfaceTool.new(); tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	if original: old.append(tool,kind,center,1.0,0.0)
	else: PropWinterCraft.append(tool,kind,center,1.0,0.0)
	return tool.commit()

func components(mesh: Mesh) -> int:
	var vertices: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var lookup: Dictionary = {}; var parents: Array[int] = []
	for i: int in range(0,vertices.size(),3):
		var ids: Array[int] = []
		for j: int in range(3):
			var key := Vector3i((vertices[i+j]*10000.0).round())
			if not lookup.has(key): lookup[key] = parents.size(); parents.append(parents.size())
			ids.append(lookup[key])
		for j: int in range(1,3):
			var a: int = ids[0]; var b: int = ids[j]
			while parents[a] != a: a = parents[a]
			while parents[b] != b: b = parents[b]
			parents[b] = a
	var roots: Dictionary = {}
	for i: int in range(parents.size()):
		var at: int = i
		while parents[at] != at: at = parents[at]
		roots[at] = true
	return roots.size()

func run() -> void:
	old = GDScript.new()
	old.source_code = FileAccess.get_file_as_string(BASE+"/before/prop_winter_craft.gd.txt").replace("\r\n","\n").replace("class_name PropWinterCraft\n","")
	check(old.reload() == OK,"saved pre-correction model source loads")
	for kind: String in ["igloo","snowman","snow_lantern","ice_lantern"]:
		check(source_mesh(kind,false).surface_get_arrays(0) == source_mesh(kind,true).surface_get_arrays(0),kind+" keeps every original mesh channel")
	var before: ArrayMesh = source_mesh("snow_castle",true)
	var original_candidate: bool = "--original" in OS.get_cmdline_user_args()
	var after: ArrayMesh = source_mesh("snow_castle",original_candidate)
	var parts: int = components(after)
	check(parts <= 16,"castle uses continuous sculpted masses instead of separate masonry blocks")
	check(after.surface_get_array_len(0)/3 < 10000,"castle retains the original triangle ceiling")
	check(after.get_aabb().position.x >= -3.7 and after.get_aabb().end.x <= 3.7 and after.get_aabb().position.z >= -3.2 and after.get_aabb().end.z <= 3.2,"fort retains the authored placement footprint")
	var colors: PackedColorArray = after.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	var world_snow: bool = true
	for color: Color in colors: world_snow = world_snow and color.a > 0.5 and color.a < 0.7
	check(world_snow,"all castle surfaces use the surrounding world's snow finish")
	check(PropWinterCraft.material().get_shader_parameter("castle_snow") == NativeTrackVisual.WINTER_SNOW,"castle reuses the exact existing mipmapped world texture")
	print("SNOW_CASTLE_FIT_METRICS: ",JSON.stringify({"original_components":components(before),"sculpted_components":parts,"triangles":after.surface_get_array_len(0)/3,"bounds":str(after.get_aabb())}))
	if DisplayServer.get_name() != "headless":
		await studio()
		await world()
		await other_craft_pixels()
	print("SNOW_CASTLE_FIT: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func frames(count: int = 5) -> void:
	for i: int in range(count): await process_frame
	await RenderingServer.frame_post_draw

func folder() -> String:
	var result: String = ProjectSettings.globalize_path(BASE+"/"+RenderingServer.get_current_rendering_method())
	DirAccess.make_dir_recursive_absolute(result)
	return result

func old_material() -> ShaderMaterial:
	var material := ShaderMaterial.new(); var shader := Shader.new()
	shader.code = FileAccess.get_file_as_string(BASE+"/before/winter_craft_snow.gdshader.txt")
	material.shader = shader
	return material

func studio() -> void:
	var host := Button.new(); root.add_child(host)
	var view: SubViewport = ObjectThumbnail._render_preview(host,"snow_castle","winter")
	view.size = Vector2i(1400,1000); view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var camera: Camera3D = view.get_camera_3d(); camera.size = 8.4
	var visual: NativeTrackVisual
	for child: Node in view.get_children():
		if child is NativeTrackVisual: visual = child
	var node: MeshInstance3D = visual.get_node("WinterCraft")
	var refined: Mesh = node.mesh
	var material: Material = node.material_override
	node.mesh = source_mesh("snow_castle",true,Vector3(0,0.014,0)); node.material_override = old_material()
	await frames(); check(view.get_texture().get_image().save_png(folder()+"/studio-before.png") == OK,"original studio view saved")
	node.mesh = refined; node.material_override = material
	await frames(); check(view.get_texture().get_image().save_png(folder()+"/studio-after.png") == OK,"sculpted studio view saved")
	camera.look_at_from_position(Vector3(0,4.2,-12),Vector3(0,1.2,0))
	await frames(); check(view.get_texture().get_image().save_png(folder()+"/gate-after.png") == OK,"sculpted arch and jambs saved")
	host.queue_free(); await process_frame

func world() -> void:
	var doc: Dictionary = TrackDocument.create_blank(); doc.theme = "winter"; doc.automatic_scenery = false
	var position := Vector2(-28,-18); var heading: float = 0.0
	for kind: String in ["straight","hairpin","straight","hairpin"]:
		var piece: Dictionary = RoadPieces.create(kind,position,heading)
		piece.length = 56.0 if kind == "straight" else 0.0; piece.radius = 18.0
		doc.pieces.append(piece)
		var pose: Dictionary = RoadPieces.end_pose(piece); position = pose.position; heading = pose.heading
	doc = RoadPieces.route_from_pieces(doc).document
	doc.start_line = {"position":[0.0,-18.0],"heading":0.0}
	doc.objects = [{"kind":"snow_castle","position":[35,0],"rotation":0},{"kind":"ice_lantern","position":[34,-7],"rotation":0},{"kind":"tree","position":[24,11],"rotation":0},{"kind":"rock","position":[55,10],"rotation":0}]
	doc = JSON.parse_string(JSON.stringify(doc))
	check(TrackDocument.validate(doc).is_empty(),"actual Winter race fixture validates: "+str(TrackDocument.validate(doc)))
	var track: NativeTrack = TrackCompiler.compile(doc)
	check(track != null,"actual Winter race fixture compiles")
	if track == null: return
	var cells: PackedInt32Array = track.cells.duplicate()
	var content: String = track.content_hash
	var game: Node = load("res://core/game.tscn").instantiate()
	game.set("initial_track",track); game.set("production_mode",true); game.set("vehicle_id","pickup")
	root.add_child(game); game.set_physics_process(false); game.set("paused",true)
	game.get("race_cues").hide()
	game.get("sim").reset(Vector2(45.5,-1),0.3)
	game.call("_process",0.0); game.set_process(false)
	game.get("hud").get("message_label").hide()
	var snapshot: Array = game.get("sim").state.snapshot()
	var camera: Camera3D = game.get("camera"); camera.size = 26.0
	camera.look_at_from_position(Vector3(48,24,20),Vector3(37,0,0))
	root.size = Vector2i(1600,900); root.content_scale_size = root.size
	var node: MeshInstance3D = game.get("track_ground").get_node("WinterCraft")
	var refined: Mesh = node.mesh; var material: Material = node.material_override
	for original: bool in [true,false]:
		node.mesh = source_mesh("snow_castle",true,Vector3(35,0.014,0)) if original else refined
		node.material_override = old_material() if original else material
		await frames(8)
		check(root.get_texture().get_image().save_png(folder()+"/race-"+("before" if original else "after")+".png") == OK,"actual Winter race context saved")
	check(track.cells == cells and track.content_hash == content,"visual correction preserves the compiled track and canonical contacts")
	check(game.get("sim").state.snapshot() == snapshot,"visual review never advances or changes the canonical car")
	check(node.get_surface_override_material_count() <= 1 and refined.get_surface_count() == 1,"fort stays in the original single Winter craft surface")
	game.queue_free(); await frames()

func other_craft_pixels() -> void:
	for kind: String in ["igloo","snowman","snow_lantern"]:
		var host := Button.new(); root.add_child(host)
		var view: SubViewport = ObjectThumbnail._render_preview(host,kind,"winter")
		view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		var visual: NativeTrackVisual
		for child: Node in view.get_children():
			if child is NativeTrackVisual: visual = child
		var node: MeshInstance3D
		if kind == "igloo": node = visual.get_node("WinterCraft")
		else: node = visual.light_instances[0].get_node("DamagePhase0")
		var current: Material = node.material_override
		node.material_override = old_material()
		await frames(); var original: PackedByteArray = view.get_texture().get_image().get_data()
		node.material_override = current
		await frames()
		var rendered: Image = view.get_texture().get_image()
		var pixels: PackedByteArray = rendered.get_data()
		if pixels != original:
			var changed: int = 0; var maximum: int = 0
			for i: int in range(pixels.size()):
				if pixels[i] != original[i]: changed += 1; maximum = maxi(maximum,absi(int(pixels[i])-int(original[i])))
			print("CRAFT_PIXEL_DELTA: ",kind," bytes=",changed," max=",maximum)
			rendered.save_png(folder()+"/"+kind+"-pixel-after.png")
			rendered.set_data(rendered.get_width(),rendered.get_height(),false,rendered.get_format(),original)
			rendered.save_png(folder()+"/"+kind+"-pixel-before.png")
		check(pixels == original,kind+" exact original shader pixels")
		for repeat: int in range(2):
			node.material_override = old_material()
			await frames()
			check(view.get_texture().get_image().get_data() == original,kind+" repeated original-shader control "+str(repeat))
			node.material_override = current
			await frames()
			check(view.get_texture().get_image().get_data() == original,kind+" repeated unchanged craft pixels "+str(repeat))
		host.queue_free(); await process_frame
