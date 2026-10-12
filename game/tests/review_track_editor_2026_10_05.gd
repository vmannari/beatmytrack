extends SceneTree
## Disposable observations for a review; known problems are not passing invariants.

var app: Node
var folder: String
var evidence: String

class FailedSaveLibrary extends TrackLibrary:
	func save_wip(_document: Dictionary) -> Error:
		last_error = "Injected storage write failure"
		return ERR_FILE_CANT_WRITE

func _initialize() -> void:
	call_deferred("run")

func observe(label: String, data: Dictionary) -> void:
	print("EDITOR_REVIEW ",label," ",JSON.stringify(data))

func settle() -> void:
	var deadline: int = Time.get_ticks_msec()+30000
	var slowest: float = 0.0
	var started: int = Time.get_ticks_usec()
	while (app.editor_preview_thread != null or app.editor_world._building) and Time.get_ticks_msec()<deadline:
		var before: int = Time.get_ticks_usec()
		await process_frame
		slowest = maxf(slowest,(Time.get_ticks_usec()-before)/1000.0)
	observe("settle",{"elapsed_ms":(Time.get_ticks_usec()-started)/1000.0,"longest_frame_interval_ms":slowest,"completed":app.editor_preview_thread == null and not app.editor_world._building})

func show(doc: Dictionary) -> void:
	app.canvas = null
	app.editor_view.clear()
	app.history.clear()
	app.redo_history.clear()
	app.document = doc.duplicate(true)
	var started: int = Time.get_ticks_usec()
	app.call("_show_screen","create")
	observe("open",{"pieces":doc.pieces.size(),"handler_ms":(Time.get_ticks_usec()-started)/1000.0})
	await process_frame
	await settle()

func oval() -> Dictionary:
	var doc: Dictionary = TrackDocument.create_blank()
	doc.id = "review_oval"
	doc.name = "Editor review oval"
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
	return RoadPieces.route_from_pieces(doc).document

