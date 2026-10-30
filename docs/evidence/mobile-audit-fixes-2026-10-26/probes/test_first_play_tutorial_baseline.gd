extends SceneTree
## Isolated native App actions, real quantized driving, persistence and renderer captures.
const Progress = preload("res://tutorial/tutorial_progress.gd")
var app: Node
var checks: int = 0
var failures: int = 0
var failed: Array[String] = []
var output: String = ""
var directory: String
var snapshots: Array[String] = []

func _initialize() -> void: run.call_deferred()

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		failed.append(message)
		print("FAIL: "+message)

func frame(count: int = 1) -> void:
	for index: int in range(count):
		await process_frame
		if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw

func resize(dimensions: Vector2i) -> void:
	root.size = dimensions
	root.content_scale_size = dimensions
	await frame(3)
	await restore_foreground()

func restore_foreground() -> void:
	# Renderer/window recreation can legitimately trigger the existing background pause.
	if DisplayServer.get_name() != "headless": root.grab_focus()
	if not is_instance_valid(app): return
	app._notification(NOTIFICATION_APPLICATION_FOCUS_IN)
	if app.tutorial != null: app.tutorial._notification(NOTIFICATION_APPLICATION_FOCUS_IN)
	if is_instance_valid(app.game) and app.game.preparation_complete:
		app.game._notification(NOTIFICATION_APPLICATION_FOCUS_IN)
		if app.game.paused and app.game.hud.pause_menu.visible:
			print("TUTORIAL: resume normal foreground-pause fixture")
			await click(app.game.hud.pause_menu.find_child("Resume",true,false))

func click(button: Button) -> void:
	# A forced contextual-clock advance must not race the real native page tween.
	var settle_deadline: int = Time.get_ticks_msec()+2000
	while is_instance_valid(app) and app.menu_page_motion != null and Time.get_ticks_msec()<settle_deadline: await frame()
	if is_instance_valid(app) and app.tutorial != null and app.tutorial._backgrounded:
		# Resizing a native renderer window may deliver focus-out after resize() returns.
		if DisplayServer.get_name() != "headless": root.grab_focus()
		app.tutorial._notification(NOTIFICATION_APPLICATION_FOCUS_IN)
		app.tutorial._process(0)
		await frame(2)
	check(button != null and button.is_visible_in_tree(),"visible tutorial action")
	if button == null or not button.is_visible_in_tree(): return
	var ancestor: Node = button.get_parent()
	while ancestor != null:
		if ancestor is ScrollContainer: ancestor.ensure_control_visible(button)
		ancestor = ancestor.get_parent()
	await frame(2)
	var point: Vector2 = button.get_global_rect().get_center()
	print("TUTORIAL: click ",button.name," at ",point)
	for pressed: bool in [true,false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event,true)
		await frame()

func capture(label: String) -> void:
	if output.is_empty() or DisplayServer.get_name() == "headless": return
	await frame(2)
	check(root.get_texture().get_image().save_png(output.path_join(label+".png")) == OK,"native capture "+label)
	snapshots.append(label+".png")

func card_fits(label: String) -> void:
	await frame(2)
	var view: Control = app.tutorial.view
	check(view.safe_area().encloses(view.card.get_rect()),label+" stays in the safe area")
	for button: Button in [view.primary,view.secondary,view.skip_button]:
		if button.visible:
			check(button.size.y >= 48 and view.card.get_global_rect().encloses(button.get_global_rect()),label+" keeps its action reachable")
	check(view.card.get_global_rect().encloses(view.copy.get_global_rect()),label+" keeps its complete instruction inside the card")

func card_is_drawn(label: String) -> void:
	check(app.tutorial._layer.layer > app.menu_layer.layer,label+" draws above the actual menu canvas")
	if DisplayServer.get_name() == "headless": return
	await frame(3)
	var picture: Image = root.get_texture().get_image()
	var rect: Rect2 = app.tutorial.view.card.get_global_rect()
	var gold := Vector3(MenuStyle.ACCENT.r,MenuStyle.ACCENT.g,MenuStyle.ACCENT.b)
	var found: bool = false
	for dy: int in range(-1,4):
		var pixel: Color = picture.get_pixel(clampi(roundi(rect.get_center().x),0,picture.get_width()-1),clampi(floori(rect.position.y)+dy,0,picture.get_height()-1))
		found = found or Vector3(pixel.r,pixel.g,pixel.b).distance_to(gold) < 0.12
	check(found,label+" has its visible gold border above the menu/backdrop")

