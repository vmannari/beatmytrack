extends "res://tests/audit_track_editor_2026_10_28.gd"
## Regression coverage for the eight editor review findings. Workspace-only saves.
var checks: int = 0
var failures: int = 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; print("FAIL: ",message)
func observe(key: String, value: Variant) -> void:
	# The review-only fixture labels the proposed 4080 m as "after_metres".
	# Its committed sections are all 120 m: report their actual retained total.
	if key == "road_global_limit": value.after_metres = value.after_pieces*120.0
	super.observe(key,value)
	match key:
		"paint_global_limit":
			check(value.baseline_errors.is_empty() and value.baseline_save == OK,"paint boundary starts recoverable")
			check(value.after_strokes == 32 and value.pending_points_after_confirm == 2,"excess paint remains a preview")
			check(value.errors.is_empty() and value.save_error == OK and value.recovery_strokes == 32,"rejected paint keeps exact recoverable data")
		"road_global_limit":
			check(value.after_metres == 3960.0,"rejected section leaves the committed road length unchanged")
			check(value.baseline_errors.is_empty() and value.baseline_save == OK,"road boundary starts recoverable")
			check(value.after_pieces == 33 and value.ghost_retained,"excess road remains a preview")
			check(value.errors.is_empty() and value.save_error == OK and value.recovery_pieces == 33,"rejected road keeps exact recoverable data")
		"cancelled_object_touch","cancel_gesture_after_drag":
			check(value.position == [0.0,0.0],key+" rolls back movement")
			check(value.signals.finished == 0 and value.signals.cancelled == 1,key+" cancels exactly one transaction")
		"invalid_parameter_feedback":
			check(value.unchanged and value.status_visible and not value.text.is_empty(),"rejected parameter has visible feedback")
		"escape_during_object_drag":
			check(value.before_escape == [10.0,0.0] and value.after_escape == [0.0,0.0],"Esc restores the actual moved object")
			check(value.wip_position == [0.0,0.0] and value.undo_entries == 0,"Esc restores WIP and grouped undo")
		"share_pending_road": check(value.pending_work and not value.dialog_open,"Share waits for preview resolution")
		"road_accept_start_flip_overlap": check(value.overlap_size == [0.0,0.0] and value.heading_after == value.heading_before,"separate accept and direction targets")

func handles_and_lighting() -> void:
	var canvas := EditorCanvas.new(); root.add_child(canvas); canvas.size = Vector2(1280,720)
	canvas.document = TrackDocument.create_blank()
	for heading: float in [0.0,45.0,90.0,135.0,180.0,225.0,270.0,315.0]:
		var piece: Dictionary = RoadPieces.create("straight",Vector2(-30,0),heading,6)
		piece.length = 56.0; canvas.document.pieces = [piece]
		canvas.document["start_line"] = {"position":piece.position.duplicate(),"heading":heading}
		for scale: float in [1.0,4.0,8.0]:
			canvas.zoom = scale/8.0; canvas.selected_piece = 0
			var accept: Rect2 = canvas.piece_accept_rect(piece)
			var flip: Vector2 = canvas.start_controls().flip
			var nearest: Vector2 = flip.clamp(accept.position,accept.end)
			check(flip.distance_to(nearest) > 28.0,"accept avoids arrow circle at %s/%s" % [heading,scale])
			var before: float = canvas.document.start_line.heading
			touch(canvas,accept.get_center(),true); touch(canvas,accept.get_center(),false)
			check(canvas.selected_piece == -1 and canvas.document.start_line.heading == before,"accept deselects without changing heading")
	var world := EditorWorld.new(); world.theme_id = "night_city"; root.add_child(world)
	check(world.environment.ambient_light_energy >= 0.35 and world.sunlight.light_energy >= 0.5,"Night defaults to readable authoring light")
	world.set_race_lighting_preview(true)
	check(is_equal_approx(world.environment.ambient_light_energy,0.045) and is_equal_approx(world.sunlight.light_energy,0.025),"Night race preview retains exact racing light")
	world.set_race_lighting_preview(false)
	check(world.environment.ambient_light_energy >= 0.35,"authoring light restores")
	world.queue_free(); canvas.queue_free(); await process_frame

