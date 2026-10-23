extends SceneTree
## Native material integration and paired views using the production camera.
var checks: int = 0
var failures: int = 0
var output: String
var metrics: Dictionary = {}

func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; print("FAIL: ",label)
func frames() -> void:
	for i: int in range(8):
		if DisplayServer.get_name() == "headless": await process_frame
		else: await RenderingServer.frame_post_draw

func fixture(theme: String = "night_city") -> NativeTrack:
	var doc: Dictionary = TrackDocument.create_default()
	doc.theme = theme
	doc["automatic_scenery"] = false
	if theme == "night_city":
		for p: Vector2 in [Vector2(-29,-10),Vector2(-25,5),Vector2(-11,19),Vector2(3,22),Vector2(27,12)]:
			doc.objects.append({"kind":"light","position":[p.x,p.y],"rotation":0.0,"scale":1.0})
	check(TrackDocument.validate(doc).is_empty(),theme+" fixture validates: "+str(TrackDocument.validate(doc)))
	return TrackCompiler.compile(doc)

func materials(visual: Node3D) -> Array[ShaderMaterial]:
	var result: Array[ShaderMaterial] = []
	for node: Node in visual.find_children("*","MeshInstance3D",true,false):
		var material: ShaderMaterial = node.material_override as ShaderMaterial
		if material != null and material.has_meta("surface_dynamic_material") and material not in result: result.append(material)
	return result

func enabled(visual: Node3D, value: bool) -> void:
	for material: ShaderMaterial in materials(visual):
		var dynamic: ShaderMaterial = material.get_meta("surface_dynamic_material")
		material.shader = dynamic.shader
		material.set_shader_parameter("industrial_ground",value)
		SurfaceShaderVariants.specialize(material)

func capture(name: String) -> Image:
	await frames()
	var image: Image = root.get_texture().get_image()
	check(image.save_png(output.path_join(name+".png")) == OK,name+" native capture")
	return image

func run() -> void:
	output = ProjectSettings.globalize_path("res://../docs/evidence/night-terrain-2026-10-16/"+RenderingServer.get_current_rendering_method()+"-"+DisplayServer.get_name())
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1600,900)
	root.content_scale_size = root.size
	var artwork: Image = NativeTrackVisual.NIGHT_GROUND_ALBEDO.get_image()
	check(artwork != null and artwork.get_width() <= 1024 and artwork.get_height() <= 1024,"bounded imported ground artwork")
	check(artwork.has_mipmaps(),"minification has prefiltered mipmaps")
	var count_samplers := RegEx.new(); count_samplers.compile("uniform sampler2D ")
	for theme: String in TrackTheme.IDS:
		var track: NativeTrack = fixture(theme)
		var original: PackedByteArray = var_to_bytes([track.content_hash,track.cells,track.route,track.metadata])
		var visual := NativeTrackVisual.new(); root.add_child(visual)
		await visual.build(track,BridgePresentation.new(track))
		var surface_count: int = 0
		for material: ShaderMaterial in materials(visual):
			var industrial: bool = material.get_shader_parameter("industrial_ground") == true
			check(industrial == (theme == "night_city"),theme+" isolates industrial terrain")
			check(count_samplers.search_all(material.shader.code).size() <= 8,theme+" retains GLES sampler allowance")
			if theme == "night_city":
				check(material.get_shader_parameter("night_ground_albedo") == NativeTrackVisual.NIGHT_GROUND_ALBEDO,"Night shares the imported artwork")
			else:
				check(not material.shader.code.contains("uniform sampler2D night_ground_albedo"),theme+" has no added texture unit")
			surface_count += 1
		check(surface_count > 0,theme+" checks actual production surfaces")
		check(original == var_to_bytes([track.content_hash,track.cells,track.route,track.metadata]),theme+" canonical track stays exact")
		visual.free()
	var track: NativeTrack = fixture()
	var game: Node = load("res://core/game.tscn").instantiate()
	game.initial_track = track; game.production_mode = true
	game.preference_records = LocalRecords.new(output.path_join("disposable.json"))
	root.add_child(game)
	game.set_process(false); game.set_physics_process(false)
	game.hitch_diagnostics.persist_enabled = false
	game.paused = true
	game.process_mode = Node.PROCESS_MODE_DISABLED
	var state: Array = game.sim.state.snapshot()
	game._present_frame(0.0)
	game.race_cues.reset()
	var pose: Transform3D = game.camera.transform
	var size: float = game.camera.size
	if DisplayServer.get_name() != "headless":
		# Both views share the actual road/car/lights/camera; only material mode changes.
		for point: Vector2 in [game.sim.state.position,Vector2(-25,9),Vector2(-8,24)]:
			game.camera.follow(point,Vector2.ZERO,0.0,0.0,true)
			var tag: String = "view-"+str(metrics.size())
			enabled(game.track_ground,false)
			var before: Image = await capture(tag+"-before")
			enabled(game.track_ground,true)
			var after: Image = await capture(tag+"-after")
			check(before.get_data() != after.get_data(),tag+" terrain changes native pixels")
			metrics[tag] = {"focus":str(point),"camera":str(game.camera.transform),"size":game.camera.size}
		game.camera.transform = pose; game.camera.size = size
	check(game.sim.state.snapshot() == state,"material comparison preserves canonical vehicle state")
	check(game.camera.transform == pose and game.camera.size == size,"original gameplay camera restored exactly")
	game.free()
	await process_frame
	# A new race restored from the retained prepared world must keep the artwork.
	var restored := NativeTrackVisual.new(); root.add_child(restored)
	await restored.build(track,BridgePresentation.new(track))
	check(materials(restored).all(func(m: ShaderMaterial) -> bool: return m.get_shader_parameter("industrial_ground") == true and m.get_shader_parameter("night_ground_albedo") == NativeTrackVisual.NIGHT_GROUND_ALBEDO),"prepared world retains Night artwork bindings")
	restored.free()
	var report := FileAccess.open(output.path_join("result.json"),FileAccess.WRITE)
	report.store_string(JSON.stringify({"checks":checks,"failures":failures,"views":metrics},"\t")); report.close()
	print("NIGHT_TERRAIN: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
