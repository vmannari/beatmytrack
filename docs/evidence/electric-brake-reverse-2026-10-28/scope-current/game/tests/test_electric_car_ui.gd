extends SceneTree
## Actual Garage selection, save/reload, runtime race and native review images.
var checks: int = 0
var failures: int = 0
const OUTPUT: String = "res://../docs/evidence/electric-car-2026-10-25/native"
var output: String = OUTPUT

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: "+label)

func settle(count: int = 12) -> void:
	for tick: int in range(count):
		await process_frame
		if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw

func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	check(root.get_texture().get_image().save_png(output.path_join(label+".png")) == OK,"native capture "+label)

func click(button: Button) -> void:
	for down: bool in [true,false]:
		var event := InputEventMouseButton.new()
		event.position = button.get_global_rect().get_center()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		Input.parse_input_event(event)
		await settle(2)

func tap(button: Button) -> void:
	for down: bool in [true,false]:
		var event := InputEventScreenTouch.new()
		event.index = 7
		event.position = button.get_global_rect().get_center()
		event.pressed = down
		Input.parse_input_event(event)
		await settle(2)

func powered_drift_review(game: Node, track: NativeTrack) -> void:
	var configured: float=game.handling.power_lateral_response_scale
	var peaks: Array[float]=[]
	for response: float in [1.0,configured]:
		game.handling.power_lateral_response_scale=response
		game.driver.clear()
		game.sim.reset(track.spawn,track.spawn_heading)
		game.sim.state.velocity=game.sim.state.forward()*10.0
		Input.action_press("accelerate")
		Input.action_press("steer_right")
		var peak: float=0.0
		for tick: int in range(60):
			game._physics_process(VehicleSimulation.STEP)
			peak=maxf(peak,rad_to_deg(absf(game.sim.state.slip_angle())))
		peaks.append(peak)
	game.handling.power_lateral_response_scale=configured
	check(game.frame.throttle==255 and game.frame.steer==127,"actual Game receives simultaneous full accelerator and steering")
	check(peaks[1]>peaks[0]*1.8 and peaks[1]>15.0 and peaks[1]<24.0,"actual Game acceleration develops deliberate sliding over its planted response")
	check(game.sim.state.velocity.length()>10.0 and game.sim.state.collision_count==0,"actual powered turn accelerates without a contact")
	print("ELECTRIC_POWER_SLIDE_SAMPLE ",JSON.stringify({"without_power_aid":peaks[0],"with_power_aid":peaks[1]}))
	await settle(2)
	await capture("power-slide")
	game.driver.clear()
	for tick: int in range(240): game._physics_process(VehicleSimulation.STEP)
	check(game.sim.state.velocity.length()<0.001 and absf(game.sim.state.slip_angle())<deg_to_rad(0.1),"actual Game lifting and straightening catches the powered slide")

func geometry_signature(car: CarVisual) -> String:
	var values: Array=[car.scale,car.wheel_radii,car.wheel_rest_positions]
	for mesh: MeshInstance3D in car.find_children("*","MeshInstance3D",true,false):
		values.append([car.get_path_to(mesh),mesh.transform,mesh.cast_shadow])
		for surface: int in range(mesh.mesh.get_surface_count()): values.append(mesh.mesh.surface_get_arrays(surface))
	var digest:=HashingContext.new()
	digest.start(HashingContext.HASH_SHA256)
	digest.update(var_to_bytes(values))
	return digest.finish().hex_encode()

