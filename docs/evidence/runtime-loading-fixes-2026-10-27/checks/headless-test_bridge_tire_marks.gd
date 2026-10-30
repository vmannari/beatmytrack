extends SceneTree
## Sample the real four-wheel renderer on the visible road, ramps and deck.
const OUT: String = "res://../build/runtime-loading-fixes-2026-10-27/outputs/headless-test_bridge_tire_marks/"
var checks: int = 0
var failures: int = 0
var baseline: bool = false
var report: Dictionary = {}
var game: Node

func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; print("FAIL: ",label)

func circuit(theme: String) -> NativeTrack:
	var doc: Dictionary = TrackDocument.create_blank(); doc.theme = theme
	var point := Vector2(-32,-16); var heading: float = 0.0
	for kind: String in ["straight","bridge","straight","hairpin","straight","hairpin"]:
		var piece: Dictionary = RoadPieces.create(kind,point,heading,10)
		piece.length = 32.0 if kind == "bridge" else 64.0 if doc.pieces.size() == 4 else 16.0 if kind == "straight" else 0.0
		piece.radius = 16.0; doc.pieces.append(piece)
		var pose: Dictionary = RoadPieces.end_pose(piece); point = pose.position; heading = pose.heading
	var result: Dictionary = RoadPieces.route_from_pieces(doc)
	assert(result.ok)
	return TrackCompiler.compile(result.document)

func capture() -> Image:
	for frame: int in range(4):
		game.paused = false; game.hud.pause_menu.hide()
		await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()

func different(a: Color, b: Color) -> bool:
	return maxf(absf(a.r-b.r),maxf(absf(a.g-b.g),absf(a.b-b.b))) > 2.0/255.0

func deposit(trails: SkidTrails, track: NativeTrack, bridge: BridgePresentation, reverse: bool = false, elevated: bool = true) -> void:
	trails.active = false
	var state := VehicleState.new(); var frame := DriveFrame.sample(0,0,1)
	state.heading = -PI*0.5 if reverse else PI*0.5
	state.velocity = Vector2(-16,0) if reverse else Vector2(16,0)
	state.track_elevated = elevated
	for index: int in range(141):
		state.position = Vector2(22.0-index*0.32 if reverse else -22.0+index*0.32,-16)
		var snapshot: Array = state.snapshot()
		trails.sample(state,frame,bridge,track)
		assert(state.snapshot() == snapshot)

