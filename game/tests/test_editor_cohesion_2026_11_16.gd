extends "res://tests/review_editor_interactions_2026_11_14.gd"
## Actual App composition and object touch transactions, with isolated storage.

func fixture() -> void:
	await show_fixture()
	var doc: Dictionary = TrackDocument.create_blank()
	doc.id = "cohesion"; doc.name = "Lakeside Circuit"; doc["automatic_scenery"] = false
	var at := Vector2(-28,-18)
	var heading: float = 0
	for kind: String in ["straight","hairpin","straight","hairpin"]:
		var piece: Dictionary = RoadPieces.create(kind,at,heading,8)
		piece.length = 56.0 if kind == "straight" else 0.0; piece.radius = 18.0
		doc.pieces.append(piece)
		var pose: Dictionary = RoadPieces.end_pose(piece); at = pose.position; heading = pose.heading
	doc = RoadPieces.route_from_pieces(doc).document
	doc["start_line"] = {"position":[-28.0,-18.0],"heading":0.0}
	doc.objects = [object(0,0),object(15,0)]
	app.canvas = null; app.editor_pending_tools.clear(); app.editor_view.clear(); app.history.clear(); app.redo_history.clear()
	app.document = doc
	await app._show_screen("create"); await settle()
	await frames(8); app.canvas.fit(); await frames()

func bounds() -> void:
	var viewport: Rect2 = root.get_visible_rect()
	var header: Control = app.root_ui.find_child("EditorTopBar",true,false)
	var dock: Control = app.root_ui.find_child("EditorToolDock",true,false)
	check(header != null and dock != null,"one top bar and one contextual dock exist")
	if header == null or dock == null: return
	check(viewport.encloses(header.get_global_rect()) and viewport.encloses(dock.get_global_rect()),"header and dock fit "+str(root.size))
	check(header.size.y <= 76,"header stays a single compact row")
	check(not header.get_global_rect().intersects(dock.get_global_rect()),"header and dock remain separate")
	for name: String in ["EditorSaveLabel","EditorHistory","EditorMoveView","EditorFitView"]:
		check(header.is_ancestor_of(app.root_ui.find_child(name,true,false)),name+" belongs to the top bar")
	for item: Control in [app.editor_status,app.surface_toolbar,app.object_browser,app.object_controls_panel,app.editor_palette]:
		check(dock.is_ancestor_of(item),str(item.name)+" belongs to the same tool dock")
	check(app.editor_status.size.y <= 28,"guidance is a single line")
	check(app.canvas.get_global_rect() == viewport,"canvas retains the full viewport")