func run() -> void:
	OS.set_environment("BMT_API_URL","")
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--evidence-root="): output = argument.trim_prefix("--evidence-root=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	root.size = Vector2i(1280,720)
	if "--bake-art" in OS.get_cmdline_user_args():
		var studio := CarShowroom.new()
		studio.vehicle_id = "electric"
		studio.livery = VehicleLivery.defaults("electric")
		studio.read_only = true
		studio.size = Vector2(1280,720)
		root.add_child(studio)
		await settle()
		check(studio.showroom_viewport.get_texture().get_image().save_png("res://assets/menu/electric_illustration_v1.png") == OK,"bake original native car artwork")
		studio.queue_free()
		await settle(2)
		quit(1 if failures else 0)
		return
	var directory: String = ProjectSettings.globalize_path("res://../build/electric-car/"+TrackLibrary.unique_id())
	DirAccess.make_dir_recursive_absolute(directory)
	var app: Node = load("res://core/app.tscn").instantiate()
	app.records = LocalRecords.new(directory.path_join("records.json"))
	app.records.settings.selected_car = "electric"
	app.library = TrackLibrary.new(directory)
	app.cloud_root_override = directory.path_join("cloud")
	root.add_child(app)
	while not app.startup_complete: await process_frame
	VehicleCatalog.selected = "electric"
	app._show_screen("garage")
	await settle()
	var page: GaragePage = app.root_ui.find_child("GaragePage",true,false)
	check(page != null,"actual App opens Garage")
	# The progressive Garage prepares its live car after the page itself exists.
	for warmup: int in range(1200):
		if page.showroom.showroom_ready and (not page.progressive_entry or not page.showroom.get("preparing")): break
		await settle(1)
	check(page.showroom.showroom_ready and (not page.progressive_entry or not page.showroom.get("preparing")),"actual Garage studio prepares before selection")
	page.open_car(VehicleCatalog.IDS.find("electric"))
	await settle(40)
	for warmup: int in range(1200):
		if not page.progressive_entry or not page.showroom.get("preparing"): break
		await settle(1)
	check(page.showroom.car.vehicle_id == "electric" and VehicleCatalog.selected == "electric","Garage selects actual electric mesh and saves choice")
	var reference:=CarVisual.new()
	reference.vehicle_id="electric"
	root.add_child(reference)
	while not reference.model_ready: await process_frame
	check(geometry_signature(page.showroom.car)==geometry_signature(reference),"actual Garage geometry matches current canonical electric model")
	reference.queue_free()
	var reopened := LocalRecords.new(app.records.path)
	reopened.load_records()
	check(reopened.settings.selected_car == "electric","electric selection survives atomic reload")
	for dimensions: Vector2i in [Vector2i(960,540),Vector2i(1280,720),Vector2i(1600,720)]:
		root.size = dimensions
		page._show_section("customise")
		await settle(30)
		check(root.get_visible_rect().encloses(page.showroom.get_global_rect()),"electric showroom fits "+str(dimensions))
		await capture("garage-"+str(dimensions.x))
	root.size = Vector2i(1280,720)
	page._show_section("cars")
	await settle(30)
	await capture("catalogue")
	check(VehicleCatalog.artwork("electric") != null,"electric catalogue artwork loads")
	# Local creator race uses the real App launch without a published-cloud ticket.
	var track: NativeTrack=NativeTrack.read("res://resources/tracks/ellipse.json")
	var input_track: NativeTrack=track
	if "--over-and-under" in OS.get_cmdline_user_args():
		var document: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://resources/cloud_tracks/ecde9782d147738d3ab50d94a4a14255dd1e79069d96823960c77c46a394c948.json"))
		input_track=TrackCompiler.compile(document)
		check(document.name=="Over and under" and input_track.creator_bridges.size()==3,"actual Game uses the requested Over and under bridge track")
	await app._start_race(track,true,true)
	await settle(30)
	var game: Node = app.game
	for warmup: int in range(600):
		if game.preparation_complete: break
		await settle(1)
	check(game.preparation_complete,"native track preparation completes before input checks")
	game.set_physics_process(false)
	if game.paused: game.toggle_pause(false)
	game.countdown_label.hide()
	check(game.handling.vehicle_id == "electric" and game.car.vehicle_id == "electric","race uses electric handling and production mesh")
	check(game.trails.wheelbase == game.handling.wheelbase,"tire trails follow electric wheelbase")
	check(not game.driver.single_pedal and game.hud.direction_button == null,"actual race uses brake/reverse input without D/R selector")
	game.countdown_ticks = 0
	game.sim.state.velocity = Vector2.ZERO
	for dimensions: Vector2i in [Vector2i(960,540),Vector2i(1280,720)]:
		root.size = dimensions
		await settle()
		check(root.get_visible_rect().encloses(game.hud.menu_button.get_global_rect()),"Pause remains visible "+str(dimensions))
		var zones: Array[Rect2] = game.hud.touch.touch_zones()
		check(zones[2].has_area() and zones[3].has_area() and not zones[4].has_area(),"actual race exposes brake/gas without handbrake "+str(dimensions))
	if game.paused: game.toggle_pause(false)
	Input.action_press("brake")
	for tick: int in range(150): game._physics_process(VehicleSimulation.STEP)
	Input.action_release("brake")
	check(game.sim.state.velocity.dot(game.sim.state.forward()) < -1,"holding brake powers Reverse in actual Game")
	check(game.frame.brake == 255 and game._tire_effect_frame(game.frame).brake == 255,"reverse keeps the standard brake/reverse replay channel")
	for tick: int in range(120): game._physics_process(VehicleSimulation.STEP)
	check(game.sim.state.velocity == Vector2.ZERO,"actual Game release stops fully in Reverse")
	Input.action_press("accelerate")
	for tick: int in range(90): game._physics_process(VehicleSimulation.STEP)
	Input.action_release("accelerate")
	check(game.sim.state.velocity.dot(game.sim.state.forward()) > 1,"accelerator powers Drive")
	var released_speed: float = game.sim.state.velocity.length()
	game._physics_process(VehicleSimulation.STEP)
	check(game.frame.throttle == 0 and (released_speed-game.sim.state.velocity.length())/VehicleSimulation.STEP >= game.handling.regeneration,"actual Game applies configured regeneration on the first released-pedal tick")
	for tick: int in range(240): game._physics_process(VehicleSimulation.STEP)
	check(game.sim.state.velocity == Vector2.ZERO,"actual Game release stops fully in Drive")
	if "--powered-drift" in OS.get_cmdline_user_args(): await powered_drift_review(game,track)
	# Keep the retained exact-stop fixture on its original flat track. Exercise
	# the requested bridge track in a fresh actual Game for keyboard/controller.
	if "--over-and-under" in OS.get_cmdline_user_args():
		app._leave_race()
		await settle(3)
		track=input_track
		await app._start_race(track,true,true)
		await settle(30)
		game=app.game
		for warmup: int in range(600):
			if game.preparation_complete: break
			await settle(1)
		check(game.preparation_complete,"Over and under Game prepares before keyboard/controller input")
		game.set_physics_process(false)
		if game.paused: game.toggle_pause(false)
		game.countdown_ticks=0
	# Actual App keyboard and controller paths use the same finite steering ramp.
	game.sim.state.position=track.spawn
	game.sim.state.heading=track.spawn_heading
	game.sim.state.velocity=game.sim.state.forward()*(20.0/3.6)
	game.sim.state.steering=0.0
	game.sim.state.yaw_rate=0.0
	var keyboard := InputEventKey.new()
	keyboard.device=16
	keyboard.physical_keycode=KEY_D
	keyboard.keycode=KEY_D
	keyboard.pressed=true
	Input.parse_input_event(keyboard)
	await settle(2)
	Input.action_press("accelerate",0.25)
	for tick: int in range(24): game._physics_process(VehicleSimulation.STEP)
	check(game.frame.steer==127,"actual Game receives full keyboard input")
	check(game.sim.state.steering>0.95 and game.sim.state.steering<=1.0,"actual Game reaches usable keyboard lock within 200 ms")
	var keyboard_heading: float=absf(wrapf(game.sim.state.heading-track.spawn_heading,-PI,PI))
	print("ELECTRIC_KEYBOARD_SAMPLE ",JSON.stringify({"heading_degrees":rad_to_deg(keyboard_heading),"steering":game.sim.state.steering}))
	check(keyboard_heading>deg_to_rad(2.0) and keyboard_heading<deg_to_rad(12.0),"actual Game weighted turn-in remains useful and bounded at 20 km/h")
	var keyboard_release: InputEventKey=keyboard.duplicate() as InputEventKey
	keyboard_release.pressed=false
	Input.parse_input_event(keyboard_release)
	await settle(2)
	Input.action_release("accelerate")
	for tick: int in range(60): game._physics_process(VehicleSimulation.STEP)
	check(game.frame.steer==0 and game.sim.state.steering==0.0,"actual Game keyboard release recentres")
	game.sim.state.position=track.spawn
	game.sim.state.heading=track.spawn_heading
	game.sim.state.velocity=game.sim.state.forward()*(20.0/3.6)
	game.sim.state.steering=0.0
	game.sim.state.yaw_rate=0.0
	var controller := InputEventJoypadMotion.new()
	controller.device=0
	controller.axis=JOY_AXIS_LEFT_X
	controller.axis_value=0.5
	Input.parse_input_event(controller)
	await settle(2)
	Input.action_press("accelerate",0.25)
	for tick: int in range(24): game._physics_process(VehicleSimulation.STEP)
	check(game.frame.steer>0 and game.frame.steer<127,"actual Game receives partial controller steering")
	check(game.sim.state.steering>0.0 and game.sim.state.steering<0.5,"actual Game retains partial controller lock")
	var controller_release: InputEventJoypadMotion=controller.duplicate() as InputEventJoypadMotion
	controller_release.axis_value=0.0
	Input.parse_input_event(controller_release)
	await settle(2)
	game.driver.clear()
	for tick: int in range(60): game._physics_process(VehicleSimulation.STEP)
	check(game.frame.steer==0 and game.sim.state.steering==0.0,"actual Game controller release recentres")
	await capture("race")
	for method: String in ControlLayout.METHODS:
		for left: bool in [false,true]:
			var layout: Dictionary = ControlLayout.preset(left)
			layout.steering_type = method
			game.hud.touch.layout = layout
			await settle(4)
			check(game.hud.direction_button.position.is_equal_approx(game.hud.touch.direction_rect().position),method+str(left)+" selector follows saved brake placement")
			check(not game.hud.direction_button.get_global_rect().intersects(game.hud.touch.zones()[3]),method+str(left)+" selector remains separate from accelerator")
			var was_reverse: bool = game.driver.reverse_selected
			await tap(game.hud.direction_button)
			check(game.driver.reverse_selected != was_reverse and game.driver.sample().throttle == 0,method+str(left)+" actual direction touch never presses gas")
			if method != "buttons" and not left: await capture("controls-"+method)
	game.driver.reverse_selected = true
	game.hud.direction_button.text = "R"
	game.hud.direction_button.disabled = true
	game.restart()
	await settle(4)
	check(not game.driver.reverse_selected and game.hud.direction_button.text == "D" and not game.hud.direction_button.disabled,"restart immediately restores stopped Drive selection")
	game.camera.current = false
	var camera := Camera3D.new()
	game.get_node("World").add_child(camera)
	camera.position = game.car.position + Vector3(-5,3.8,-7)
	camera.look_at(game.car.position+Vector3(0,0.60,0))
	camera.current = true
	game.hud.hide()
	await settle()
	await capture("model-front")
	camera.position = game.car.position + Vector3(5,3.5,7)
	camera.look_at(game.car.position+Vector3(0,0.60,0))
	await settle()
	await capture("model-rear")
	app._leave_race()
	app.queue_free()
	await settle(5)
	print("ELECTRIC_UI: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
