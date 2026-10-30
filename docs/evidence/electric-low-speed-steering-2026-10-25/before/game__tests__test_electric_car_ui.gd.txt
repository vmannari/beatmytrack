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
	page.open_car(VehicleCatalog.IDS.find("electric"))
	await settle(40)
	check(page.showroom.car.vehicle_id == "electric" and VehicleCatalog.selected == "electric","Garage selects actual electric mesh and saves choice")
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
	var track: NativeTrack = NativeTrack.read("res://resources/tracks/ellipse.json")
	await app._start_race(track,true,true)
	await settle(30)
	var game: Node = app.game
	game.set_physics_process(false)
	game.countdown_label.hide()
	check(game.handling.vehicle_id == "electric" and game.car.vehicle_id == "electric","race uses electric handling and production mesh")
	check(game.trails.wheelbase == game.handling.wheelbase,"tire trails follow electric wheelbase")
	check(game.driver.single_pedal,"actual race samples one-pedal input")
	game.countdown_ticks = 0
	game.sim.state.velocity = Vector2.ZERO
	for dimensions: Vector2i in [Vector2i(960,540),Vector2i(1280,720)]:
		root.size = dimensions
		await settle()
		check(root.get_visible_rect().encloses(game.hud.direction_button.get_global_rect()),"D/R fits "+str(dimensions))
		check(root.get_visible_rect().encloses(game.hud.menu_button.get_global_rect()),"Pause remains visible "+str(dimensions))
		check(not game.hud.direction_button.get_global_rect().intersects(game.hud.menu_button.get_global_rect()),"D/R and Pause do not overlap "+str(dimensions))
		check(game.hud.direction_button.position.is_equal_approx(game.hud.touch.direction_rect().position),"D/R occupies the former brake position "+str(dimensions))
		check(game.hud.touch.action_at(game.hud.direction_button.get_global_rect().get_center()) == &"","D/R area cannot trigger the accelerator padding "+str(dimensions))
	var zones: Array[Rect2] = game.hud.touch.touch_zones()
	check(not zones[2].has_area() and not zones[4].has_area() and zones[3].has_area(),"actual race exposes only the accelerator pedal")
	await tap(game.hud.direction_button)
	check(game.driver.reverse_selected,"actual D/R button selects Reverse at rest")
	check(game.driver.sample().throttle == 0,"touching D/R never applies the accelerator")
	Input.action_press("accelerate")
	for tick: int in range(90): game._physics_process(VehicleSimulation.STEP)
	Input.action_release("accelerate")
	check(game.sim.state.velocity.dot(game.sim.state.forward()) < -1,"same gas pedal powers Reverse in actual Game")
	check(game.hud.direction_button.disabled,"direction button locks while moving")
	check(game.frame.brake == 255 and game._tire_effect_frame(game.frame).brake == 0,"Reverse replay command cannot create locked-wheel smoke or trails")
	game.hud.direction_requested.emit()
	check(game.driver.reverse_selected,"Game rejects direction changes while moving even if signalled")
	for tick: int in range(40): game._physics_process(VehicleSimulation.STEP)
	check(game.sim.state.velocity == Vector2.ZERO,"actual Game release stops fully in Reverse")
	await click(game.hud.direction_button)
	check(not game.driver.reverse_selected,"actual D/R button returns to Drive after complete stop")
	Input.action_press("accelerate")
	for tick: int in range(90): game._physics_process(VehicleSimulation.STEP)
	Input.action_release("accelerate")
	check(game.sim.state.velocity.dot(game.sim.state.forward()) > 1,"one gas pedal powers Drive")
	var released_speed: float = game.sim.state.velocity.length()
	game._physics_process(VehicleSimulation.STEP)
	check(game.frame.throttle == 0 and (released_speed-game.sim.state.velocity.length())/VehicleSimulation.STEP >= 26,"actual Game applies braking strength on the first released-pedal tick")
	for tick: int in range(95): game._physics_process(VehicleSimulation.STEP)
	check(game.sim.state.velocity == Vector2.ZERO,"actual Game release stops fully in Drive")
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
