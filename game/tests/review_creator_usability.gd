extends SceneTree
## Exploratory review observations, not assertions that preserve known bugs.
## All writes are isolated from owner drafts and records.

var app: Node
var folder: String

func _initialize() -> void:
	call_deferred("run")

func observe(id: String, values: Dictionary) -> void:
	print("REVIEW ",id," ",JSON.stringify(values))

func show_doc(doc: Dictionary) -> void:
	app.set("canvas",null)
	app.set("editor_view",{})
	app.set("document",doc.duplicate(true))
	app.set("history",[])
	app.set("redo_history",[])
	app.set("editor_geometry","")
	app.call("_show_screen","create")
	await process_frame
	await process_frame
	app.call("_save_draft")

func button(node: Node, label: String) -> Button:
	if node is Button and node.text == label: return node
	for child: Node in node.get_children():
		var found: Button = button(child,label)
		if found != null: return found
	return null

func run() -> void:
	root.size = Vector2i(1280,720)
	folder = "user://creator_review_"+TrackLibrary.unique_id()
	DirAccess.make_dir_recursive_absolute(folder)
	app = load("res://core/app.tscn").instantiate()
	app.set("library",TrackLibrary.new(folder))
	app.set("records",LocalRecords.new(folder+"/records.json"))
	root.add_child(app)
	await process_frame
	var doc: Dictionary = TrackDocument.create_blank()
	doc.id = "review_track"
	var position := Vector2.ZERO
	for i: int in range(4):
		var piece: Dictionary = RoadPieces.create("curve",position,float(i)*90)
		piece.length = 0.0
		doc.pieces.append(piece)
		position = RoadPieces.end_pose(piece).position
	await show_doc(doc)
	var canvas: EditorCanvas = app.get("canvas")
	var off_road: int = 0
	for p: Vector2 in canvas.native_preview.route:
		if canvas.native_preview.cell_at(p) != 0: off_road += 1
	observe("unconfigured_lap",{"open_ends":RoadPieces.joins(doc.pieces).size(),"lap_samples_off_asphalt":off_road,"samples":canvas.native_preview.route.size(),"test_enabled":not (app.get("test_button") as Button).disabled,"share_enabled":not (app.get("share_button") as Button).disabled,"issues":(app.get("editor_issues") as Array).size()})
	app.call("_route_from_roads")
	var ready: Dictionary = (app.get("document") as Dictionary).duplicate(true)
	canvas.selected_piece = 0
	app.call("_change_piece","width",2.0)
	var changed: Dictionary = app.get("document")
	var snapped: Dictionary = RoadPieces.snap(changed.pieces[0],changed.pieces,0)
	observe("individual_width",{"requested_width":changed.pieces[0].width,"open_ends":RoadPieces.joins(changed.pieces).size(),"route_generation_ok":RoadPieces.connected_route(changed.pieces).ok,"width_after_snap":snapped.piece.width})
	await show_doc(ready)
	canvas = app.get("canvas")
	canvas.choose_piece("straight")
	var pieces_before: int = canvas.document.pieces.size()
	await app.call("_test_document")
	await process_frame
	var game: Node = app.get("game")
	var test_started: bool = game != null
	if test_started: app.call("_leave_race")
	await process_frame
	canvas = app.get("canvas")
	observe("preview_test_return",{"test_started":test_started,"pending_piece_survives":not canvas.ghost.is_empty(),"committed_count_before":pieces_before,"committed_count_after":canvas.document.pieces.size()})
	await show_doc(ready)
	canvas = app.get("canvas")
	canvas.selected_piece = 0
	canvas.snap_enabled = false
	var point: Vector2 = canvas.to_screen(RoadPieces.samples(canvas.document.pieces[0])[8])
	canvas._begin(point,-1)
	canvas._move(point+Vector2(150*canvas.scale_factor(),0))
	canvas._end(-1)
	var errors: Array[String] = TrackDocument.validate(app.get("document"))
	var saved: Dictionary = (app.get("library") as TrackLibrary).load_document(ready.id)
	observe("out_of_bounds_drag",{"invalid":not errors.is_empty(),"error":errors[0] if not errors.is_empty() else "","disk_matches_visible_edit":saved == app.get("document"),"old_native_preview_retained":canvas.native_preview.content_hash == TrackCompiler.compile(ready).content_hash})
	await show_doc(ready)
	canvas = app.get("canvas")
	canvas.choose_piece("straight")
	var pending: Dictionary = canvas.ghost.duplicate(true)
	var first := InputEventScreenTouch.new()
	first.index = 0; first.position = Vector2(190,100); first.pressed = true
	canvas._gui_input(first)
	var second := InputEventScreenTouch.new()
	second.index = 1; second.position = Vector2(450,100); second.pressed = true
	canvas._gui_input(second)
	observe("pinch_pending_piece",{"preview_moved_before_pinch":canvas.ghost.position != pending.position})
	canvas.cancel_gesture()
	await show_doc(ready)
	canvas = app.get("canvas")
	canvas.selected_piece = 0
	app.call("_change_piece","width",2.0)
	app.call("_focus_issue")
	var first_issue: Vector2 = canvas.issue_marker
	app.call("_focus_issue")
	observe("issue_navigation",{"issue_count":(app.get("editor_issues") as Array).size(),"repeated_tap_same_issue":canvas.issue_marker == first_issue})
	var blank: Dictionary = TrackDocument.create_blank()
	blank.id = "review_blank"
	await show_doc(blank)
	canvas = app.get("canvas")
	canvas.mode = "run"
	canvas.stamp_kind = "barrier"
	canvas._place(canvas.to_screen(Vector2(-30,-10)))
	canvas._place(canvas.to_screen(Vector2(20,15)))
	observe("barriers_without_road",{"placed_objects":canvas.document.objects.size(),"road_pieces":canvas.document.pieces.size(),"paint_strokes":canvas.document.paint.size()})
	await show_doc(ready)
	canvas = app.get("canvas")
	var draft: Dictionary = app.get("document")
	draft["practice_start"] = {"position":[0.0,0.0],"heading":0.0}
	app.call("_editor_category","paint")
	button(app.get("root_ui"),"Clear map").pressed.emit()
	observe("clear_map",{"practice_start_retained":draft.has("practice_start"),"lap_nodes_retained":draft.points.size(),"test_enabled":not (app.get("test_button") as Button).disabled})
	app.queue_free()
	await process_frame
	var directory := DirAccess.open(folder)
	for file: String in directory.get_files(): DirAccess.remove_absolute(folder+"/"+file)
	DirAccess.remove_absolute(folder)
	print("REVIEW_COMPLETE: observations only; no owner drafts modified")
	quit()
