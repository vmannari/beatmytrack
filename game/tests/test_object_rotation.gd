extends SceneTree
const ROTATION = preload("res://editor/object_rotation.gd")
var checks: int = 0
var failures: int = 0
var app: Node
var out: String = ""

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ",label)

func wait_preview() -> void:
	var deadline: int = Time.get_ticks_msec()+20000
	while (app.editor_commits.unsettled() or app.editor_preview_thread != null or app.editor_world._building) and Time.get_ticks_msec()<deadline: await process_frame
	check(not app.editor_commits.unsettled() and app.editor_preview_thread == null and not app.editor_world._building,"editor preparation settles")

func capture(label: String) -> void:
	if out.is_empty() or DisplayServer.get_name() == "headless": return
	for i: int in range(3): await process_frame
	await RenderingServer.frame_post_draw
	var path: String = out.path_join(label+"-"+RenderingServer.get_current_rendering_method()+".png")
	check(root.get_texture().get_image().save_png(path) == OK,"native capture "+label)

func picker():
	app._object_rotation_dialog()
	return app.root_ui.find_child("ObjectRotationDialog",true,false)

func confirm(dialog) -> void:
	dialog.hide()
	dialog.confirmed.emit()
	for i: int in range(2): await process_frame

func cancel(dialog) -> void:
	dialog.hide()
	dialog.canceled.emit()
	for i: int in range(2): await process_frame

