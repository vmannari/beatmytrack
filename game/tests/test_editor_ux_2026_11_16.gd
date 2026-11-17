extends "res://tests/review_editor_interactions_2026_11_14.gd"
## Offline UX acceptance sequences. Every persistent path belongs to this fixture.
var audit_only: bool = false

func shot(label: String) -> void:
	await frames(6)
	if DisplayServer.get_name() != "headless":
		check(root.get_texture().get_image().save_png(out.path_join(label+".png")) == OK,"capture "+label)

func audit() -> void:
	await show_fixture()
	await shot("01-road-idle-1280")
	app.canvas.choose_piece("curve")
	await shot("02-road-preview-1280")
	app.canvas.ghost.clear(); app._build_editor_tools()
	app.editor_map_panel.show()
	await shot("03-map-1280")
	app.editor_map_panel.hide(); app._editor_category("paint")
	app.canvas.paint_mode = "area"
	app.canvas.paint_points = [[0.0,-5.0],[20.0,-5.0],[20.0,-20.0]]
	app._build_editor_tools()
	await shot("04-surface-preview-1280")
	app.canvas.paint_points.clear()
	await choose_crate()
	await shot("05-object-place-1280")
	for dimensions: Vector2i in [Vector2i(960,540),Vector2i(1560,720)]:
		root.size = dimensions; root.content_scale_size = dimensions
		await frames(8)
		await shot("06-objects-"+str(dimensions.x))
	root.size = Vector2i(1280,720); root.content_scale_size = root.size
	await frames(8)
	# Capture deterministic before/after evidence without equating it to player testing.
	await show_fixture()
	app.canvas.mode = "place"; app.canvas.stamp_rotation = 137.5
	app.canvas.stamp_container_color = "#8b4134"; app.canvas.snap_enabled = false
	app.canvas.protect_road = false
	await app._show_screen("create"); await settle()
	record("round_trip_settings",{"rotation":app.canvas.stamp_rotation,"container_color":app.canvas.stamp_container_color,"snap":app.canvas.snap_enabled,"protect_road":app.canvas.protect_road})
	var doc: Dictionary = TrackDocument.create_blank()
	doc.pieces = [road(0)]; doc.pieces[0].position = [-30.23,0.37]
	var c: EditorCanvas = canvas(doc,"road")
	c.selected_piece = 0; c.snap_enabled = false
	var at: Vector2 = c.to_screen(Vector2(7,0.37))
	var before: Dictionary = doc.duplicate(true)
	touch(c,at,true); drag(c,at+Vector2(4,0)); touch(c,at+Vector2(4,0),false)
	record("road_tap_jitter",{"unchanged":doc == before,"position":doc.pieces[0].position})
	c.free()
	await show_fixture()
	app._remember(); app.document.objects.append(object(20,20)); app._save_draft(true)
	await settle()
	var committed: Dictionary = app.document.duplicate(true)
	app.canvas.choose_piece("curve"); app._undo()
	record("undo_preview",{"committed_preserved":app.document == committed,"preview_cleared":app.canvas.ghost.is_empty(),"history":app.history.size()})
	await settle()