func wait_game(hall: bool) -> bool:
	var deadline: int = Time.get_ticks_msec()+60000
	while Time.get_ticks_msec() < deadline:
		if is_instance_valid(app.game) and app.game.preparation_complete and not is_instance_valid(app.race_loading):
			app.game.set_physics_process(false)
			check(app.game.free_drive_mode == hall,"correct tutorial driving scene")
			await frame(2)
			await restore_foreground()
			return app.game.free_drive_mode == hall
		await frame()
	check(false,"tutorial driving scene prepared within deadline")
	return false

func progress_contract() -> void:
	print("TUTORIAL: persistence")
	var path: String = directory.path_join("progress/unit.json")
	var progress: RefCounted = Progress.new(path)
	progress.load_progress()
	check(progress.status == "new" and progress.step == 0,"fresh progress starts unoffered")
	progress.begin()
	progress.advance(2)
	progress.dismiss("garage")
	var resumed: RefCounted = Progress.new(path)
	resumed.load_progress()
	check(resumed.status == "active" and resumed.step == 2 and resumed.seen.has("garage"),"exact step and dismissed topic survive restart")
	resumed.skip()
	var skipped: RefCounted = Progress.new(path)
	skipped.load_progress()
	check(skipped.status == "skipped","skip survives restart")
	skipped.begin(true)
	check(skipped.step == 0 and skipped.seen.has("garage"),"replay resets driving without reintroducing dismissed tips")
	skipped.advance(5)
	var completed: RefCounted = Progress.new(path)
	completed.load_progress()
	check(completed.status == "completed" and completed.step == 5,"completion survives restart")
	var original := FileAccess.open(path,FileAccess.WRITE)
	original.store_string("invalid partial file")
	original.close()
	var recovered: RefCounted = Progress.new(path)
	recovered.load_progress()
	check(recovered.status == "active" and recovered.step == 0,"corrupt current file recovers the last atomic backup")
	var existing: RefCounted = Progress.new(directory.path_join("existing.json"))
	existing.load_progress(true)
	check(existing.status == "existing" and existing.seen.size() == Progress.TOPICS.size(),"existing racers are never forced into a new tutorial")
	var blocked: String = directory.path_join("unwritable")
	var file := FileAccess.open(blocked,FileAccess.WRITE)
	file.store_string("directory collision")
	file.close()
	var unavailable: RefCounted = Progress.new(blocked.path_join("progress.json"))
	unavailable.begin()
	check(unavailable.last_error != OK and unavailable.status == "active","failed saving permits the current lesson to continue")
	var record := LocalRecords.new(directory.path_join("old.json"))
	check(not Progress.has_played(record),"untouched save is new")
	record.settings.last_track = "ellipse"
	check(Progress.has_played(record),"existing last-track preference suppresses onboarding")
	for value: Variant in [{}, {"schema":1,"status":"completed","step":1,"seen":{}}, {"schema":1,"status":"active","step":2.5,"seen":{}}, {"schema":1,"status":"new","step":0,"seen":{"unknown":true}}]:
		var invalid_path: String = directory.path_join("invalid.json")
		file = FileAccess.open(invalid_path,FileAccess.WRITE)
		file.store_string(JSON.stringify(value))
		file.close()
		check(Progress._read(invalid_path).is_empty(),"invalid progress is rejected: "+JSON.stringify(value))

func touch_event(point: Vector2, pressed: bool, index: int = 5) -> void:
	var event := InputEventScreenTouch.new()
	event.position = point
	event.pressed = pressed
	event.index = index
	root.push_input(event,true)
	await frame()

func check_layouts(game: Node) -> void:
	print("TUTORIAL: input layouts")
	game.driver.clear()
	var tutorial: Node = app.tutorial
	for method: String in ControlLayout.METHODS:
		var layout: Dictionary = ControlLayout.preset(true)
		layout.steering_type = method
		game.hud.touch.layout = layout
		await frame(2)
		tutorial._process(0.0)
		check(not tutorial.view.outlines.is_empty(),"saved left-handed "+method+" is highlighted before the first touch")
		check(tutorial.view.copy.text.contains("highlighted"),"default "+method+" instruction points to its on-screen control")
		var control: Rect2 = game.hud.touch.group_rects().accelerator
		var point: Vector2 = control.get_center()
		await touch_event(point,true)
		if method != "buttons":
			var drag := InputEventScreenDrag.new()
			drag.index = 5
			drag.position = point-Vector2(0,control.size.y*0.4)
			root.push_input(drag,true)
			await frame()
		check(game.driver.sample().throttle > 0,"tutorial overlay passes through actual "+method+" driving touches")
		await touch_event(point,false)
		check(game.driver.sample().throttle == 0 and game.driver.touches.is_empty(),"releasing "+method+" leaves no held input")
		check(tutorial.view.copy.text.contains("slide") == (method != "buttons"),"pedal instruction matches "+method)
		await capture("touch-"+method)
	game.hud.touch.layout = ControlLayout.preset()
	var moved: Dictionary = ControlLayout.preset()
	moved.accelerator.x = 0.5
	moved.accelerator.y = 0.0
	game.hud.touch.layout = moved
	await frame(2)
	tutorial._process(0)
	check(not tutorial.view.card.get_global_rect().intersects(game.hud.touch.group_rects().accelerator),"coach moves clear of a custom pedal position")
	game.hud.touch.layout = ControlLayout.preset()
	var key := InputEventKey.new()
	key.keycode = KEY_W
	key.pressed = true
	root.push_input(key,true)
	key = InputEventKey.new()
	key.keycode = KEY_W
	root.push_input(key,true)
	var pad := InputEventJoypadButton.new()
	pad.button_index = JOY_BUTTON_A
	pad.pressed = true
	root.push_input(pad,true)
	pad = InputEventJoypadButton.new()
	pad.button_index = JOY_BUTTON_A
	root.push_input(pad,true)
	tutorial._process(0.0)
	check(not tutorial.view.outlines.is_empty() and tutorial.view.copy.text.contains("highlighted"),"keyboard and gamepad events preserve touch teaching and highlights")