func run() -> void:
	var task_config:=ConfigFile.new()
	task_config.set_value("backend","url","")
	assert(task_config.save("user://backend.cfg")==OK)
	OS.unset_environment("BMT_API_URL")

	baseline = "--before" in OS.get_cmdline_user_args()
	root.size = Vector2i(1280,900); root.msaa_3d = Viewport.MSAA_2X
	var graphical: bool = DisplayServer.get_name() != "headless"
	var renderer: String = RenderingServer.get_current_rendering_method() if graphical else "headless"
	var folder: String = OUT+("before/" if baseline else "final/")+renderer+"/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	for theme: String in ["desert","pine","winter","storm","night_city"]:
		var track: NativeTrack = circuit(theme)
		var bridge := BridgePresentation.new(track)
		var trails: SkidTrails
		if graphical:
			game = load("res://core/game.tscn").instantiate()
			game.initial_track = track; game.production_mode = true
			root.add_child(game); game.set_process(false); game.set_physics_process(false)
			game.process_mode = Node.PROCESS_MODE_DISABLED
			game.countdown_ticks = 0; game.race_cues.reset(); game.hud.hide()
			game.car.hide(); game.sand_dust.hide(); game.camera.speed_zoom_enabled = false
			if game.weather_layer != null: game.weather_layer.hide()
			game.camera.follow(Vector2(0,-16),Vector2.ZERO,0.0,0.0,true)
			trails = game.trails; bridge = game.bridge_presentation
			if theme == "night_city":
				# Diagnostic illumination exposes the very dark native Night materials
				# to the same strict pixel test; no game lighting is changed.
				var inspection_light := DirectionalLight3D.new()
				inspection_light.rotation_degrees = Vector3(-58,-35,0)
				inspection_light.light_energy = 1.0; game.add_child(inspection_light)
		else:
			trails = SkidTrails.new(); root.add_child(trails)
		var original: Array = [track.cells.duplicate(),track.deck_cells.duplicate(),track.route.duplicate()]
		var reference: Image
		if graphical:
			for warmup: int in range(30): await process_frame
			reference = await capture(); reference.save_png(folder+theme+"-reference.png")
		deposit(trails,track,bridge)
		check(trails.cursor == 400,theme+" emits the complete sampled four-wheel braking path")
		check(trails.instances.instance_count == 16384,theme+" retains the fixed trail budget")
		var minimum: float = INF; var maximum: float = -INF
		for i: int in range(trails.cursor):
			var pose: Transform3D = trails.mark_transforms[i]
			for point: Vector3 in [pose.origin-pose.basis.z*0.5,pose.origin+pose.basis.z*0.5]:
				var expected: float = bridge.visual_height_at(Vector2(point.x,-point.z),0,1)+0.028
				minimum = minf(minimum,point.y-expected); maximum = maxf(maximum,point.y-expected)
		check(maxf(absf(minimum),absf(maximum)) < 0.00001,theme+" every deposited endpoint follows the visible support")
		var material: ShaderMaterial = trails.instances.mesh.surface_get_material(0)
		var metrics: Dictionary = {"segments":trails.cursor,"endpoint_error":[minimum,maximum]}
		if graphical:
			var protected: Image = await capture(); protected.save_png(folder+theme+"-protected.png")
			material.set_shader_parameter("dust_bridge_count",0)
			var control: Image = await capture(); control.save_png(folder+theme+"-control.png")
			for region: String in ["entry","deck","exit"]:
				var bounds: Vector2 = Vector2(-13,-9) if region == "entry" else Vector2(-5,5) if region == "deck" else Vector2(9,13)
				var polygon := PackedVector2Array()
				for p: Vector2 in [Vector2(bounds.x,-18),Vector2(bounds.y,-18),Vector2(bounds.y,-14),Vector2(bounds.x,-14)]:
					polygon.append(game.camera.unproject_position(VisualGeometry.world(p)+Vector3.UP*(bridge.visual_height_at(p,0,1)+0.028)))
				var visible: int = 0; var available: int = 0
				for y: int in range(root.size.y):
					for x: int in range(root.size.x):
						if not Geometry2D.is_point_in_polygon(Vector2(x,y),polygon): continue
						if different(reference.get_pixel(x,y),control.get_pixel(x,y)):
							available += 1
							if different(reference.get_pixel(x,y),protected.get_pixel(x,y)): visible += 1
				metrics[region] = {"visible":visible,"control":available}
				check(available > 40,theme+" "+region+" has visible actual tire marks in the control")
				if not baseline: check(visible >= available*0.95,theme+" "+region+" preserves at least 95% of actual mark pixels with clipping")
			material.set_shader_parameter("dust_bridge_count",track.creator_bridges.size())
		trails.clear(); deposit(trails,track,bridge,true)
		check(trails.cursor == 400,theme+" reverse travel emits the same four-wheel trail path")
		if graphical and not baseline:
			# Stress the mask independently of hardware depth, using real lower-layer contacts.
			trails.clear(); deposit(trails,track,bridge,false,false)
			var shader := Shader.new()
			shader.code = material.shader.code.replace("depth_draw_opaque,","depth_draw_opaque, depth_test_disabled,")
			material.shader = shader
			var ground_protected: Image = await capture()
			material.set_shader_parameter("dust_bridge_count",0)
			var ground_control: Image = await capture()
			var polygon := PackedVector2Array()
			for p: Vector2 in [Vector2(-5,-18),Vector2(5,-18),Vector2(5,-14),Vector2(-5,-14)]:
				polygon.append(game.camera.unproject_position(VisualGeometry.world(p)+Vector3.UP*(bridge.visual_height_at(p,0,1)+0.025)))
			var leaked: int = 0; var control_pixels: int = 0
			for y: int in range(root.size.y):
				for x: int in range(root.size.x):
					if not Geometry2D.is_point_in_polygon(Vector2(x,y),polygon): continue
					if different(reference.get_pixel(x,y),ground_control.get_pixel(x,y)): control_pixels += 1
					if different(reference.get_pixel(x,y),ground_protected.get_pixel(x,y)): leaked += 1
			check(control_pixels > 40,theme+" depth-disabled control reproduces ground-mark leakage")
			check(leaked == 0,theme+" masks every underpass mark from the visible deck without hardware depth")
			metrics["underpass"] = {"control":control_pixels,"leaked":leaked}
			ground_protected.save_png(folder+theme+"-underpass-protected.png")
			material.set_shader_parameter("dust_bridge_count",track.creator_bridges.size())
		trails.clear()
		var state := VehicleState.new(); state.position = Vector2(0,-16); state.velocity = Vector2(12,0); state.heading = PI*0.5
		trails.sample(state,DriveFrame.sample(0,0,1),bridge,track)
		state.position.x += 0.4; trails.sample(state,DriveFrame.sample(0,0,1),bridge,track)
		var cursor: int = trails.cursor; state.track_elevated = true; state.position.x += 0.4
		trails.sample(state,DriveFrame.sample(0,0,1),bridge,track)
		check(trails.cursor == cursor,theme+" cannot connect ground and upper-layer marks")
		check(original == [track.cells,track.deck_cells,track.route],theme+" presentation preserves canonical track data")
		report[theme] = metrics
		if graphical: game.free()
		else: trails.free()
		await process_frame
	var file := FileAccess.open(folder+"results.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"biomes":report},"\t")); file.close()
	print("BRIDGE_TIRE_MARKS: ",checks," checks, ",failures," failures; ",JSON.stringify(report))
	quit(1 if failures else 0)