func run() -> void:
	root.size = Vector2i(1280,720)
	create_timer(90.0).timeout.connect(func() -> void: print("ROTATION_TEST_TIMEOUT"); quit(2))
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--rotation-evidence="): out = arg.trim_prefix("--rotation-evidence=")
	var folder: String = "user://object_rotation_"+TrackLibrary.unique_id()
	app = load("res://core/app.tscn").instantiate()
	app.library = TrackLibrary.new(folder)
	app.records = LocalRecords.new(folder.path_join("records.json"))
	root.add_child(app)
	while not app.startup_complete: await process_frame
	var doc: Dictionary = TrackDocument.create_default()
	doc.id = "rotation_test"
	doc["automatic_scenery"] = false
	doc.objects = [{"kind":"barrier","position":[12.0,12.0],"rotation":0.0,"scale":1.25},{"kind":"tree","position":[-18.0,12.0],"rotation":45.0}]
	check(TrackDocument.validate(doc).is_empty(),"rotation fixture is valid")
	app.document = doc
	app._show_screen("create")
	await wait_preview()
	app._editor_category("objects")
	app.canvas.selected_object = 0
	app.canvas.mode = "objects"
	app._build_editor_tools()
	var other: Dictionary = doc.objects[1].duplicate(true)
	for i: int in range(1,17):
		app._rotate_object()
		check(doc.objects[0].rotation == fposmod(i*22.5,360.0),"orientation "+str(i)+" uses the 16-direction grid")
	check(doc.objects[1] == other and doc.objects[0].scale == 1.25 and doc.objects[0].position == [12.0,12.0],"rotation preserves other objects, position and scale")
	app._undo()
	check(app.document.objects[0].rotation == 337.5,"undo restores previous orientation")
	app._redo()
	check(app.document.objects[0].rotation == 0.0,"redo restores wrapped orientation")
	app.canvas.selected_object = 0
	app._build_editor_tools()
	await wait_preview()
	await capture("selected-object")
	var history_size: int = app.history.size()
	var before: Dictionary = app.document.duplicate(true)
	var dialog = picker()
	check(dialog.presets.size() == 16 and dialog.free_button.text == "Free rotation","picker offers sixteen orientations and Free rotation")
	for i: int in range(16):
		dialog.presets[i].pressed.emit()
		check(dialog.angle == i*22.5 and not dialog.free_rotation,"preset "+str(i)+" selects its absolute angle")
	check(app.document == before and app.history.size() == history_size,"choosing angles is transactional until Apply")
	dialog.presets[3].pressed.emit()
	await capture("sixteen-orientations")
	await confirm(dialog)
	await process_frame
	check(app.document.objects[0].rotation == 67.5 and app.history.size() == history_size+1,"Apply commits exactly one rotation history entry")
	dialog = picker()
	dialog.free_button.pressed.emit()
	dialog.slider.value = 13.37
	check(dialog.free_rotation and is_equal_approx(dialog.field.value,13.37),"Free rotation synchronizes continuous slider and angle field")
	await cancel(dialog)
	await process_frame
	check(app.document.objects[0].rotation == 67.5 and app.history.size() == history_size+1,"Cancel leaves object and history unchanged")
	dialog = picker()
	dialog.free_button.pressed.emit()
	dialog.field.get_line_edit().text = "13.37"
	await confirm(dialog)
	await process_frame
	check(is_equal_approx(app.document.objects[0].rotation,13.37),"Apply accepts typed free angle without pressing Enter")
	app._undo()
	check(app.document.objects[0].rotation == 67.5,"free rotation has one exact undo step")
	app._redo()
	check(is_equal_approx(app.document.objects[0].rotation,13.37),"redo restores free angle")
	app.canvas.selected_object = 0
	app._rotate_object()
	check(app.document.objects[0].rotation == 22.5,"stepping from a free angle rejoins the absolute grid")
	app._set_object_rotation(359.99)
	app._rotate_object()
	check(app.document.objects[0].rotation == 0.0,"last free angle wraps to zero on the next step")
	dialog = picker()
	dialog.free_button.pressed.emit()
	dialog.field.value = 360.0
	check(dialog.angle == 0.0,"full-turn input normalizes to zero")
	dialog.field.value = 28.75
	await capture("free-rotation")
	for viewport: Vector2i in [Vector2i(960,540),Vector2i(1600,900)]:
		root.size = viewport
		await process_frame
		dialog.popup_centered_clamped(Vector2i(410,360))
		for i: int in range(3): await process_frame
		check(Rect2(Vector2.ZERO,root.get_visible_rect().size).encloses(Rect2(dialog.position,dialog.size)),"rotation dialog fits "+str(viewport)+" at "+str(Rect2i(dialog.position,dialog.size)))
		await capture("free-rotation-"+str(viewport.x))
	await confirm(dialog)
	await process_frame
	app._flush_editor_writes()
	var saved: Dictionary = app.library.load_wip(str(app.document.id))
	if saved.is_empty(): print("WIP_READ_ERROR ",app.library.directory," ",app.library.last_error," validation=",TrackDocument.validate(app.document)," save=",app.editor_save_message)
	check(not saved.is_empty() and saved.objects[0].rotation == 28.75,"free angle survives real WIP save/reload")
	check(TrackDocument.validate(saved).is_empty(),"fractional rotations retain valid track format")
	var saved_track: NativeTrack = TrackCompiler.compile(saved)
	var current_track: NativeTrack = TrackCompiler.compile(app.document)
	check(saved_track != null and current_track != null and saved_track.content_hash == current_track.content_hash,"reloaded fractional rotation retains compiled track identity")
	# New placement uses the same picker without editing existing objects.
	app._choose_object("barrier")
	history_size = app.history.size()
	dialog = picker()
	dialog.free_button.pressed.emit()
	dialog.field.value = 71.23
	await confirm(dialog)
	await process_frame
	if not is_equal_approx(app.canvas.stamp_rotation,71.23): print("PLACEMENT_ANGLE ",app.canvas.stamp_rotation," selection=",app.canvas.selected_object," history=",app.history.size()," previous=",history_size)
	check(is_equal_approx(app.canvas.stamp_rotation,71.23) and app.history.size() == history_size,"new-object angle changes placement state without history")
	check(app.document.objects[0].rotation == 28.75,"placement rotation leaves existing objects untouched")
	app._editor_category("road")
	app._editor_category("objects")
	check(is_equal_approx(app.canvas.stamp_rotation,71.23) and app.object_browser.rotation_button.text == "71.23°","tool switching retains placement angle and its label")
	var count: int = app.document.objects.size()
	app.canvas.mode = "place"
	var point: Vector2 = app.canvas.to_screen(Vector2(28,16))
	app.canvas._begin(point,0); app.canvas._end(0)
	check(app.document.objects.size() == count+1 and is_equal_approx(app.document.objects[-1].rotation,71.23),"actual touch placement uses the chosen free angle")
	await wait_preview()
	# A stale picker cannot rotate a different selection.
	app.canvas.mode = "objects"; app.canvas.selected_object = 0
	dialog = picker()
	dialog.presets[8].pressed.emit()
	app.canvas.selected_object = 1
	await confirm(dialog)
	await process_frame
	check(app.document.objects[1] == other,"stale picker cannot modify a replacement selection")
	app.queue_free()
	for i: int in range(4): await process_frame
	GameSoundtrack.instance().queue_free()
	await create_timer(0.3).timeout
	print("OBJECT_ROTATION_TESTS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
