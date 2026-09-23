extends SceneTree
var failures: int = 0
var checks: int = 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(description)
func run() -> void:
	root.size = Vector2i(1280,720)
	for track_id: String in ["track_acf29166cceaaa42","track_f7dc946b49ce9ea8"]:
		await exercise(track_id)
	print("SURFACE_PROFILE_TESTS: ",checks," checks, ",failures," failures")
	quit(0 if failures == 0 else 1)
func exercise(track_id: String) -> void:
	var document: Dictionary = TrackLibrary.new().load_document(track_id)
	check(not document.is_empty(),"saved Ajorata fixture available")
	if document.is_empty(): quit(1); return
	var game: Node = load("res://core/game.tscn").instantiate()
	game.initial_track = TrackCompiler.compile(document)
	root.add_child(game)
	game.paused = true
	for i: int in range(10): await process_frame
	var probe = load("res://diagnostics/surface_material_probe.gd").new()
	probe.collect(game.track_ground)
	check(probe.entries.size() > 2,"road and terrain material coverage")
	var meshes: Array = []
	for entry: Dictionary in probe.entries: meshes.append(entry.mesh.mesh)
	for mode: String in ["asphalt_previous","directional_off","road_flat","terrain_flat","baseline"]:
		probe.apply(mode)
		for i: int in range(8): await process_frame
		await RenderingServer.frame_post_draw
		for i: int in range(probe.entries.size()):
			var entry: Dictionary = probe.entries[i]
			check(entry.mesh.mesh == meshes[i],"unchanged mesh " + mode)
			var actual: ShaderMaterial = entry.mesh.material_override
			var parameter: String = "road_color" if entry.path.ends_with("creator_road.gdshader") else ("ground_color" if entry.path.ends_with("ground.gdshader") else "color_0")
			check(actual.get_shader_parameter(parameter) == entry.original.get_shader_parameter(parameter),"palette survives shader swap " + mode)
			for uniform: String in ["wet_road","icy_road","asphalt_surface","road_marking","edge_fringe","gravel","grass","overlay_mask","surface_low","surface_high","map_extent"]:
				check(actual.get_shader_parameter(uniform) == entry.original.get_shader_parameter(uniform),"uniform survives swap: " + uniform + " " + mode)
		root.get_texture().get_image().save_png("res://../build/surface-profile-"+track_id+"-"+mode+".png")
	probe.restore()
	for entry: Dictionary in probe.entries: check(entry.mesh.material_override == entry.original,"exact original material restored")
	game.free()
