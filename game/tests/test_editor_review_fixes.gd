extends SceneTree
## Real app/editor regression for the remaining review findings, isolated saves.
var checks: int = 0
var failures: int = 0
var app: Node
var folder: String
var evidence: String

class StorageFault extends TrackLibrary:
	var fail_wip: bool = false
	var fail_original: bool = false
	func save_wip(doc: Dictionary) -> Error:
		if fail_wip: last_error = "Injected recovery write failure"; return ERR_FILE_CANT_WRITE
		return super.save_wip(doc)
	func save_document(doc: Dictionary) -> Error:
		if fail_original: last_error = "Injected original write failure"; return ERR_FILE_CANT_WRITE
		return super.save_document(doc)

func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; print("FAIL: ",label)

func settle() -> void:
	var deadline: int = Time.get_ticks_msec()+20000
	while (app.editor_preview_thread != null or app.editor_world._building) and Time.get_ticks_msec()<deadline: await process_frame
	check(app.editor_preview_thread == null and not app.editor_world._building,"current collision and scenery preparation completes")

func oval(id: String) -> Dictionary:
	var doc: Dictionary = TrackDocument.create_blank()
	doc.id = id; doc.name = "Review fixes circuit"
	var position := Vector2(-28,-18)
	var heading: float = 0.0
	for kind: String in ["straight","hairpin","straight","hairpin"]:
		var piece: Dictionary = RoadPieces.create(kind,position,heading)
		piece.length = 56.0 if kind == "straight" else 0.0
		piece.radius = 18.0; doc.pieces.append(piece)
		var pose: Dictionary = RoadPieces.end_pose(piece)
		position = pose.position; heading = pose.heading
	return RoadPieces.route_from_pieces(doc).document

func show(doc: Dictionary) -> void:
	app.canvas = null; app.editor_view.clear()
	app.document = doc
	app.history.clear(); app.redo_history.clear()
	app.call("_show_screen","create")
	await settle()
	await process_frame

func dismiss() -> void:
	for dialog: Node in app.root_ui.find_children("*","AcceptDialog",true,false): dialog.queue_free()
	await process_frame

func shot(name: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(evidence+"/"+name+".png") == OK,"graphical evidence saved: "+name)

