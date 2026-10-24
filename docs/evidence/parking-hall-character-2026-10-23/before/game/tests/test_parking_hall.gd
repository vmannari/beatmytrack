extends SceneTree
## Real Garage entry/return, all five cars, collisions, input and native captures.
const HallData = preload("res://garage/parking_hall_data.gd")
var checks: int = 0
var failures: int = 0
var app: Node
var output: String = ""

func _initialize() -> void: run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: "+message)

func frame() -> void:
	await process_frame
	if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw

func capture(label: String) -> void:
	if output.is_empty() or DisplayServer.get_name() == "headless": return
	check(root.get_texture().get_image().save_png(output.path_join(label+".png")) == OK,"capture "+label)

func resize(dimensions: Vector2i) -> void:
	root.size = dimensions
	root.content_scale_size = dimensions

func settle(page: GaragePage) -> void:
	for index: int in range(5): await frame()
	while page._menu_motion != null: await frame()
	for index: int in range(3): await frame()

func click(button: Button, touch: bool = false) -> void:
	check(button.is_visible_in_tree(),"action is visible: "+button.name)
	var point: Vector2 = button.get_global_rect().get_center()
	for pressed: bool in [true,false]:
		if touch:
			var event := InputEventScreenTouch.new()
			event.index = 3
			event.position = point
			event.pressed = pressed
			root.push_input(event,true)
		else:
			var event := InputEventMouseButton.new()
			event.button_index = MOUSE_BUTTON_LEFT
			event.position = point
			event.pressed = pressed
			root.push_input(event,true)
		await frame()

func physics_contract() -> void:
	var hall := HallData.new()
	check(hall.half_extent*2 == Vector2(240,160),"240 by 160 metre hall")
	check(hall.islands.size() == 26,"bounded shared pillar layout")
	for id: String in VehicleCatalog.IDS:
		var config: HandlingConfig = VehicleCatalog.config(id,HandlingSelection.ORIGINAL_PLUS_INDEX)
		var sim := VehicleSimulation.new(config)
		sim.reset(hall.spawn,hall.spawn_heading)
		for tick: int in range(480): sim.step(DriveFrame.sample(0,1,0),hall)
		check(sim.state.position.x > hall.spawn.x+30,"useful acceleration distance: "+id)
		check(sim.state.collision_count == 0,"uninterrupted straight: "+id)
		for direction: Vector2 in [Vector2.RIGHT,Vector2.LEFT,Vector2.UP,Vector2.DOWN]:
			sim.reset(Vector2(10,-24))
			sim.state.velocity = direction*200
			sim.state.position += direction*500
			hall.resolve(sim.state,Vector2(10,-24),config)
			check(absf(sim.state.position.x) <= hall.half_extent.x-config.collision_radius and absf(sim.state.position.y) <= hall.half_extent.y-config.collision_radius,"wall contains swept car: "+id+str(direction))
		var pillar: Vector3 = hall.islands[0]
		var center := Vector2(pillar.x,pillar.y)
		var start: Vector2 = center-Vector2(6,0)
		sim.reset(start,PI*0.5)
		sim.state.velocity = Vector2(200,0)
		sim.state.position = center+Vector2(6,0)
		hall.resolve(sim.state,start,config)
		check(sim.state.position.x < center.x and sim.state.position.distance_to(center) >= pillar.z+config.collision_radius,"swept pillar stops tunnelling: "+id)
		for pillar_point: Vector3 in hall.islands:
			check(Vector2(pillar_point.x,pillar_point.y).distance_to(HallData.TURNING_CENTER) > HallData.TURNING_RADIUS+pillar_point.z+config.collision_radius,"clear turning circle: "+id)

