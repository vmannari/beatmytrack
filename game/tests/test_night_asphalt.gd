extends SceneTree
## Production Night road/bridge materials, canonical isolation and paired native views.
const OUT: String = "res://../docs/evidence/night-asphalt-2026-10-17/"
const BEFORE = preload("res://tests/fixtures/night_asphalt_variants_before.gd")
var checks: int = 0
var failures: int = 0
var output: String
var views: Dictionary = {}
var sampler_counts: Dictionary = {}

func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; print("FAIL: ",label)

func fixture(theme: String, bridge: bool = false) -> NativeTrack:
	var doc: Dictionary = TrackDocument.create_default() if not bridge else TrackDocument.create_blank()
	doc.theme = theme; doc["automatic_scenery"] = false
	if bridge:
		var point := Vector2(-32,-16); var heading: float = 0.0
		for kind: String in ["straight","bridge","straight","hairpin","straight","hairpin"]:
			var piece: Dictionary = RoadPieces.create(kind,point,heading,10)
			piece.length = 32.0 if kind == "bridge" else 64.0 if doc.pieces.size() == 4 else 16.0 if kind == "straight" else 0.0
			piece.radius = 16.0; doc.pieces.append(piece)
			var pose: Dictionary = RoadPieces.end_pose(piece); point = pose.position; heading = pose.heading
		var route: Dictionary = RoadPieces.route_from_pieces(doc)
		check(route.ok,"bridge fixture connects")
		doc = route.document
	if theme == "night_city":
		var points: Array[Vector2] = [Vector2(-29,-10),Vector2(-25,5),Vector2(-11,19),Vector2(3,22),Vector2(27,12)]
		if bridge: points = [Vector2(-20,-10),Vector2(0,-10),Vector2(20,-10),Vector2(35,2)]
		for p: Vector2 in points:
			doc.objects.append({"kind":"light","position":[p.x,p.y],"rotation":0.0,"scale":1.0})
		if bridge: doc.objects.append({"kind":"abandoned_warehouse","position":[0,3],"rotation":0.0,"scale":0.9})
	check(TrackDocument.validate(doc).is_empty(),theme+" fixture validates "+str(TrackDocument.validate(doc)))
	return TrackCompiler.compile(doc)

func materials(visual: Node3D) -> Array[ShaderMaterial]:
	var result: Array[ShaderMaterial] = []
	for node: Node in visual.find_children("*","MeshInstance3D",true,false):
		var material: ShaderMaterial = node.material_override as ShaderMaterial
		# Winter bridges retain the original dynamic shader without specialization.
		if material != null and not material.has_meta("surface_dynamic_material") and node.is_in_group("race_bridge_rendering") and material.shader.code.contains("bridge_road"):
			material.set_meta("surface_dynamic_material",material.duplicate())
		if material != null and material.has_meta("surface_dynamic_material") and material not in result: result.append(material)
	return result

func geometry(visual: Node3D) -> PackedByteArray:
	var data: Array = []
	for node: Node in visual.find_children("*","MeshInstance3D",true,false):
		data.append([node.name,node.transform,node.mesh.get_aabb(),node.mesh.get_surface_count()])
		for index: int in range(node.mesh.get_surface_count()): data.append(node.mesh.surface_get_arrays(index))
	return var_to_bytes(data)

func wear(visual: Node3D, value: bool) -> void:
	for material: ShaderMaterial in materials(visual):
		var dynamic: ShaderMaterial = material.get_meta("surface_dynamic_material")
		material.shader = dynamic.shader
		material.set_shader_parameter("industrial_asphalt",value)
		if value: SurfaceShaderVariants.specialize(material)
		else: BEFORE.specialize(material)

func capture(name: String) -> Image:
	for frame: int in range(8): await RenderingServer.frame_post_draw
	var picture: Image = root.get_texture().get_image()
	check(picture.save_png(output.path_join(name+".png")) == OK,name+" native capture")
	return picture

