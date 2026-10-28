extends SceneTree
## Real Game input/lap capture and real local journals, with an injected receipt failure.
const Client = preload("res://backend/backend_client.gd")
const Cloud = preload("res://backend/cloud_tracks.gd")
const OUTPUT: String = "res://../docs/evidence/storm-test-recovery-2026-10-26"
var checks: int = 0
var failures: int = 0
var original: bool = false
var app: Node
var storage: ReceiptStorage
var flow: TrackLifecycle
var before_app: GDScript
var before_game: GDScript
var folder: String

class Harness extends "res://core/app.gd":
	func _ready() -> void: pass
	func _show_screen(next: String) -> void:
		screen = next
		root_ui.process_mode = Node.PROCESS_MODE_INHERIT
		root_ui.show()

class ReceiptStorage extends TrackLibrary:
	var fail_receipt: bool = true
	var calls: int = 0
	func mark_tested(document: Dictionary) -> Error:
		calls += 1
		if fail_receipt:
			last_error = "Test receipt storage is unavailable."
			return ERR_FILE_CANT_WRITE
		return super(document)

func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; print("FAIL: ",label)

func settle() -> void:
	for i: int in range(4): await process_frame
	if DisplayServer.get_name()!="headless": await RenderingServer.frame_post_draw

func current_dialog() -> AcceptDialog:
	for child: Node in app.root_ui.get_children():
		if child is AcceptDialog and child.visible and not child.is_queued_for_deletion(): return child
	return null

func dialogs() -> int:
	var count: int = 0
	for child: Node in app.root_ui.get_children():
		if child is AcceptDialog and not child.is_queued_for_deletion(): count += 1
	return count

func click(dialog: AcceptDialog, button: Button, touch: bool = false) -> void:
	var center: Vector2 = button.get_global_rect().get_center()
	if touch:
		var event := InputEventScreenTouch.new()
		event.index = 0; event.position = center; event.pressed = true
		dialog.push_input(event,true)
		event = event.duplicate(); event.pressed = false
		dialog.push_input(event,true)
	else:
		center += Vector2(dialog.position)
		var motion := InputEventMouseMotion.new()
		motion.position = center; motion.global_position = center
		root.push_input(motion,true)
		var event := InputEventMouseButton.new()
		event.position = center; event.global_position = center; event.button_index = MOUSE_BUTTON_LEFT; event.pressed = true
		event.button_mask = MOUSE_BUTTON_MASK_LEFT
		root.push_input(event,true)
		event = event.duplicate(); event.pressed = false
		event.button_mask = 0
		root.push_input(event,true)
	await settle()

func attempt(label: String, drafts: bool = false) -> void:
	app = Harness.new()
	if original: app.set_script(before_app)
	# Replace only the bootstrap/navigation hooks in the task-start App when
	# comparing it; the complete save/dialog/leave methods remain exact.
	if original:
		var source: String = FileAccess.get_file_as_string(OUTPUT+"/before/game/core/app.gd")
		var start: int = source.find("func _ready() -> void:")
		var stop: int = source.find("\nfunc ",start+1)
		source = source.left(start)+"func _ready() -> void:\n\tpass\n"+source.substr(stop)
		start = source.find("func _show_screen(")
		stop = source.find("\nfunc ",start+1)
		source = source.left(start)+"func _show_screen(next: String) -> void:\n\tscreen = next\n\troot_ui.process_mode = Node.PROCESS_MODE_INHERIT\n\troot_ui.show()\n"+source.substr(stop)
		var harness_script := GDScript.new(); harness_script.source_code = source
		check(harness_script.reload()==OK,"task-start App methods load in isolated process memory")
		app.set_script(harness_script)
	root.add_child(app)
	app.root_ui = Control.new()
	app.root_ui.size = Vector2(root.size)
	app.add_child(app.root_ui)
	var client := Client.new()
	app.add_child(client)
	client.configure("http://127.0.0.1:1")
	var cloud := Cloud.new()
	cloud.client = client
	cloud.root_override = folder.path_join(label+"/cloud")
	app.add_child(cloud)
	storage = ReceiptStorage.new(folder.path_join(label+"/tracks"))
	app.library = storage
	app.records = LocalRecords.new(folder.path_join(label+"/records.json"))
	app.cloud = cloud
	flow = TrackLifecycle.new()
	flow.cloud = cloud; flow.library = storage; flow.records = app.records
	app.add_child(flow)
	app.lifecycle = flow
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://../backend/tests/fixtures/verified_oval.json"))
	var document: Dictionary = data.document.duplicate(true)
	document.id = "recovery_"+label
	document.creator = "Guest"
	check(storage.save_document(document)==OK,"fixture draft saved before practice: "+label)
	app.document = document
	app.test_document_snapshot = document.duplicate(true)
	app.test_library_snapshot = storage
	app.test_scope_snapshot = flow.scope()
	app.test_vehicle_snapshot = "compact"
	app.test_return_to_drafts = drafts
	app.returning_to_editor = true
	app.screen = "drafts" if drafts else "create"
	app._telemetry_race_finished = true
	var track: NativeTrack = TrackCompiler.compile(document)
	check(track!=null,"test fixture compiles: "+label)
	var game: Node = preload("res://core/game.tscn").instantiate()
	if original: game.set_script(before_game)
	game.initial_track = track; game.editor_test = true; game.production_mode = true
	app.game = game
	app.add_child(game)
	while not game.preparation_complete: await process_frame
	game.set_process(false); game.set_physics_process(false)
	app.root_ui.process_mode = Node.PROCESS_MODE_DISABLED
	app.root_ui.hide()
	game.practice_lap_completed.connect(app._complete_draft_test,CONNECT_DEFERRED)
	var driver := RouteDriver.new()
	for tick: int in range(24000):
		var frame: DriveFrame = driver.sample(game.sim.state,track,game.handling)
		game.driver.clear()
		game.driver.set_touch(0,&"steer_right" if frame.steer>=0 else &"steer_left",absf(float(frame.steer))/127.0)
		game.driver.set_touch(1,&"accelerate",float(frame.throttle)/255.0)
		game.driver.set_touch(2,&"brake",float(frame.brake)/255.0)
		game._physics_process(1.0/120)
		if game.practice_validation.finished: break
	check(game.practice_validation.finished and game.practice_validation_eligible,"real input completes one ordered publication-test lap: "+label)
	await settle()
	check(current_dialog()!=null,"failed receipt produces a recovery dialog: "+label)
	check(app.root_ui.process_mode==Node.PROCESS_MODE_DISABLED,"underlying editor remains suspended: "+label)
	check(not flow.status_for(document).is_empty(),"completed recording is durably staged before receipt failure: "+label)
	game._process(0)