func feed(game: Node, input: DriveFrame, observe: bool = true) -> void:
	game.driver.set_touch(90,&"steer_right" if input.steer >= 0 else &"steer_left",absf(input.steer/127.0))
	game.driver.set_touch(91,&"accelerate",input.throttle/255.0)
	game.driver.set_touch(92,&"brake",input.brake/255.0)
	game._physics_process(1.0/120.0)
	if observe: app.tutorial._process(1.0/120.0)

func floor_marker_contract(game: Node) -> void:
	if DisplayServer.get_name() == "headless": return
	var tutorial: Node = app.tutorial
	var start: Vector2 = game.sim.state.position
	var heading: float = game.sim.state.heading
	for stage: int in range(3):
		var goal: Vector2 = tutorial.HALL_GOALS[stage]
		tutorial.progress.advance(stage)
		game.sim.reset(goal,heading)
		game.previous_position = goal
		game.previous_heading = heading
		game._present_frame(0)
		game.camera.follow(goal,Vector2.ZERO,heading,0,true)
		tutorial._process(0)
		await frame(3)
		var center: Vector2 = game.camera.unproject_position(VisualGeometry.world(goal)+Vector3(0,0.08,0))
		var picture: Image = root.get_texture().get_image()
		var gold := Vector3(MenuStyle.ACCENT.r,MenuStyle.ACCENT.g,MenuStyle.ACCENT.b)
		var marked: bool = false
		for dx: int in range(-3,4):
			for dy: int in range(-3,4):
				var pixel: Color = picture.get_pixel(roundi(center.x)+dx,roundi(center.y)+dy)
				marked = marked or Vector3(pixel.r,pixel.g,pixel.b).distance_to(gold) < 0.12
		check(marked,"stage %d draws its visible target on the actual simulation goal" % stage)
		await capture("floor-target-%d" % stage)
	game.sim.reset(start,heading)
	game.previous_position = start
	game.previous_heading = heading
	game._present_frame(0)
	game.camera.follow(start,Vector2.ZERO,heading,0,true)
	tutorial.progress.advance(0)
	tutorial._process(0)

func highlight_contract(game: Node) -> void:
	var tutorial: Node = app.tutorial
	var saved_step: int = tutorial.progress.step
	for method: String in ControlLayout.METHODS:
		var layout: Dictionary = ControlLayout.preset(true)
		layout.steering_type = method
		game.hud.touch.layout = layout
		for stage: int in range(3):
			tutorial.progress.advance(stage)
			tutorial._process(0)
			var names: Array[String] = []
			names.assign([method] if stage == 1 and method != "buttons" else ["steer_left","steer_right"] if stage == 1 else ["brake" if stage == 2 and method == "buttons" else "accelerator"])
			var expected: Array[Rect2] = []
			for control: String in names: expected.append(game.hud.touch.get_global_transform_with_canvas()*game.hud.touch.group_rects()[control])
			check(tutorial.view.outlines == expected,"stage %d highlights actual saved %s controls" % [stage,method])
			if DisplayServer.get_name() != "headless" and not tutorial.view.outlines.is_empty():
				await frame(2)
				var rect: Rect2 = expected[0].grow(5)
				var picture: Image = root.get_texture().get_image()
				var gold := Vector3(MenuStyle.ACCENT.r,MenuStyle.ACCENT.g,MenuStyle.ACCENT.b)
				var visible: bool = false
				for dy: int in range(4):
					var pixel: Color = picture.get_pixel(roundi(rect.get_center().x),roundi(rect.position.y)+dy)
					visible = visible or Vector3(pixel.r,pixel.g,pixel.b).distance_to(gold) < 0.12
				check(visible,"stage %d %s highlight is drawn above the HUD" % [stage,method])
			await capture("highlight-%s-%d" % [method,stage])
	game.hud.touch.layout = ControlLayout.preset()
	tutorial.progress.advance(saved_step)
	tutorial._process(0)

