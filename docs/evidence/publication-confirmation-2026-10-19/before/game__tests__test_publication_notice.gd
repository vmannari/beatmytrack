extends SceneTree
## Publication outcomes through the actual app callback and owned modal lifecycle.
const Fault = preload("res://ui/fault_dialog.gd")
const Client = preload("res://backend/backend_client.gd")
var checks: int = 0
var failures: int = 0
var app: Node
var evidence: String = "res://../docs/evidence/publication-status-2026-10-18/headless"

class ConsentClient extends Client:
	func request_api(path: String, _method: int = HTTPClient.METHOD_GET, _body: Dictionary = {}, _key: String = "", _authenticated: bool = false) -> Dictionary:
		if path == "/community/terms": return {"ok":true,"status":200,"data":{"accepted":true}}
		return {"ok":false,"status":503,"error":"isolated notice fixture"}

class NoticeFlow extends TrackLifecycle:
	var job: Dictionary = {}
	var owner_scope: String = "fixture-owner"
	var publish_calls: int = 0
	func scope() -> String: return owner_scope
	func status_for(_document: Dictionary) -> Dictionary: return job
	func request_publish(_document: Dictionary) -> bool:
		publish_calls += 1
		return true
	func process_jobs() -> void: pass

func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ",label)

func settle() -> void:
	for frame: int in range(4): await process_frame
	if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw

func current() -> FaultDialog:
	for child: Node in app.root_ui.get_children():
		if child is FaultDialog: return child
	return null

func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await settle()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(evidence))
	root.get_texture().get_image().save_png(evidence.path_join(label+".png"))

func layout(dialog: FaultDialog, label: String) -> void:
	check(root.get_visible_rect().encloses(Rect2(Vector2(dialog.position),Vector2(dialog.size))),"notice fits viewport: "+label)
	check(dialog.copy_scroll.get_global_rect().end.y <= dialog.confirm_button.get_global_rect().position.y-12,"copy cannot overlap OK: "+label)
	check(dialog.confirm_button.size.y >= 52 and dialog.close_button.size.x >= 52,"dismissal touch targets preserved: "+label)
	check(not dialog.eyebrow.visible and not dialog.support.visible,"publication outcome has no duplicate labels: "+label)
	check(dialog.message_label.get_line_count() == dialog.message_label.get_visible_line_count(),"complete publication message fits: "+label)

