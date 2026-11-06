extends SceneTree
## Actual App transactions and real isolated files for TER5-01 through TER5-03.
const WRITES = preload("res://editor/write_queue.gd")
var app: Node
var checks: int = 0
var failures: int = 0
var output: String
var original: bool = false

class FailingLibrary extends TrackLibrary:
	var fail_delete: bool = false
	var fail_copy: bool = false
	func delete_wip(id: String) -> Error:
		if fail_delete:
			last_error = "Injected recovery deletion failure."
			return ERR_FILE_CANT_WRITE
		return super.delete_wip(id)
	func save_wip(document: Dictionary) -> Error:
		if fail_copy:
			last_error = "Injected copy write failure."
			return ERR_FILE_CANT_WRITE
		return super.save_wip(document)

func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; printerr("EDITOR_FIX_FAIL ",message)
func frames(count: int = 4) -> void:
	for _index: int in range(count): await process_frame
func close_dialogs() -> void:
	for window: Node in app.find_children("*","Window",true,false):
		if window is Window: window.hide(); window.queue_free()
	await frames()
func settle() -> void:
	var deadline: int = Time.get_ticks_msec()+60000
	while Time.get_ticks_msec()<deadline and (app.editor_preview_thread != null or app.editor_commits.unsettled() or app.editor_writes.unsettled(app.library,str(app.document.get("id",""))) or (is_instance_valid(app.editor_world) and app.editor_world._building)):
		await process_frame
	check(app.editor_preview_thread == null and not app.editor_commits.unsettled(),"editor CPU work settles")
	await frames()
func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless" or output.is_empty(): return
	await frames()
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(output.path_join(label+".png")) == OK,"capture "+label)

func open_document(id: String, saved: bool = true) -> Dictionary:
	app._flush_editor_writes(); app._finish_preview_thread()
	var doc: Dictionary = TrackDocument.create_default()
	doc.id = id; doc.name = "Saved baseline"; doc["creator"] = app.library.owner_name
	doc.objects = [{"kind":"cone","position":[40.0,40.0],"rotation":0.0}]
	if saved:
		var error: Error = app.library.save_document(doc)
		check(error == OK,"saved original fixture persists: "+app.library.last_error)
		if error != OK: quit(2); return {}
	app.document = doc; app.canvas = null; app.editor_view.clear()
	app.editor_session = preload("res://editor/editor_session.gd").new()
	app.editor_saved_snapshot = doc.duplicate(true) if saved else {}
	app.editor_saved_store = app.library if saved else null
	app.editor_saved_disk_hash = ""
	app._show_screen("create")
	await settle()
	return doc.duplicate(true)

static func held_write(entry: Dictionary, started: Semaphore) -> Dictionary:
	started.post()
	OS.delay_usec(150000)
	return WRITES.write(entry)

func discard_cases() -> void:
	for state: String in ["settled","analysis","writer","active"]:
		var baseline: Dictionary = await open_document("discard_"+state)
		app.set_process(false)
		app._remember(); app.document.objects[0].position = [45.0,40.0]
		app._save_draft(true)
		if state == "settled": app._flush_editor_writes()
		elif state in ["writer","active"]:
			app.editor_commits.flush(); app._apply_editor_commits()
			if state == "active":
				app.editor_writes.active = app.editor_writes.pending.pop_front()
				app.editor_writes.thread = Thread.new()
				var started := Semaphore.new()
				check(app.editor_writes.thread.start(held_write.bind(app.editor_writes.active,started)) == OK,"active writer starts")
				started.wait()
				check(app.editor_writes.thread.is_alive(),"discard meets a real unfinished write")
		if state == "analysis": check(app.editor_commits.unsettled(),"analysis is pending at discard")
		elif state == "writer": check(app.editor_writes.unsettled(app.library,baseline.id),"write is queued at discard")
		app.canvas.choose_piece("straight")
		app._editor_category("paint")
		app.canvas.paint_mode = "line"; app.canvas.paint_points = [[20.0,20.0],[25.0,25.0]]
		app._open_drafts()
		var dialog: ConfirmationDialog = app.root_ui.find_child("SaveChangesDialog",true,false)
		check(dialog != null,"Load offers Save/Discard")
		if dialog == null: app.set_process(true); return
		dialog.custom_action.emit(&"discard")
		app.set_process(true)
		check(app.screen == "drafts","discard opens Load")
		check(app.library.load_wip(baseline.id).is_empty(),state+" discard removes every recovery revision")
		check(app.document == baseline and app.history.is_empty() and app.redo_history.is_empty(),state+" discard restores original and clears history")
		check(not app._has_pending_editor_work(),state+" discard removes active and hidden previews")
		await frames()
		var browser: Node = app.root_ui.find_child("DraftBrowser",true,false)
		browser.back_requested.emit()
		await settle()
		check(app.screen == "create" and app.document == baseline,state+" Back restores only saved data")
		check(not app._editor_has_unsaved_changes(),state+" restored data is clean")
		app._undo(); app._redo()
		check(app.document == baseline,state+" history cannot resurrect rejected edits")
		if state == "active": await capture("discard-restored-original")
	await open_document("discard_new",false)
	app._save_draft(true)
	app._open_drafts()
	var fresh: ConfirmationDialog = app.root_ui.find_child("SaveChangesDialog",true,false)
	fresh.custom_action.emit(&"discard")
	check(app.document.is_empty() and app.library.load_wip("discard_new").is_empty(),"never-saved discard clears the draft")
	await frames()
	app.root_ui.find_child("DraftBrowser",true,false).back_requested.emit()
	check(app.screen == "biome","Back after discarding new work returns to creation menu")