func shot(name: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(evidence+"/"+name+".png")

func run() -> void:
	evidence = ProjectSettings.globalize_path("res://").path_join("../docs/evidence/track-editor-review-2026-10-05").simplify_path()
	DirAccess.make_dir_recursive_absolute(evidence)
	root.size = Vector2i(1280,720)
	folder = "user://editor_review_20261005_"+TrackLibrary.unique_id()
	app = load("res://core/app.tscn").instantiate()
	app.library = TrackLibrary.new(folder)
	app.records = LocalRecords.new(folder+"/records.json")
	root.add_child(app)
	await process_frame
	await show(oval())
	await shot("road-desktop")
	# A clean saved document with a changed, unconfirmed road is still 'clean'.
	app.call("_save_draft")
	app.editor_saved_snapshot = app.document.duplicate(true)
	app.canvas.choose_piece("curve")
	app.canvas.ghost.radius = 23.0
	observe("pending_departure",{"has_pending_road":not app.canvas.ghost.is_empty(),"dirty":app.call("_editor_has_unsaved_changes")})
	app.call("_request_editor_exit")
	observe("pending_departure_result",{"screen":app.screen,"save_dialog":app.root_ui.find_child("SaveChangesDialog",true,false) != null})
	await show(oval())
	app.canvas.choose_piece("curve")
	app.canvas.ghost.radius = 23.0
	app.call("_editor_category","objects")
	observe("category_pending_road",{"survives":not app.canvas.ghost.is_empty()})
	await shot("objects-desktop")
	var browser_samples: Array = []
	for repeat: int in range(3):
		var started: int = Time.get_ticks_usec()
		app.object_browser.refresh()
		browser_samples.append((Time.get_ticks_usec()-started)/1000.0)
		await process_frame
	observe("object_browser_refresh",{"handler_ms":browser_samples,"tiles":app.object_browser.tiles.get_child_count()})
	# Multi-touch navigation should not commit a one-finger content move.
	app.call("_editor_category","road")
	app.canvas.selected_piece = 0
	app.canvas.snap_enabled = false
	var before_piece: Dictionary = app.document.pieces[0].duplicate(true)
	var at: Vector2 = app.canvas.to_screen(Vector2(10,-18))
	var first := InputEventScreenTouch.new()
	first.index = 0; first.position = at; first.pressed = true
	app.canvas._gui_input(first)
	var move := InputEventScreenDrag.new()
	move.index = 0; move.position = at+Vector2(14,0)
	app.canvas._gui_input(move)
	var second := InputEventScreenTouch.new()
	second.index = 1; second.position = at+Vector2(200,70); second.pressed = true
	app.canvas._gui_input(second)
	observe("pinch_after_initial_motion",{"piece_moved":app.document.pieces[0] != before_piece,"history":app.history.size(),"preview_worker":app.editor_preview_thread != null})
	app.canvas.cancel_gesture()
	await settle()
	# Repeated issue taps always select the same issue.
	var open_doc: Dictionary = oval()
	open_doc.pieces[0].position[0] += 8.0
	await show(open_doc)
	var selected: Array = []
	for i: int in range(3):
		app.call("_focus_issue")
		selected.append(app.canvas.selected_piece)
	observe("issue_navigation",{"issue_count":app.editor_issues.size(),"selected_pieces":selected,"status_visible":app.editor_status.is_visible_in_tree()})
	await shot("issues-desktop")
	# Inject the write-failure return at the persistence boundary. The command
	# wrapper correctly stops on genuine engine filesystem ERROR messages.
	var old_library: TrackLibrary = app.library
	app.library = FailedSaveLibrary.new(folder)
	app.library.owner_name = old_library.owner_name
	app.document.name = "Unsaved change"
	var save_error: Error = app.call("_save_draft",true)
	observe("autosave_failure",{"error":save_error,"status":app.editor_status.text,"status_visible":app.editor_status.is_visible_in_tree(),"dirty":app.call("_editor_has_unsaved_changes")})
	await shot("save-failure-desktop")
	app.library = old_library
	await settle()
	# Road-follow runs on a blank map use the invisible fallback route.
	var blank: Dictionary = TrackDocument.create_blank()
	observe("barriers_without_roads",{"pieces":blank.pieces.size(),"paint":blank.paint.size(),"barriers":RoadPieces.barrier_run(blank,Vector2(-38,-12),Vector2(-25,22)).size()})
	# Compact layout uses the actual app controls and graphical renderer.
	root.size = Vector2i(960,540)
	await show(oval())
	var identity: Control = app.root_ui.find_child("EditorIdentityAndHistory",true,false)
	var issue_parent: Control = app.editor_issue_button.get_parent()
	observe("compact_header",{"identity_rect":str(identity.get_global_rect()),"actions_rect":str(issue_parent.get_global_rect()),"overlap":identity.get_global_rect().intersects(issue_parent.get_global_rect())})
	await shot("road-compact")
	app.call("_editor_category","paint")
	await process_frame
	observe("surface_header",{"toolbar_rect":str(app.surface_toolbar.get_global_rect()),"identity_rect":str(identity.get_global_rect()),"overlap":app.surface_toolbar.get_global_rect().intersects(identity.get_global_rect()),"physical_size":str(root.size),"logical_size":str(root.get_visible_rect().size)})
	await shot("surface-compact")
	app.call("_editor_category","objects")
	await process_frame
	await shot("objects-compact")
	# Measure supported authoring sizes; disconnected sections are legitimate WIP.
	root.size = Vector2i(1280,720)
	for count: int in [4,24,48,96]:
		var large: Dictionary = TrackDocument.create_blank()
		large.id = "review_scale"
		large.name = "Scale %d" % count
		for i: int in range(count):
			var piece: Dictionary = RoadPieces.create("straight",Vector2(-100+(i%12)*17,-94+(i/12)*24),0,6)
			piece.length = 12.0
			large.pieces.append(piece)
		var samples: Array = []
		for repetition: int in range(3):
			var started: int = Time.get_ticks_usec()
			RoadPieces.route_from_pieces(large)
			RoadPieces.joins(large.pieces)
			samples.append((Time.get_ticks_usec()-started)/1000.0)
		observe("route_and_issues",{"pieces":count,"handler_samples_ms":samples,"validation_errors":TrackDocument.validate(large,false)})
		if count != 96: continue
		await show(large)
		app.call("_remember")
		app.document.pieces[0].position[0] += 1.0
		var started: int = Time.get_ticks_usec()
		app.call("_save_draft",true)
		observe("large_edit",{"pieces":count,"save_and_queue_ms":(Time.get_ticks_usec()-started)/1000.0})
		started = Time.get_ticks_usec()
		app.call("_undo")
		observe("large_undo",{"handler_ms":(Time.get_ticks_usec()-started)/1000.0})
		await settle()
		await shot("large-ready")
		started = Time.get_ticks_usec()
		app.call("_update_editor_issues")
		observe("large_issue_refresh",{"handler_ms":(Time.get_ticks_usec()-started)/1000.0,"issues":app.editor_issues.size()})
	# A 96-piece connected loop uses 47 minimum-length straights per side,
	# with two hairpins. This also covers complete authoring, not only open WIP.
	var closed: Dictionary = TrackDocument.create_blank()
	closed.id = "review_closed"
	closed.name = "96 connected pieces"
	var position := Vector2(-47,-36)
	var heading: float = 0.0
	for side: int in range(2):
		for i: int in range(47):
			var piece: Dictionary = RoadPieces.create("straight",position,heading,6)
			piece.length = 2.0
			closed.pieces.append(piece)
			position = RoadPieces.end_pose(piece).position
		var turn: Dictionary = RoadPieces.create("hairpin",position,heading,6)
		turn.radius = 36.0
		closed.pieces.append(turn)
		var pose: Dictionary = RoadPieces.end_pose(turn)
		position = pose.position; heading = pose.heading
	var started: int = Time.get_ticks_usec()
	var route: Dictionary = RoadPieces.route_from_pieces(closed)
	observe("closed_route",{"pieces":96,"ok":route.ok,"elapsed_ms":(Time.get_ticks_usec()-started)/1000.0,"errors":route.errors})
	if route.ok:
		await show(route.document)
		app.call("_remember")
		app.document.name = "Changed closed title"
		started = Time.get_ticks_usec()
		app.call("_save_draft",true)
		observe("closed_edit",{"save_and_queue_ms":(Time.get_ticks_usec()-started)/1000.0})
		started = Time.get_ticks_usec()
		app.call("_save_draft")
		observe("closed_foreground_save",{"handler_ms":(Time.get_ticks_usec()-started)/1000.0})
		await settle()
		await shot("closed-large-ready")
	app.queue_free()
	await process_frame
	# Remove only this uniquely allocated disposable directory.
	cleanup(folder)
	cleanup("user://editor_review_20261005_track_21de8308f09cdede3fc87eb1fcf44d48")
	print("EDITOR_REVIEW_COMPLETED")
	quit()

func cleanup(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path): return
	for child: String in DirAccess.get_directories_at(path): cleanup(path.path_join(child))
	for file: String in DirAccess.get_files_at(path): DirAccess.remove_absolute(path.path_join(file))
	DirAccess.remove_absolute(path)