func stop_fixture(game: Node, position: Vector2) -> void:
	var tutorial: Node = app.tutorial
	tutorial.progress.advance(2)
	# Observe a moving/outside state so separate cases cannot share a partial stop.
	game.sim.state.position = tutorial.HALL_GOALS[2]+Vector2(12,0)
	game.sim.state.velocity = Vector2.ZERO
	feed(game,DriveFrame.new())
	game.sim.state.position = position
	game.sim.state.velocity = Vector2.ZERO

func stopped_ticks(game: Node, ticks: int) -> void:
	# 120 Hz physics / 30 Hz presentation; brake taps may fall between observations.
	for tick: int in range(ticks):
		feed(game,DriveFrame.new(),false)
		if tick%4 == 3: app.tutorial._process(4.0/120.0)

func stopping_contract(game: Node) -> void:
	print("TUTORIAL: stopped-circle regression")
	var tutorial: Node = app.tutorial
	var goal: Vector2 = tutorial.HALL_GOALS[2]
	stop_fixture(game,goal+Vector2(12,0))
	stopped_ticks(game,40)
	check(tutorial.progress.step == 2,"stopping outside the circle cannot finish")
	stop_fixture(game,goal)
	game.sim.state.velocity = Vector2(0,3)
	stopped_ticks(game,12)
	check(game.sim.state.velocity.length() > 0.8 and tutorial.progress.step == 2,"driving through the circle cannot finish")
	stop_fixture(game,goal)
	for render: int in range(100): tutorial._process(1.0/30.0)
	check(tutorial.progress.step == 2,"render frames without simulation cannot finish a stop")
	stopped_ticks(game,28)
	check(tutorial.progress.step == 3,"a stable stop inside the circle completes without a hidden brake requirement")
	await capture("stopped-without-brake")
	stop_fixture(game,goal)
	feed(game,DriveFrame.sample(0,0,1),false)
	stopped_ticks(game,4)
	check(game.frame.brake == 0,"short brake press ends before the presentation sample")
	stopped_ticks(game,28)
	check(tutorial.progress.step == 3,"a brake released between presentation samples still completes the stop")
	stop_fixture(game,goal)
	stopped_ticks(game,12)
	game.sim.state.position = goal+Vector2(12,0)
	stopped_ticks(game,4)
	game.sim.state.position = goal
	stopped_ticks(game,20)
	check(tutorial.progress.step == 2,"leaving the circle resets the continuous stop")
	stopped_ticks(game,8)
	check(tutorial.progress.step == 3,"a new continuous stop succeeds after leaving and returning")
	stop_fixture(game,goal+Vector2(8.9,0))
	stopped_ticks(game,28)
	check(tutorial.progress.step == 3,"stopping just inside the visible circle succeeds")
	# Restore the real driver's next objective after the isolated edge cases.
	tutorial.progress.advance(2)
	game.sim.reset(tutorial.HALL_GOALS[1],0)
	tutorial._process(0)

func drive_hall_stage(game: Node, stage: int) -> void:
	var target: Vector2 = app.tutorial.HALL_GOALS[stage]
	var ticks: int = 0
	while app.tutorial.progress.step == stage and ticks < 7200:
		var offset: Vector2 = target-game.sim.state.position
		var error: float = wrapf(atan2(offset.x,offset.y)-game.sim.state.heading,-PI,PI)
		var speed: float = game.sim.state.velocity.length()
		var desired_speed: float = 5.0 if absf(error) < 0.45 else 3.0
		if stage == 2 and offset.length() < 8: desired_speed = 0
		var turn: float = clampf(error*2.3-game.sim.state.yaw_rate*0.15,-1,1)
		feed(game,DriveFrame.sample(turn,0.5 if speed < desired_speed else 0.0,0.8 if speed > desired_speed+0.2 else 0.0))
		ticks += 1
		if ticks%120 == 0: await frame()
	check(app.tutorial.progress.step == stage+1,"real quantized driving completes hall stage "+str(stage))
	game.driver.clear()
	await frame(2)

