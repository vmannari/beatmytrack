extends SceneTree
## Actual-App inspector interactions, isolated saves and native layout captures.
var app: Node
var checks: int = 0
var failures: int = 0
var folder: String
var captures: Array[String] = []

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ",label)

func frames(count: int = 3) -> void:
	for index: int in range(count): await process_frame

func settle() -> void:
	var deadline: int = Time.get_ticks_msec()+30000
	while (app.canvas.preparing or app.editor_commits.unsettled() or app.editor_preview_thread != null or app.editor_world._building) and Time.get_ticks_msec()<deadline: await process_frame
	check(not app.canvas.preparing and not app.editor_commits.unsettled(),"edit settles before another gesture")
	await frames()

func press(window: Window, node_name: String) -> void:
	var button: BaseButton = window.find_child(node_name,true,false)
	check(button != null,"control exists: "+node_name)
	if button == null: return
	# Deliver actual pointer events through the embedded inspector viewport.
	var point: Vector2 = Vector2(window.position)+button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	root.push_input(motion,true)
	await process_frame
	for down: bool in [true,false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		event.position = point
		event.global_position = point
		root.push_input(event,true)
		await process_frame

func shot(label: String, popup: Window = null) -> void:
	await frames(5)
	if popup != null:
		var rect := Rect2(Vector2(popup.position),Vector2(popup.size))
		check(root.get_visible_rect().encloses(rect),"inspector is inside viewport: "+label)
		var done: Control = popup.find_child("DoneProperties",true,false)
		check(Rect2(Vector2.ZERO,Vector2(popup.size)).encloses(done.get_global_rect()),"Done stays reachable: "+label)
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	var path: String = folder.path_join(label+".png")
	check(root.get_texture().get_image().save_png(path) == OK,"capture: "+label)
	captures.append(path)

func open(kind: String) -> Window:
	app.object_browser.choose(kind)
	app.object_browser.open_properties()
	await frames()
	return app.object_browser.options

func run() -> void:
	create_timer(150).timeout.connect(func() -> void: print("OBJECT_PROPERTIES_TIMEOUT"); quit(2))
	OS.set_environment("BMT_API_URL","")
	folder = ProjectSettings.globalize_path("res://../docs/evidence/object-properties-2026-10-28/")+DisplayServer.get_name()+"-"+RenderingServer.get_current_rendering_method()
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
	doc.id = "object_properties_review"
	doc["automatic_scenery"] = false
	doc.objects = [{"kind":"tree","position":[-18.0,10.0],"rotation":0.0,"scale":1.0},
		{"kind":"speed_bump","position":[18.0,12.0],"rotation":0.0,"span":8.0},
		{"kind":"container","position":[-18.0,-12.0],"rotation":45.0,"color":ContainerPaint.DEFAULT}]
	app.document = doc
	app._show_screen("create")
	var deadline: int = Time.get_ticks_msec()+30000
	while (app.editor_preview_thread != null or app.editor_world._building) and Time.get_ticks_msec()<deadline: await process_frame
	check(app.editor_preview_thread == null and not app.editor_world._building,"editor preparation settles")
	app._editor_category("objects")
	await frames()
	check(app.object_browser.properties_button.is_visible_in_tree(),"Properties has an explicit visible entry")
	await shot("01-palette")
	var popup: Window = await open("tree")
	var before: Dictionary = app.document.duplicate(true)
	var history_size: int = app.history.size()
	await press(popup,"ObjectSize_2")
	check(is_equal_approx(app.canvas.stamp_scale,1.5),"pointer selection changes placement size")
	check((popup.find_child("ObjectDimensions",true,false) as Label).text.contains("4.5"),"size readout describes actual footprint")
	await press(popup,"TurnRight")
	check(app.canvas.stamp_rotation == 22.5,"orientation button changes placement angle")
	var field: SpinBox = popup.find_child("RotationAngle",true,false)
	field.get_line_edit().text = "13.37"
	await press(popup,"DoneProperties")
	check(is_equal_approx(app.canvas.stamp_rotation,13.37),"Done accepts typed angle without Enter")
	app.object_browser._activate_asset("tree")
	await frames()
	popup = app.object_browser.options
	check(app.canvas.stamp_scale == 1.5 and is_equal_approx(app.canvas.stamp_rotation,13.37),"reopening preserves size and orientation")
	check(app.document == before and app.history.size() == history_size,"placement defaults never alter placed objects or undo history")
	await shot("02-size-orientation",popup)
	popup.hide()
	await settle()
	var object_count: int = app.document.objects.size()
	var point: Vector2 = app.canvas.to_screen(Vector2(32,-20))
	app.canvas._begin(point,11)
	app.canvas._end(11)
	check(app.document.objects.size() == object_count+1,"actual placement creates one object")
	check(app.document.objects[-1].kind == "tree" and app.document.objects[-1].scale == 1.5 and is_equal_approx(app.document.objects[-1].rotation,13.37),"actual placement uses inspector size and angle")
	app._undo()
	check(app.document.objects.size() == object_count,"placement undoes as one action")
	await settle()
	popup = await open("guardrail")
	await press(popup,"Placement_curve")
	check(app.canvas.mode == "run" and app.canvas.run_shape == "curve","Curve card selects the actual curve tool")
	check(not (popup.find_child("RotationAngle",true,false) as SpinBox).editable,"automatic run orientation cannot be edited")
	popup.hide()
	app.object_browser._activate_asset("guardrail")
	await frames()
	popup = app.object_browser.options
	check(app.object_browser.placement == "curve" and app.canvas.mode == "run","reopening preserves fence placement")
	await shot("03-fence-curve",popup)
	var help: Control = popup.get("placement_hint")
	check((popup.get("scroll") as Control).get_global_rect().encloses(help.get_global_rect()),"run instructions fit without scrolling at desktop size")
	popup.hide()
	await settle()
	object_count = app.document.objects.size()
	app.canvas._begin(app.canvas.to_screen(Vector2(24,-18)),12)
	app.canvas._move(app.canvas.to_screen(Vector2(32,-18)))
	app.canvas._move(app.canvas.to_screen(Vector2(40,-10)))
	app.canvas._end(12)
	check(app.document.objects.size() > object_count,"actual curve gesture creates a fence run")
	app._undo()
	check(app.document.objects.size() == object_count,"the whole fence run undoes as one action")
	await settle()
	app.object_browser.open_properties()
	await frames()
	popup = app.object_browser.options
	await press(popup,"Placement_road_edge")
	check(not app.canvas.free_run,"Road edge uses production road alignment")
	await shot("04-fence-road-edge",popup)
	await press(popup,"Placement_single")
	check(app.canvas.mode == "place" and (popup.find_child("RotationAngle",true,false) as SpinBox).editable,"Single restores manual orientation")
	popup.hide()
	popup = await open("rock")
	var variants: OptionButton = popup.find_child("ObjectVariant",true,false)
	variants.select(1)
	variants.item_selected.emit(1)
	await frames(5)
	check(app.canvas.stamp_kind == "boulder","variant selects Boulder")
	app.object_browser.options.hide()
	app.object_browser._activate_asset("rock")
	await frames()
	check(app.canvas.stamp_kind == "boulder" and app.object_browser.options.visible,"family reselect preserves variant and opens properties")
	await shot("05-boulder",app.object_browser.options)
	app.object_browser.options.hide()
	popup = await open("cliff")
	check(app.canvas.stamp_scale == 2.0,"cliff defaults to its established 16 metre size")
	await press(popup,"ObjectSize_2")
	check(app.canvas.stamp_scale == 3.0 and (popup.find_child("ObjectDimensions",true,false) as Label).text.contains("24.0"),"large cliff preset retains the 24 metre footprint")
	popup.hide()
	popup = await open("speed_bump")
	var width: SpinBox = popup.find_child("SpeedBumpWidth",true,false)
	width.value = 12.25
	check(app.canvas.stamp_span == 12.25 and popup.find_child("ObjectSize_0",true,false) == null,"speed bump changes width independently")
	await shot("06-speed-bump",popup)
	popup.hide()
	popup = await open("container")
	check(popup.find_child("ContainerColour",true,false) != null,"container exposes contextual paint")
	await shot("07-container",popup)
	popup.hide()
	# Selected object uses the same inspector, with real undo/redo transactions.
	app.canvas.mode = "objects"
	app.canvas.selected_object = 0
	app._build_editor_tools()
	app._selected_object_properties()
	await frames()
	popup = app.root_ui.find_child("SelectedObjectPropertiesPopup",true,false)
	history_size = app.history.size()
	await press(popup,"ObjectSize_2")
	check(app.document.objects[0].scale == 1.5 and app.history.size() == history_size+1,"selected size edit adds one undo step")
	await press(popup,"TurnRight")
	check(app.document.objects[0].rotation == 22.5 and app.history.size() == history_size+2,"selected rotation adds one undo step")
	await shot("08-selected-object",popup)
	popup.hide()
	await frames()
	app.canvas.selected_object = 1
	app.canvas.mode = "objects"
	app._selected_object_properties()
	await frames()
	popup = app.root_ui.find_child("SelectedObjectPropertiesPopup",true,false)
	history_size = app.history.size()
	width = popup.find_child("SpeedBumpWidth",true,false)
	width.value = 10.5
	check(CreatorObjects.size_of(app.document.objects[1]).y == 10.5 and app.history.size() == history_size+1,"selected width adds one undo step")
	await shot("08b-selected-speed-bump",popup)
	popup.hide()
	await frames()
	app._undo()
	check(CreatorObjects.size_of(app.document.objects[1]).y == 8.0,"speed bump width undo is exact")
	app.canvas.selected_object = 0
	app.canvas.mode = "objects"
	# Restore the two preceding property edits, then test their ordinary history.
	app._undo()
	check(app.document.objects[0].scale == 1.5 and app.document.objects[0].rotation == 0.0,"undo restores only orientation")
	app._undo()
	check(app.document.objects[0].scale == 1.0,"undo restores size")
	app._redo()
	app._redo()
	check(app.document.objects[0].scale == 1.5 and app.document.objects[0].rotation == 22.5,"redo restores both properties")
	app.canvas.selected_object = 0
	app.canvas.mode = "objects"
	app._selected_object_properties()
	await frames()
	popup = app.root_ui.find_child("SelectedObjectPropertiesPopup",true,false)
	app.canvas.selected_object = 2
	var other: Dictionary = app.document.objects[2].duplicate(true)
	(popup.find_child("TurnRight",true,false) as Button).pressed.emit()
	check(app.document.objects[2] == other,"stale inspector cannot modify a replacement selection")
	await frames()
	app.canvas.selected_object = -1
	app._editor_category("objects")
	# Landscape phone, tablet and portrait viewport bounds; native captures retain actual scale.
	for extent: Vector2i in [Vector2i(960,540),Vector2i(1920,1080),Vector2i(720,1000)]:
		root.size = extent
		root.content_scale_size = extent
		await frames(5)
		popup = await open("fence")
		await shot("09-fence-%dx%d" % [extent.x,extent.y],popup)
		check((popup.find_child("Placement_single",true,false) as Control).size.y >= 44,"placement cards retain touch target height")
		popup.hide()
	root.size = Vector2i(1280,720)
	root.content_scale_size = root.size
	for locale: String in ["fi","de"]:
		TranslationServer.set_locale(locale)
		await frames()
		popup = await open("fence")
		check(TranslationServer.translate("Placement properties") != "Placement properties","properties copy is translated: "+locale)
		await shot("10-localized-"+locale,popup)
		popup.hide()
	TranslationServer.set_locale("en")
	check(TrackDocument.validate(app.document).is_empty(),"edited document remains valid")
	check(app.library.save_document(app.document) == OK,"edited document saves")
	check(app.library.load_document(app.document.id).objects == JSON.parse_string(JSON.stringify(app.document.objects)),"all edits round trip through local storage")
	app.queue_free()
	await frames(5)
	GameSoundtrack.instance().queue_free()
	await create_timer(0.3).timeout
	var report := FileAccess.open(folder.path_join("result.json"),FileAccess.WRITE)
	report.store_string(JSON.stringify({"checks":checks,"failures":failures,"captures":captures},"\t"))
	report.close()
	print("OBJECT_PROPERTIES: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
