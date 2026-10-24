extends SceneTree
const Keyboard = preload("res://ui/keyboard_dialog.gd")
var checks: int = 0
var failures: int = 0

func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)

func run() -> void:
	root.size = Vector2i(1280,720)
	var folder: String = "user://rename_dialog_"+TrackLibrary.unique_id()
	var app: Node = load("res://core/app.gd").new()
	app.library = TrackLibrary.new(folder)
	app.records = LocalRecords.new(folder.path_join("records.json"))
	app.cloud_root_override = folder.path_join("cloud")
	root.add_child(app)
	var deadline: int = Time.get_ticks_msec()+20000
	while not app.startup_complete and Time.get_ticks_msec()<deadline: await process_frame
	check(app.startup_complete,"isolated app startup completes")
	app.document = TrackDocument.create_default()
	app._show_screen("create")
	await process_frame
	app._rename_track()
	await process_frame
	var dialog: ConfirmationDialog = app.root_ui.find_child("RenameDialog",true,false)
	check(dialog != null,"the actual rename flow creates its dialog")
	if dialog != null:
		var field: LineEdit = dialog.find_child("CircuitName",true,false)
		check(field.has_focus() and field.virtual_keyboard_enabled,"the actual rename field owns keyboard focus")
		check(not dialog.find_children("*","Timer",true,false).is_empty(),"the actual dialog owns its KeyboardDialog layout timer")
		if DisplayServer.get_name() == "headless":
			for scale: float in [1.0,2.0,3.0]:
				var transform := Transform2D(Vector2(scale,0),Vector2(0,scale),Vector2.ZERO)
				var available: Rect2 = Keyboard.available_rect(Rect2(0,0,1280,720),transform,720*scale,320*scale)
				check(is_equal_approx(available.end.y,392) and available.size.y>=dialog.get_contents_minimum_size().y,"the current adapter reserves the full dialog at screen scale "+str(scale))
		else:
			for height: float in [0.0,240.0,320.0]:
				Keyboard.layout(dialog,root,height)
				var available: Rect2 = Keyboard.available_rect(root.get_visible_rect(),root.get_screen_transform(),DisplayServer.window_get_size().y,height)
				check(dialog.position.y>=available.position.y and dialog.position.y+dialog.size.y<=available.end.y+1.0,"the actual dialog clears the simulated keyboard at height "+str(height))
			for timer: Node in dialog.find_children("*","Timer",true,false): timer.process_mode = Node.PROCESS_MODE_DISABLED
			Keyboard.layout(dialog,root,320)
			for argument: String in OS.get_cmdline_user_args():
				if argument.begins_with("--evidence-root="):
					await RenderingServer.frame_post_draw
					check(root.get_texture().get_image().save_png(argument.trim_prefix("--evidence-root=").path_join("rename-keyboard.png"))==OK,"native rename capture is saved")
		field.text = "Retained rename"
		dialog.confirmed.emit()
		await process_frame
		check(app.document.name == "Retained rename","the actual Apply action retains the requested track name")
	app.queue_free()
	await process_frame
	print("RENAME_DIALOG: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