func run() -> void:
	restore_task_start()
	OS.set_environment("BMT_API_URL","")
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--evidence-root="): output = ProjectSettings.globalize_path(argument.trim_prefix("--evidence-root="))
	if not output.is_empty(): DirAccess.make_dir_recursive_absolute(output)
	directory = ProjectSettings.globalize_path("res://../build/tutorial-validation/fixtures/"+TrackLibrary.unique_id())
	DirAccess.make_dir_recursive_absolute(directory)
	progress_contract()
	await resize(Vector2i(1280,720))
	app = load("res://core/app.tscn").instantiate()
	app.records = LocalRecords.new(directory.path_join("records.json"))
	app.library = TrackLibrary.new(directory.path_join("tracks"))
	app.cloud_root_override = directory.path_join("cloud")
	root.add_child(app)
	var deadline: int = Time.get_ticks_msec()+60000
	while not app.startup_complete and Time.get_ticks_msec()<deadline: await frame()
	check(app.startup_complete,"isolated App starts")
	if not app.startup_complete: await finish(); return
	await frame(5)
	var tutorial: Node = app.tutorial
	check(app.screen == "account" and not tutorial.view.visible,"account setup precedes the driving tutorial")
	await capture("account-before-tutorial")
	await click(app.root_ui.find_child("ContinueWithoutSignIn",true,false))
	await frame(4)
	print("TUTORIAL: entry screen=",app.screen," offer=",tutorial._offer_pending," background=",tutorial._backgrounded," dialog=",tutorial._has_dialog()," key=",tutorial.view.key," size=",tutorial.view.size," processing=",tutorial.is_processing())
	check(tutorial.view.visible and tutorial.view.key == "welcome","actual Guest action opens welcome")
	if tutorial.view.key != "welcome": await finish(); return
	for dimensions: Vector2i in [Vector2i(960,540),Vector2i(1280,720),Vector2i(1600,720)]:
		await resize(dimensions)
		var bounds := Rect2(Vector2.ZERO,Vector2(dimensions))
		check(bounds.encloses(tutorial.view.card.get_global_rect()),"welcome fits "+str(dimensions))
		for button: Button in [tutorial.view.primary,tutorial.view.secondary,tutorial.view.skip_button]:
			check(button.size.y >= 48 and tutorial.view.card.get_global_rect().encloses(button.get_global_rect()),"welcome actions remain inside card "+str(dimensions))
		await capture("welcome-%dx%d" % [dimensions.x,dimensions.y])
	await resize(Vector2i(1280,720))
	await click(tutorial.view.secondary)
	check(app.screen == "settings" and not tutorial.view.visible,"welcome Controls opens settings without starting a lesson")
	app._show_screen("rivalry")
	await frame(4)
	check(tutorial.view.key == "welcome" and tutorial.view.visible,"leaving control setup restores the welcome choice")
	await click(tutorial.view.skip_button)
	check(tutorial.progress.status == "skipped" and not tutorial.view.visible,"skip is immediate and persisted")
	check(not tutorial._layer.visible,"hidden tutorial releases the menu's modal layer")
	app._show_screen("garage")
	# MA13 prepares the single live room on first entry, under the normal cover.
	while app.screen != "garage": await frame()
	await frame(4)
	tutorial._process(1.0)
	check(tutorial.view.key == "topic_garage_0","first Garage entry supplies a contextual tip")
	await card_is_drawn("Garage entry instruction")
	await capture("garage-first-entry-tip")
	var preview_before: String = app._retained_garage.vehicle_id
	check(app._retained_garage.gallery.input_exclusion.is_valid(),"retained Garage carousel respects the active tutorial card")
	await click(tutorial.view.primary)
	check(tutorial.progress.seen.has("garage"),"automatic feature tip is dismissed permanently")
	check(app._retained_garage.vehicle_id == preview_before and app._retained_garage.gallery.is_processing_input(),"dismissing the tip neither selects a car nor disables the carousel")
	if "--entry-only" in OS.get_cmdline_user_args(): await finish(); return
	app._show_screen("settings")
	await frame(4)
	var settings: SettingsPage = app.root_ui.find_child("SettingsPage",true,false)
	settings._show_section("help")
	check(not settings.reset_button.visible and not settings.apply_button.visible,"Help has no unrelated Apply or Reset action")
	await capture("settings-help")
	await click(settings.find_child("ReplayTutorial",true,false))
	check(tutorial.view.key == "welcome","Settings replay reopens the tutorial")
	await click(tutorial.view.primary)
	if not await wait_game(true): await finish(); return
	var hall: Node = app.game
	var records_before: Dictionary = app.records.records.duplicate(true)
	var condition_before: Dictionary = VehicleCondition.read(app.records,hall.vehicle_id).duplicate(true)
	check(tutorial.progress.status == "active" and tutorial.progress.step == 0,"hall begins at saved first objective")
	for tick: int in range(120): feed(hall,DriveFrame.new())
	check(tutorial.progress.step == 0,"waiting cannot complete a driving objective")
	await check_layouts(hall)
	await floor_marker_contract(hall)
	await highlight_contract(hall)
	for dimensions: Vector2i in [Vector2i(960,540),Vector2i(1280,720),Vector2i(1600,720)]:
		await resize(dimensions)
		await card_fits("hall "+str(dimensions))
		await capture("hall-%dx%d" % [dimensions.x,dimensions.y])
	await resize(Vector2i(1280,720))
	tutorial.view.safe_override = Rect2(70,24,1140,660)
	tutorial.view._layout()
	await card_fits("notched-screen coach")
	tutorial.view.safe_override = Rect2()
	tutorial.view._layout()
	await capture("hall-accelerate")
	hall.toggle_pause(false)
	tutorial._process(0.0)
	var paused_tick: int = hall.sim.state.tick
	for tick: int in range(120): feed(hall,DriveFrame.sample(0,1,0))
	check(hall.sim.state.tick == paused_tick and tutorial.progress.step == 0 and not tutorial.view.visible,"pause freezes progress and hides teaching controls")
	hall.toggle_pause(false)
	hall.driver.clear()
	tutorial._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(not tutorial.view.visible,"background hides the tutorial")
	tutorial._notification(NOTIFICATION_APPLICATION_FOCUS_IN)
	tutorial._process(0)
	check(tutorial.view.visible,"foreground restores the current instruction")
	await drive_hall_stage(hall,0)
	await capture("hall-steer")
	await drive_hall_stage(hall,1)
	await capture("hall-brake")
	await stopping_contract(hall)
	await drive_hall_stage(hall,2)
	check(app.records.records == records_before and VehicleCondition.read(app.records,hall.vehicle_id) == condition_before,"parking lesson preserves PBs and saved car condition")
	check(app.cloud_ticket.is_empty() and hall.online_frames.is_empty(),"parking lesson creates no ticket or recorded race")
	await capture("hall-ready")
	var resumed: RefCounted = Progress.new(directory.path_join("tutorial.json"))
	resumed.load_progress()
	check(resumed.status == "active" and resumed.step == 3,"completed parking lesson survives a restart")
	if "--hall-only" in OS.get_cmdline_user_args(): await finish(); return
	await click(tutorial.view.secondary)
	check(tutorial.view.key == "ready_compact" and tutorial.view.primary.visible,"Practise more retains a compact way to start the first race")
	await capture("hall-practise-more")
	await click(tutorial.view.primary)
	if not await wait_game(false): await finish(); return
	var race: Node = app.game
	check(race.native_track.identity == "ellipse" and race.native_track.metadata.title == "Ellipse","tutorial races the existing Ellipse")
	var ellipse_source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://resources/cloud_tracks/893027446fb96e8a38a64b3143b033c04c15587b0364f6700fbda7985973defc.json"))
	check(race.native_track.metadata.creator_document == ellipse_source,"tutorial preserves the official Ellipse layout and objects")
	check(BuiltinTracks.ids() == ["ellipse","storm_freight","storm_switchyard","storm_timber","storm_quarry","storm_floodgate"] and not FileAccess.file_exists("res://resources/tracks/starter_circuit.json"),"Ellipse remains the lesson alongside the five original Storm circuits; Starter Circuit stays retired")
	check(race.track_session.target_laps == 5 and not race.editor_test and not race.attempt_practice,"first race keeps ordinary five-lap rules")
	check(bool(race.get_meta("tutorial_lesson",false)) and app.cloud_ticket.is_empty(),"bundled lesson is explicitly local with no verified ticket")
	check(race.resume_client == null and not race.hud.rewind_button.visible,"lesson offers no resource-consuming resume")
	race.open_rewind()
	check(not is_instance_valid(race.rewind_panel),"keyboard rewind cannot spend a lesson resource")
	var other: NativeTrack = NativeTrack.read("res://resources/tracks/ellipse.json")
	check(tutorial.authorizes(race.native_track) and not tutorial.authorizes(other),"same-ID documents cannot acquire tutorial launch authority")
	await capture("first-race-countdown")
	for tick: int in range(360): feed(race,DriveFrame.new())
	check(race.countdown_ticks == 0 and tutorial.view.key == "race_lap","countdown leads to checkpoint guidance")
	await capture("first-race-driving")
	print("TUTORIAL: real five-lap race")
	# Ellipse has a tyre wall across the centreline. Use the existing physical
	# detour driver so the native test steers around it with ordinary inputs.
	var traits: Dictionary = {"seed":7,"skill":0.7,"consistency":1.0,"aggression":0.5,"learning":0.5,"strengths":{}}
	var driver := ProfiledRouteDriver.new(traits,"pine",race.native_track.content_hash,0)
	driver.obstacle_detours = true
	# Detours follow the native route directly; no pilot optimisation is needed.
	driver.trajectory = RacingTrajectory.new()
	driver.trajectory.build(race.native_track,race.handling,"center")
	var ticks: int = 0
	while not race.track_session.finished and ticks < 48000:
		feed(race,driver.sample(race.sim.state,race.native_track,race.handling,race.track_session))
		ticks += 1
		if ticks%600 == 0: await frame()
		if race.paused:
			print("TUTORIAL: diagnostic race paused at simulation tick ",race.sim.state.tick," focus=",root.has_focus()," tutorial_background=",tutorial._backgrounded," pause_menu=",race.hud.pause_menu.visible)
			await capture("diagnostic-race-paused")
			break
	check(race.track_session.finished and race.track_session.completed_laps == 5,"real quantized driver finishes all five ordered laps")
	print("TUTORIAL: race ticks ",ticks," simulation_tick=",race.sim.state.tick," laps ",race.track_session.completed_laps," paused=",race.paused," position=",race.sim.state.position," speed=",race.sim.state.velocity.length())
	if not race.track_session.finished: await finish(); return
	for tick: int in range(600):
		if race.paused: break
		feed(race,DriveFrame.new())
	await frame(5)
	check(tutorial.progress.status == "completed" and tutorial.view.key.begins_with("result"),"normal results finish the tutorial and explain the PB")
	check(app.records.best_for(race.native_track,race.handling) > 0 and app.cloud_ticket.is_empty(),"completed five-lap time is saved locally")
	await capture("first-race-results")
	for dimensions: Vector2i in [Vector2i(960,540),Vector2i(1280,720)]:
		await resize(dimensions)
		await card_fits("results "+str(dimensions))
		await card_is_drawn("result instruction "+str(dimensions))
		var banner: Control = app.achievement_notification.find_child("AchievementBanner",true,false)
		if banner.is_visible_in_tree(): check(not tutorial.view.card.get_global_rect().intersects(banner.get_global_rect()),"result instruction clears the live achievement banner "+str(dimensions))
		check(not tutorial.view.card.get_global_rect().intersects(app.root_ui.find_child("RetryRace",true,false).get_global_rect()),"result instruction clears Race Again "+str(dimensions))
		await capture("results-%dx%d" % [dimensions.x,dimensions.y])
		var result_scroll: ScrollContainer = app.root_ui.find_child("TutorialResultScroll",true,false)
		var retry_action: Control = app.root_ui.find_child("RetryRace",true,false)
		result_scroll.ensure_control_visible(retry_action)
		await frame(3)
		check(Rect2(Vector2.ZERO,Vector2(dimensions)).encloses(retry_action.get_global_rect()),"first-race Retry is reachable on "+str(dimensions))
		await capture("results-footer-%dx%d" % [dimensions.x,dimensions.y])
	await resize(Vector2i(1280,720))
	await click(tutorial.view.primary)
	check(not tutorial.view.visible,"result tip dismisses without starting another race")
	app._retry_race()
	await frame(3)
	check(race.countdown_ticks > 0 and not app.root_ui.visible,"actual Retry retains a playable local race")
	check(race.rating_records == null,"retry cannot introduce a finish-rating prompt")
	# Exercise ordinary rewind presentation without confirming or funding any resume.
	race.set_meta("tutorial_lesson",false)
	for tick: int in range(360): feed(race,DriveFrame.new())
	for tick: int in range(240): feed(race,DriveFrame.sample(0,0.5,0))
	race.driver.clear()
	var rewind_count: int = race.online_rewinds.size()
	race.open_rewind()
	await frame(3)
	check(is_instance_valid(race.rewind_panel) and tutorial.view.key == "topic_rewind_0","first ordinary rewind opening teaches cancellation and confirmation")
	if is_instance_valid(race.rewind_panel):
		await capture("rewind-first-opening")
		await click(race.rewind_panel.cancel)
		check(not is_instance_valid(race.rewind_panel) and race.online_rewinds.size() == rewind_count,"cancelling the taught rewind spends no resume")
	race.set_meta("tutorial_lesson",true)
	app._leave_race()
	await frame(4)
	app._show_screen("settings")
	await frame(4)
	settings = app.root_ui.find_child("SettingsPage",true,false)
	settings._show_section("help")
	for topic: String in Progress.TOPICS:
		await click(settings.find_child("Help_"+topic,true,false))
		check(tutorial.view.key.begins_with("topic_"+topic),"Help opens "+topic)
		await capture("help-"+topic)
		while not tutorial._topic.is_empty(): await click(tutorial.view.primary)
		check(tutorial.progress.seen.has(topic),"dismissed "+topic+" is remembered")
	print("TUTORIAL: navigation fences")
	var saved_player: Dictionary = app.online.client.player.duplicate(true)
	var saved_status: String = tutorial.progress.status
	tutorial._offer_pending = true
	tutorial._running = true
	tutorial._result_id = 999
	tutorial.lesson_track = NativeTrack.read("res://resources/tracks/ellipse.json")
	app.online.client.player = {"id":"isolated-account-switch"}
	tutorial._process(0)
	check(not tutorial._running and not tutorial._offer_pending and tutorial.lesson_track == null and tutorial._result_id == 0 and not tutorial.view.visible,"account switch fences pending lessons, results and local launch authority")
	check(tutorial.progress.status == saved_status,"account changes never overwrite learning progress")
	app.online.client.player = saved_player
	tutorial._process(0)
	tutorial._offer_pending = true
	app.challenge_queued_invitation = "isolated-invitation"
	tutorial._process(0)
	check(not tutorial._offer_pending and not tutorial.view.visible,"incoming invitation takes precedence over onboarding")
	app.challenge_queued_invitation = ""
	var completed_progress: RefCounted = tutorial.progress
	tutorial.progress = Progress.new(directory.path_join("new-account-progress.json"))
	app.online.client.player = {"id":"isolated-completed-sign-in"}
	tutorial.offer()
	tutorial._process(0)
	check(tutorial._offer_pending and tutorial.view.key == "welcome" and tutorial.view.visible,"completed sign-in can offer the tutorial before the next process frame")
	tutorial.progress = completed_progress
	app.online.client.player = saved_player
	tutorial._process(0)
	await finish()