func run() -> void:
	root.size = Vector2i(1280,720)
	original = "--original" in OS.get_cmdline_user_args()
	folder = ProjectSettings.globalize_path("res://../build/storm-test-recovery-2026-10-26/"+str(OS.get_process_id()))
	DirAccess.make_dir_recursive_absolute(folder)
	if original:
		before_app = GDScript.new(); before_app.source_code = FileAccess.get_file_as_string(OUTPUT+"/before/game/core/app.gd")
		before_game = GDScript.new(); before_game.source_code = FileAccess.get_file_as_string(OUTPUT+"/before/game/core/game.gd")
		check(before_app.reload()==OK and before_game.reload()==OK,"exact task-start App and Game load without replacing runtime files")
	await attempt("retry")
	var dialog: AcceptDialog = current_dialog()
	if dialog!=null:
		check(dialog.can_process(),"recovery input stays active under a disabled editor")
		check(dialog.has_signal("return_requested"),"explicit return action is available")
		var recorded: Dictionary = app.game.race_proof.recording(app.game.practice_validation)
		var staged: Dictionary = flow.status_for(app.document)
		var proof_path: String = storage.directory.path_join(".workflow").path_join(flow.scope().sha256_text()).path_join(str(staged.proof_file))
		var proof_hash: String = FileAccess.get_sha256(proof_path)
		var upload_key: String = str(staged.upload_key)
		if not original:
			app._complete_draft_test()
			await settle()
			check(dialogs()==1,"repeat completion cannot stack modal windows")
		if not original and DisplayServer.get_name()!="headless":
			check(app.game.paused,"save failure pauses the car behind its modal")
			for size: Vector2i in [Vector2i(1280,720),Vector2i(960,540),Vector2i(600,800),Vector2i(390,844)]:
				root.size = size
				root.content_scale_size = size
				app.root_ui.size = Vector2(size)
				dialog.popup_message()
				await settle()
				var surface: Rect2 = dialog.surface.get_global_rect()
				check(Vector2(dialog.size).x<=float(size.x) and Vector2(dialog.size).y<=float(size.y),"recovery window fits logical viewport "+str(size))
				check(surface.encloses(dialog.confirm_button.get_global_rect()) and surface.encloses(dialog.return_button.get_global_rect()),"both actions fit at "+str(size))
				check(dialog.copy_scroll.get_global_rect().end.y<=minf(dialog.confirm_button.get_global_rect().position.y,dialog.return_button.get_global_rect().position.y)-12,"message clears the action row at "+str(size))
				if size.x==390:
					var compact_path: String = OUTPUT+"/"+RenderingServer.get_current_rendering_method()
					DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(compact_path))
					check(root.get_texture().get_image().save_png(compact_path+"/recovery-390.png")==OK,"compact native recovery capture")
			root.size = Vector2i(1280,720); root.content_scale_size = root.size
			app.root_ui.size = Vector2(root.size); dialog.popup_message(); await settle()
			if DisplayServer.get_name()!="headless":
				var path: String = OUTPUT+"/"+RenderingServer.get_current_rendering_method()
				DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path))
				check(root.get_texture().get_image().save_png(path+"/recovery.png")==OK,"native recovery capture")
		storage.fail_receipt = false
		var button: Button = dialog.confirm_button if dialog.has_signal("return_requested") else dialog.get_ok_button()
		if DisplayServer.get_name()=="headless":
			var event := InputEventKey.new(); event.keycode = KEY_ENTER; event.pressed = true
			dialog.push_input(event,true)
			await settle()
		else: await click(dialog,button)
		print("RECOVERY_RETRY calls=",storage.calls," dialogs=",dialogs()," tested=",storage.is_tested(app.document)," processing=",dialog.can_process() if is_instance_valid(dialog) else false)
		check(storage.is_tested(app.document),"native Retry saves the same completed test after storage recovers")
		check(FileAccess.get_sha256(proof_path)==proof_hash and str(flow.status_for(app.document).upload_key)==upload_key,"Retry preserves the exact recording and operation identity")
		check(app.game.race_proof.recording(app.game.practice_validation)==recorded,"Retry never restarts or changes the completed lap")
	app.free(); await settle()
	await attempt("return",true)
	dialog = current_dialog()
	if dialog!=null:
		check(dialog.can_process(),"draft-list recovery also remains interactive")
		if dialog.has_signal("return_requested"):
			await click(dialog,dialog.return_button,true)
			check(app.game==null and app.screen=="drafts" and app.root_ui.visible,"native touch Return leaves practice and opens Load track")
			check(not storage.load_document("recovery_return").is_empty() and not storage.is_tested(app.document),"return keeps the draft and does not mark a failed test complete")
		else: check(false,"draft-list recovery provides an exit without successful saving")
	app.free(); await settle()
	await attempt("fences")
	dialog = current_dialog()
	if dialog!=null and not original:
		var context: Dictionary = app._draft_test_save_context
		var calls: int = storage.calls
		var escape := InputEventKey.new(); escape.keycode = KEY_ESCAPE; escape.pressed = true
		dialog.push_input(escape,true)
		await settle()
		check(current_dialog()==null and is_instance_valid(app.game) and app.root_ui.process_mode==Node.PROCESS_MODE_DISABLED,"Escape closes the modal and retains the paused attempt")
		app._leave_race()
		await settle()
		check(current_dialog()!=null and dialogs()==1,"pause-menu exit offers the pending recording choices instead of trapping the player")
		flow.cloud.client.player = {"id":"different-fixture-owner"}
		app._retry_draft_test_save(context)
		app._return_from_draft_test_save(context)
		check(storage.calls==calls and is_instance_valid(app.game),"account change fences both delayed Retry and Return")
		flow.cloud.client.player = {}
		app.game.restart()
		app._retry_draft_test_save(context)
		check(storage.calls==calls,"restarted attempt cannot save a previous lap through a stale dialog")
		var authored: Dictionary = app.game.native_track.metadata.creator_document.duplicate(true)
		app.game.native_track.metadata.creator_document.erase("start_line")
		app.game.restart()
		check(not app.game.practice_validation_eligible,"practice without a placed start line never attempts a publication receipt")
		app.game.native_track.metadata.creator_document = authored.duplicate(true)
		app.game.native_track.metadata.creator_document.pieces.pop_back()
		app.game.restart()
		check(not app.game.practice_validation_eligible,"an open road chain remains untimed practice without a completion receipt")
		app.game.native_track.metadata.creator_document = authored
		app.game.restart()
		check(app.game.practice_validation_eligible,"a complete connected track with a placed start line remains eligible")
		app._leave_race()
		check(app.game==null and dialogs()==0,"stale recovery closes while the new attempt can exit")
	else: check(false,"recovery callbacks are fenced to their original account and attempt")
	app.free(); await settle()
	if not original:
		await attempt("keyboard",true)
		dialog = current_dialog()
		if dialog!=null:
			var tab := InputEventKey.new(); tab.keycode = KEY_TAB; tab.pressed = true
			dialog.push_input(tab,true)
			await settle()
			check(dialog.return_button.has_focus(),"Tab focuses the explicit return action")
			var enter := InputEventKey.new(); enter.keycode = KEY_ENTER; enter.pressed = true
			dialog.push_input(enter,true)
			await settle()
			check(app.game==null and app.screen=="drafts","Enter activates the focused Return action instead of Retry")
		app.free(); await settle()
	print("PRACTICE_SAVE_RECOVERY: %d checks, %d failures; original=%s" % [checks,failures,original])
	var suffix: String = "headless" if DisplayServer.get_name()=="headless" else RenderingServer.get_current_rendering_method()
	var file := FileAccess.open(OUTPUT+("/original-result.json" if original else "/"+suffix+"-result.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"original":original},"\t")); file.close()
	quit(1 if failures else 0)
