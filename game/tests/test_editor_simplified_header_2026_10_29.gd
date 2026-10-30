extends SceneTree
## Real App header with actual mouse input, resized while issues appear.
var app: Node
var checks: int = 0
var failures: int = 0
var folder: String

func _initialize() -> void: run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ",message)

func frames(count: int = 4) -> void:
	for i: int in range(count): await process_frame

func settle() -> void:
	var deadline: int = Time.get_ticks_msec()+60000
	while Time.get_ticks_msec()<deadline and (app.editor_preview_thread != null or app.editor_commits.unsettled() or app.editor_world._building):
		await process_frame
	check(app.editor_preview_thread == null and not app.editor_commits.unsettled(),"editor work settles")
	await frames(8)

func click(control: Control) -> void:
	var point: Vector2 = control.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	root.push_input(motion,true)
	await process_frame
	for down: bool in [true,false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		root.push_input(event,true)
		await process_frame
	await frames()

func tap(control: Control) -> void:
	var point: Vector2 = control.get_global_rect().get_center()
	for down: bool in [true,false]:
		var event := InputEventScreenTouch.new()
		event.index = 7
		event.position = point
		event.pressed = down
		Input.parse_input_event(event)
		await process_frame
	await frames()

func visible_buttons() -> Array[Control]:
	var result: Array[Control] = []
	var header: Control = app.root_ui.find_child("EditorIdentityAndHistory",true,false)
	var overlay: Control = app.root_ui.find_child("EditorOverlay",true,false)
	for node: Node in header.find_children("*","Button",true,false):
		if node.is_visible_in_tree(): result.append(node)
	for node: Node in overlay.find_child("EditorHistory",true,false).find_children("*","Button",true,false):
		if node.is_visible_in_tree(): result.append(node)
	for node: Node in overlay.get_children():
		if node is HBoxContainer and node != header:
			for item: Node in node.find_children("*","Button",true,false):
				if item.is_visible_in_tree(): result.append(item)
	var close: Control = app.root_ui.find_child("CloseEditor",true,false)
	result.append(close)
	return result

func layout(label: String) -> void:
	var buttons: Array[Control] = visible_buttons()
	check(buttons.has(app.editor_undo) and buttons.has(app.editor_redo),label+": both history controls visible")
	for i: int in range(buttons.size()):
		var rect: Rect2 = buttons[i].get_global_rect()
		check(root.get_visible_rect().encloses(rect),label+": target inside viewport: "+str(buttons[i].name))
		for j: int in range(i+1,buttons.size()):
			check(not rect.intersects(buttons[j].get_global_rect()),label+": no overlap: "+str(buttons[i].name)+" / "+str(buttons[j].name))
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var path: String = folder.path_join(label+".png")
		check(root.get_texture().get_image().save_png(path) == OK,"capture saves: "+label)

func run() -> void:
	folder = ProjectSettings.globalize_path("res://../docs/evidence/editor-header-responsive-2026-10-29")
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--evidence="): folder = argument.trim_prefix("--evidence=")
	if not folder.is_absolute_path():
		print("FAIL: evidence path must be absolute")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(folder)
	OS.set_environment("BMT_API_URL","")
	root.size = Vector2i(1280,720)
	root.content_scale_size = root.size
	app = load("res://core/app.tscn").instantiate()
	app.library = TrackLibrary.new(folder.path_join("storage/tracks"))
	app.records = LocalRecords.new(folder.path_join("storage/records.json"))
	app.cloud_root_override = folder.path_join("storage/cloud")
	root.add_child(app)
	var deadline: int = Time.get_ticks_msec()+60000
	while not app.startup_complete and Time.get_ticks_msec()<deadline: await process_frame
	check(app.startup_complete,"isolated guest startup completes")
	if not app.startup_complete: quit(1); return
	app.document = TrackDocument.create_blank()
	app.document.id = "header_review_track"
	app.document.name = "An especially long circuit name for UX"
	app._show_screen("create")
	await settle()
	# Create one undoable, open road; the two open ends make Issues visible.
	app.canvas.choose_piece("straight")
	app.canvas.confirm_piece()
	await settle()
	check(app.editor_issue_button.visible,"open road displays issue action")
	var with_road: Dictionary = app.document.duplicate(true)
	for dimensions: Vector2i in [Vector2i(1600,900),Vector2i(1280,720),Vector2i(960,540),Vector2i(900,506),Vector2i(960,540),Vector2i(1280,720)]:
		root.size = dimensions
		root.content_scale_size = dimensions
		await frames(8)
		await layout("header-%dx%d-issues" % [dimensions.x,dimensions.y])
		await click(app.editor_undo)
		await settle()
		check(app.document.pieces.is_empty(),"pointer Undo removes road at "+str(dimensions))
		check(not app.editor_map_panel.visible,"Undo does not open Map at "+str(dimensions))
		check(not app.editor_issue_button.visible,"resolved issues hide action at "+str(dimensions))
		await layout("header-%dx%d-clear" % [dimensions.x,dimensions.y])
		await click(app.editor_redo)
		await settle()
		check(app.document == with_road,"pointer Redo restores exact road at "+str(dimensions))
		check(app.editor_issue_button.visible,"issues return on Redo at "+str(dimensions))
	var title: Label = app.root_ui.find_child("TrackName",true,false)
	check(app.root_ui.find_child("TrackCreator",true,false) == null and title.custom_minimum_size.x == 160.0,"creator removed and title compact")
	check(not app.editor_save_button.visible and not app.editor_status.visible,"draft and guidance hidden")
	app._editor_hint("Action feedback")
	app._build_editor_tools()
	check(app.editor_status.visible and app.editor_status.text == "Action feedback","temporary feedback survives toolbar rebuild")
	await create_timer(4.2).timeout
	check(not app.editor_status.visible,"temporary feedback disappears")
	root.size = Vector2i(1600,900)
	root.content_scale_size = root.size
	await frames(8)
	var history: Control = app.root_ui.find_child("EditorHistory",true,false)
	check(absf(history.get_global_rect().get_center().x-800.0) < 1.0,"history centered on wide view")
	app.editor_save_error = ERR_CANT_CREATE
	app._update_editor_save_state()
	check(app.editor_save_button.visible and app.editor_status.visible,"save failure and retry remain visible")
	app.editor_save_error = OK
	app._update_editor_save_state()
	app.editor_status.hide()
	root.size = Vector2i(960,540)
	root.content_scale_size = root.size
	await frames(8)
	await tap(app.editor_undo)
	await settle()
	check(app.document.pieces.is_empty() and not app.editor_map_panel.visible,"viewport touch Undo removes the road without opening Map")
	await tap(app.editor_redo)
	await settle()
	check(app.document == with_road,"viewport touch Redo restores exact road")
	app.queue_free()
	await frames(5)
	print("EDITOR_SIMPLIFIED_HEADER: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
