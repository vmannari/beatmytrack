extends SceneTree
## Actual rail activation, both vertical directions, refreshes and interrupted slides.
var checks: int = 0
var failures: int = 0
var app: Node
var evidence: String = ""

func _initialize() -> void: call_deferred("run")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		print("FAIL: "+message)

func settle() -> void:
	await create_timer(0.4).timeout
	for _frame: int in range(3): await process_frame

func midpoint() -> void:
	# Inspect a fixed tween position even when first-frame rendering is expensive.
	var motion: Tween = app.menu_page_motion
	motion.pause()
	for _frame: int in range(2): await process_frame
	motion.custom_step(0.16)

func capture(id: String, dimensions: Vector2i) -> void:
	if evidence.is_empty() or DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(evidence.path_join(id+"-%dx%d.png" % [dimensions.x,dimensions.y])) == OK,"capture "+id)

func visible_rails(node: Node) -> int:
	var count: int = 0
	if node is RaceModeRail and node.is_visible_in_tree() and node.modulate.a > 0.0: count += 1
	for child: Node in node.get_children(): count += visible_rails(child)
	return count

func run() -> void:
	OS.set_environment("BMT_API_URL","")
	evidence = OS.get_environment("BMT_RACE_MODE_CAPTURE_DIR")
	if not evidence.is_empty(): DirAccess.make_dir_recursive_absolute(evidence)
	var directory: String = "user://race_mode_carousel_"+TrackLibrary.unique_id()
	DirAccess.make_dir_recursive_absolute(directory)
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
		var header: Rect2 = app.root_ui.find_child("MenuHeader",true,false).get_global_rect()
		var rail: Rect2 = app.content.find_child("RaceModes",true,false).get_global_rect()
		var old_body: Control = app.menu_body
		var page_height: float = app.menu_body_slot.size.y
		(app.content.find_child("Mode_trophy",true,false) as Button).pressed.emit()
		check(app.screen == "rivalry" and app.menu_body.position.y < 0.0,"higher rail destination enters from above")
		check(app.outgoing_menu_page == old_body and not old_body.can_process(),"departing race page is retained without active input")
		check(is_zero_approx(app.menu_body.position.x),"Race mode change has no horizontal movement")
		check(is_equal_approx(absf(app.menu_body.position.y),page_height+app.MENU_PAGE_GAP),"carousel starts one whole viewport away")
		await midpoint()
		check(app.menu_body.position.y < 0.0 and old_body.position.y > 0.0,"both pages roll in the same vertical direction")
		check(app.root_ui.find_child("MenuHeader",true,false).get_global_rect().is_equal_approx(header),"top navigation stays fixed")
		check(app.race_mode_transition_rail.get_global_rect().is_equal_approx(rail),"mode rail stays fixed")
		check(app.menu_body_slot.clip_contents and app.menu_body.clip_contents,"moving pages stay clipped below the header")
		app.rivalry.changed.emit()
		check((app.content.find_child("RaceModes",true,false) as Control).modulate.a == 0.0,"background response keeps the moving copy of the rail hidden")
		check(visible_rails(app.menu_body_slot) == 1,"only the stationary mode rail is drawn")
		await capture("toward-rivalry",dimensions)
		app.menu_page_motion.play()
		await settle()
		check(app.menu_body.position == Vector2.ZERO and not is_instance_valid(app.outgoing_menu_page),"vertical transition settles and disposes departing content")
		check(not is_instance_valid(app.race_mode_transition_rail) and (app.content.find_child("RaceModes",true,false) as Control).modulate.a == 1.0,"real destination rail becomes active at rest")
		await capture("rivalry",dimensions)
		(app.content.find_child("Mode_flag",true,false) as Button).pressed.emit()
		check(app.screen == "tracks" and app.menu_body.position.y > 0.0,"lower rail destination enters from below")
		await midpoint()
		check(app.menu_body.position.y > 0.0 and app.outgoing_menu_page.position.y < 0.0,"reverse transition rolls upward (incoming %s, outgoing %s)" % [app.menu_body.position,app.outgoing_menu_page.position])
		await capture("toward-free-race",dimensions)
		# A new rail action interrupts the first movement cleanly.
		app._request_race_mode("challenges")
		check(app.screen == "challenges" and app.menu_body.position.y > 0.0,"rapid mode selection rolls directly to Challenges")
		app.challenges.changed.emit()
		check(visible_rails(app.menu_body_slot) == 1,"challenge responses preserve the stationary rail during movement")
		await midpoint()
		await capture("toward-challenges",dimensions)
		app.menu_page_motion.play()
		await settle()
		check(app.content.find_child("ChallengesPage",true,false) != null,"Challenges remains actionable after its slide")
		await capture("challenges",dimensions)
		(app.content.find_child("Mode_trophy",true,false) as Button).pressed.emit()
		check(app.menu_body.position.y < 0.0,"skipping over Free Race retains the rail order")
		await create_timer(0.04).timeout
		app._navigate_menu_page("garage")
		check(app.screen == "garage" and is_zero_approx(app.menu_body.position.y),"primary page navigation interrupts vertical movement")
		check(not is_instance_valid(app.race_mode_transition_rail),"leaving Race removes the temporary mode rail")
		await settle()
		check(app.menu_body.position == Vector2.ZERO,"primary horizontal navigation settles at its normal position")
	app.queue_free()
	await process_frame
	await create_timer(0.1).timeout
	print("RACE_MODE_CAROUSEL: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