func pointer_probes() -> void:
	var doc: Dictionary = TrackDocument.create_blank()
	doc.pieces = [road(0),road(22)]; doc.pieces[0].position = [-30.23,0.37]
	var c: EditorCanvas = canvas(doc,"road")
	c.selected_piece = 0; c.snap_enabled = false
	var at: Vector2 = c.to_screen(Vector2(7,0.37))
	var original: Dictionary = doc.duplicate(true)
	touch(c,at,true); drag(c,at+Vector2(4,0)); touch(c,at+Vector2(4,0),false)
	check(doc == original,"UX02 small selection jitter preserves exact road coordinates")
	touch(c,at,true); drag(c,at+Vector2(16,0)); touch(c,at+Vector2(16,0),false)
	record("deliberate_road_move",{"before":original.pieces[0].position,"after":doc.pieces[0].position})
	check(is_equal_approx(float(doc.pieces[0].position[0]),-28.23) and doc.pieces[0].position[1] == original.pieces[0].position[1],"UX02 deliberate road move snaps displacement and preserves untouched axis")
	check(doc.pieces[1] == original.pieces[1],"UX02 road move preserves unrelated neighbour exactly")
	var moved: Dictionary = doc.duplicate(true)
	at = c.to_screen(Vector2(9,0.37))
	touch(c,at,true); drag(c,at+Vector2(40,0)); c.cancel_gesture(false)
	check(doc == moved and c.active_pointer == -99,"UX02 cancellation restores deliberate road move exactly")
	c.choose_piece("curve")
	var preview: Dictionary = c.ghost.duplicate(true)
	at = c.piece_accept_rect(c.ghost).get_center()
	touch(c,at,true); touch(c,at+Vector2(60,0),false)
	check(c.ghost == preview and doc == moved,"UX03 release beyond road check without motion cannot confirm")
	at = c.piece_accept_rect(c.ghost).get_center()
	touch(c,at,true); touch(c,Vector2(-20,-20),false)
	check(c.ghost == preview and doc == moved,"UX03 off-canvas release keeps road preview and document")
	c.ghost.clear(); c.mode = "paint"; c.paint_mode = "area"
	c.paint_points = [[0.0,0.0],[20.0,0.0],[20.0,-20.0]]
	var pending: Array = c.paint_points.duplicate(true)
	at = c.paint_accept_rect().get_center()
	touch(c,at,true); touch(c,at+Vector2(80,0),false)
	check(c.paint_points == pending and doc.paint.is_empty(),"UX03 release outside paint check retains preview")
	for tool: String in ["road","paint","place","objects","run","start_line"]:
		c.mode = tool; c.navigation_override = true
		var view_before: Vector2 = c.pan
		at = Vector2(600,450)
		touch(c,at,true); drag(c,at+Vector2(40,20)); touch(c,at+Vector2(40,20),false)
		check(c.pan == view_before+Vector2(40,20) and doc == moved,"UX04 Move view pans without authoring in "+tool)
		check(c.paint_points == pending,"UX04 navigation retains pending area in "+tool)
	c.mode = "place"; c.navigation_override = false; c.paint_points.clear()
	at = c.to_screen(Vector2(20,-20))
	touch(c,at,true); touch(c,at+Vector2(50,0),false)
	check(doc.objects.size() == 1,"drag-to-aim commits one object at release")
	# A second finger must cancel authoring and either lift order must stay navigation.
	touch(c,at,true)
	var second := InputEventScreenTouch.new(); second.index = 8; second.position = at+Vector2(80,0); second.pressed = true
	c._gui_input(second)
	touch(c,at,false); second.pressed = false; c._gui_input(second)
	check(doc.objects.size() == 1 and c.active_pointer == -99,"UX03 pinch handoff never leaves a pending object stamp")
	c.free()

