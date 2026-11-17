extends "res://tests/test_editor_cohesion_2026_11_16.gd"

var measurements: Array = []

func bounds() -> void:
	super.bounds()
	if "--before" in OS.get_cmdline_user_args(): return
	var header: Control = app.root_ui.find_child("EditorTopBar",true,false)
	var dock: Control = app.root_ui.find_child("EditorToolDock",true,false)
	check(header.size.y <= 56,"header is at most 56 logical units")
	check(header.position.x == dock.position.x and header.size.x == dock.size.x,"shelves share both side margins")
	var rail: Control = app.root_ui.find_child("EditorRailPanel",true,false)
	check(rail.get_global_rect().position.y >= header.get_global_rect().end.y+8 and rail.get_global_rect().end.y <= dock.get_global_rect().position.y-8,"category rail stays clear of both shelves")
	measurements.append({"viewport":str(root.size),"mode":app.canvas.mode,"picker":app.object_browser.visible,"header_height":header.size.y,"dock_height":dock.size.y,"left":dock.position.x,"width":dock.size.x})
	if app.object_browser.visible:
		if not app.editor_hint_active and app.editor_save_error == OK: check(dock.size.y <= 144,"picker uses two compact rows")
		for tab: Control in app.object_browser.categories.get_children():
			if tab.visible: check(app.object_browser.categories.get_parent().get_global_rect().encloses(tab.get_global_rect()),"category is visible: "+tab.text)
	elif not app.editor_hint_active and not app.editor_loading.visible:
		if app.canvas.mode == "paint": check(dock.size.y <= 88,"surface shelf remains compact")
		elif app.canvas.mode in ["objects","place"]: check(dock.size.y <= 80,"object controls use a compact row")
	if app.canvas.mode == "paint":
		check(absf((app.root_ui.find_child("EditorDockBody",true,false) as Control).get_global_rect().get_center().x-dock.get_global_rect().get_center().x) <= 1,"painting tools form a centred group")
		var scroll: Control = app.editor_context.get_parent()
		for material: Control in app.editor_context.get_children():
			check(scroll.get_global_rect().encloses(material.get_global_rect()),"every material is visible without scrolling: "+material.text)
			check(material.size.y >= 48 and material.size.x >= 48,"material has a full touch target")
		for name: String in ["BrushSizeSlider","BrushSmaller","BrushBigger","SurfaceOptions","PaintMode_free","PaintMode_area","PaintMode_line"]:
			var control: Control = app.root_ui.find_child(name,true,false)
			if control != null and control.is_visible_in_tree():
				check(control.size.x >= 48 and control.size.y >= 48,"touch target retained: "+name)
	for control: Control in [app.editor_undo,app.editor_redo,app.test_button,app.root_ui.find_child("EditorDocumentName",true,false)]:
		check(control.size.x >= 48 and control.size.y >= 48,"header touch target retained: "+str(control.name))

func captures() -> void:
	await super.captures()
	if "--before" in OS.get_cmdline_user_args(): return
	root.size = Vector2i(960,540); root.content_scale_size = root.size
	for biome: String in ["winter","desert","night_city"]:
		await fixture()
		app.document.biome = biome; app.document.theme = biome
		app.canvas.refresh(); await settle()
		app._editor_category("paint"); await frames(8); bounds()
		await shot("08-materials-"+biome+"-960")
	root.size = Vector2i(1560,720); root.content_scale_size = root.size
	await fixture(); app._editor_category("objects"); await frames(8); bounds()
	await shot("09-object-picker-wide")
	app.editor_save_error = ERR_FILE_CANT_WRITE; app.editor_save_message = "Could not save: fixture failure"
	app._build_editor_tools(); await frames(8)
	var heading: Control = app.root_ui.find_child("EditorDockHeading",true,false)
	check(heading.visible and app.editor_save_button.is_visible_in_tree(),"save failure and Retry remain visible while browsing objects")
	check(app.editor_status.text == app.editor_save_message,"picker preserves the actual save error")
	app.editor_save_error = OK; app.editor_save_message = ""; app._build_editor_tools(); await frames(8)
	app._editor_hint("Tap an object to move, rotate or delete"); await frames(5)
	check(heading.visible and app.editor_status.text == "Tap an object to move, rotate or delete","transient feedback remains visible while browsing")
	app.editor_hint_active = false; app._build_editor_tools(); await frames(6)
	check(not heading.visible,"supplementary feedback row collapses after feedback ends")
	await click_named("EditorMoveView"); await frames(5)
	check(app.canvas.navigation_override and heading.visible and app.editor_status.text == app.editor_guidance,"Move view retains its visible navigation guidance")
	await click_named("EditorMoveView"); await frames(5)
	check(not app.canvas.navigation_override and not heading.visible,"returning to editing removes the temporary navigation guidance")

