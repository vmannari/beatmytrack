extends SceneTree
## Real App touches must pass through the persistent achievement overlay.
var checks: int = 0
var failures: int = 0
var app: Node
var output: String = ""

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		print("FAIL: " + message)

func touch(point: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.position = point
	event.pressed = pressed
	root.push_input(event, true)

func swipe(point: Vector2, distance: float) -> void:
	touch(point, true)
	var event := InputEventScreenDrag.new()
	event.position = point + Vector2(distance, 0)
	root.push_input(event, true)
	touch(event.position, false)
	await settle()

func settle() -> void:
	for i: int in range(8): await process_frame
	await create_timer(0.65).timeout

func capture(title: String) -> void:
	if output.is_empty() or DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(output)
	check(root.get_texture().get_image().save_png(output.path_join(title + ".png")) == OK, "capture " + title)

func run() -> void:
	OS.set_environment("BMT_API_URL", "")
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output = ProjectSettings.globalize_path(argument.trim_prefix("--output="))
	var directory: String = "user://page_swipe_notifications_" + TrackLibrary.unique_id()
	DirAccess.make_dir_recursive_absolute(directory)
	app = load("res://core/app.tscn").instantiate()
	app.library = TrackLibrary.new(directory)
	app.records = LocalRecords.new(directory.path_join("records.json"))
	app.cloud_root_override = directory.path_join("cloud")
	root.add_child(app)
	while not app.startup_complete: await process_frame
	app.race_area_mode = "free"
	app._show_screen("tracks")
	await settle()
	var overlay: CanvasLayer = app.get_node("AchievementOverlayLayer")
	var handler: Node = app.root_ui.get_node("MenuPageSwipe")
	check(overlay.visible, "persistent achievement layer exists and is visible")
	check(not handler._modal_open(app), "idle notification layer does not block navigation")
	# Native tooltips are mouse-transparent windows, rather than modal dialogs.
	var tooltip := PopupPanel.new()
	tooltip.set_flag(Window.FLAG_MOUSE_PASSTHROUGH, true)
	app.root_ui.add_child(tooltip)
	tooltip.show()
	check(tooltip.visible and not handler._modal_open(tooltip), "input-transparent tooltip does not block navigation")
	tooltip.hide()
	tooltip.queue_free()
	await settle()
	for dimensions: Vector2i in [Vector2i(1280,720), Vector2i(960,540)]:
		root.size = dimensions
		await settle()
		var point: Vector2 = app.root_ui.find_child("MenuHeader",true,false).get_child(0).get_global_rect().get_center()
		await swipe(point, -90)
		check(app.screen == "biome", "left swipe opens Create at " + str(dimensions))
		await capture("create-%d" % dimensions.x)
		await swipe(point, 90)
		check(app.screen == "tracks", "right swipe returns to Race at " + str(dimensions))
		# A visible award is decorative too; it must not disable the whole menu.
		app.achievement_notification._card.show()
		check(not handler._modal_open(app), "visible award does not become a modal")
		await swipe(point, -90)
		check(app.screen == "biome", "page swipe works while award is visible")
		app.achievement_notification._card.hide()
		# Passthrough on the notification layer must still inspect real modals.
		var dialog := AcceptDialog.new()
		overlay.add_child(dialog)
		dialog.popup_centered()
		await swipe(point, 90)
		check(app.screen == "biome", "dialog beneath passthrough layer blocks swipe")
		dialog.queue_free()
		await settle()
		var drawer := CanvasLayer.new()
		drawer.layer = 40
		app.root_ui.add_child(drawer)
		await swipe(point, 90)
		check(app.screen == "biome", "ordinary modal layer still blocks swipe")
		drawer.queue_free()
		await settle()
		await swipe(point, 90)
		check(app.screen == "tracks", "closing modal restores swipe")
		await capture("race-%d" % dimensions.x)
	app.queue_free()
	await process_frame
	print("PAGE_SWIPE_NOTIFICATIONS: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
