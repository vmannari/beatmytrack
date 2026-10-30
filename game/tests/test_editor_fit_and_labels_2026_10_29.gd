extends SceneTree
## Real editor fit through viewport input plus road-control layout regressions.
var app: Node
var checks: int = 0
var failures: int = 0
var out: String

func _initialize() -> void: run.call_deferred()

func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ",what)

func frames(count: int = 3) -> void:
	for i: int in range(count): await process_frame

func click(control: Control) -> void:
	if control == null:
		check(false,"click target exists")
		return
	var point: Vector2 = control.get_global_rect().get_center()
	for down: bool in [true,false]:
		var event := InputEventMouseButton.new()
		event.position = point; event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT; event.pressed = down
		root.push_input(event,true)
		await process_frame
	await frames()

func tap(control: Control) -> void:
	if control == null:
		check(false,"tap target exists")
		return
	var point: Vector2 = control.get_global_rect().get_center()
	for down: bool in [true,false]:
		var event := InputEventScreenTouch.new()
		event.index = 7; event.position = point; event.pressed = down
		Input.parse_input_event(event)
		await process_frame
	await frames()

func settle() -> void:
	var deadline: int = Time.get_ticks_msec()+60000
	while Time.get_ticks_msec()<deadline and (app.canvas.preparing or app.editor_commits.unsettled() or app.editor_preview_thread != null or app.editor_world._building): await process_frame
	if app.canvas.preparing or app.editor_world._building: print("FIT_SETTLE_TIMEOUT canvas=",app.canvas.preparing," world=",app.editor_world._building," worker=",app.editor_preview_thread != null," commits=",app.editor_commits.unsettled())
	check(not app.canvas.preparing and not app.editor_world._building,"editor preparation completed")
	await frames(5)

func capture(name: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(out.path_join(name+".png")) == OK,"capture "+name)

func named(value: String) -> Control:
	return app.root_ui.find_child(value,true,false) as Control

func labels() -> void:
	var canvas := EditorCanvas.new()
	canvas.document = TrackDocument.create_blank()
	root.add_child(canvas)
	canvas.size = Vector2(1280,720)
	canvas.pan = Vector2.ZERO
	for kind: String in ["curve","hairpin","s_bend","bridge","taper"]:
		for heading: float in [0.0,45.0,135.0,270.0]:
			var piece: Dictionary = RoadPieces.create(kind,Vector2(-12,-6),heading,10)
			var positions: Dictionary = canvas.geometry_controls(piece)
			var captions: Dictionary = canvas.geometry_caption_rects(piece)
			var accept: Rect2 = canvas.piece_accept_rect(piece).grow(4)
			for key: String in canvas.geometry_keys(piece):
				var box: Rect2 = captions[key]
				check(not box.intersects(accept),kind+" "+key+" caption avoids acceptance at "+str(heading))
				check(Rect2(Vector2.ZERO,canvas.size).encloses(box),kind+" "+key+" caption remains visible at "+str(heading))
				for handle: Vector2 in positions.values():
					check(not box.intersects(Rect2(handle-Vector2(20,20),Vector2(40,40))),kind+" caption avoids handle")
			for first: String in captions:
				for second: String in captions:
					if first < second: check(not (captions[first] as Rect2).intersects(captions[second]),kind+" captions do not overlap")
	canvas.size = Vector2(960,540)
	canvas.fit_area = func() -> Rect2: return Rect2(400,84,544,182)
	canvas.document.paint = [{"width":4.0,"points":[[-110.0,-110.0],[110.0,110.0]]}]
	canvas.fit()
	var wide_area: Rect2 = canvas.fit_area.call()
	check(wide_area.has_point(canvas.to_screen(Vector2(-112,-112))) and wide_area.has_point(canvas.to_screen(Vector2(112,112))),"large maps fit into the uncovered area")
	var fitted_zoom: float = canvas.zoom
	canvas.zoom_by(1.15)
	check(canvas.zoom > fitted_zoom and canvas.zoom < 0.25,"zooming in from a large-map fit does not jump to the old minimum")
	canvas.queue_free()
	await frames()