func captures() -> void:
	for dimensions: Vector2i in [Vector2i(1280,720),Vector2i(960,540)]:
		root.size = dimensions; root.content_scale_size = dimensions; await frames(8)
		await fixture(); bounds(); await shot("01-road-"+str(dimensions.x))
		app._editor_category("paint"); await frames(8); bounds()
		check(app.surface_toolbar.is_visible_in_tree() and app.editor_palette.is_visible_in_tree(),"surface materials and brush controls share the dock")
		await shot("02-surfaces-"+str(dimensions.x))
		app._editor_category("objects"); await frames(8); bounds()
		check(app.object_browser.is_visible_in_tree(),"entering Objects opens the picker")
		await shot("03-object-picker-"+str(dimensions.x))
		app.object_browser.choose("crate"); await frames(8); bounds()
		check(not app.object_browser.is_visible_in_tree() and app.object_controls_panel.is_visible_in_tree(),"choosing an asset collapses to placement controls")
		await shot("04-object-place-"+str(dimensions.x))
		var before: Dictionary = app.document.duplicate(true)
		tap(app.canvas,app.canvas.to_screen(Vector2.ZERO)); await frames(8)
		check(app.canvas.mode == "objects" and app.canvas.selected_object == 0 and app.document == before and app.history.is_empty(),"occupied tap reselects on release without changing the track")
		await shot("05-object-selected-"+str(dimensions.x))
		await click_named("ObjectOrientation"); await frames(8); bounds()
		check(not app.editor_palette.is_visible_in_tree(),"property adjustment hides unrelated selection actions")
		var property_view: Control = app.root_ui.find_child("ObjectControlScroll",true,false)
		for cardinal: String in ["Face_0","Face_90","Face_180","Face_270"]:
			var preset: Control = app.root_ui.find_child(cardinal,true,false)
			check(preset != null and property_view.get_global_rect().encloses(preset.get_global_rect()),"orientation preset is visible without horizontal hunting: "+cardinal)
		await shot("07-object-orientation-"+str(dimensions.x))
		await click_named("ObjectControlsBack"); await frames(5)
		await click_named("EditorBrowseObjects"); await frames(6)
		check(app.object_browser.is_visible_in_tree(),"object picker can be reopened directly")
		check(app.object_browser.tiles.find_child("Asset_crate",true,false) != null,"reopened picker reveals its active family")
		app.object_browser.choose("tree"); await frames(6)
		var pressed: Vector2 = app.canvas.to_screen(Vector2(8,-2))
		touch(app.canvas,pressed,true); drag(app.canvas,pressed+Vector2(20,15)); await shot("06-object-preview-"+str(dimensions.x))
		app.canvas.cancel_gesture(false)
		check(app.document == before,"cancelled placement preview preserves the document")

func object_flow() -> void:
	root.size = Vector2i(1280,720); root.content_scale_size = root.size
	await fixture(); app._editor_category("objects"); app.object_browser.choose("crate"); await frames()
	var initial: Dictionary = app.document.duplicate(true)
	var c: EditorCanvas = app.canvas
	var at: Vector2 = c.to_screen(Vector2.ZERO)
	touch(c,at,true)
	check(c.mode == "place" and c.pending_object_selection == 0,"existing-object selection waits for release")
	var cancel := InputEventScreenTouch.new(); cancel.index=4; cancel.position=at; cancel.canceled=true
	c._gui_input(cancel)
	check(c.mode == "place" and c.selected_object == -1 and app.document == initial,"cancelled occupied tap neither selects nor edits")
	tap(c,at)
	check(c.mode == "objects" and c.selected_object == 0,"tap selects an existing object from Place")
	var selected_before: Dictionary = app.document.duplicate(true)
	touch(c,at,true); drag(c,at+Vector2(24,0))
	check(c.active_pointer == 4 and app.document != selected_before,"selection refresh preserves capture for a deliberate object drag")
	c.cancel_gesture(false); await settle()
	check(app.document == selected_before,"cancelling the selected-object drag restores its exact position")
	var stamp_before: float = c.stamp_rotation
	app._set_object_rotation(90); await settle()
	check(app.document.objects[0].rotation == 90.0 and c.stamp_rotation == stamp_before,"selected rotation edits only the selection")
	await click_named("ObjectPlaceMode")
	check(c.mode == "place" and c.stamp_kind == "crate" and c.stamp_rotation == 90.0,"Place continues with the selected object's exact settings")
	var count: int = app.document.objects.size()
	var start: Vector2 = c.to_screen(Vector2(-8,3))
	var end: Vector2 = c.to_screen(Vector2(-12,6))
	touch(c,start,true); drag(c,end)
	check(app.document.objects.size() == count and c.pending_stamp,"drag-to-aim remains an uncommitted preview")
	touch(c,end,false); await settle()
	check(app.document.objects.size() == count+1 and app.document.objects.back().rotation == 90.0,"release places exactly one aimed object with the selected orientation")
	check(Vector2(app.document.objects.back().position[0],app.document.objects.back().position[1]).distance_to(Vector2(-12,6)) < 0.01,"placement uses the release position and snapping")
	var committed: Dictionary = app.document.duplicate(true)
	app._undo(); await settle(); check(app.document.objects.size() == count,"one Undo removes the placed object")
	app._redo(); await settle(); check(app.document == committed,"Redo restores the exact placement")
	c = app.canvas; c.mode = "place"
	start = c.to_screen(Vector2(-18,4)); touch(c,start,true); drag(c,start+Vector2(30,0))
	var dock: Control = app.root_ui.find_child("EditorToolDock",true,false)
	touch(c,dock.get_global_rect().get_center(),false)
	check(app.document == committed and c.active_pointer == -99,"release over the dock cancels rather than placing behind UI")
	c.mode = "place"; at = c.to_screen(Vector2.ZERO)
	var pan_before: Vector2 = c.pan
	touch(c,at,true); drag(c,at+Vector2(24,0)); touch(c,at+Vector2(24,0),false)
	check(app.document == committed and c.pan != pan_before and c.mode == "place","drag starting on an occupied object pans without accidental movement or reselection")
	await settle()
	for source: Dictionary in [
		{"kind":"container","position":[0.0,5.0],"rotation":37.5,"scale":1.5,"color":"#8b4134"},
		{"kind":"speed_bump","position":[0.0,5.0],"rotation":22.5,"span":13.2},
		{"kind":"jump","position":[0.0,5.0],"rotation":90.0,"jump_profile":"tabletop_v1","scale":1.5},
		{"kind":"jump","position":[0.0,5.0],"rotation":45.0},
		{"kind":"barrier","position":[0.0,5.0],"rotation":22.5,"length":9.0}
	]:
		app._remember(); app.document.objects.append(source.duplicate(true)); app._save_draft(true); await settle()
		c = app.canvas; c.mode = "objects"; c.selected_object = app.document.objects.size()-1; app._build_editor_tools()
		var saved: Dictionary = app.document.duplicate(true)
		app._edit_object_control("mode","place")
		check(app.document == saved,"Place changes intent without editing the selected "+str(source.kind))
		var copy: Dictionary = c.placement_object(c.to_screen(Vector2(-10,6)))
		copy.erase("position")
		var expected: Dictionary = source.duplicate(true); expected.erase("position")
		check(copy == expected,"Place preserves every encoded setting of the selected "+str(source.kind))
		app._undo(); await settle()

