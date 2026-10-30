extends SceneTree
## Actual race-camera visibility check for the kart contact shadow.
var checks := 0
var failures := 0

func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: " + label)
func frame_image() -> Image:
	for i: int in range(4): await RenderingServer.frame_post_draw
	return root.get_texture().get_image()
func run() -> void:
	root.size = Vector2i(1280,720)
	root.content_scale_size = root.size
	var game: Node = load("res://core/game.tscn").instantiate()
	game.initial_track = TrackCompiler.compile(TrackDocument.create_default())
	game.vehicle_id = "kart"
	game.production_mode = true
	root.add_child(game)
	while not game.preparation_complete: await process_frame
	game.set_physics_process(false)
	game.countdown_ticks = 0
	game.race_cues.hide()
	game.call("_process",0.016)
	game.set_process(false)
	var car: CarVisual = game.car
	var shadow: MeshInstance3D = game.contact_shadow
	var material := shadow.material_override as ShaderMaterial
	check(shadow.visible, "actual race shows kart contact shadow")
	check(game.biome_light.shadow_enabled, "directional shadow enabled on default setting")
	var normal := await frame_image()
	var same_state := await frame_image()
	shadow.hide()
	var unshaded := await frame_image()
	var visible_pixels := 0
	var unstable_pixels := 0
	# In this fixed default track and production camera, the car is within this
	# rectangle. Count changes outside it so car self-shading cannot pass the test.
	for y: int in range(300,410):
		for x: int in range(590,690):
			if x >= 621 and x <= 660 and y >= 330 and y <= 382: continue
			var a := normal.get_pixel(x,y)
			var b := unshaded.get_pixel(x,y)
			if b.get_luminance()-a.get_luminance() > 3.0/255.0: visible_pixels += 1
			var repeat := same_state.get_pixel(x,y)
			if maxf(absf(a.r-repeat.r),maxf(absf(a.g-repeat.g),absf(a.b-repeat.b))) > 3.0/255.0: unstable_pixels += 1
	print("KART_SHADOW_GROUND_PIXELS: ", visible_pixels, " SAME_STATE_UNSTABLE: ", unstable_pixels)
	check(unstable_pixels == 0, "same-state ground frames stable")
	check(visible_pixels >= 40, "contact visibly darkens ground outside the kart")
	var output := OS.get_environment("BMT_KART_SHADOW_CAPTURE")
	if not output.is_empty():
		DirAccess.make_dir_recursive_absolute(output)
		check(normal.save_png(output.path_join("kart-shadow-on.png")) == OK,"save shadow-on capture")
		check(unshaded.save_png(output.path_join("kart-shadow-off.png")) == OK,"save shadow-off capture")
	var test_state := VehicleState.new()
	ContactShading.present_car(shadow,car,test_state,Vector2.ZERO,0,null,null)
	var ground_strength := float(material.get_shader_parameter("strength"))
	var ground_size := shadow.scale
	check(is_equal_approx(ground_strength,0.55), "kart ground contact uses stronger normal strength")
	check(is_equal_approx(ground_size.x,2.0*HandlingConfig.BODY_SCALE*1.3) and is_equal_approx(ground_size.z,3.2*HandlingConfig.BODY_SCALE*1.3), "kart ground contact uses enlarged footprint")
	test_state.jump_height = 2.0
	ContactShading.present_car(shadow,car,test_state,Vector2.ZERO,0,null,null)
	check(float(material.get_shader_parameter("strength")) < ground_strength*0.25,"kart airborne shadow fades")
	check(shadow.scale.x > ground_size.x and shadow.scale.z > ground_size.z,"kart airborne shadow spreads")
	car.vehicle_id = "compact"
	test_state.jump_height = 0.0
	ContactShading.present_car(shadow,car,test_state,Vector2.ZERO,0,null,null)
	check(is_equal_approx(float(material.get_shader_parameter("strength")),0.34),"compact contact strength remains unchanged")
	check(is_equal_approx(shadow.scale.x,2.35*HandlingConfig.BODY_SCALE) and is_equal_approx(shadow.scale.z,4.8*HandlingConfig.BODY_SCALE),"compact footprint remains unchanged")
	car.vehicle_id = "kart"
	var track: NativeTrack = game.initial_track
	var original_theme: String = str(track.metadata.get("theme","pine"))
	track.metadata.theme = "winter"
	ContactShading.present_car(shadow,car,test_state,game.sim.state.position,0,track,game.bridge_presentation)
	check(is_equal_approx(float(material.get_shader_parameter("strength")),0.64),"winter kart contact retains stronger contrast")
	track.metadata.theme = original_theme
	track = null
	game.queue_free()
	await process_frame
	print("KART_CONTACT_VISIBILITY: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)


