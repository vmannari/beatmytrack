extends SceneTree
## Review probes only. Runtime sources are not modified; all saves are disposable.
var out: String = ProjectSettings.globalize_path("res://../docs/evidence/editor-interactions-2026-11-14")
var observations: Dictionary = {}
var controls: Dictionary = {}
var app: Node
var fixture_checks: int = 0
var fixture_failures: int = 0
var before_hashes: Dictionary = {}

func _initialize() -> void: run.call_deferred()

func check(ok: bool, message: String) -> void:
	fixture_checks += 1
	if not ok: fixture_failures += 1; print("FIXTURE_FAIL ",message)

func record(key: String, value: Dictionary) -> void:
	observations[key] = value
	print("EDITOR_INTERACTION ",key," ",JSON.stringify(value))

func frames(count: int = 3) -> void:
	for i: int in range(count): await process_frame
	if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw

func hashes() -> Dictionary:
	var result: Dictionary = {}
	for path: String in ["editor/editor_canvas.gd","editor/object_editing.gd","editor/object_properties.gd","core/features/editor.gd","core/app.gd"]:
		result[path] = FileAccess.get_sha256("res://"+path)
	return result

func object(x: float, y: float) -> Dictionary:
	return {"kind":"crate","position":[x,y],"rotation":0.0}

func road(y: float) -> Dictionary:
	var piece: Dictionary = RoadPieces.create("straight",Vector2(-30,y),0,6)
	piece.length = 60.0
	return piece

func canvas(doc: Dictionary, mode: String) -> EditorCanvas:
	var result := EditorCanvas.new()
	result.document = doc; result.mode = mode
	root.add_child(result); result.size = Vector2(1280,720)
	result.zoom = 1.0; result.pan = Vector2.ZERO
	return result