func run() -> void:
	out = ProjectSettings.globalize_path("res://../docs/evidence/editor-usability-fixes-2026-10-29/fit-"+RenderingServer.get_current_rendering_method()+"-"+DisplayServer.get_name())
	DirAccess.make_dir_recursive_absolute(out)
	OS.set_environment("BMT_API_URL","")
	OS.set_environment("BMT_DEV_AUTH_KEY","")
	root.size = Vector2i(1280,720); root.content_scale_size = root.size
	await labels()
	app = load("res://core/app.tscn").instantiate()
	app.library = TrackLibrary.new(out.path_join("storage/tracks"))
	app.records = LocalRecords.new(out.path_join("storage/records.json"))
	app.cloud_root_override = out.path_join("storage/cloud")
	root.add_child(app)
	while not app.startup_complete: await process_frame
	var doc: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/editor_review_user_track.json"))
	doc.id = "fit_usability_fixture"
	app.document = doc
	app._show_screen("create")
	await settle()
	await click(named("EditorObjects"))
	await click(named("ObjectSizeControl"))
	for dimensions: Vector2i in [Vector2i(1280,720),Vector2i(960,540)]:
		root.size = dimensions; root.content_scale_size = dimensions
		await frames(8)
		check(not app.editor_status.get_global_rect().intersects(named("EditorRailPanel").get_global_rect()),"feedback does not cover the tool rail "+str(dimensions))
		check(app.object_controls_panel.size.y <= 100,"object strip remains compact "+str(dimensions))
		check(not app.object_controls_panel.get_global_rect().intersects(app.object_browser.get_global_rect()),"object strip does not cover palette "+str(dimensions))
		# Open the real Map menu and activate its touch-visible Fit view action.
		var menu: Control = null
		for button: Node in app.root_ui.find_children("*","Button",true,false):
			if button.text == "Map" and button.is_visible_in_tree(): menu = button; break
		if dimensions.x == 960 and DisplayServer.get_name() != "headless": await tap(menu)
		else: await click(menu)
		var fit_button: Control = named("EditorFitView")
		check(fit_button != null and fit_button.is_visible_in_tree(),"Fit view is available in Map at "+str(dimensions))
		var before: Dictionary = app.document.duplicate(true)
		if dimensions.x == 960 and DisplayServer.get_name() != "headless": await tap(fit_button)
		else: await click(fit_button)
		await frames(5)
		check(app.document == before,"fitting the viewport leaves the track unchanged")
		var area: Rect2 = app._editor_fit_area()
		check(area.size.x >= 40 and area.size.y >= 40,"usable fit area remains positive "+str(dimensions))
		check(area.end.y <= app.object_controls_panel.get_global_rect().position.y-app.canvas.get_global_rect().position.y,"fit area ends above object controls")
		for piece: Dictionary in doc.pieces:
			for point: Vector2 in RoadPieces.samples(piece):
				var margin := Vector2.ONE*float(piece.width)*0.5
				check(area.has_point(app.canvas.to_screen(point-margin)) and area.has_point(app.canvas.to_screen(point+margin)),"road fits exposed canvas "+str(dimensions))
		await capture("fitted-objects-%dx%d" % [dimensions.x,dimensions.y])
		print("EDITOR_FIT_AREA ",dimensions," ",area," zoom=",app.canvas.zoom)
	await click(named("EditorRoad"))
	for dimensions: Vector2i in [Vector2i(1280,720),Vector2i(960,540)]:
		root.size = dimensions; root.content_scale_size = dimensions
		await frames(8)
		app.canvas.fit()
		app.canvas.choose_piece("curve")
		await frames(5)
		var area: Rect2 = app._editor_fit_area()
		var captions: Dictionary = app.canvas.geometry_caption_rects(app.canvas.ghost)
		for key: String in captions:
			check(area.encloses(captions[key]),"curve caption remains in unobscured area "+str(dimensions)+" "+key)
			check(not (captions[key] as Rect2).intersects(app.canvas.piece_accept_rect(app.canvas.ghost)),"curve caption clears acceptance")
		await capture("curve-labels-%dx%d" % [dimensions.x,dimensions.y])
	await click(named("EditorSurface"))
	await frames(5)
	print("EDITOR_SURFACE_RECTS feedback=",app.editor_status.get_global_rect()," toolbar=",app.surface_toolbar.get_global_rect())
	await capture("surface-guidance-960x540")
	check(not app.editor_status.get_global_rect().intersects(named("EditorRailPanel").get_global_rect()),"surface guidance clears the tool rail")
	check(not app.editor_status.get_global_rect().intersects(app.surface_toolbar.get_global_rect()),"surface guidance clears paint controls")
	check(not app.editor_save_button.get_global_rect().intersects(app.surface_toolbar.get_global_rect()),"save status clears paint controls")
	app.canvas.fit()
	var paint_area: Rect2 = app._editor_fit_area()
	for piece: Dictionary in doc.pieces:
		for point: Vector2 in RoadPieces.samples(piece):
			check(paint_area.has_point(app.canvas.to_screen(point)),"painting fit keeps roads clear of toolbars")
	app.queue_free()
	await frames(5)
	print("EDITOR_FIT_LABELS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
