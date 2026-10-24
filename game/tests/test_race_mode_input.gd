extends SceneTree
## Native input must survive animation completion and rapid rail selections.
var checks: int = 0
var failures: int = 0
var app: Node
var output: String
var timings: Array[Dictionary] = []

func _initialize() -> void: run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: "+message)

func frames(count: int = 3) -> void:
	for _index: int in range(count): await process_frame

func settle() -> void:
	if app.menu_page_motion != null: app._finish_menu_page_slide()
	await frames(5)

func rail_button(id: String) -> Button:
	var rail: Control = app.race_mode_transition_rail if is_instance_valid(app.race_mode_transition_rail) else app.content.find_child("RaceModes",true,false)
	return rail.find_child("Mode_"+id,true,false) as Button

func mouse(point: Vector2, down: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
	event.pressed = down
	root.push_input(event,true)

func touch(point: Vector2, down: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = 0
	event.position = point
	event.pressed = down
	root.push_input(event,true)

func capture(id: String) -> void:
	if output.is_empty() or DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(output.path_join(id+".png")) == OK,"capture "+id)

func run() -> void:
	OS.set_environment("BMT_API_URL","")
	output = OS.get_environment("BMT_RACE_MODE_INPUT_OUTPUT")
	if not output.is_empty(): DirAccess.make_dir_recursive_absolute(output)
	var directory: String = "user://race_mode_input_"+TrackLibrary.unique_id()
	app = load("res://core/app.tscn").instantiate()
	app.library = TrackLibrary.new(directory.path_join("tracks"))
	app.records = LocalRecords.new(directory.path_join("records.json"))
	app.cloud_root_override = directory.path_join("cloud")
	root.add_child(app)
	while not app.startup_complete: await process_frame
	app.rivalry.model = WeeklyRivalry.new(true)
	for dimensions: Vector2i in [Vector2i(1280,720),Vector2i(960,540)]:
		root.size = dimensions
		app._show_screen("tracks")
		await settle()
		# A mouse press starts on the temporary rail, then lifts after arrival.
		app._request_race_mode("rivalry")
		var rivalry_page: WeeklyRivalryPage = app.content.find_child("WeeklyRivalryPage",true,false)
		var podium_car: Node = rivalry_page.find_child("RivalryPodiumCar_1",true,false)
		var builds: int = rivalry_page.content_builds
		var motion: Tween = app.menu_page_motion
		motion.pause()
		await frames()
		motion.custom_step(0.28)
		var point: Vector2 = rail_button("target").get_global_rect().get_center()
		mouse(point,true)
		motion.custom_step(0.08)
		await frames()
		mouse(point,false)
		check(app.screen == "challenges","mouse rail selection survives the end of an arrival")
		await settle()
		check(is_instance_valid(rivalry_page) and not rivalry_page.is_visible_in_tree() and not rivalry_page.can_process(),"departed Rivalry stays retained, hidden and inactive")
		if is_instance_valid(podium_car):
			check(podium_car.viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED,"parked podium does not draw")
		# Rail actions acknowledge DOWN immediately, without waiting for lift.
		point = rail_button("flag").get_global_rect().get_center()
		touch(point,true)
		check(app.screen == "tracks","touch rail selection responds on press")
		touch(point,false)
		check(app.screen == "tracks","touch release does not select a second mode")
		await frames(2)
		# Real rapid presses interrupt movement and the final choice wins.
		for item: Array in [["trophy","rivalry"],["target","challenges"],["flag","tracks"],["target","challenges"],["trophy","rivalry"],["flag","tracks"]]:
			point = rail_button(item[0]).get_global_rect().get_center()
			var began: int = Time.get_ticks_usec()
			touch(point,true)
			check(app.screen == item[1],"rapid touch selects "+str(item[1])+" before release")
			touch(point,false)
			check(app.screen == item[1],"rapid touch release retains "+str(item[1]))
			if item[1] == "rivalry":
				check(app.content.find_child("WeeklyRivalryPage",true,false) == rivalry_page,"return retains the actual Rivalry page")
				check(is_instance_valid(rivalry_page) and rivalry_page.content_builds == builds,"unchanged Rivalry return avoids rebuilding its cars and controls")
			timings.append({"viewport":str(dimensions),"mode":item[1],"dispatch_ms":(Time.get_ticks_usec()-began)/1000.0})
			await frames(2)
		await settle()
		check(app.menu_body.position == Vector2.ZERO,"rapid input leaves the final page settled")
		check(not is_instance_valid(app.race_mode_transition_rail),"rapid input disposes the temporary rail")
		await capture("free-race-%dx%d" % [dimensions.x,dimensions.y])
		app.rivalry.error = "Offline input fixture"
		app._rivalry_changed()
		app._request_race_mode("rivalry")
		await settle()
		check(app.content.find_child("WeeklyRivalryPage",true,false) == rivalry_page,"settled return promotes the same cached page")
		check(rivalry_page.find_child("RivalryPodiumCar_1",true,false) == podium_car,"settled return retains the same rendered car")
		check((rivalry_page.find_child("RivalryStatusMessage",true,false) as Label).text == app.rivalry.error,"return applies status received while parked")
		check((rivalry_page.find_child("RaceModes",true,false) as Control).modulate.a == 1.0,"retained rail is visible after arrival")
		app.rivalry.error = ""
		app._rivalry_changed()
		await capture("reused-rivalry-%dx%d" % [dimensions.x,dimensions.y])
		app._request_race_mode("free")
		await settle()
		check(app._rivalry_parking.get_child_count() == 1,"retained page cache stays bounded to one page")
	# A parked page from another account cannot be promoted.
	var old_page: WeeklyRivalryPage = app._retained_rivalry_page
	app.online.client.player = {"id":"another-input-fixture"}
	app.online.client._access_token = "offline-fixture"
	app._request_race_mode("rivalry")
	check(app.content.find_child("WeeklyRivalryPage",true,false) != old_page,"account scope change discards the old retained page")
	await settle()
	await capture("rivalry-final")
	app.queue_free()
	await frames()
	if not output.is_empty():
		var file := FileAccess.open(output.path_join("input.json"),FileAccess.WRITE)
		file.store_string(JSON.stringify({"checks":checks,"failures":failures,"timings":timings},"\t"))
	print("RACE_MODE_INPUT: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
