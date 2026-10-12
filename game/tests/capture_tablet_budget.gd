extends SceneTree
## Same-state 3000x2120 desktop visual review, not Android performance evidence.
const GAME = preload("res://core/game.gd")
const SCENE = preload("res://core/game.tscn")

func _initialize() -> void: call_deferred("run")

func run() -> void:
	root.size = Vector2i(3000,2120)
	root.content_scale_size = Vector2i(1280,720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	var output: String = ProjectSettings.globalize_path("res://../docs/evidence/tablet-performance-2026-10-08/desktop-review")
	DirAccess.make_dir_recursive_absolute(output)
	var document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/ajorata.json"))
	var track: NativeTrack = TrackCompiler.compile(document)
	NativeTrackVisual.ROAD_DISK_CACHE.directory = ProjectSettings.globalize_path("res://../build/tablet-performance-2026-10-08/visual-cache")
	var game: Node = SCENE.instantiate()
	game.set("initial_track",track)
	game.set("production_mode",true)
	root.add_child(game)
	game.set_physics_process(false)
	game.set("countdown_ticks",0)
	game.get("race_cues").reset()
	var camera: FollowCamera = game.get("camera")
	camera.speed_zoom_enabled = false
	var sim: VehicleSimulation = game.get("sim")
	sim.state.tick = 600
	sim.state.velocity = sim.state.forward()*18.0
	game.set("previous_position",sim.state.position)
	game.set("previous_heading",sim.state.heading)
	camera.follow(sim.state.position,sim.state.velocity,sim.state.heading,0.0,true)
	for index: int in range(8): game.call("_process",0.0)
	game.set_process(false)
	var candidate_scale: float = GAME.render_scale_for("pine",0.667,true,root.size)
	var scales: Array[float] = [0.667,candidate_scale,candidate_scale]
	var labels: Array[String] = ["previous","candidate","dynamic-shader"]
	var surface_probe: RefCounted = load("res://diagnostics/surface_material_probe.gd").new()
	surface_probe.call("collect",game.get("track_ground"))
	for index: int in range(scales.size()):
		surface_probe.call("apply","terrain_dynamic" if labels[index]=="dynamic-shader" else "baseline")
		root.scaling_3d_scale = scales[index]
		for frame: int in range(4): await process_frame
		await RenderingServer.frame_post_draw
		if not is_equal_approx(root.scaling_3d_scale,scales[index]):
			push_error("Review scale was not applied")
			quit(1)
			return
		var result: Error = root.get_texture().get_image().save_png(output.path_join(labels[index]+".png"))
		if result!=OK:
			push_error("Tablet review capture failed")
			quit(1)
			return
		print("TABLET_DESKTOP_CAPTURE ",labels[index]," scale=",root.scaling_3d_scale," output=",root.size)
	game.free()
	await process_frame
	quit()