func run() -> void:
	OS.set_environment("BMT_API_URL", "")
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--evidence="): evidence = argument.trim_prefix("--evidence=")
	create_timer(90).timeout.connect(func() -> void: print("FAIL: publication notice deadline"); quit(1))
	var receipt: Dictionary = {"track_id":"fixture-track","version_id":"fixture-version"}
	for state: String in ["queued","verifying"]:
		var value: Dictionary = Fault.publication_presentation({"state":state,"publication_id":"intent"})
		check(value.title == "Not published yet" and value.symbol == "clock","acknowledged pending state clearly says unpublished: "+state)
		check(not value.message.contains("retry") and value.message.contains("close this message"),"ordinary queue/check is not presented as a retry: "+state)
	for state: String in ["finishing","published"]:
		var value: Dictionary = Fault.publication_presentation({"state":state,"receipt":receipt,"failure":"local download failed"})
		check(value.title == "Track published" and value.symbol == "check","public receipt overrides local recovery trouble: "+state)
		check(value.message.contains("available to other players"),"published outcome states public availability: "+state)
	for job: Dictionary in [{"state":"publishing","publication_upload_attempted":true},{"state":"published"},{"_read_error":true}]:
		check(Fault.publication_presentation(job).title == "Publication not confirmed","uncertain delivery or missing receipt never asserts publication or nonpublication")
	var failed: Dictionary = Fault.publication_presentation({"state":"failed","failure":"No publishing slots left. Add slots, then Retry. Your track remains saved."})
	check(failed.title == "Track not published" and failed.symbol == "warning" and failed.message.contains("Add slots"),"actual failure retains its actionable cause")
	root.size = Vector2i(1280,720)
	var folder: String = "user://publication_notice_"+TrackLibrary.unique_id()
	app = load("res://core/app.tscn").instantiate()
	app.library = TrackLibrary.new(folder)
	app.records = LocalRecords.new(folder.path_join("records.json"))
	app.cloud_root_override = folder.path_join("cloud")
	root.add_child(app)
	while not app.startup_complete: await process_frame
	app._show_screen("drafts")
	await settle()
	var client := ConsentClient.new()
	client.configure("http://127.0.0.1:1")
	root.add_child(client)
	client.player = {"id":"fixture-owner"}
	client._access_token = "isolated-fixture"
	app.online.client = client
	var original_flow: TrackLifecycle = app.lifecycle
	original_flow.changed.disconnect(app._lifecycle_changed)
	var flow := NoticeFlow.new()
	flow.cloud = app.cloud
	flow.library = app.library
	flow.records = app.records
	app.add_child(flow)
	app.lifecycle = flow
	flow.changed.connect(app._lifecycle_changed)
	var document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://../backend/tests/fixtures/verified_oval.json")).document
	check(app.library.save_document(document) == OK,"disposable real local draft is saved for the app callback")
	for dimensions: Vector2i in [Vector2i(1280,720),Vector2i(960,540),Vector2i(1600,720)]:
		root.size = dimensions
		await settle()
		flow.job = {"state":"queued","publication_id":"intent"}
		var calls_before: int = flow.publish_calls
		await app._publish_saved_draft(str(document.id))
		await settle()
		var dialog: FaultDialog = current()
		check(dialog != null and flow.publish_calls == calls_before+1,"real Publish callback opens one tracked outcome")
		if dialog == null: continue
		check(dialog.heading.text == "Not published yet","actual queued dialog does not imply completion")
		layout(dialog,"queued "+str(dimensions))
		await capture("queued-%dx%d" % [dimensions.x,dimensions.y])
		flow.job.state = "verifying"
		flow.changed.emit()
		await settle()
		check(current() == dialog and dialog.message_label.text.contains("is being checked"),"same open dialog follows server checking state")
		flow.job = {"state":"finishing","receipt":receipt}
		flow.changed.emit()
		await settle()
		check(current() == dialog and dialog.heading.text == "Track published" and dialog.message_label.text.contains("still finishing"),"publication success is shown before local download finishes")
		layout(dialog,"finishing "+str(dimensions))
		await capture("published-downloading-%dx%d" % [dimensions.x,dimensions.y])
		flow.job.state = "published"
		flow.changed.emit()
		await settle()
		check(dialog.heading.text == "Track published" and not dialog.message_label.text.contains("finishing"),"open success notice follows completed local finalization")
		await capture("published-%dx%d" % [dimensions.x,dimensions.y])
		check(flow.publish_calls == calls_before+1,"status updates never resubmit Publish")
		dialog.confirm_button.pressed.emit()
		await settle()
		check(current() == null and app.root_ui.find_child("FaultMessageScrim",false,false) == null,"OK removes dialog and input scrim")
		flow.changed.emit()
		await settle()
		check(current() == null,"later updates never reopen a dismissed notice")
	root.size = Vector2i(1280,720)
	flow.job = {"state":"publishing","publication_upload_attempted":true}
	await app._publish_saved_draft(str(document.id))
	await settle()
	check(current().heading.text == "Publication not confirmed","lost upload confirmation has an honest uncertain outcome")
	await capture("confirmation-missing")
	flow.job = {"state":"failed","failure":"No publishing slots left. Add slots, then Retry. Your track remains saved."}
	flow.changed.emit()
	await settle()
	check(current().heading.text == "Track not published" and current().message_label.text.contains("Add slots"),"asynchronous failure replaces pending copy with an actionable unpublished outcome")
	await capture("not-published-no-slots")
	flow.owner_scope = "other-owner"
	flow.changed.emit()
	await settle()
	check(current() == null,"account scope change dismisses another owner's outcome")
	flow.owner_scope = "fixture-owner"
	flow.job = {"state":"queued"}
	await app._publish_saved_draft(str(document.id))
	await settle()
	app._show_screen("tracks")
	await settle()
	check(current() == null,"navigation destroys the tracked notice")
	flow.changed.emit()
	await settle()
	check(current() == null,"navigation leaves no callback reopening the old notice")
	app.queue_free()
	client.queue_free()
	await process_frame
	print("PUBLICATION_NOTICE: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