func run() -> void:
	out = ProjectSettings.globalize_path("res://../docs/evidence/editor-cohesion-2026-11-16/"+RenderingServer.get_current_rendering_method())
	DirAccess.make_dir_recursive_absolute(out)
	OS.set_environment("BMT_API_URL",""); OS.set_environment("BMT_DEV_AUTH_KEY","")
	root.size=Vector2i(1280,720); root.content_scale_size=root.size; root.gui_embed_subwindows=true
	app=load("res://core/app.tscn").instantiate()
	var storage: String = ProjectSettings.globalize_path("res://../build/editor-cohesion-2026-11-16/"+str(OS.get_process_id()))
	app.library=TrackLibrary.new(storage.path_join("tracks")); app.records=LocalRecords.new(storage.path_join("records.json")); app.cloud_root_override=storage.path_join("cloud")
	root.add_child(app)
	var deadline: int = Time.get_ticks_msec()+90000
	while not app.startup_complete and Time.get_ticks_msec()<deadline: await process_frame
	check(app.startup_complete,"isolated offline App starts")
	if app.startup_complete:
		await captures(); await object_flow()
	await settle(); app.queue_free(); await frames(8)
	if is_instance_valid(GameSoundtrack.instance()): GameSoundtrack.instance().queue_free()
	await frames(3); await create_timer(0.3).timeout
	var file := FileAccess.open(out.path_join("report.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":fixture_checks,"failures":fixture_failures,"renderer":RenderingServer.get_current_rendering_method()},"\t")); file.close()
	print("EDITOR_COHESION ",fixture_checks," checks / ",fixture_failures," failures")
	quit(0 if fixture_failures == 0 else 1)