func finish() -> void:
	if is_instance_valid(app):
		app.queue_free()
		await frame(8)
	var report: Dictionary = {"checks":checks,"failures":failures,"failed":failed,"renderer":RenderingServer.get_current_rendering_method(),"display":DisplayServer.get_name(),"captures":snapshots,"fixtures":directory}
	if not output.is_empty():
		var file := FileAccess.open(output.path_join("test-report.json"),FileAccess.WRITE)
		file.store_string(JSON.stringify(report,"\t"))
		file.close()
	print("First-play tutorial: %d checks, %d failures" % [checks,failures])
	quit(1 if failures > 0 else 0)

func restore_task_start() -> void:
	var before_0: GDScript = load("res://ui/car_showroom.gd")
	before_0.source_code = FileAccess.get_file_as_string("res://../build/mobile-audit-fixes-2026-10-26/before/game/ui/car_showroom.gd")
	assert(before_0.reload(true)==OK)
	var before_1: GDScript = load("res://ui/garage_reflections.gd")
	before_1.source_code = FileAccess.get_file_as_string("res://../build/mobile-audit-fixes-2026-10-26/before/game/ui/garage_reflections.gd")
	assert(before_1.reload(true)==OK)
	var before_2: GDScript = load("res://ui/garage_page.gd")
	before_2.source_code = FileAccess.get_file_as_string("res://../build/mobile-audit-fixes-2026-10-26/before/game/ui/garage_page.gd")
	assert(before_2.reload(true)==OK)
	var before_3: GDScript = load("res://ui/race_pause_menu.gd")
	before_3.source_code = FileAccess.get_file_as_string("res://../build/mobile-audit-fixes-2026-10-26/before/game/ui/race_pause_menu.gd")
	assert(before_3.reload(true)==OK)
	var before_4: GDScript = load("res://ui/settings_page.gd")
	before_4.source_code = FileAccess.get_file_as_string("res://../build/mobile-audit-fixes-2026-10-26/before/game/ui/settings_page.gd")
	assert(before_4.reload(true)==OK)
	var before_5: GDScript = load("res://editor/track_document.gd")
	before_5.source_code = FileAccess.get_file_as_string("res://../build/mobile-audit-fixes-2026-10-26/before/game/editor/track_document.gd")
	assert(before_5.reload(true)==OK)
	var before_6: GDScript = load("res://race/attempt_evidence.gd")
	before_6.source_code = FileAccess.get_file_as_string("res://../build/mobile-audit-fixes-2026-10-26/before/game/race/attempt_evidence.gd")
	assert(before_6.reload(true)==OK)
	var before_7: GDScript = load("res://backend/cloud_tracks.gd")
	before_7.source_code = FileAccess.get_file_as_string("res://../build/mobile-audit-fixes-2026-10-26/before/game/backend/cloud_tracks.gd")
	assert(before_7.reload(true)==OK)
	var before_8: GDScript = load("res://core/app.gd")
	before_8.source_code = FileAccess.get_file_as_string("res://../build/mobile-audit-fixes-2026-10-26/before/game/core/app.gd")
	assert(before_8.reload(true)==OK)
	print("ISOLATED_TASK_START_SOURCES: 9 exact scripts restored only in this process memory")
