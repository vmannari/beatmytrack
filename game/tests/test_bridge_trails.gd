extends SceneTree
## Actual multimesh ruts, projected roof, and independent ground/deck layers.
var checks: int = 0
var failures: int = 0
var game: Node
var output: String = "res://../docs/evidence/dust-depth-2026-10-10/trails"
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ",label)
func capture() -> Image:
	for frame: int in range(5):
		game.paused = false
		game.hud.pause_menu.hide()
		await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()
func difference(a: Color, b: Color) -> float:
	return maxf(absf(a.r-b.r),maxf(absf(a.g-b.g),absf(a.b-b.b)))
func run() -> void:
	root.size = Vector2i(1280,900)
	root.msaa_3d = Viewport.MSAA_2X
	var track: NativeTrack = TrackCompiler.compile(JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/dust_cloud.json")))
	game = load("res://core/game.tscn").instantiate()
	game.initial_track = track
	game.production_mode = true
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game.countdown_ticks = 0
	game.race_cues.reset()
	game.sand_dust.visible = false
	game.camera.speed_zoom_enabled = false
	var span: Dictionary = track.creator_bridges[0]
	var start := Vector2(float(span.position[0]),float(span.position[1]))
	var angle: float = deg_to_rad(float(span.heading))
	var along := Vector2(cos(angle),sin(angle))
	var normal := Vector2(-along.y,along.x)
	var center: Vector2 = start+along*float(span.length)*0.5
	game.camera.follow(center,Vector2.ZERO,0.0,0.0,true)
	var trails: SkidTrails = game.trails
	trails._bind_bridges(track)
	trails.desert_sand = true
	trails.clear()
	var material: ShaderMaterial = trails.instances.mesh.surface_get_material(0)
	var shader := Shader.new()
	# Force unavailable hardware occlusion to stress the geometric protection.
	shader.code = material.shader.code.replace("depth_draw_opaque,","depth_draw_opaque, depth_test_disabled,")
	material.shader = shader
	var state_before: Array = game.sim.state.snapshot()
	var folder: String = ProjectSettings.globalize_path(output)
	DirAccess.make_dir_recursive_absolute(folder)
	var reference: Image = await capture()
	reference.save_png(folder.path_join("reference.png"))
	for across: float in [-4.0,-3.0,-2.0,-1.0,0.0,1.0,2.0,3.0,4.0]:
		for index: int in range(-20,90):
			var a: Vector2 = start+along*(index*0.4)+normal*across
			var b: Vector2 = a+along*0.4
			trails._mark(VisualGeometry.world(a)+Vector3.UP*0.028,VisualGeometry.world(b)+Vector3.UP*0.028,0.0,2,0.9)
	material.set_shader_parameter("dust_bridge_count",0)
	var unprotected: Image = await capture()
	unprotected.save_png(folder.path_join("depth-unavailable.png"))
	material.set_shader_parameter("dust_bridge_count",track.creator_bridges.size())
	var protected: Image = await capture()
	protected.save_png(folder.path_join("ground-protected.png"))
	var contaminated_control: int = 0
	var contaminated_guard: int = 0
	var roof_polygon := PackedVector2Array()
	for local: Vector2 in [Vector2(9,-3),Vector2(19,-3),Vector2(19,3),Vector2(9,3)]:
		roof_polygon.append(game.camera.unproject_position(VisualGeometry.world(start+along*local.x+normal*local.y)+Vector3.UP*3.525))
	var roof_pixels: int = 0
	for y: int in range(150,700):
		for x: int in range(150,1150):
			if not Geometry2D.is_point_in_polygon(Vector2(x,y),roof_polygon): continue
			roof_pixels += 1
			if difference(reference.get_pixel(x,y),unprotected.get_pixel(x,y))>2.0/255.0: contaminated_control += 1
			if difference(reference.get_pixel(x,y),protected.get_pixel(x,y))>1.0/255.0: contaminated_guard += 1
	check(roof_pixels>100,"opaque roof interior sampled across the actual narrow tread strips")
	print("BRIDGE_TRAIL_ROOF control=",contaminated_control," protected=",contaminated_guard," pixels=",roof_pixels)
	check(contaminated_control>0,"actual ground trail leakage reproduced without hardware depth")
	check(contaminated_guard==0,"ground marks cannot cover the roof even without hardware depth")
	trails.clear()
	for index: int in range(20,60):
		var a: Vector2 = start+along*(index*0.4)
		var b: Vector2 = a+along*0.4
		trails._mark(VisualGeometry.world(a)+Vector3.UP*(CreatorBridges.height(span,a)+0.028),VisualGeometry.world(b)+Vector3.UP*(CreatorBridges.height(span,b)+0.028),0.0,2,0.9)
	var deck: Image = await capture()
	deck.save_png(folder.path_join("deck-preserved.png"))
	var visible_deck: int = 0
	for index: int in range(25,46):
		var point: Vector2 = start+along*(index*0.4+0.2)
		var pixel: Vector2 = game.camera.unproject_position(VisualGeometry.world(point)+Vector3.UP*(CreatorBridges.height(span,point)+0.033))
		if difference(reference.get_pixel(roundi(pixel.x),roundi(pixel.y)),deck.get_pixel(roundi(pixel.x),roundi(pixel.y)))>0.02: visible_deck += 1
	check(visible_deck>5,"legitimate deck tyre marks remain visible")
	trails.clear()
	var state := VehicleState.new()
	state.position = start+along*1.0
	state.velocity = along*12.0
	state.heading = PI*0.5-angle
	trails.sample(state,DriveFrame.new(),game.bridge_presentation,track)
	state.position += along*0.4
	trails.sample(state,DriveFrame.new(),game.bridge_presentation,track)
	check(trails.cursor>0,"ordinary ground marks emitted")
	var previous_cursor: int = trails.cursor
	state.position += along*0.4
	state.track_elevated = true
	trails.sample(state,DriveFrame.new(),game.bridge_presentation,track)
	check(trails.cursor==previous_cursor,"no trail segment joins independent ground/deck layers")
	state.position += along*0.4
	trails.sample(state,DriveFrame.new(),game.bridge_presentation,track)
	check(trails.cursor>previous_cursor,"deck trail resumes on its own layer")
	check(game.sim.state.snapshot()==state_before,"presentation does not change canonical motion")
	print("BRIDGE_TRAIL_TESTS: ",checks," checks, ",failures," failures")
	game.free()
	quit(1 if failures else 0)