func recovery_probes() -> void:
	await show_fixture()
	app._remember(); app.document.objects.append(object(20,20)); app._save_draft(true)
	await settle()
	var committed: Dictionary = app.document.duplicate(true)
	var count: int = app.history.size()
	app.canvas.choose_piece("curve")
	check(not app.editor_undo.disabled,"UX01 Undo available for an uncommitted preview")
	# Real toolbar mouse routing, then the real unhandled keyboard path.
	await click(app.editor_undo.get_global_rect().get_center())
	check(app.document == committed and app.history.size() == count and app.canvas.ghost.is_empty(),"UX01 toolbar Undo cancels preview before committed history")
	app.canvas.choose_piece("curve")
	var undo_key := InputEventKey.new(); undo_key.keycode = KEY_Z; undo_key.physical_keycode = KEY_Z; undo_key.ctrl_pressed = true; undo_key.pressed = true
	root.gui_release_focus(); root.push_input(undo_key,true); await frames()
	check(app.document == committed and app.history.size() == count and app.canvas.ghost.is_empty(),"UX01 Ctrl+Z follows the toolbar preview policy")
	app._undo(); await settle()
	check(app.document.objects.size() == 1 and app.redo_history.size() == 1,"UX01 committed edit remains undoable")
	var undone: Dictionary = app.document.duplicate(true)
	app._editor_category("paint"); app.canvas.paint_mode = "area"
	app.canvas.paint_points = [[0.0,0.0],[10.0,0.0],[10.0,10.0]]; app._build_editor_tools()
	app._undo()
	check(app.canvas.paint_points.size() == 2 and app.document == undone and app.redo_history.size() == 1,"UX01 area Undo removes one point and preserves document redo")
	var pending: Array = app.canvas.paint_points.duplicate(true)
	app._redo()
	check(app.canvas.paint_points == pending and app.document == undone and app.redo_history.size() == 1,"UX01 Redo cannot silently replace a pending area")
	app._editor_category("road"); app._undo(); await frames()
	var dialog: ConfirmationDialog = app.root_ui.find_child("PendingPreviewDialog",true,false) as ConfirmationDialog
	check(dialog != null and dialog.visible and app.document == undone,"UX01 hidden area is resolved before traversing document history")
	if dialog != null:
		check(dialog.dialog_text == "Confirm or discard the pending previews before undoing earlier edits.","UX01 hidden-preview dialog describes the actual Undo action")
		dialog.canceled.emit(); await frames()
	app._editor_category("paint")
	check(app.canvas.paint_points == pending,"UX01 cancelling hidden-preview resolution preserves the area")
	app.canvas.paint_points.clear(); app._editor_category("objects"); app.canvas.mode = "objects"
	var at: Vector2 = app.canvas.to_screen(Vector2(0,14))
	touch(app.canvas,at,true); drag(app.canvas,at+Vector2(40,0))
	check(app.document != undone,"UX01 live drag changes the fixture before cancellation")
	app._undo()
	check(app.document == undone and app.redo_history.size() == 1 and app.history.is_empty(),"UX01 Undo rolls back current drag without traversing earlier history")
	app._redo(); await settle()
	check(app.document.objects == committed.objects,"UX01 redo survives cancelled live drag")
	for shortcut: Key in [KEY_DELETE,KEY_ENTER,KEY_E]:
		var saved: Dictionary = app.document.duplicate(true)
		app.canvas.mode = "objects"
		at = app.canvas.to_screen(Vector2(0,14))
		touch(app.canvas,at,true); drag(app.canvas,at+Vector2(40,0))
		await key(shortcut)
		check(app.document == saved and app.canvas.active_pointer == -99,"UX01 editing shortcut cancels a captured gesture safely: "+str(shortcut))
	# Dormant tools must retain their parameters as well as the active tool.
	app.canvas.stamp_rotation = 137.5; app.canvas.stamp_container_color = "#8b4134"
	app.canvas.snap_enabled = false; app.canvas.protect_road = false
	app._editor_category("road")
	var camera: Vector2 = Vector2(31,-17)
	app.canvas.pan = camera; app.canvas.zoom = 0.8
	await app._show_screen("create"); await settle()
	check(app.canvas.stamp_rotation == 137.5 and app.canvas.stamp_container_color == "#8b4134" and not app.canvas.snap_enabled and not app.canvas.protect_road,"UX05 dormant tool preferences survive complete view recreation")
	check(app.canvas.pan == camera and app.canvas.zoom == 0.8,"UX05 camera survives complete view recreation")
	check(app.editor_save_error == OK and (app.root_ui.find_child("EditorSaveLabel",true,false) as Label).is_visible_in_tree(),"UX06 normal saving state is visible")
	var label: Label = app.root_ui.find_child("EditorSaveLabel",true,false) as Label
	check(label.mouse_filter == Control.MOUSE_FILTER_IGNORE,"UX06 normal saving state does not block canvas input")
	app.editor_save_error = ERR_CANT_CREATE; app.editor_save_message = "Fixture save error"; app._update_editor_save_state()
	check(app.editor_save_button.is_visible_in_tree() and not label.visible and app.editor_save_button.size.y >= 48,"UX06 failure replaces status with a large retry target")
	app.editor_save_error = OK; app._update_editor_save_state()
	await settle()
	check(app.library.load_wip(app.document.id).objects == JSON.parse_string(JSON.stringify(app.document.objects)),"UX08 recovery still stores the committed document")

