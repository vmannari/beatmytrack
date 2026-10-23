extends SceneTree
## Review-only native captures; all draft/record writes use disposable evidence storage.

var app: Node
var folder: String
var observations: Array[Dictionary] = []
var failures: int = 0
var source_before: Dictionary = {}

func source_hashes() -> Dictionary:
	var result: Dictionary = {}
	for path: String in ["core/app.gd","editor/editor_canvas.gd","editor/editor_world.gd","editor/editor_style.gd","editor/editor_button.gd","editor/object_browser.gd","editor/object_thumbnail.gd","editor/creator_catalog.gd","editor/object_population.gd","track/native_track_visual.gd","track/creator_prop_visual.gd"]:
		result[path] = FileAccess.get_sha256("res://"+path)
	return result

func _initialize() -> void:
	call_deferred("run")

func frames(count: int = 4) -> void:
	for index: int in range(count): await process_frame
	await RenderingServer.frame_post_draw

func settle() -> void:
	var deadline: int = Time.get_ticks_msec()+60000
	while (app.editor_preview_thread != null or app.editor_world._building) and Time.get_ticks_msec()<deadline:
		await process_frame
	if app.editor_preview_thread != null or app.editor_world._building:
		failures += 1
		print("VISUAL_REVIEW: preview deadline exceeded")
	await frames(6)

func show(doc: Dictionary) -> void:
	app.canvas = null
	app.editor_pending_tools.clear()
	app.editor_view.clear()
	app.history.clear()
	app.redo_history.clear()
	app.document = doc.duplicate(true)
	app.call("_show_screen","create")
	await frames(2)
	await settle()

func rectangle(control: Control) -> Dictionary:
	var rect: Rect2 = control.get_global_rect()
	return {"x":rect.position.x,"y":rect.position.y,"w":rect.size.x,"h":rect.size.y}

func shot(label: String) -> void:
	# Thumbnails render serially. Wait for the actual visible set, so a capture
	# never mistakes pending artwork for a missing asset.
	var deadline: int = Time.get_ticks_msec()+15000
	var pending: bool = true
	while pending and Time.get_ticks_msec()<deadline:
		pending = app.editor_world._building
		for item: Node in app.root_ui.find_children("Asset_*","Button",true,false):
			if item is ObjectThumbnail and item._visible() and (item._image.texture == null or item._viewport != null): pending = true
		if pending: await process_frame
	await frames(5)
	var controls: Array[Dictionary] = []
	for item: Node in app.root_ui.find_children("*","Control",true,false):
		if not item.is_visible_in_tree(): continue
		if item is BaseButton or item is Slider:
			var data: Dictionary = {"name":str(item.name),"rect":rectangle(item),"class":item.get_class()}
			if item is BaseButton:
				data["text"] = item.text
				data["disabled"] = item.disabled
				data["tooltip"] = item.tooltip_text
			controls.append(data)
	var state: Dictionary = {"capture":label,"window":[root.size.x,root.size.y],"logical":[root.get_visible_rect().size.x,root.get_visible_rect().size.y],"mode":app.canvas.mode,"controls":controls,"status_text":app.editor_status.text,"status_visible":app.editor_status.is_visible_in_tree(),"save_text":app.editor_save_button.text}
	if app.canvas.selected_piece >= 0 and not app.document.pieces.is_empty() and app.document.has("start_line"):
		var accept: Rect2 = app.canvas.piece_accept_rect(app.document.pieces[app.canvas.selected_piece])
		var flip: Vector2 = app.canvas.start_controls().flip
		var flip_bounds := Rect2(flip-Vector2(28,28),Vector2(56,56))
		state["confirm_bounds"] = [accept.position.x,accept.position.y,accept.size.x,accept.size.y]
		state["start_flip_bounds"] = [flip_bounds.position.x,flip_bounds.position.y,56,56]
		state["confirm_start_flip_bounds_overlap"] = accept.intersects(flip_bounds)
		var probe: Vector2 = accept.intersection(flip_bounds).get_center()
		state["overlap_center_in_start_flip_hit_circle"] = probe.distance_to(flip) <= 28
	for item_name: String in ["EditorIdentityAndHistory","SurfacePlacementToolbar","EditorTools","EditorMap","EditorRailPanel","ObjectBrowser"]:
		var item: Control = app.root_ui.find_child(item_name,true,false)
		if item != null and item.is_visible_in_tree(): state[item_name] = rectangle(item)
	observations.append(state)
	var error: Error = root.get_texture().get_image().save_png(folder.path_join(label+".png"))
	if error != OK: failures += 1
	print("VISUAL_REVIEW_CAPTURE: ",label)