func touch(target: EditorCanvas, point: Vector2, down: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = 4; event.position = point; event.pressed = down
	target._gui_input(event)

func drag(target: EditorCanvas, point: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = 4; event.position = point; target._gui_input(event)

func tap(target: EditorCanvas, point: Vector2) -> void:
	touch(target,point,true); touch(target,point,false)

func direct_probes() -> void:
	var doc: Dictionary = TrackDocument.create_blank()
	doc.objects = [object(0,0)]
	var c: EditorCanvas = canvas(doc,"place")
	c.stamp_kind = "crate"
	tap(c,c.to_screen(Vector2.ZERO))
	var after_hit: String = c.mode
	tap(c,c.to_screen(Vector2(20,0)))
	record("placement_click_existing",{"mode_after_hit":after_hit,"mode_after_empty":c.mode,"objects_after_two_taps":doc.objects.size()})
	c.free()
	doc = TrackDocument.create_blank(); doc.pieces = [road(0),road(8)]
	c = canvas(doc,"road"); c.zoom = 0.35
	tap(c,c.to_screen(Vector2.ZERO))
	var picked: int = c.selected_piece
	c.selected_piece = 0
	tap(c,c.to_screen(Vector2(0,8)))
	record("road_nearest_and_sticky",{"exact_first_center_picks":picked,"exact_second_center_with_first_selected_picks":c.selected_piece,"center_separation_px":c.to_screen(Vector2.ZERO).distance_to(c.to_screen(Vector2(0,8))),"hit_radius_px":maxf(24,3*c.scale_factor())})
	c.free()
	doc = TrackDocument.create_blank(); doc.objects = [object(0.49,0.49)]
	c = canvas(doc,"objects")
	var from: Vector2 = c.to_screen(Vector2(0.49,0.49))
	touch(c,from,true); drag(c,from+Vector2(1,0)); touch(c,from+Vector2(1,0),false)
	record("object_one_pixel_jitter",{"input_px":1,"before":[0.49,0.49],"after":doc.objects[0].position.duplicate(),"screen_displacement_px":from.distance_to(c.to_screen(Vector2(doc.objects[0].position[0],doc.objects[0].position[1])))})
	c.free()
	# Controls: explicit navigation, pure taps, overlap cycling and cancelled drags.
	doc = TrackDocument.create_blank(); doc.objects = [object(0.49,0.49)]
	c = canvas(doc,"objects"); var saved: Dictionary = doc.duplicate(true)
	tap(c,c.to_screen(Vector2(0.49,0.49)))
	controls.pure_selection_unchanged = doc == saved
	from = c.to_screen(Vector2(0.49,0.49)); touch(c,from,true); drag(c,from+Vector2(50,0)); c.cancel_gesture()
	controls.cancelled_drag_restored = doc == saved
	c.free()
	doc = TrackDocument.create_blank(); doc.pieces = [road(0),road(8)]
	c = canvas(doc,"road"); c.zoom = 0.35; tap(c,c.to_screen(Vector2.ZERO)); c.cycle_piece()
	controls.road_cycle_reaches_other = c.selected_piece == 0
	c.free()
	for key: String in controls: check(controls[key],key)

func settle() -> void:
	var deadline: int = Time.get_ticks_msec()+90000
	var next_log: int = Time.get_ticks_msec()+10000
	while Time.get_ticks_msec()<deadline:
		if Time.get_ticks_msec() >= next_log:
			print("READINESS ",{"background_allowed":app._background_work_allowed(),"game":is_instance_valid(app.game),"loading":is_instance_valid(app.race_loading),"feature_loading":is_instance_valid(app._feature_loading),"preparing":app.canvas.preparing,"native":app.canvas.native_preview != null,"building":app.editor_world._building,"initial_done":app.editor_world._initial_preparation_done,"thread":app.editor_preview_thread != null,"thread_alive":app.editor_preview_thread.is_alive() if app.editor_preview_thread != null else false,"pointer":app.canvas.active_pointer})
			next_log += 10000
		if not app.canvas.preparing and app.canvas.native_preview != null and not app.editor_commits.unsettled() and app.editor_preview_thread == null and not app.editor_world._building and not app.editor_writes.unsettled(app.library,str(app.document.id)):
			await frames(4)
			if not app.canvas.preparing and app.editor_preview_thread == null and not app.editor_world._building: return
		await process_frame
	check(false,"editor settles within 90 seconds")

func show_fixture() -> void:
	if is_instance_valid(app.canvas) and is_instance_valid(app.editor_world): await settle()
	app.canvas = null; app.editor_pending_tools.clear(); app.editor_pending_id = ""
	app.editor_view.clear(); app.history.clear(); app.redo_history.clear()
	var doc: Dictionary = TrackDocument.create_blank()
	doc.id = "interaction_review"; doc.name = "Interaction review"; doc["automatic_scenery"] = false
	doc.pieces = [road(0)]; doc.objects = [object(0,14)]
	check(TrackDocument.validate(doc,false).is_empty(),"review fixture passes unchanged production document validation")
	app.document = doc
	await app._show_screen("create"); await frames(); await settle()
	app.canvas.zoom = 1.0; app.canvas.pan = Vector2.ZERO
	app.canvas.queue_redraw(); await frames()

func click(point: Vector2) -> void:
	for down: bool in [true,false]:
		var event := InputEventMouseButton.new()
		event.position = point; event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT; event.pressed = down
		root.push_input(event,true); await process_frame
	await frames()

func click_named(node_name: String) -> void:
	var target: Control = app.root_ui.find_child(node_name,true,false) as Control
	check(target != null and target.is_visible_in_tree(),"visible click target "+node_name)
	if target != null and target.is_visible_in_tree(): await click(target.get_global_rect().get_center())

func click_text(text: String) -> void:
	for target: Node in app.root_ui.find_children("*","Button",true,false):
		if target.is_visible_in_tree() and target.text == text:
			await click(target.get_global_rect().get_center()); return
	check(false,"visible button "+text)

func choose_crate() -> void:
	await click_named("EditorObjects")
	await click_named("Category_Props")
	for page: int in range(3):
		var tile: Control = app.root_ui.find_child("Asset_crate",true,false) as Control
		if tile != null and tile.is_visible_in_tree(): break
		await click_named("NextObjects")
	await click_named("Asset_crate")
	check(app.canvas.mode == "place" and app.canvas.stamp_kind == "crate","object palette arms crate placement")
	await settle()

func key(value: Key) -> void:
	root.gui_release_focus()
	for down: bool in [true,false]:
		var event := InputEventKey.new(); event.keycode = value; event.physical_keycode = value; event.pressed = down
		root.push_input(event,true); await process_frame
	await frames()

func shot(label: String) -> void:
	await frames(5)
	if DisplayServer.get_name() != "headless":
		check(root.get_texture().get_image().save_png(out.path_join(label+".png")) == OK,"save "+label)

func app_probes() -> void:
	app = load("res://core/app.tscn").instantiate()
	var storage: String = ProjectSettings.globalize_path("res://../build/editor-interactions-2026-11-14/storage-"+str(OS.get_process_id()))
	app.library = TrackLibrary.new(storage.path_join("tracks"))
	app.records = LocalRecords.new(storage.path_join("records.json"))
	app.cloud_root_override = storage.path_join("cloud")
	root.add_child(app)
	while not app.startup_complete: await process_frame
	await show_fixture()
	await choose_crate()
	await shot("01-place-before-click")
	await click(app.canvas.to_screen(Vector2(0,14)))
	var mode_after: String = app.canvas.mode
	await shot("02-placement-became-selection")
	await click(app.canvas.to_screen(Vector2(30,14)))
	record("app_placement_lost",{"mode_after_existing_click":mode_after,"mode_after_empty_click":app.canvas.mode,"object_count":app.document.objects.size(),"browser_visible":app.object_browser.is_visible_in_tree()})
	await show_fixture()
	await choose_crate()
	await click(app.canvas.to_screen(Vector2(20,0)))
	check(app.document.objects.size() == 2,"viewport click places a second crate")
	var angle_before: float = app.document.objects.back().rotation
	var history_before: int = app.history.size()
	await settle(); await shot("03-after-placement")
	await click_named("ObjectOrientation")
	await click_named("Face_90")
	record("app_stamp_rotation_edits_previous",{"mode":app.canvas.mode,"selected_object":app.canvas.selected_object,"controls_selected":app.object_controls.selected,"before_degrees":angle_before,"after_degrees":app.document.objects.back().rotation,"stamp_degrees":app.canvas.stamp_rotation,"undo_delta":app.history.size()-history_before})
	await settle(); await shot("04-stamp-rotation-changed-existing")
	await settle()
	var count: int = app.document.objects.size()
	await key(KEY_ESCAPE); var selected_after_escape: int = app.canvas.selected_object
	var mode_after_escape: String = app.canvas.mode
	await key(KEY_DELETE)
	record("app_escape_delete",{"mode_after_escape":mode_after_escape,"selection_after_escape":selected_after_escape,"objects_before":count,"objects_after_delete":app.document.objects.size()})
	await show_fixture()
	app._editor_category("paint"); await frames()
	await click_named("PaintMode_area")
	for point: Vector2 in [Vector2(10,-6),Vector2(25,-6),Vector2(25,-17)]: await click(app.canvas.to_screen(point))
	check(app.canvas.paint_points.size() == 3,"three viewport taps define an area preview")
	var before_points: Array = app.canvas.paint_points.duplicate(true)
	await shot("05-pending-area")
	await click_named("PaintMode_area")
	record("app_reclick_active_paint_mode",{"before_points":before_points,"after_points":app.canvas.paint_points.duplicate(true),"history_entries":app.history.size(),"pending_work":app._has_pending_editor_work()})
	await shot("06-area-lost-on-active-tool-click")
	for point: Vector2 in [Vector2(10,-6),Vector2(25,-6),Vector2(25,-17)]: await click(app.canvas.to_screen(point))
	check(app.canvas.paint_points.size() == 3,"area preview before Map")
	await click_text("Map")
	record("app_open_map_discards_area",{"after_points":app.canvas.paint_points.duplicate(true),"map_visible":app.editor_map_panel.is_visible_in_tree(),"pending_work":app._has_pending_editor_work()})
	await show_fixture()
	app._editor_category("paint"); app.canvas.paint_mode = "line"; app._build_editor_tools(); await frames()
	# Last canvas click is on a road; Tab is routed through the real App handler.
	await click(app.canvas.to_screen(Vector2(0,0)))
	var mode_before: String = app.canvas.mode
	await key(KEY_TAB)
	record("app_tab_from_surface",{"before_mode":mode_before,"after_mode":app.canvas.mode,"selected_piece":app.canvas.selected_piece,"surface_toolbar_visible":app.surface_toolbar.is_visible_in_tree()})
	await shot("07-tab-switched-to-road")
	await show_fixture()
	await choose_crate()
	await key(KEY_ESCAPE)
	var mode_before_click: String = app.canvas.mode
	await click(app.canvas.to_screen(Vector2(20,0)))
	record("app_escape_keeps_stamp_armed",{"mode_after_escape":mode_before_click,"objects_after_click":app.document.objects.size()})
	# Positive control: switching categories preserves an unfinished road preview.
	await show_fixture()
	app.canvas.choose_piece("curve"); var preview: Dictionary = app.canvas.ghost.duplicate(true)
	app._editor_category("objects"); app._editor_category("road")
	controls.category_round_trip_keeps_road_preview = app.canvas.ghost == preview
	check(controls.category_round_trip_keeps_road_preview,"category round trip retains road preview")
	record("app_guidance_visibility",{"guidance":app.editor_guidance,"guidance_visible":app.editor_status.is_visible_in_tree(),"hint_active":app.editor_hint_active})
	await shot("08-road-guidance")
	await settle(); app.queue_free(); await frames(6)
	if is_instance_valid(GameSoundtrack.instance()): GameSoundtrack.instance().queue_free()
	await frames(3); await create_timer(0.25).timeout

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--review-out="): out = argument.trim_prefix("--review-out=")
	DirAccess.make_dir_recursive_absolute(out)
	OS.set_environment("BMT_API_URL",""); OS.set_environment("BMT_DEV_AUTH_KEY","")
	root.size = Vector2i(1280,720); root.content_scale_size = root.size; root.gui_embed_subwindows = true
	before_hashes = hashes()
	direct_probes()
	if "--direct-only" not in OS.get_cmdline_user_args(): await app_probes()
	var after: Dictionary = hashes(); check(after == before_hashes,"reviewed production sources unchanged during probes")
	var report: Dictionary = {"observations":observations,"positive_controls":controls,"fixture_checks":fixture_checks,"fixture_failures":fixture_failures,"sources_before":before_hashes,"sources_after":after,"renderer":RenderingServer.get_current_rendering_method(),"display":DisplayServer.get_name()}
	var file := FileAccess.open(out.path_join("report.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t")); file.close()
	print("EDITOR_INTERACTION_REVIEW ",fixture_checks," checks / ",fixture_failures," fixture failures")
	quit(0 if fixture_failures == 0 else 1)