func layout_probes() -> void:
	await show_fixture()
	for dimensions: Vector2i in [Vector2i(960,540),Vector2i(1280,720),Vector2i(1560,720)]:
		root.size = dimensions; root.content_scale_size = dimensions; await frames(8)
		for name: String in ["EditorMoveView","EditorFitView"]:
			var control: Control = app.root_ui.find_child(name,true,false) as Control
			check(control != null and control.is_visible_in_tree() and control.size.x >= 48 and control.size.y >= 48,"UX04 visible view target at "+str(dimensions)+" "+name)
			check(Rect2(Vector2.ZERO,Vector2(dimensions)).encloses(control.get_global_rect()),"UX04 view target stays inside viewport")
		var before: Dictionary = app.document.duplicate(true)
		app.canvas.choose_piece("curve")
		var ghost: Dictionary = app.canvas.ghost.duplicate(true)
		await click_named("EditorMoveView")
		check(app.canvas.navigation_override and (app.root_ui.find_child("EditorMoveView",true,false) as Button).button_pressed,"UX04 view toggle visibly selects camera intent")
		var at := Vector2(600,310)
		touch(app.canvas,at,true); drag(app.canvas,at+Vector2(20,20)); touch(app.canvas,at+Vector2(20,20),false)
		check(app.document == before and app.canvas.ghost == ghost,"UX04 actual control protects the road preview")
		await click_named("EditorFitView")
		check(app.document == before and app.canvas.ghost == ghost,"UX04 one-tap Fit preserves authoring and preview")
		await shot("07-view-mode-"+str(dimensions.x))
		await click_named("EditorRoad")
		check(not app.canvas.navigation_override and app.canvas.ghost == ghost,"UX04 category selection resumes editing without losing preview")
		app.canvas.ghost.clear(); app._build_editor_tools()
		app.editor_map_panel.show(); await frames(5)
		check(app.editor_map_panel.get_global_rect().end.y <= dimensions.y-15,"UX06 map panel fits its available height")
		for button: Node in app.editor_map_panel.find_children("*","Button",true,false):
			check(button.size.y >= 48,"UX06 Map utility target is at least 48 logical units")
		app.editor_map_panel.hide()
	root.size = Vector2i(1280,720); root.content_scale_size = root.size; await frames(8)
	# Simulate an inset overlay without pretending it is an Android cutout test.
	var overlay: Control = app.root_ui.find_child("EditorOverlay",true,false) as Control
	overlay.offset_left = 40; overlay.offset_right = -60; overlay.offset_top = 12; overlay.offset_bottom = -20
	await frames(8)
	var safe_rect: Rect2 = overlay.get_global_rect()
	for name: String in ["EditorViewControls","EditorRailPanel","EditorHeaderActions"]:
		check(safe_rect.encloses((app.root_ui.find_child(name,true,false) as Control).get_global_rect()),"UX04 synthetic safe-area containment for "+name)
	await shot("08-simulated-safe-area")
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await frames(5)

func practice_probe() -> void:
	await show_fixture()
	app.canvas.stamp_rotation = 137.5; app.canvas.stamp_container_color = "#8b4134"
	app.canvas.snap_enabled = false; app.canvas.protect_road = false
	app._remember(); app.document.objects.append(object(35,20)); app._save_draft(true)
	await settle()
	app.canvas.zoom = 1.25
	var history_count: int = app.history.size()
	var before: Dictionary = app.document.duplicate(true)
	check(not app.test_button.disabled,"UX08 locally testable road enables one Test action")
	await click(app.test_button.get_global_rect().get_center())
	var deadline: int = Time.get_ticks_msec()+90000
	while Time.get_ticks_msec()<deadline and (not is_instance_valid(app.game) or is_instance_valid(app.race_loading) or not app.game.preparation_complete): await process_frame
	check(is_instance_valid(app.game) and not is_instance_valid(app.race_loading),"UX08 actual Test enters practice")
	if is_instance_valid(app.game):
		app.game.set_physics_process(false)
		var edit: Button = app.game.hud.find_child("EditHere",true,false) as Button
		check(edit != null,"UX08 practice exposes Edit here")
		if edit != null: edit.pressed.emit()
		await frames(8); await settle()
		check(not is_instance_valid(app.game) and app.document == before and app.history.size() == history_count,"UX08 actual practice return preserves document and history")
		check(app.canvas.stamp_rotation == 137.5 and app.canvas.stamp_container_color == "#8b4134" and not app.canvas.snap_enabled and not app.canvas.protect_road and app.canvas.zoom == 1.25,"UX05 actual practice return retains dormant settings and zoom")
		await shot("09-practice-return")

