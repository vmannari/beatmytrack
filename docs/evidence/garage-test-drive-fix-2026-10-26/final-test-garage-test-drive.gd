extends SceneTree
## Actual Garage entry, electric-first free drive and retained-menu return.
var checks: int = 0
var failures: int = 0
var app: Node
var output: String = "res://../docs/evidence/garage-test-drive-fix-2026-10-26"

func _initialize() -> void: run.call_deferred()

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		print("FAIL: ",label)

func frames(count: int = 4) -> void:
	for _index: int in range(count): await process_frame

func settle(page: GaragePage) -> void:
	await frames()
	while page._menu_motion != null: await process_frame
	await frames()

func click(button: Button, touch: bool) -> void:
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
		await process_frame

func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(output.path_join(RenderingServer.get_current_rendering_method()+"-"+label+".png")) == OK,"capture "+label)

func run() -> void:
	create_timer(140).timeout.connect(func() -> void: print("FAIL: test-drive deadline"); quit(1))
	OS.set_environment("BMT_API_URL","")
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--evidence-root="): output = argument.trim_prefix("--evidence-root=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	root.size = Vector2i(1280,720)
	root.content_scale_size = root.size
	var folder: String = "user://garage-test-drive-"+TrackLibrary.unique_id()
	app = load("res://core/app.tscn").instantiate()
	app.records = LocalRecords.new(folder.path_join("records.json"))
	app.library = TrackLibrary.new(folder.path_join("tracks"))
	app.cloud_root_override = folder.path_join("cloud")
	root.add_child(app)
	while not app.startup_complete: await process_frame
	app.records.settings.music_enabled = false
	app._show_screen("garage")
	var page: GaragePage = app._retained_garage
	await settle(page)
	var original_ui: Control = app.root_ui
	var original_track: NativeTrack = app.selected_track
	var original_records: Dictionary = app.records.records.duplicate(true)
	var original_condition: Dictionary = app.records.settings.get("vehicle_conditions",{}).duplicate(true)
	for id: String in ["electric","compact","pickup","classic","formula","kart","forklift"]:
		if "--electric-only" in OS.get_cmdline_user_args() and id != "electric": continue
		page.preview_car(VehicleCatalog.IDS.find(id))
		await settle(page)
		await capture("garage-"+id)
		var button: Button = page.find_child("GarageTestDrive",true,false)
		check(button != null and button.is_visible_in_tree(),"test-drive action visible: "+id)
		if button == null: quit(1); return
		print("GARAGE_TEST_DRIVE_START: ",id)
		await click(button,VehicleCatalog.IDS.find(id)%2 == 0)
		var deadline: int = Time.get_ticks_msec()+45000
		while (not is_instance_valid(app.game) or not app.game.preparation_complete or is_instance_valid(app.race_loading)) and Time.get_ticks_msec()<deadline:
			await process_frame
		var ready: bool = is_instance_valid(app.game) and app.game.preparation_complete and not is_instance_valid(app.race_loading)
		check(ready,"prepared hall becomes visible: "+id)
		if not ready:
			print("GARAGE_TEST_DRIVE_STATE: game=",is_instance_valid(app.game)," loading=",is_instance_valid(app.race_loading)," root_visible=",app.root_ui.visible)
			if is_instance_valid(app.game): print("GAME_STATE: car=",is_instance_valid(app.game.car)," hud=",is_instance_valid(app.game.hud)," preparation=",app.game.preparation_complete)
			await capture("failed-"+id)
			quit(1)
			return
		var game: Node = app.game
		# Offscreen native windows can lose focus while graphics are prepared.
		# Resume before testing controls, retaining the real background-pause guard.
		game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
		if game.paused: game.toggle_pause(false)
		game.process_mode = Node.PROCESS_MODE_DISABLED
		check(game.vehicle_id == id and game.car.vehicle_id == id,"chosen car enters hall: "+id)
		check(game.free_drive_mode and game.native_track == null and game.countdown_ticks == 0,"untimed hall: "+id)
		check(game.track_ground.visible and game.car.visible and game.car.model_ready,"hall and finished car visible: "+id)
		check(not is_instance_valid(game.world_render_preparation) or game.world_render_preparation.pending.is_empty(),"all held geometry revealed before opening: "+id)
		var visible_car_meshes: int = 0
		for mesh: GeometryInstance3D in game.car.find_children("*","GeometryInstance3D",true,false):
			if mesh.is_visible_in_tree(): visible_car_meshes += 1
		check(visible_car_meshes>0,"actual car meshes visible: "+id)
		var visible_hall_meshes: int = 0
		for mesh: GeometryInstance3D in game.track_ground.find_children("*","GeometryInstance3D",true,false):
			if mesh.is_visible_in_tree(): visible_hall_meshes += 1
		check(visible_hall_meshes>0,"actual hall meshes visible: "+id)
		check(game.car.livery == VehicleLivery.for_car(app.records.settings,id),"saved paint: "+id)
		check(game.car.customisation == VehicleCustomisation.for_car(app.records.settings,id),"saved parts: "+id)
		check(app.cloud_ticket.is_empty() and game.ghost_store == null,"no online ticket or ghost store: "+id)
		if id == "electric":
			game.call("_process",0.0)
			await capture("ready-electric")
		var start: Vector2 = game.sim.state.position
		game.driver.set_touch(25,&"accelerate")
		for _tick: int in range(240): game._advance_physics(VehicleSimulation.STEP)
		game.driver.clear()
		check(game.sim.state.position.distance_to(start)>5,"controls move car: "+id)
		check(game.online_frames.is_empty() and game.race_proof.samples.is_empty(),"no race proof: "+id)
		check(game.track_session.elapsed_ticks == 0 and not game.track_session.finished,"no timed result: "+id)
		# The fixture advances two seconds in one frame; snap its capture camera
		# to the driven pose just as the retained hall's pose fixtures do.
		game.camera.follow(game.sim.state.position,game.sim.state.velocity,game.sim.state.heading,0.0,true)
		game.call("_process",0.0)
		check(root.get_visible_rect().has_point(game.camera.unproject_position(game.car.global_position)),"driven car projects inside viewport: "+id)
		await frames()
		await capture("driving-"+id)
		game.toggle_pause(false)
		var paused_tick: int = game.sim.state.tick
		game._advance_physics(VehicleSimulation.STEP)
		check(game.sim.state.tick == paused_tick and not game.hud.touch.enabled,"pause stops driving and touch: "+id)
		game.hud.pause_menu.column.get_node("Restart").pressed.emit()
		check(not game.paused and game.sim.state.position == game.yard.spawn,"reset returns to hall entrance: "+id)
		game.driver.set_touch(25,&"accelerate")
		game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
		check(game.paused and game.driver.touches.is_empty(),"background pauses and releases inputs: "+id)
		game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
		game.toggle_pause(false)
		game.hud.find_child("ReturnToGarage",true,false).pressed.emit()
		await settle(page)
		check(not is_instance_valid(app.game) and app.root_ui == original_ui and original_ui.visible,"return restores Garage: "+id)
		check(app._retained_garage == page and page.vehicle_id == id,"same Garage and car: "+id)
		check(app.selected_track == original_track and app.records.records == original_records,"track and records preserved: "+id)
		check(app.records.settings.get("vehicle_conditions",{}) == original_condition,"condition preserved: "+id)
	app.queue_free()
	await frames(20)
	print("GARAGE_TEST_DRIVE: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