func failed_discard() -> void:
	var baseline: Dictionary = await open_document("discard_failure")
	app._remember(); app.document.objects[0].position = [48.0,40.0]
	app._save_draft(true); await settle()
	var edited: Dictionary = app.document.duplicate(true)
	var storage := FailingLibrary.new(app.library.directory)
	storage.owner_name = app.library.owner_name
	storage.fail_delete = true
	app.library = storage; app.lifecycle.library = storage
	app._open_drafts()
	var dialog: ConfirmationDialog = app.root_ui.find_child("SaveChangesDialog",true,false)
	dialog.custom_action.emit(&"discard")
	check(app.screen == "create" and app.document == edited,"failed deletion keeps the current editor")
	check(storage.load_wip(baseline.id) == edited and not app.history.is_empty(),"failed deletion preserves recovery and history")
	storage.fail_delete = false
	await close_dialogs()
	# A corrupt saved original must not cause the only recoverable edits to be deleted.
	for suffix: String in [".json",".json.bak",".json.tmp"]:
		var path: String = storage.directory.path_join(baseline.id+suffix)
		if not FileAccess.file_exists(path): continue
		var file := FileAccess.open(path,FileAccess.WRITE); file.store_string("invalid"); file.close()
	app._open_drafts()
	dialog = app.root_ui.find_child("SaveChangesDialog",true,false)
	dialog.custom_action.emit(&"discard")
	check(app.screen == "create" and app.document == edited,"unreadable original retains editor data")
	check(storage.load_wip(baseline.id) == edited,"unreadable original retains the recovery file")
	await close_dialogs()
	app.library = TrackLibrary.new(storage.directory); app.library.owner_name = storage.owner_name; app.lifecycle.library = app.library

func title_history() -> void:
	var baseline: Dictionary = await open_document("rename_history")
	app._remember(); app.document.objects[0].position = [50.0,40.0]
	app._save_draft(true); await settle()
	app._undo(); await settle()
	app._rename_track()
	var dialog: ConfirmationDialog = app.root_ui.find_child("RenameDialog",true,false)
	var field: LineEdit = dialog.find_child("CircuitName",true,false)
	field.text = "  New review name  "; dialog.confirmed.emit()
	await settle()
	check(app.document.name == "New review name" and app.history.size() == 1 and app.redo_history.is_empty(),"rename is one undo step and clears obsolete redo")
	app._redo()
	check(app.document.name == "New review name" and app.document.objects == baseline.objects,"obsolete redo cannot revert a rename or move an object")
	app._undo(); await settle()
	check(app.document == baseline,"Undo restores the old name and unchanged geometry")
	# Applying the same trimmed name must preserve the live redo branch.
	app._rename_track(); dialog = app.root_ui.find_child("RenameDialog",true,false)
	field = dialog.find_child("CircuitName",true,false)
	field.text = "  "+str(baseline.name)+"  "; dialog.confirmed.emit()
	await frames()
	check(app.history.is_empty() and app.redo_history.size() == 1,"no-op rename leaves history intact")
	app._redo(); await settle()
	check(app.document.name == "New review name" and app.library.load_wip(baseline.id).name == "New review name","Redo and autosave retain the renamed title")
	await capture("rename-redone")
	app._undo(); await settle()
	app._confirm_editor_departure(Callable(),false)
	dialog = app.root_ui.find_child("SaveChangesDialog",true,false)
	field = dialog.find_child("SaveDraftName",true,false)
	field.text = "Name from Save"; dialog.confirmed.emit()
	await settle(); await close_dialogs()
	check(app.document.name == "Name from Save" and app.redo_history.is_empty() and app.history.size() == 1,"Save-dialog title edit also branches history")
	app._undo(); await settle()
	check(app.document.name == baseline.name,"Save-dialog title can be undone")