func share_choices() -> void:
	app = load("res://core/app.tscn").instantiate()
	app.library = TrackLibrary.new(out+"/share-storage")
	app.records = LocalRecords.new(out+"/share-records.json")
	app.cloud_root_override = out+"/share-cloud"; root.add_child(app)
	while not app.startup_complete: await process_frame
	app.document = TrackDocument.create_blank(); app.document.id = "share_choices"
	app._show_screen("create"); await settle("share_entry")
	app.canvas.choose_piece("straight"); app._share_dialog()
	var dialog: ConfirmationDialog = app.root_ui.find_child("PendingPreviewDialog",true,false)
	check(dialog != null and dialog.visible,"Share opens explicit resolution")
	dialog.canceled.emit(); await process_frame
	check(not app.canvas.ghost.is_empty() and app.document.pieces.is_empty(),"Cancel retains preview and original")
	app._share_dialog(); dialog = app.root_ui.find_child("PendingPreviewDialog",true,false)
	dialog.confirmed.emit(); await process_frame
	check(app.document.pieces.size() == 1 and app.canvas.ghost.is_empty(),"Confirm includes the road in the shared document")
	check(app.library.load_wip(app.document.id).pieces.size() == 1,"Confirm saves exactly the shared document")
	for notice: Node in app.root_ui.find_children("*","AcceptDialog",true,false): notice.hide(); notice.queue_free()
	await process_frame
	app.canvas.choose_piece("straight"); app._editor_category("paint")
	app.canvas.paint_mode = "line"; app.canvas.paint_points = [[20.0,20.0],[25.0,25.0]]
	app._editor_category("objects"); app._share_dialog()
	dialog = app.root_ui.find_child("PendingPreviewDialog",true,false)
	check(dialog != null,"hidden road and paint previews require resolution")
	dialog.custom_action.emit(&"discard"); await process_frame
	check(not app._has_pending_editor_work() and app.document.pieces.size() == 1 and app.document.paint.is_empty(),"Discard resolves all tools without adding work")
	app.queue_free(); await process_frame

func history_integrity() -> void:
	var history = preload("res://editor/editor_history.gd")
	var session = preload("res://editor/editor_session.gd").new()
	var document: Dictionary = TrackDocument.create_blank()
	for index: int in range(4096): document.objects.append({"kind":"grass_clump","position":[float(index%64)-32,float(index/64)-32],"rotation":0.0})
	session.prime(document)
	check(not session.primed.is_empty() and history.matches(session.primed,document),"loaded large document primes an exact immutable checkpoint")
	var expected: Dictionary = document.duplicate(true)
	session.begin_gesture(document); document.objects[0].position[0] += 2.0
	session.cancel_gesture()
	check(session.undo.is_empty() and session.primed.is_empty(),"cancel releases a consumed primed checkpoint without adding history")
	document = expected.duplicate(true); session.prime(document)
	document.objects[0].position[0] += 1.0
	session.remember(document)
	check(history.restore(session.undo[0]) == document,"changed data rejects stale priming and captures its exact replacement")
	var restored: Dictionary = history.restore(session.undo[0])
	restored.objects[0].position[0] += 3.0
	check(history.restore(session.undo[0]) == document,"restored history is editable and cannot mutate checkpoint values")
	check(history.bytes_used([session.undo,session.redo]) <= history.BUDGET,"large history retains the original shared allowance")

func run() -> void:
	out = ProjectSettings.globalize_path("res://../docs/evidence/track-editor-fixes-2026-10-28/focused/"+DisplayServer.get_name()+"-"+RenderingServer.get_current_rendering_method())
	DirAccess.make_dir_recursive_absolute(out); root.size = Vector2i(1280,720)
	paint_admission(); road_admission(); await interrupted_drag(); await editor_feedback()
	await handles_and_lighting(); await share_choices(); history_integrity()
	var file := FileAccess.open(out+"/results.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"observations":observations},"\t")); file.close()
	await create_timer(0.3).timeout
	print("EDITOR_REVIEW_ITEMS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
