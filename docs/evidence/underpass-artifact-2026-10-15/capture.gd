extends SceneTree

func _initialize() -> void: run.call_deferred()

func settle() -> void:
	for i: int in range(20): await process_frame
	await RenderingServer.frame_post_draw

func run() -> void:
	root.size = Vector2i(1280,780)
	var doc: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://../build/underpass-artifact-2026-10-15/Underpass.json"))
	var track: NativeTrack = TrackCompiler.compile(doc)
	var folder: String = ProjectSettings.globalize_path("res://../docs/evidence/underpass-artifact-2026-10-15/"+RenderingServer.get_current_rendering_method()+"/before")
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): folder = ProjectSettings.globalize_path(argument.trim_prefix("--output="))
	DirAccess.make_dir_recursive_absolute(folder)
	var game: Node = preload("res://core/game.tscn").instantiate()
	game.initial_track = track
	root.add_child(game)
	game.set_physics_process(false)
	game.set_process(false)
	if "--baseline" in OS.get_cmdline_user_args():
		# Run the saved, original road builder against the saved original mouth
		# helper. All scene, shader, camera, lighting and car code stays shared.
		var saved: String = FileAccess.get_file_as_string("res://../docs/evidence/underpass-artifact-2026-10-15/before/native_track_visual.gd").replace("\r\n","\n")
		var method: String = "func _build_creator_roads"+saved.get_slice("func _build_creator_roads",1).get_slice("\nfunc ",0)
		var baseline := GDScript.new()
		baseline.source_code = "extends NativeTrackVisual\nconst BASE_HEIGHT = preload(\"res://../docs/evidence/underpass-artifact-2026-10-15/before/road_surface_height.gd\")\n"+method.replace("ROAD_HEIGHT","BASE_HEIGHT")
		assert(baseline.reload() == OK)
		var old: NativeTrackVisual = baseline.new()
		old.cache_road_meshes = false
		old.persist_road_meshes = false
		old.cache_race_world = false
		var bridge := BridgePresentation.new(track)
		bridge.road_surface = preload("res://../docs/evidence/underpass-artifact-2026-10-15/before/road_surface_height.gd").new(track)
		var parent: Node = game.track_ground.get_parent()
		game.track_ground.free()
		parent.add_child(old)
		await old.build(track,bridge)
		game.track_ground = old
	var camera: Camera3D = root.get_viewport().get_camera_3d()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 120
	camera.position = Vector3(0,100,-8)
	camera.rotation_degrees = Vector3(-90,0,0)
	await settle()
	root.get_texture().get_image().save_png(folder+"/map.png")
	var poses: Array[Vector3] = [Vector3(13,-37,300),Vector3(13,-37,320),Vector3(9,-34,280),Vector3(3,-24,270)]
	for i: int in range(poses.size()):
		var pose: Vector3 = poses[i]
		game.sim.state.position = Vector2(pose.x,pose.y)
		game.previous_position = game.sim.state.position
		game.sim.state.heading = deg_to_rad(pose.z)
		game.previous_heading = game.sim.state.heading
		game.sim.state.track_elevated = false
		game._process(0.0)
		camera.follow(game.sim.state.position,Vector2.ZERO,game.sim.state.heading,0,true)
		await settle()
		root.get_texture().get_image().save_png(folder+"/pose-%d.png"%i)
	game.biome_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	game.biome_environment.ambient_light_energy = 1.0
	await settle()
	root.get_texture().get_image().save_png(folder+"/ambient.png")
	for child: Node in game.track_ground.find_children("*","MeshInstance3D",true,false):
		if not child.material_override is ShaderMaterial: continue
		if child.material_override.get_shader_parameter("asphalt_surface") != true or child.material_override.get_shader_parameter("edge_fringe") == true: continue
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color("343943")
		mat.roughness = 1.0
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		child.material_override = mat
	await settle()
	root.get_texture().get_image().save_png(folder+"/standard.png")
	game.free()
	await process_frame
	quit()
