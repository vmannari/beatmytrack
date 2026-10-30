extends SceneTree
## Actual-App pointer/gesture review of the road-style object strip.
var app: Node
var checks: int = 0
var failures: int = 0
var folder: String
var captures: Array[String] = []
var layouts: Array[Dictionary] = []

func _initialize() -> void: run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ",message)

func frames(count: int = 3) -> void:
	for index: int in range(count): await process_frame

func settle() -> void:
	var deadline: int = Time.get_ticks_msec()+30000
	while (app.canvas.preparing or app.editor_commits.unsettled() or app.editor_preview_thread != null or app.editor_world._building) and Time.get_ticks_msec()<deadline: await process_frame
	check(not app.canvas.preparing and not app.editor_commits.unsettled(),"preparation settles before editing")
	await frames()

func named(node_name: String) -> Node:
	return app.root_ui.find_child(node_name,true,false)

func press(node_name: String) -> void:
	var control: Control = named(node_name)
	check(control != null and control.is_visible_in_tree(),"visible control: "+node_name)
	if control == null: return
	var point: Vector2 = control.get_global_rect().get_center()
	for down: bool in [true,false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		root.push_input(event,true)
		await process_frame

func shot(caption: String) -> void:
	await frames(5)
	var strip: Control = app.object_controls_panel
	check(root.get_visible_rect().encloses(strip.get_global_rect()),"strip stays inside viewport: "+caption)
	check(strip.size.y <= 100,"strip stays as compact as the road controls: "+caption)
	if app.object_browser.is_visible_in_tree(): check(not strip.get_global_rect().intersects(app.object_browser.get_global_rect()),"controls do not cover the palette: "+caption)
	check(named("ObjectOptionsPopup") == null and named("SelectedObjectPropertiesPopup") == null,"no object inspector window: "+caption)
	layouts.append({"caption":caption,"viewport":[root.size.x,root.size.y],"strip_position":[strip.position.x,strip.position.y],"strip_size":[strip.size.x,strip.size.y]})
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	var path: String = folder.path_join(caption+".png")
	check(root.get_texture().get_image().save_png(path) == OK,"native capture: "+caption)
	captures.append(path)

func choose(kind: String) -> void:
	app.object_browser.choose(kind)
	await frames()

func select(index: int) -> void:
	app.canvas.mode = "objects"
	app.canvas.multi_select = false
	app.canvas.selected_objects.clear()
	app.canvas.selected_object = index
	app._build_editor_tools()
	await frames()

func run() -> void:
	create_timer(160).timeout.connect(func() -> void: print("OBJECT_CONTROLS_TIMEOUT"); quit(2))
	folder = ProjectSettings.globalize_path("res://../docs/evidence/object-controls-inline-2026-10-28/")+DisplayServer.get_name()+"-"+RenderingServer.get_current_rendering_method()
	DirAccess.make_dir_recursive_absolute(folder)
	root.size = Vector2i(1280,720)
	root.content_scale_size = root.size
	app = load("res://core/app.tscn").instantiate()
	app.library = TrackLibrary.new(folder.path_join("disposable-storage"))
	app.records = LocalRecords.new(folder.path_join("disposable-storage/records.json"))
	app.cloud_root_override = folder.path_join("disposable-storage/cloud")
	root.add_child(app)
	while not app.startup_complete: await process_frame
	var doc: Dictionary = TrackDocument.create_default()
	doc.id = "inline_object_controls"
	doc["automatic_scenery"] = false
	doc.objects = [{"kind":"tree","position":[-18.0,10.0],"rotation":0.0,"scale":1.0},
		{"kind":"speed_bump","position":[18.0,12.0],"rotation":0.0,"span":8.0},
		{"kind":"container","position":[-18.0,-12.0],"rotation":45.0,"color":ContainerPaint.DEFAULT}]
	app.document = doc
	app._show_screen("create")
	await settle()
	app._editor_category("objects")
	await choose("tree")
	check(app.object_controls.is_visible_in_tree() and not app.object_controls is Window,"controls are available immediately in the editor")
	await shot("01-placement-controls")
	var before: Dictionary = app.document.duplicate(true)
	var history_size: int = app.history.size()
	await press("ObjectSizeControl")
	await press("ObjectSize_2")
	check(app.canvas.stamp_scale == 1.5,"Large changes placement size")
	await shot("02-size-adjustment")
	await press("ObjectControlsBack")
	await press("ObjectOrientation")
	await press("ObjectIncrease")
	check(app.canvas.stamp_rotation == 22.5,"road-style increment changes orientation")
	var angle: SpinBox = named("RotationAngle")
	angle.get_line_edit().text = "13.37"
	await press("ObjectControlsBack")
	check(is_equal_approx(app.canvas.stamp_rotation,13.37),"Back accepts typed free angle without Enter")
	app.object_browser._activate_asset("tree")
	check(app.canvas.stamp_scale == 1.5 and is_equal_approx(app.canvas.stamp_rotation,13.37),"reselecting the asset preserves size and orientation")
	check(app.document == before and app.history.size() == history_size,"placement defaults do not change existing objects or history")
	await settle()
	var count: int = app.document.objects.size()
	var point: Vector2 = app.canvas.to_screen(Vector2(32,-20))
	app.canvas._begin(point,11); app.canvas._end(11)
	check(app.document.objects.size() == count+1 and app.document.objects[-1].scale == 1.5 and is_equal_approx(app.document.objects[-1].rotation,13.37),"map remains usable for placement with the strip visible")
	app._undo()
	await settle()
	check(app.document.objects.size() == count,"placement has one exact undo")
	await choose("guardrail")
	await press("Placement_curve")
	check(app.canvas.mode == "run" and app.canvas.run_shape == "curve" and (named("ObjectOrientation") as Button).disabled,"Curve selects a run and communicates automatic orientation")
	await shot("03-fence-curve")
	app.object_browser._activate_asset("guardrail")
	check(app.object_browser.placement == "curve","reselecting a fence preserves placement mode")
	await settle()
	count = app.document.objects.size()
	app.canvas._begin(app.canvas.to_screen(Vector2(24,-18)),12)
	app.canvas._move(app.canvas.to_screen(Vector2(32,-18)))
	app.canvas._move(app.canvas.to_screen(Vector2(40,-10)))
	app.canvas._end(12)
	check(app.document.objects.size() > count,"map remains usable to draw a whole fence run")
	app._undo()
	await settle()
	check(app.document.objects.size() == count,"one undo removes the complete run")
	await press("Placement_road_edge")
	check(not app.canvas.free_run,"Road edge enables road alignment")
	await shot("04-road-edge")
	await press("Placement_single")
	check(app.canvas.mode == "place" and not (named("ObjectOrientation") as Button).disabled,"Single restores manual orientation")
	await choose("rock")
	var variant: OptionButton = named("ObjectVariant")
	variant.select(1); variant.item_selected.emit(1)
	check(app.canvas.stamp_kind == "boulder","visible variant choice selects Boulder")
	app.object_browser._activate_asset("rock")
	check(app.canvas.stamp_kind == "boulder","family reselect preserves variant")
	await choose("cliff")
	await press("ObjectSizeControl")
	await press("ObjectSize_2")
	check(app.canvas.stamp_scale == 3.0 and CreatorObjects.size_of(app.object_controls.state) == Vector2(24,9),"24 metre cliff preset remains exact")
	await press("ObjectControlsBack")
	await choose("speed_bump")
	await press("ObjectWidth")
	(named("SpeedBumpWidth") as SpinBox).value = 12.25
	check(app.canvas.stamp_span == 12.25,"bump width changes independently")
	await shot("05-width-adjustment")
	await select(0)
	history_size = app.history.size()
	await press("ObjectSizeControl")
	await press("ObjectSize_2")
	await press("ObjectControlsBack")
	await press("ObjectOrientation")
	await press("ObjectIncrease")
	check(app.document.objects[0].scale == 1.5 and app.document.objects[0].rotation == 22.5 and app.history.size() == history_size+2,"selected edits create one history entry per change")
	await shot("06-selected-orientation")
	await press("ObjectControlsBack")
	await shot("07-selected-object")
	app._undo()
	check(app.document.objects[0].scale == 1.5 and app.document.objects[0].rotation == 0.0,"undo restores orientation separately")
	app._undo()
	check(app.document.objects[0].scale == 1.0,"undo restores size")
	app._redo(); app._redo()
	check(app.document.objects[0].scale == 1.5 and app.document.objects[0].rotation == 22.5,"redo restores size and orientation")
	await select(0)
	await press("ObjectOrientation")
	var stale: Button = named("ObjectIncrease")
	app.canvas.selected_object = 2
	app._build_editor_tools()
	stale.pressed.emit()
	check(app.document.objects[2].rotation == 45.0,"retired controls cannot edit a new selection")
	await frames()
	await shot("08-container-controls")
	await select(1)
	await press("ObjectWidth")
	(named("SpeedBumpWidth") as SpinBox).value = 10.5
	check(CreatorObjects.size_of(app.document.objects[1]).y == 10.5,"selected bump width changes")
	app._undo()
	check(CreatorObjects.size_of(app.document.objects[1]).y == 8.0,"width undo is exact")
	app.canvas.selected_object = -1
	app._editor_category("objects")
	for extent: Vector2i in [Vector2i(960,540),Vector2i(1920,1080),Vector2i(720,1000)]:
		root.size = extent; root.content_scale_size = extent
		await frames(5)
		await choose("fence")
		await shot("09-fence-%dx%d" % [extent.x,extent.y])
		check((named("Placement_curve") as Control).size.y >= 44,"placement controls retain touch target size")
	root.size = Vector2i(1280,720); root.content_scale_size = root.size
	for locale: String in ["fi","de"]:
		TranslationServer.set_locale(locale)
		await choose("fence")
		await shot("10-fence-"+locale)
	TranslationServer.set_locale("en")
	check(TrackDocument.validate(app.document).is_empty(),"edited track remains valid")
	check(app.library.save_document(app.document) == OK,"edited track saves")
	check(app.library.load_document(app.document.id).objects == JSON.parse_string(JSON.stringify(app.document.objects)),"properties round trip through persistence")
	app.queue_free(); await frames(5)
	GameSoundtrack.instance().queue_free()
	await create_timer(0.3).timeout
	var report := FileAccess.open(folder.path_join("result.json"),FileAccess.WRITE)
	report.store_string(JSON.stringify({"checks":checks,"failures":failures,"captures":captures,"layouts":layouts},"\t")); report.close()
	print("OBJECT_CONTROLS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