func paired_views(track: NativeTrack, points: Array[Vector2], tag: String) -> void:
	var game: Node = load("res://core/game.tscn").instantiate()
	game.initial_track = track; game.production_mode = true
	game.preference_records = LocalRecords.new(output.path_join("disposable-"+tag+".json"))
	root.add_child(game)
	game.set_process(false); game.set_physics_process(false)
	game.hitch_diagnostics.persist_enabled = false
	game.paused = true; game.process_mode = Node.PROCESS_MODE_DISABLED
	game._present_frame(0.0); game.race_cues.reset()
	var state: Array = game.sim.state.snapshot()
	var original: PackedByteArray = geometry(game.track_ground)
	var camera: Transform3D = game.camera.transform
	var size: float = game.camera.size
	if DisplayServer.get_name() != "headless":
		for index: int in range(points.size()):
			game.camera.follow(points[index],Vector2.ZERO,0.0,0.0,true)
			var pose: Transform3D = game.camera.transform
			var name: String = tag+"-"+str(index)
			wear(game.track_ground,false)
			var before: Image = await capture(name+"-before")
			wear(game.track_ground,true)
			var after: Image = await capture(name+"-after")
			check(before.get_data() != after.get_data(),name+" road wear is visible under actual lighting")
			check(game.camera.transform == pose,name+" comparison keeps the actual camera fixed")
			views[name] = {"focus":str(points[index]),"camera":str(pose),"size":game.camera.size}
		game.camera.transform = camera; game.camera.size = size
	check(game.sim.state.snapshot() == state,tag+" canonical vehicle stays exact")
	check(geometry(game.track_ground) == original,tag+" all road/terrain/prop geometry stays exact")
	check(game.camera.transform == camera and game.camera.size == size,tag+" gameplay framing restored exactly")
	game.free(); await process_frame

func run() -> void:
	output = ProjectSettings.globalize_path(OUT+RenderingServer.get_current_rendering_method()+"-"+DisplayServer.get_name())
	DirAccess.make_dir_recursive_absolute(output)
	NativeTrackVisual.ROAD_DISK_CACHE.directory = output.path_join("disposable-road-cache-v8")
	root.size = Vector2i(1600,900); root.content_scale_size = root.size
	var artwork: Image = NativeTrackVisual.NIGHT_ASPHALT_WEAR.get_image()
	check(artwork != null and artwork.get_size() == Vector2i(1024,1024),"one bounded shared data texture")
	check(artwork.has_mipmaps(),"wear is filtered with imported mipmaps")
	var samplers := RegEx.new(); samplers.compile("uniform sampler2D ")
	for theme: String in TrackTheme.IDS:
		var track: NativeTrack = fixture(theme,true)
		var canonical: PackedByteArray = var_to_bytes([track.content_hash,track.cells,track.route,track.metadata,track.creator_bridges])
		var visual := NativeTrackVisual.new(); root.add_child(visual)
		await visual.build(track,BridgePresentation.new(track))
		var found_bridge: bool = false
		var actual_max: int = 0
		var original_max: int = 0
		for material: ShaderMaterial in materials(visual):
			var baseline: ShaderMaterial = (material.get_meta("surface_dynamic_material") as ShaderMaterial).duplicate()
			BEFORE.specialize(baseline)
			var count: int = samplers.search_all(material.shader.code).size()
			var original_count: int = samplers.search_all(baseline.shader.code).size()
			actual_max = maxi(actual_max,count); original_max = maxi(original_max,original_count)
			check((material.get_shader_parameter("industrial_asphalt") == true) == (theme == "night_city"),theme+" isolates worn finish")
			check(count <= 8 if theme == "night_city" else count <= original_count,theme+" bounds new sampler cost against original production shader")
			if theme == "night_city":
				check(material.get_shader_parameter("night_asphalt_wear") == NativeTrackVisual.NIGHT_ASPHALT_WEAR,"ground/road/bridge share wear data")
			else:
				check(not material.shader.code.contains("uniform sampler2D night_asphalt_wear"),theme+" adds no sampler")
				check(not material.shader.get_shader_uniform_list().any(func(uniform: Dictionary) -> bool: return uniform.name == "night_asphalt_wear"),theme+" compiled material adds no sampler")
			if material.shader.code.contains("uniform bool winter_bridge_width_data") or baseline.shader.code.contains("uniform bool winter_bridge_width_data"): found_bridge = true
		check(found_bridge,theme+" tests actual bridge material")
		sampler_counts[theme] = {"before":original_max,"after":actual_max}
		check(canonical == var_to_bytes([track.content_hash,track.cells,track.route,track.metadata,track.creator_bridges]),theme+" canonical track stays exact")
		visual.free()
	var track: NativeTrack = fixture("night_city")
	await paired_views(track,[track.route[0],Vector2(-25,9),Vector2(-8,24)],"road")
	await paired_views(fixture("night_city",true),[Vector2(0,-16),Vector2(15,-16)],"bridge")
	var restored := NativeTrackVisual.new(); root.add_child(restored)
	await restored.build(track,BridgePresentation.new(track))
	check(materials(restored).all(func(m: ShaderMaterial) -> bool: return m.get_shader_parameter("industrial_asphalt") == true and m.get_shader_parameter("night_asphalt_wear") == NativeTrackVisual.NIGHT_ASPHALT_WEAR),"prepared world restores Night wear bindings")
	restored.free()
	var report := FileAccess.open(output.path_join("result.json"),FileAccess.WRITE)
	report.store_string(JSON.stringify({"checks":checks,"failures":failures,"samplers":sampler_counts,"views":views},"\t")); report.close()
	print("NIGHT_ASPHALT: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
