extends SceneTree
## Read-only graphical review of an existing creator document. Never saves records.

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var path: String = ""
	var output: String = ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--style-document="): path = argument.trim_prefix("--style-document=")
		if argument.begins_with("--style-output="): output = argument.trim_prefix("--style-output=")
	if not FileAccess.file_exists(path) or not output.is_absolute_path():
		push_error("CaptureStyle requires -StyleDocument pointing to an existing creator JSON.")
		quit(1)
		return
	var document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var track: NativeTrack = TrackCompiler.compile(document)
	if track == null:
		quit(1)
		return
	root.size = Vector2i(1494,1009)
	var original_cells: PackedInt32Array = track.cells.duplicate()
	var game: Node = load("res://core/game.tscn").instantiate()
	game.set("initial_track",track)
	game.set("production_mode",true)
	root.add_child(game)
	game.set_physics_process(false)
	game.set("paused",true)
	_audit_road_normals(game)
	for frame: int in range(4):
		game.call("_process",0.1)
		await RenderingServer.frame_post_draw
	if track.cells != original_cells:
		push_error("Presentation changed native collision cells")
		quit(1)
		return
	print("STYLE_CHECK: native cells preserved")
	var error: Error = root.get_texture().get_image().save_png(output)
	print("STYLE_CAPTURE: ",error_string(error))
	if error == OK:
		var sim: VehicleSimulation = game.get("sim")
		var camera: FollowCamera = game.get("camera")
		for sample: int in range(12):
			var point: Vector2 = track.route[sample*track.route.size()/12]
			sim.reset(point,track.spawn_heading)
			game.set("previous_position",point)
			camera.follow(point,Vector2.ZERO,track.spawn_heading,0.0,true)
			for frame: int in range(3):
				game.call("_process",0.1)
				await RenderingServer.frame_post_draw
			var view_error: Error = root.get_texture().get_image().save_png(output.get_basename()+"-view-%d.png" % sample)
			if view_error != OK: error = view_error
		print("STYLE_ROUTE_VIEWS: ",error_string(error))
	# Separate model-review camera; never changes the gameplay camera contract.
	game.queue_free()
	await process_frame
	var stage := Node3D.new()
	root.add_child(stage)
	var car := CarVisual.new()
	stage.add_child(car)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-48,-28,0)
	light.light_color = Color("fff1d8")
	light.shadow_enabled = true
	stage.add_child(light)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("202e35")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("bac8ce")
	environment.environment.ambient_light_energy = 0.35
	stage.add_child(environment)
	VisualGeometry.box(stage,Vector3(40,0.1,40),Vector3(0,-0.10,0),VisualGeometry.material(Color("37444a")))
	var model_camera := Camera3D.new()
	stage.add_child(model_camera)
	model_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	model_camera.size = 5.0
	model_camera.current = true
	var angles: Array[Vector3] = [Vector3(6,3.5,-7),Vector3(6,3.5,7),Vector3(7,1.8,0)]
	for index: int in range(angles.size()):
		model_camera.position = angles[index]
		model_camera.look_at(Vector3(0,0.6,0))
		for frame: int in range(3): await RenderingServer.frame_post_draw
		var model_error: Error = root.get_texture().get_image().save_png(output.get_basename()+"-car-%d.png" % index)
		if model_error != OK: error = model_error
	print("STYLE_MODEL_VIEWS: ",error_string(error))
	quit(0 if error == OK else 1)


func _audit_road_normals(node: Node) -> void:
	if node is MeshInstance3D and node.material_override is ShaderMaterial:
		var material: ShaderMaterial = node.material_override
		if material.shader.resource_path == "res://track/creator_road.gdshader":
			var arrays: Array = node.mesh.surface_get_arrays(0)
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var down: int = 0
			for normal: Vector3 in normals:
				if normal.y < 0.99: down += 1
			print("ROAD_NORMALS gravel=",material.get_shader_parameter("gravel")," grass=",material.get_shader_parameter("grass")," bad=",down," total=",normals.size())
	for child: Node in node.get_children(): _audit_road_normals(child)
