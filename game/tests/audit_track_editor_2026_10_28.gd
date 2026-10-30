extends SceneTree
## Review probes only. All persistence belongs to this review's workspace folder.
var out: String = ProjectSettings.globalize_path("res://../docs/evidence/track-editor-review-2026-10-28")
var observations: Dictionary = {}
var app: Node

func _initialize() -> void: run.call_deferred()

func observe(key: String, value: Variant) -> void:
	observations[key] = value
	print("TRACK_EDITOR_AUDIT ",key," ",JSON.stringify(value))

func paint_admission() -> void:
	var doc: Dictionary = TrackDocument.create_default()
	doc.id = "paint_admission"
	for stroke: int in range(32):
		var points: Array = []
		for index: int in range(512): points.append([-100.0+index*0.39,-100.0+stroke*6.0])
		doc.paint.append({"surface":2,"width":2.0,"shape":"round","points":points})
	var library := TrackLibrary.new(out+"/probe-storage/paint")
	var baseline_errors: Array[String] = TrackDocument.validate(doc,false)
	var baseline_save: Error = library.save_wip(doc)
	var canvas := EditorCanvas.new()
	canvas.document = doc; canvas.mode = "paint"; canvas.paint_mode = "free"
	canvas.paint_points = [[0.0,0.0],[1.0,0.0]]
	canvas.confirm_paint()
	var current_errors: Array[String] = TrackDocument.validate(doc,false)
	var current_save: Error = library.save_wip(doc)
	var recovery: Dictionary = library.load_wip(doc.id)
	observe("paint_global_limit",{"before_points":16384,"baseline_errors":baseline_errors,"baseline_save":baseline_save,
		"after_strokes":doc.paint.size(),"errors":current_errors,"save_error":current_save,
		"pending_points_after_confirm":canvas.paint_points.size(),"recovery_strokes":recovery.paint.size()})
	canvas.free()

func road_admission() -> void:
	var doc: Dictionary = TrackDocument.create_blank(); doc.id = "road_admission"
	for index: int in range(33):
		var piece: Dictionary = RoadPieces.create("straight",Vector2(-60,-96+index*6),0,6)
		piece.length = 120.0; doc.pieces.append(piece)
	var library := TrackLibrary.new(out+"/probe-storage/roads")
	var baseline_errors: Array[String] = TrackDocument.validate(doc,false)
	var baseline_save: Error = library.save_wip(doc)
	var canvas := EditorCanvas.new(); canvas.document = doc
	canvas.ghost = RoadPieces.create("straight",Vector2(-60,108),0,6); canvas.ghost.length = 120.0
	canvas.confirm_piece()
	var current_errors: Array[String] = TrackDocument.validate(doc,false)
	var current_save: Error = library.save_wip(doc)
	observe("road_global_limit",{"before_metres":3960,"after_metres":4080,"baseline_errors":baseline_errors,
		"baseline_save":baseline_save,"after_pieces":doc.pieces.size(),"ghost_retained":not canvas.ghost.is_empty(),
		"errors":current_errors,"save_error":current_save,"recovery_pieces":library.load_wip(doc.id).pieces.size()})
	canvas.free()

func touch(canvas: EditorCanvas, point: Vector2, pressed: bool, cancelled: bool = false) -> void:
	var event := InputEventScreenTouch.new(); event.index = 7; event.position = point
	event.pressed = pressed; event.canceled = cancelled; canvas._gui_input(event)

func interrupted_drag() -> void:
	var canvas := EditorCanvas.new(); canvas.document = TrackDocument.create_blank()
	canvas.document.objects = [{"kind":"container","position":[0.0,0.0],"rotation":0.0}]
	canvas.mode = "objects"; canvas.size = Vector2(1280,720); root.add_child(canvas)
	var counts: Dictionary = {"started":0,"finished":0,"cancelled":0}
	canvas.edit_started.connect(func() -> void: counts.started += 1)
	canvas.edit_finished.connect(func() -> void: counts.finished += 1)
	canvas.edit_cancelled.connect(func() -> void: counts.cancelled += 1)
	var first: Vector2 = canvas.to_screen(Vector2.ZERO)
	touch(canvas,first,true)
	var drag := InputEventScreenDrag.new(); drag.index = 7; drag.position = canvas.to_screen(Vector2(10,0))
	canvas._gui_input(drag); touch(canvas,drag.position,false,true)
	observe("cancelled_object_touch",{"position":canvas.document.objects[0].position,"signals":counts.duplicate()})
	canvas.document.objects[0].position = [0.0,0.0]; counts.started = 0; counts.finished = 0; counts.cancelled = 0
	touch(canvas,first,true); canvas._gui_input(drag); canvas.cancel_gesture()
	observe("cancel_gesture_after_drag",{"position":canvas.document.objects[0].position,"signals":counts.duplicate()})
	canvas.queue_free(); await process_frame