func copies() -> void:
	await open_document("copy_source")
	app._show_screen("drafts"); await frames()
	var source: Dictionary = app.library.load_document("copy_source")
	for length: int in [35,36,40]:
		source.name = "ä".repeat(length)
		var before: Dictionary = source.duplicate(true)
		app._fork_track_draft(source)
		check(app.screen == "create" and str(app.document.name).length() == 40,"copy admits "+str(length)+"-character source")
		check(str(app.document.name).ends_with(" copy") and app.document.id != source.id,"copy retains suffix and new identity")
		check(app.library.load_wip(str(app.document.id)) == app.document and TrackDocument.validate(app.document).is_empty(),"copy persists a valid Unicode title")
		check(source == before,"copy does not mutate its source")
		await settle()
		if length == 40: await capture("copied-long-name")
		app._show_screen("drafts"); await frames()
	var storage := FailingLibrary.new(app.library.directory)
	storage.owner_name = app.library.owner_name; storage.fail_copy = true
	app.library = storage; app.lifecycle.library = storage
	var current: Dictionary = app.document
	var snapshot: Dictionary = current.duplicate(true)
	var history: Array = app.history.duplicate()
	app._fork_track_draft(source)
	check(is_same(app.document,current) and app.document == snapshot and app.screen == "drafts","failed copy keeps the current document and navigation")
	check(app.history == history,"failed copy preserves current history")
	storage.fail_copy = false
	await close_dialogs()

func run() -> void:
	create_timer(240,true,false,true).timeout.connect(func() -> void: printerr("EDITOR_FIX_TIMEOUT"); quit(2))
	root.size = Vector2i(1280,720)
	output = OS.get_environment("BMT_EDITOR_FIX_OUTPUT")
	if not output.is_empty(): DirAccess.make_dir_recursive_absolute(output)
	original = "--before" in OS.get_cmdline_user_args()
	var config := ConfigFile.new(); config.set_value("backend","url","")
	check(config.save("user://backend.cfg") == OK,"isolated offline configuration saves")
	app = load("res://core/app.tscn").instantiate()
	app.library = TrackLibrary.new("user://editor-fix-tests/"+TrackLibrary.unique_id())
	app.records = LocalRecords.new(app.library.directory+"/records.json"); app.records.settings.music_enabled = false
	app.cloud_root_override = app.library.directory+"/cloud"
	root.add_child(app)
	while not app.startup_complete: await process_frame
	check(not app.online.configured,"App is offline")
	if app.online.configured: quit(2); return
	app._garage_preloader.set_process(false)
	if original:
		var controller: Node = load("res://../docs/evidence/track-editor-fixes-2026-11-05/before/game/core/features/editor.gd").new()
		app.add_child(controller); app._feature_resources["res://core/features/editor.gd"] = controller; app._editor_module = controller
	await discard_cases(); await failed_discard(); await title_history(); await copies()
	app.queue_free(); GameSoundtrack.instance().queue_free()
	await frames(5); await create_timer(0.3).timeout
	if not output.is_empty():
		var file := FileAccess.open(output.path_join("results.json"),FileAccess.WRITE)
		file.store_string(JSON.stringify({"checks":checks,"failures":failures,"before":original,"renderer":DisplayServer.get_name()},"\t")); file.close()
	print("EDITOR_REVIEW_2026_11_05: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