func loop_probe() -> void:
	await show_fixture()
	var blank: Dictionary = TrackDocument.create_blank(); blank.id = "ux_closed_loop"; blank["automatic_scenery"] = false
	app.canvas = null; app.editor_pending_tools.clear(); app.editor_view.clear(); app.history.clear(); app.redo_history.clear()
	app.document = blank
	await app._show_screen("create"); await settle()
	var actions: int = 0
	for index: int in range(4):
		app.canvas.choose_piece("curve"); actions += 1
		var at: Vector2 = app.canvas.piece_accept_rect(app.canvas.ghost).get_center()
		touch(app.canvas,at,true); touch(app.canvas,at,false); actions += 1
		await settle()
	check(app.document.pieces.size() == 4 and RoadPieces.connected_route(app.document.pieces).ok,"UX07 four default curves form a closed connected lap without numeric input")
	app._build_editor_tools()
	check(app.editor_guidance == "Road loop connected. Place the start line, then Test.","UX07 closed-loop guidance identifies the next step")
	await shot("10-closed-loop")
	var connected: Array = app.document.pieces.duplicate(true)
	app._undo(); await settle()
	check(app.document.pieces.size() == 3 and not RoadPieces.connected_route(app.document.pieces).ok,"UX08 removing a road opens the loop predictably")
	app._redo(); await settle()
	check(app.document.pieces == connected,"UX08 redo restores the exact loop")
	record("minimum_closed_loop",{"piece_actions":actions,"pieces":app.document.pieces.size(),"connected":RoadPieces.connected_route(app.document.pieces).ok,"player_time_measured":false})

func run() -> void:
	out = ProjectSettings.globalize_path("res://../docs/evidence/track-editor-ux-2026-11-16/after-"+RenderingServer.get_current_rendering_method())
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--review-out="): out = argument.trim_prefix("--review-out=")
		if argument == "--audit-only": audit_only = true
	DirAccess.make_dir_recursive_absolute(out)
	OS.set_environment("BMT_API_URL",""); OS.set_environment("BMT_DEV_AUTH_KEY","")
	root.size = Vector2i(1280,720); root.content_scale_size = root.size; root.gui_embed_subwindows = true
	app = load("res://core/app.tscn").instantiate()
	var storage: String = ProjectSettings.globalize_path("res://../build/track-editor-ux-2026-11-16/storage-"+str(OS.get_process_id()))
	app.library = TrackLibrary.new(storage.path_join("tracks"))
	app.records = LocalRecords.new(storage.path_join("records.json"))
	app.cloud_root_override = storage.path_join("cloud")
	root.add_child(app)
	var deadline: int = Time.get_ticks_msec()+90000
	while not app.startup_complete and Time.get_ticks_msec()<deadline: await process_frame
	check(app.startup_complete,"App starts within the fixture deadline")
	if app.startup_complete:
		await audit()
		if not audit_only:
			pointer_probes()
			await recovery_probes()
			await layout_probes()
			await practice_probe()
			await loop_probe()
	await settle()
	app.queue_free(); await frames(8)
	if is_instance_valid(GameSoundtrack.instance()): GameSoundtrack.instance().queue_free()
	await frames(4); await create_timer(0.3).timeout
	var file := FileAccess.open(out.path_join("report.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":fixture_checks,"failures":fixture_failures,"observations":observations,"renderer":RenderingServer.get_current_rendering_method(),"display":DisplayServer.get_name(),"audit_only":audit_only},"\t")); file.close()
	print("EDITOR_UX_20261116 ",fixture_checks," checks / ",fixture_failures," failures")
	quit(0 if fixture_failures == 0 else 1)