func document_flow() -> void:
	if "--before" in OS.get_cmdline_user_args(): return
	root.size = Vector2i(960,540); root.content_scale_size = root.size
	await fixture()
	app.document.name = "My circuit"; app.editor_saved_snapshot.clear(); app._build_editor_tools(); await frames(8)
	var original: Dictionary = app.document.duplicate(true)
	var count: int = app.history.size()
	var title: Label = app.root_ui.find_child("TrackName",true,false)
	check(title.text == GameText.message("New track"),"new sentinel draft is displayed as New track without changing its stored name")
	await click_named("EditorDocumentName"); await frames(5)
	var dialog: ConfirmationDialog = app.root_ui.find_child("RenameDialog",true,false)
	var field: LineEdit = dialog.find_child("CircuitName",true,false)
	check(field.text.is_empty() and dialog.get_ok_button().disabled,"new-track naming starts with an empty field and prevents blank confirmation")
	await shot("11-rename-960")
	field.text = "Uncommitted name"; dialog.canceled.emit(); await frames(5)
	check(app.document == original and app.history.size() == count,"cancelling naming preserves the exact document and history")
	await click_named("EditorDocumentName"); await frames(4)
	dialog = app.root_ui.find_child("RenameDialog",true,false)
	field = dialog.find_child("CircuitName",true,false)
	field.text = "Coastline Sprint"; field.text_changed.emit(field.text); dialog.confirmed.emit(); await settle()
	check(app.document.name == "Coastline Sprint" and title.text == "Coastline Sprint","confirmed naming updates the document and header")
	app._undo(); await settle()
	check(app.document == original and title.text == GameText.message("New track"),"one Undo restores the exact unnamed draft and header")
	app._redo(); await settle()
	check(app.document.name == "Coastline Sprint" and title.text == "Coastline Sprint","Redo restores naming")
	app.document.name = "My circuit"; app.editor_saved_snapshot = app.document.duplicate(true); app._build_editor_tools(); await frames(5)
	check(title.text == "My circuit","an already saved track named My circuit retains its real title")
	app._save_track_explicit(); await settle()
	check(app.root_ui.find_child("SaveChangesDialog",true,false) == null,"saving an already named sentinel track does not force another name")
	await fixture(); app.document.name = "My circuit"; app.editor_saved_snapshot.clear(); app._build_editor_tools(); await frames(5)
	original = app.document.duplicate(true); count = app.history.size()
	app._save_track_explicit(); await frames(5)
	dialog = app.root_ui.find_child("SaveChangesDialog",true,false)
	field = dialog.find_child("SaveDraftName",true,false)
	check(dialog.title == "Name your track" and field.text.is_empty(),"first Save explains naming and does not prefill the placeholder")
	await shot("10-first-save-name-960")
	field.text = "Cancelled save name"; dialog.canceled.emit(); await frames(5)
	check(app.document == original and app.history.size() == count,"cancelling first Save preserves the draft")
	app._save_track_explicit(); await frames(4)
	dialog = app.root_ui.find_child("SaveChangesDialog",true,false); field = dialog.find_child("SaveDraftName",true,false)
	field.text = "North Shore International Speedway"; field.text_changed.emit(field.text); dialog.confirmed.emit(); await settle()
	title = app.root_ui.find_child("TrackName",true,false)
	check(app.document.name == "North Shore International Speedway" and app.editor_saved_snapshot == app.document,"first Save persists the confirmed name and document")
	check(title.get_parent().get_global_rect().encloses(title.get_global_rect()),"long track title stays inside its document button")

func run() -> void:
	out = ProjectSettings.globalize_path("res://../docs/evidence/editor-space-2026-11-17/"+("before" if "--before" in OS.get_cmdline_user_args() else RenderingServer.get_current_rendering_method()))
	DirAccess.make_dir_recursive_absolute(out)
	OS.set_environment("BMT_API_URL",""); OS.set_environment("BMT_DEV_AUTH_KEY","")
	root.size=Vector2i(1280,720); root.content_scale_size=root.size; root.gui_embed_subwindows=true
	app=load("res://core/app.tscn").instantiate()
	var storage: String = ProjectSettings.globalize_path("res://../build/editor-space-2026-11-17/"+str(OS.get_process_id()))
	app.library=TrackLibrary.new(storage.path_join("tracks")); app.records=LocalRecords.new(storage.path_join("records.json")); app.cloud_root_override=storage.path_join("cloud")
	root.add_child(app)
	var deadline: int = Time.get_ticks_msec()+90000
	while not app.startup_complete and Time.get_ticks_msec()<deadline: await process_frame
	check(app.startup_complete,"isolated offline App starts")
	if app.startup_complete:
		await captures(); await document_flow(); await object_flow()
	await settle(); app.queue_free(); await frames(8)
	if is_instance_valid(GameSoundtrack.instance()): GameSoundtrack.instance().queue_free()
	await frames(3); await create_timer(0.3).timeout
	var file := FileAccess.open(out.path_join("report.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":fixture_checks,"failures":fixture_failures,"renderer":RenderingServer.get_current_rendering_method(),"measurements":measurements},"\t")); file.close()
	print("EDITOR_SPACE ",fixture_checks," checks / ",fixture_failures," failures")
	quit(0 if fixture_failures == 0 else 1)