func touch(canvas: EditorCanvas, index: int, point: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index=index; event.position=point; event.pressed=pressed
	canvas._gui_input(event)

func run() -> void:
	root.size = Vector2i(1280,720)
	folder = "user://editor_review_fixes_"+TrackLibrary.unique_id()
	evidence = ProjectSettings.globalize_path("res://").path_join("../docs/evidence/editor-issues-2026-10-05").simplify_path()
	DirAccess.make_dir_recursive_absolute(evidence)
	app = load("res://core/app.tscn").instantiate()
	var storage := StorageFault.new(folder)
	app.library = storage; app.records = LocalRecords.new(folder+"/records.json")
	root.add_child(app)
	while not app.startup_complete: await process_frame
	await show(oval("save_failure"))
	storage.fail_wip = true
	check(app.call("_save_draft",true) == ERR_FILE_CANT_WRITE,"genuine persistence-boundary error is returned")
	check(app.editor_save_button.is_visible_in_tree() and not app.editor_save_button.disabled and "failed" in app.editor_save_button.text,"autosave failure stays visibly actionable")
	check(app.editor_status.is_visible_in_tree() and "Injected" in app.editor_status.text,"recovery failure has visible explanation")
	check(app.call("_editor_has_unsaved_changes"),"failed writes retain unsaved state")
	await shot("recovery-failed")
	storage.fail_wip = false
	app.editor_save_button.pressed.emit()
	check(storage.load_wip(app.document.id) == JSON.parse_string(JSON.stringify(app.document)) and app.editor_save_error == OK,"Retry actually saves exact WIP data")
	storage.fail_original = true
	check(not app.call("_save_track_now") and app.editor_retry_original,"original save failure retains its own retry operation")
	await dismiss()
	app.call("_save_draft",true)
	check(app.editor_retry_original and app.editor_save_error != OK,"successful recovery save cannot hide an original-save failure")
	storage.fail_original = false
	app.editor_save_button.pressed.emit()
	check(storage.load_document(app.document.id) == JSON.parse_string(JSON.stringify(app.document)) and not app.editor_retry_original,"Retry commits the failed original as well as recovery")
	await dismiss(); await settle()
	# Pending road and surface drafts survive repeated tool navigation.
	app.canvas.choose_piece("curve"); app.canvas.ghost.radius = 23.0
	var ghost: Dictionary = app.canvas.ghost.duplicate(true)
	app.call("_editor_category","paint")
	app.canvas.paint_mode = "line"; app.canvas.paint_points = [[-8.0,0.0],[8.0,0.0]]
	var pending_paint: Array = app.canvas.paint_points.duplicate(true)
	app.call("_editor_category","objects")
	check(app.call("_has_pending_editor_work") and app.test_button.disabled,"inactive pending tools remain dirty and prevent an incomplete test drive")
	app.call("_editor_category","road")
	check(app.canvas.ghost == ghost,"switching tools retains adjusted road geometry")
	app.call("_editor_category","paint")
	check(app.canvas.paint_points == pending_paint,"switching tools retains surface points and mode")
	app.call("_request_editor_exit")
	var departure: ConfirmationDialog = app.root_ui.find_child("SaveChangesDialog",true,false)
	check(departure != null,"closing a clean original with pending previews requires a decision")
	if departure != null: departure.canceled.emit()
	await process_frame
	check(app.screen == "create" and app.call("_has_pending_editor_work"),"Cancel retains every pending tool")
	app.call("_request_editor_exit")
	departure = app.root_ui.find_child("SaveChangesDialog",true,false)
	check(departure != null,"Cancel does not leave an invisible dialog blocking future departure")
	if departure != null: departure.confirmed.emit()
	await process_frame
	var saved: Dictionary = storage.load_document("save_failure")
	check(app.screen == "tracks" and saved.pieces.size() == 5 and saved.paint.size() == 1,"Save resolves all valid pending tools before leaving")
	# Explicit discard must leave the previous original intact.
	await show(oval("discard_pending"))
	app.call("_save_track_now"); await dismiss()
	var original: Dictionary = storage.load_document("discard_pending")
	app.canvas.choose_piece("hairpin")
	app.call("_request_editor_exit")
	departure = app.root_ui.find_child("SaveChangesDialog",true,false)
	if departure != null: departure.custom_action.emit(&"discard")
	await process_frame
	check(app.screen == "tracks" and storage.load_document("discard_pending") == original and storage.load_wip("discard_pending").is_empty(),"Discard cancels previews/recovery without deleting the committed original")
	await show(oval("invalid_pending"))
	app.call("_editor_category","paint")
	app.canvas.paint_mode="area"; app.canvas.paint_points=[[0.0,0.0],[4.0,0.0]]
	app.call("_editor_category","objects")
	check(not app.call("_save_track_now") and app.canvas.paint_points.size()==2 and app.screen=="create","incomplete inactive previews block Save without losing their points")
	await dismiss()
	app.call("_discard_editor_previews")
	await show(oval("object_run_pending"))
	app.call("_editor_category","objects")
	app.canvas.mode="run"; app.canvas.run_start=Vector2.ZERO
	app.canvas.run_preview=[{"kind":"barrier","position":[0.0,0.0],"rotation":0.0},{"kind":"barrier","position":[10.0,0.0],"rotation":0.0}]
	app.call("_editor_category","road")
	check(app.call("_save_track_now") and storage.load_document("object_run_pending").objects.size()==2,"Save also commits a retained object-run preview")
	await dismiss()
	# Pinch cancels tentative content movement, including its history mutation.
	await show(oval("pinch_rollback"))
	app.call("_remember"); app.document.pieces[0].width=11.0; app.call("_undo")
	var canvas: EditorCanvas = app.canvas
	canvas.snap_enabled = false; canvas.selected_piece=0
	var before: Dictionary = app.document.duplicate(true)
	var history_before: Array = app.history.duplicate(true)
	var redo_before: Array = app.redo_history.duplicate(true)
	var at: Vector2 = canvas.to_screen(Vector2(10,-18))
	touch(canvas,0,at,true)
	var drag := InputEventScreenDrag.new(); drag.index=0; drag.position=at+Vector2(14,0)
	canvas._gui_input(drag)
	check(app.document != before,"pinch fixture actually moves a committed road with the first finger")
	touch(canvas,1,at+Vector2(160,50),true)
	check(app.document == before and app.history == history_before and app.redo_history == redo_before,"second finger restores exact geometry, undo and redo instead of committing movement")
	touch(canvas,0,at,false); touch(canvas,1,at+Vector2(160,50),false)
	check(canvas.touches.is_empty() and canvas.active_pointer == -99,"pinch rollback retains correct release handoff")
	canvas.choose_piece("curve")
	ghost = canvas.ghost.duplicate(true)
	at = canvas.to_screen(RoadPieces.samples(ghost)[8])
	touch(canvas,0,at,true); drag.position=at+Vector2(14,0); canvas._gui_input(drag)
	touch(canvas,1,at+Vector2(160,50),true)
	check(canvas.ghost == ghost,"pinch also restores an unconfirmed road preview")
	canvas.cancel_gesture(); app.call("_discard_editor_previews")
	# Issue navigation cycles all actual markers.
	var broken: Dictionary = oval("issue_navigation"); broken.pieces[0].position[0] += 8.0
	await show(broken)
	var markers: Array = []
	for i: int in range(app.editor_issues.size()):
		app.call("_focus_issue")
		markers.append(app.canvas.issue_marker)
		check(app.editor_issue_cursor == i and app.editor_issue_button.text == "Issue %d/%d" % [i+1,app.editor_issues.size()],"issue badge advances with explicit progress")
	check(markers.size() == 4 and markers[0] != markers[1],"both ends of one section are distinct selectable issues")
	app.call("_focus_issue"); check(app.editor_issue_cursor == 0,"issue navigation wraps")
	await shot("issue-navigation")
	# Real road-edge paths only; never the invisible retained lap.
	var blank: Dictionary = TrackDocument.create_blank()
	check(RoadPieces.barrier_run(blank,Vector2(-38,-12),Vector2(-25,22)).is_empty(),"blank maps cannot create barriers along a phantom route")
	blank.paint = [{"surface":0,"width":8.0,"shape":"round","points":[[-20.0,0.0],[20.0,0.0]]}]
	check(not RoadPieces.barrier_run(blank,Vector2(-16,6),Vector2(16,6)).is_empty(),"painted road lines have real followable edges")
	await show(TrackDocument.create_blank())
	app.canvas.mode="run"; app.canvas.free_run=false; app.canvas.stamp_kind="barrier"
	check(app.canvas._object_run(Vector2.ZERO,Vector2(20,0)).is_empty() and app.editor_status.is_visible_in_tree(),"unavailable road-edge runs explain how to recover")
	# Bounds at physical sizes use the project's actual stretch policy.
	for physical: Vector2i in [Vector2i(960,540),Vector2i(1280,720),Vector2i(1600,720)]:
		root.size=physical
		await show(oval("layout_%d" % physical.x))
		app.call("_editor_category","paint"); await process_frame
		var header: Control = app.root_ui.find_child("EditorIdentityAndHistory",true,false)
		check(not header.get_global_rect().intersects(app.surface_toolbar.get_global_rect()),"surface toolbar clears title/history at "+str(physical))
		check(not app.editor_save_button.get_global_rect().intersects(app.surface_toolbar.get_global_rect()),"save state clears surface toolbar at "+str(physical))
		check(root.get_visible_rect().encloses(app.surface_toolbar.get_global_rect()),"surface controls stay in bounds at "+str(physical))
		await shot("surfaces-%dx%d" % [physical.x,physical.y])
		app.call("_editor_category","road"); await process_frame
		await shot("road-%dx%d" % [physical.x,physical.y])
	app.queue_free(); await process_frame
	cleanup(folder)
	print("EDITOR_REVIEW_FIXES: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func cleanup(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path): return
	for child: String in DirAccess.get_directories_at(path): cleanup(path.path_join(child))
	for file: String in DirAccess.get_files_at(path): DirAccess.remove_absolute(path.path_join(file))
	DirAccess.remove_absolute(path)