func circuit() -> Dictionary:
	var doc: Dictionary = TrackDocument.create_blank()
	doc.id = "visual_review_fixture"
	doc.name = "Lakeside Circuit"
	var position := Vector2(-28,-18)
	var heading: float = 0.0
	for kind: String in ["straight","hairpin","straight","hairpin"]:
		var piece: Dictionary = RoadPieces.create(kind,position,heading)
		piece.length = 56.0 if kind == "straight" else 0.0
		piece.radius = 18.0
		doc.pieces.append(piece)
		var pose: Dictionary = RoadPieces.end_pose(piece)
		position = pose.position
		heading = pose.heading
	doc = RoadPieces.route_from_pieces(doc).document
	doc["start_line"] = {"position":[-28.0,-18.0],"heading":0.0}
	doc["automatic_scenery"] = false
	doc.objects = [
		{"kind":"tree","position":[-29.0,-6.0],"rotation":0.0},
		{"kind":"broadleaf","position":[-20.0,7.0],"rotation":15.0},
		{"kind":"shed","position":[23.0,-4.0],"rotation":0.0},
		{"kind":"grandstand","position":[0.0,3.0],"rotation":0.0},
		{"kind":"barrier","position":[15.0,4.0],"rotation":0.0}
	]
	return doc

func run() -> void:
	if DisplayServer.get_name() == "headless": quit(2); return
	OS.set_environment("BMT_API_URL","")
	source_before = source_hashes()
	folder = ProjectSettings.globalize_path("res://../docs/evidence/editor-visual-review-2026-10-16").simplify_path().path_join(RenderingServer.get_current_rendering_method())
	DirAccess.make_dir_recursive_absolute(folder)
	root.size = Vector2i(1280,720)
	root.content_scale_size = Vector2i(1280,720)
	app = load("res://core/app.tscn").instantiate()
	app.library = TrackLibrary.new(folder.path_join("disposable-storage"))
	app.library.owner_name = "Review driver"
	app.records = LocalRecords.new(folder.path_join("disposable-storage/records.json"))
	app.cloud_root_override = folder.path_join("disposable-storage/cloud")
	root.add_child(app)
	var startup_deadline: int = Time.get_ticks_msec()+60000
	while not app.startup_complete and Time.get_ticks_msec()<startup_deadline: await process_frame
	if not app.startup_complete:
		print("VISUAL_REVIEW: startup did not finish")
		quit(2)
		return
	await frames()
	app.library.owner_name = "Review driver"
	var blank: Dictionary = TrackDocument.create_blank()
	blank.id = "review_blank"
	await show(blank)
	await shot("01-blank-1280")
	var doc: Dictionary = circuit()
	await show(doc)
	await shot("02-track-1280")
	app.canvas.selected_piece = 0
	app.call("_build_editor_tools")
	await shot("03-selected-road-1280")
	app.canvas.selected_piece = -1
	app.canvas.choose_piece("spline")
	app.call("_build_editor_tools")
	await shot("04-spline-preview-1280")
	app.canvas.ghost.clear()
	app.call("_editor_category","paint")
	await shot("05-surfaces-1280")
	app.editor_tools_panel.show()
	await shot("06-surface-options-1280")
	app.editor_tools_panel.hide()
	app.canvas.paint_mode = "area"
	app.canvas.paint_points = [[-13.0,-9.0],[7.0,-10.0],[12.0,3.0],[-8.0,7.0]]
	app.call("_build_editor_tools")
	await shot("07-area-preview-1280")
	app.canvas.paint_points.clear()
	app.call("_editor_category","objects")
	app.object_browser.category = "Nature"
	app.object_browser.refresh()
	await shot("08-objects-1280")
	app.object_browser.call("_activate_asset","tree")
	await frames()
	app.object_browser.call("_activate_asset","tree")
	await shot("09-object-options-1280")
	app.object_browser.options.hide()
	app.canvas.selected_object = 2
	app.canvas.mode = "objects"
	app.call("_build_editor_tools")
	await shot("10-selected-object-1280")
	app.canvas.selected_object = -1
	app.call("_build_editor_tools")
	app.call("_open_object_population")
	var deadline: int = Time.get_ticks_msec()+45000
	while is_instance_valid(app.object_population_panel) and not app.object_population_panel.ready_to_apply and Time.get_ticks_msec()<deadline: await process_frame
	await shot("11-populate-1280")
	app.call("_close_object_population",false)
	await settle()
	app.call("_editor_category","road")
	app.canvas.selected_piece = -1
	app.document.pieces[0].position[0] += 8.0
	app.call("_save_draft",true)
	await settle()
	app.call("_update_editor_issues")
	app.call("_focus_issue")
	await shot("12a-issues-1280")
	await show(doc)
	app.editor_map_panel.show()
	await shot("12-map-1280")
	app.editor_map_panel.hide()
	app.call("_editor_help")
	await shot("13-help-1280")
	for item: Node in app.root_ui.get_children():
		if item is AcceptDialog: item.hide()
	# Match production 1280x720 logical stretching at a smaller physical window.
	root.size = Vector2i(960,540)
	root.content_scale_size = Vector2i(1280,720)
	await show(doc)
	await shot("14-track-960-scaled")
	app.call("_editor_category","paint")
	await shot("15-surfaces-960-scaled")
	# Also inspect an editor with only 960x540 logical layout space.
	root.content_scale_size = Vector2i(960,540)
	await show(doc)
	app.call("_editor_category","paint")
	await shot("16-surfaces-960-native")
	app.call("_editor_category","objects")
	await shot("17-objects-960-native")
	root.size = Vector2i(1600,720)
	root.content_scale_size = Vector2i(1280,720)
	await show(doc)
	await shot("18-track-wide")
	root.size = Vector2i(1280,720)
	root.content_scale_size = Vector2i(1280,720)
	doc.name = "The extraordinarily long lakeside championship circuit"
	await show(doc)
	await shot("19-long-name")
	for theme: String in ["desert","winter","night_city","storm"]:
		var themed: Dictionary = circuit()
		themed.theme = theme
		themed.name = "Review "+theme
		await show(themed)
		await shot("20-theme-"+theme)
		if theme in ["desert","winter"]:
			app.call("_editor_category","paint")
			await shot("21-surfaces-"+theme)
	# Find out whether the Night view remains dark after explicit light placement.
	var lit: Dictionary = circuit()
	lit.theme = "night_city"
	for position: Array in [[-28.0,-12.0],[0.0,12.0],[28.0,-12.0]]:
		lit.objects.append({"kind":"light","position":position,"rotation":0.0})
	await show(lit)
	await shot("22-night-with-authored-lights")
	var file := FileAccess.open(folder.path_join("observations.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"scope":"Current native editor visual and usability review; no owner drafts or records used","renderer":RenderingServer.get_current_rendering_method(),"failures":failures,"source_before":source_before,"source_after":source_hashes(),"observations":observations},"\t"))
	file.close()
	app.queue_free()
	await frames()
	print("VISUAL_REVIEW_COMPLETE: ",observations.size()," captures, ",failures," capture/deadline failures")
	quit(1 if failures else 0)