func run() -> void:
	OS.set_environment("BMT_API_URL","")
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--evidence-root="): output = ProjectSettings.globalize_path(argument.trim_prefix("--evidence-root="))
	if not output.is_empty(): DirAccess.make_dir_recursive_absolute(output)
	physics_contract()
	resize(Vector2i(1280,720))
	var directory: String = ProjectSettings.globalize_path("res://../build/parking-hall/fixtures/"+TrackLibrary.unique_id())
	DirAccess.make_dir_recursive_absolute(directory)
	app = load("res://core/app.tscn").instantiate()
	app.records = LocalRecords.new(directory.path_join("records.json"))
	app.library = TrackLibrary.new(directory)
	app.cloud_root_override = directory.path_join("cloud")
	root.add_child(app)
	var deadline: int = Time.get_ticks_msec()+60000
	while not app.startup_complete and Time.get_ticks_msec() < deadline: await frame()
	check(app.startup_complete,"app ready within deadline")
	if not app.startup_complete: quit(1); return
	var paint: Dictionary = VehicleLivery.defaults("compact")
	paint.colors.body = "843f36"
	app.records.settings.vehicle_liveries = {"compact":paint}
	app.records.settings.vehicle_customisation = {"compact":{"version":1,"hood":"louvres","aero":"lip","rims":"five","body":"street"}}
	check(app.records.save_records() == OK,"isolated saved cosmetic fixture")
	app._show_screen("garage")
	var page: GaragePage = app._retained_garage
	await settle(page)
	var original_ui: Control = app.root_ui
	var original_track: NativeTrack = app.selected_track
	var original_records: Dictionary = app.records.records.duplicate(true)
	var original_condition: Dictionary = app.records.settings.get("vehicle_conditions",{}).duplicate(true)
	page._show_section("care")
	page.find_child("GarageTestDrive",true,false).pressed.emit()
	check(not is_instance_valid(app.game) and not is_instance_valid(app.race_loading),"moving Garage action cannot accidentally launch a hall")
	await settle(page)
	page._show_section("cars")
	await settle(page)
	for dimensions: Vector2i in [Vector2i(960,540),Vector2i(1280,720),Vector2i(1600,900)]:
		resize(dimensions)
		await settle(page)
		var action: Button = page.find_child("GarageTestDrive",true,false)
		check(action != null and root.get_visible_rect().encloses(action.get_global_rect()),"Garage action fits viewport "+str(dimensions))
		await capture("garage-"+str(dimensions.x))
		page._car_menu_open = true
		for section: String in ["customise","care","tuning"]:
			page._show_section(section)
			await settle(page)
			action = page.find_child("GarageTestDrive",true,false)
			check(root.get_visible_rect().encloses(action.get_global_rect()),"selected-car test drive fits viewport "+section+str(dimensions))
			check(not action.get_global_rect().intersects(page.find_child("GarageBack",true,false).get_global_rect()),"test drive and Back do not overlap "+section+str(dimensions))
		page._show_section("cars")
		await settle(page)
	resize(Vector2i(1280,720))
	for index: int in range(VehicleCatalog.IDS.size()):
		var id: String = VehicleCatalog.IDS[index]
		page.preview_car(index)
		await settle(page)
		await click(page.find_child("GarageTestDrive",true,false),index%2 == 1)
		deadline = Time.get_ticks_msec()+45000
		while (not is_instance_valid(app.game) or not app.game.preparation_complete or is_instance_valid(app.race_loading)) and Time.get_ticks_msec() < deadline: await frame()
		check(is_instance_valid(app.game) and app.game.preparation_complete and not is_instance_valid(app.race_loading),"Garage enters prepared hall: "+id)
		if not is_instance_valid(app.game): break
		var game: Node = app.game
		game.process_mode = Node.PROCESS_MODE_DISABLED
		check(game.vehicle_id == id and game.car.vehicle_id == id,"previewed car enters: "+id)
		check(game.car.livery == VehicleLivery.for_car(app.records.settings,id),"saved paint: "+id)
		check(game.car.customisation == VehicleCustomisation.for_car(app.records.settings,id),"saved parts: "+id)
		check(game.free_drive_mode and game.native_track == null and game.countdown_ticks == 0,"untimed immediate start: "+id)
		check(app.cloud_ticket.is_empty() and game.ghost_store == null,"no ticket or personal ghost: "+id)
		check(game.hud.find_child("EditHere",true,false) == null,"no editor action: "+id)
		check(game.hud.find_child("SpeedCard",true,false).is_visible_in_tree(),"speed visible: "+id)
		var spawn: Vector2 = game.sim.state.position
		var pedal: Vector2 = game.hud.touch.zones()[3].get_center()
		var touch := InputEventScreenTouch.new()
		touch.index = 22
		touch.position = pedal
		touch.pressed = true
		game.process_mode = Node.PROCESS_MODE_INHERIT
		root.push_input(touch,true)
		check(game.driver.sample().throttle > 0,"native touch reaches accelerator: "+id)
		game.process_mode = Node.PROCESS_MODE_DISABLED
		for tick: int in range(240): game._advance_physics(VehicleSimulation.STEP)
		game.hud.touch.release_all()
		game.driver.clear()
		check(game.sim.state.position.distance_to(spawn) > 5,"normal controls drive car: "+id)
		check(game.online_frames.is_empty() and game.race_proof.samples.is_empty(),"free driving retains no race proof: "+id)
		check(game.track_session.elapsed_ticks == 0 and not game.track_session.finished,"driving never finishes a race: "+id)
		game.call("_process",0.0)
		if index == 0:
			for dimensions: Vector2i in [Vector2i(960,540),Vector2i(1280,720),Vector2i(1600,900)]:
				resize(dimensions)
				for pose: Array in [["entry",HallData.new().spawn],["turning",HallData.TURNING_CENTER],["slalom",Vector2(61,28)],["bays",Vector2(32,-70)]]:
					game.sim.reset(pose[1],PI*0.5)
					game.previous_position = game.sim.state.position
					game.camera.follow(game.sim.state.position,Vector2.ZERO,game.sim.state.heading,0,true)
					game.call("_process",0.0)
					for wait_frame: int in range(3): await frame()
					var back: Button = game.hud.find_child("ReturnToGarage",true,false)
					check(Rect2(Vector2.ZERO,Vector2(root.size)).encloses(back.get_global_rect()),"Garage HUD action fits "+str(dimensions))
					var speed: Rect2 = game.hud.find_child("SpeedCard",true,false).get_global_rect()
					for zone: Rect2 in game.hud.touch.zones(): check(not speed.intersects(zone),"speed does not cover driving controls "+str(dimensions))
					await capture(str(pose[0])+"-"+str(dimensions.x))
			resize(Vector2i(1280,720))
		game.toggle_pause(false)
		var paused_tick: int = game.sim.state.tick
		game._advance_physics(VehicleSimulation.STEP)
		check(game.sim.state.tick == paused_tick and not game.hud.touch.enabled,"pause stops driving and touch: "+id)
		if index == 0: await capture("paused")
		game.hud.pause_menu.column.get_node("Restart").pressed.emit()
		check(not game.paused and game.sim.state.position == game.yard.spawn and game.sim.state.velocity == Vector2.ZERO,"reset from pause: "+id)
		game.driver.set_touch(25,&"accelerate")
		game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
		check(game.paused and game.driver.touches.is_empty(),"background pauses and releases inputs: "+id)
		game.toggle_pause(false)
		if index == 0: game.hud.find_child("ReturnToGarage",true,false).pressed.emit()
		else:
			game.toggle_pause(false)
			game.hud.pause_menu.column.get_node("Quit").pressed.emit()
		await settle(page)
		check(not is_instance_valid(app.game) and app.root_ui == original_ui and original_ui.visible,"return restores retained Garage: "+id)
		check(app._retained_garage == page and page.vehicle_id == id,"same Garage car: "+id)
		check(app.selected_track == original_track and app.records.records == original_records,"track and PBs unchanged: "+id)
		check(app.records.settings.get("vehicle_conditions",{}) == original_condition,"saved condition unchanged: "+id)
	# Cancellation before construction keeps the menu and cannot create a late hall.
	app._start_garage_free_drive()
	app._show_screen("settings")
	for wait_frame: int in range(10): await frame()
	check(not is_instance_valid(app.game) and not is_instance_valid(app.race_loading) and app.screen == "settings","navigation cancels pending hall entry")
	app.queue_free()
	for wait_frame: int in range(90): await frame()
	print("PARKING_HALL: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