func settle(label: String) -> void:
	var began: int = Time.get_ticks_usec(); var deadline: int = Time.get_ticks_msec()+45000
	var intervals: Array[float] = []
	while (app.editor_commits.unsettled() or app.editor_preview_thread != null or app.editor_world._building) and Time.get_ticks_msec()<deadline:
		var frame: int = Time.get_ticks_usec(); await process_frame
		intervals.append((Time.get_ticks_usec()-frame)/1000.0)
	intervals.sort()
	observe(label,{"elapsed_ms":(Time.get_ticks_usec()-began)/1000.0,"frames":intervals.size(),
		"max_interval_ms":intervals[-1] if not intervals.is_empty() else 0.0,"settled":app.editor_preview_thread == null and not app.editor_world._building})

func editor_feedback() -> void:
	app = load("res://core/app.tscn").instantiate()
	app.library = TrackLibrary.new(out+"/probe-storage/app")
	app.records = LocalRecords.new(out+"/probe-storage/records.json")
	app.cloud_root_override = out+"/probe-storage/cloud"
	root.add_child(app)
	while not app.startup_complete: await process_frame
	app.document = TrackDocument.create_blank(); app.document.id = "feedback_probe"
	app._show_screen("create"); await settle("blank_entry")
	app.canvas.ghost = RoadPieces.create("straight",Vector2(-105,0),180,6)
	app.canvas.ghost.length = 4.0
	app._build_editor_tools(); app.editor_status.hide()
	var before: Dictionary = app.canvas.ghost.duplicate(true)
	app._change_piece("length",120.0)
	observe("invalid_parameter_feedback",{"before_errors":RoadPieces.validate(before),"unchanged":before == app.canvas.ghost,
		"status_visible":app.editor_status.is_visible_in_tree(),"text":app.editor_status.text})
	app.canvas.ghost.clear(); app._build_editor_tools()
	var piece: Dictionary = RoadPieces.create("straight",Vector2(-40,0),0,6); piece.length = 80.0
	app.document.pieces = [piece]
	app._save_draft(true); await settle("single_road_prepare")
	app.document.objects = [{"kind":"container","position":[0.0,0.0],"rotation":0.0}]
	app._save_draft(true); await settle("object_prepare")
	app._editor_category("objects"); app.canvas.mode = "objects"; app.canvas.selected_object = 0
	app._build_editor_tools()
	var first: Vector2 = app.canvas.to_screen(Vector2.ZERO)
	touch(app.canvas,first,true)
	var drag := InputEventScreenDrag.new(); drag.index = 7; drag.position = app.canvas.to_screen(Vector2(10,0))
	app.canvas._gui_input(drag)
	var before_escape: Array = app.document.objects[0].position.duplicate()
	var escape := InputEventKey.new(); escape.keycode = KEY_ESCAPE; escape.pressed = true
	app._unhandled_key_input(escape)
	app._flush_editor_writes()
	observe("escape_during_object_drag",{"original_position":[0.0,0.0],"before_escape":before_escape,
		"after_escape":app.document.objects[0].position,"wip_position":app.library.load_wip(app.document.id).objects[0].position,
		"undo_entries":app.history.size()})
	app._editor_category("road"); app.canvas.choose_piece("straight")
	app._share_dialog()
	var share_open: bool = false
	for dialog: Node in app.root_ui.find_children("*","AcceptDialog",true,false):
		if dialog.title == "Share your circuit":
			share_open = dialog.visible; dialog.hide(); dialog.queue_free()
	observe("share_pending_road",{"pending_work":app._has_pending_editor_work(),"dialog_open":share_open,
		"ghost_kind":app.canvas.ghost.get("kind",""),"shared_document_pieces":app.document.pieces.size()})
	app.canvas.ghost.clear(); app.canvas.selected_piece = 0
	app.document["start_line"] = {"position":[-40.0,0.0],"heading":0.0}
	app.canvas.zoom = 4.0 / maxf(0.01,minf(app.canvas.size.x/110.0,app.canvas.size.y/90.0))
	app._build_editor_tools()
	var accept: Rect2 = app.canvas.piece_accept_rect(app.document.pieces[0])
	var flip: Vector2 = app.canvas.start_controls().flip
	var overlap: Rect2 = accept.intersection(Rect2(flip-Vector2(28,28),Vector2(56,56)))
	var point: Vector2 = overlap.get_center()
	var heading_before: float = app.document.start_line.heading
	touch(app.canvas,point,true); touch(app.canvas,point,false)
	observe("road_accept_start_flip_overlap",{"accept_rect":[accept.position.x,accept.position.y,accept.size.x,accept.size.y],
		"overlap_size":[overlap.size.x,overlap.size.y],"inside_flip_circle":point.distance_to(flip)<=28,
		"heading_before":heading_before,"heading_after":app.document.start_line.heading,"selected_piece_after":app.canvas.selected_piece})
	app.queue_free(); await process_frame

func run() -> void:
	DirAccess.make_dir_recursive_absolute(out)
	root.size = Vector2i(1280,720)
	paint_admission(); road_admission(); await interrupted_drag(); await editor_feedback()
	var file := FileAccess.open(out+"/audit-"+DisplayServer.get_name()+".json",FileAccess.WRITE)
	file.store_string(JSON.stringify(observations,"\t")); file.close()
	await create_timer(0.3).timeout
	print("TRACK_EDITOR_AUDIT_COMPLETE")
	quit()
