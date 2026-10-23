extends SceneTree
## Real app callback, owned window, asynchronous status and five-second deadline.
const Client = preload("res://backend/backend_client.gd")
const Prompt = preload("res://ui/publication_dialog.gd")
var checks: int = 0
var failures: int = 0
var app: Node
var flow: PromptFlow
var client: PromptClient
var doc: Dictionary
var evidence: String = "res://../docs/evidence/publication-confirmation-2026-10-19/headless"

class PromptClient extends Client:
	signal release_terms
	var terms_reads: int = 0
	var hold_terms: bool = false
	var accepted: bool = true
	func request_api(path: String, _method: int = HTTPClient.METHOD_GET, _body: Dictionary = {}, _key: String = "", _authenticated: bool = false) -> Dictionary:
		if path == "/community/terms":
			terms_reads += 1
			if hold_terms: await release_terms
			return {"ok":true,"status":200,"data":{"accepted":accepted,"version":"fixture","text":"Fixture public rules"}}
		return {"ok":false,"status":503,"error":"isolated publication fixture"}

class PromptFlow extends TrackLifecycle:
	signal release_request
	var job: Dictionary = {}
	var owner_scope: String = "fixture-owner"
	var calls: int = 0
	var acknowledgements: Array[String] = []
	var requested: bool = true
	var hold_request: bool = false
	func scope() -> String: return owner_scope
	func status_for(_document: Dictionary) -> Dictionary: return job
	func request_publish(_document: Dictionary) -> bool:
		calls += 1
		if hold_request: await release_request
		return requested
	func process_jobs() -> void: pass
	func acknowledge_publication(version: String, owner: String) -> bool:
		if owner == owner_scope: acknowledgements.append(version); return true
		return false

func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; print("FAIL: "+label)
func settle() -> void:
	for frame: int in range(4): await process_frame
	if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw
func current() -> Prompt:
	for child: Node in app.root_ui.get_children():
		if child.get_script() == Prompt: return child
	return null
func open_warning() -> Prompt:
	await app._publish_saved_draft(str(doc.id))
	await settle()
	return current()
func close_outcome(dialog: Prompt) -> void:
	dialog.confirm_button.pressed.emit()
	await settle()
func press(dialog: Prompt, button: Button, touch: bool = false) -> void:
	var event: InputEvent = InputEventScreenTouch.new() if touch else InputEventMouseButton.new()
	event.position = button.get_global_rect().get_center()
	if dialog.is_embedded(): event.position += Vector2(dialog.position)
	var input_view: Viewport = root if dialog.is_embedded() else dialog
	if touch: event.index = 8
	else:
		var motion := InputEventMouseMotion.new()
		motion.position = event.position; motion.global_position = event.position
		input_view.push_input(motion,true)
		await process_frame
		event.global_position = event.position
		event.button_index = MOUSE_BUTTON_LEFT
		event.button_mask = MOUSE_BUTTON_MASK_LEFT
	event.pressed = true
	input_view.push_input(event,true)
	event = event.duplicate(); event.pressed = false
	if not touch: event.button_mask = 0
	input_view.push_input(event,true)
	await settle()
func layout(dialog: Prompt, label: String) -> void:
	check(root.get_visible_rect().encloses(Rect2(Vector2(dialog.position),Vector2(dialog.size))),"window fits "+label)
	check(dialog.copy_scroll.get_global_rect().end.y <= dialog.confirm_button.get_global_rect().position.y-12,"copy/activity clear the actions: "+label)
	check(dialog.confirm_button.size.y >= 52 and dialog.close_button.size.x >= 52,"touch targets retained: "+label)
	if dialog.cancel_button.visible:
		check(not dialog.cancel_button.get_global_rect().intersects(dialog.confirm_button.get_global_rect()),"confirmation actions do not overlap: "+label)
func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await settle()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(evidence))
	check(root.get_texture().get_image().save_png(evidence.path_join(label+".png")) == OK,"capture "+label)

func run() -> void:
	OS.set_environment("BMT_API_URL","")
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--evidence="): evidence = argument.trim_prefix("--evidence=")
	create_timer(120).timeout.connect(func() -> void: print("FAIL: publication confirmation deadline"); quit(1))
	root.size = Vector2i(1280,720)
	var folder: String = "user://publication_confirmation_"+TrackLibrary.unique_id()
	var baseline: String = OS.get_environment("BMT_PUBLICATION_APP_BASELINE")
	app = load("res://core/app.tscn").instantiate() if baseline.is_empty() else Node.new()
	if not baseline.is_empty(): app.set_script(load(baseline))
	app.library = TrackLibrary.new(folder)
	app.records = LocalRecords.new(folder.path_join("records.json"))
	app.cloud_root_override = folder.path_join("cloud")
	root.add_child(app)
	while not app.startup_complete: await process_frame
	app._show_screen("drafts")
	await settle()
	client = PromptClient.new(); client.configure("http://127.0.0.1:1"); root.add_child(client)
	client.player = {"id":"fixture-owner"}; client._access_token = "isolated-fixture"
	app.online.client = client
	app.lifecycle.changed.disconnect(app._lifecycle_changed)
	flow = PromptFlow.new(); flow.cloud = app.cloud; flow.library = app.library; flow.records = app.records
	app.add_child(flow); app.lifecycle = flow; flow.changed.connect(app._lifecycle_changed)
	doc = JSON.parse_string(FileAccess.get_file_as_string("res://../backend/tests/fixtures/verified_oval.json")).document
	check(app.library.save_document(doc) == OK,"real local draft saved")
	var original_bytes: String = FileAccess.get_sha256(app.library.directory.path_join(str(doc.id)+".json"))
	var dialog: Prompt = await open_warning()
	check(dialog != null and dialog.heading.text == "Publish track?" and dialog.message_label.text.contains("cannot change"),"Publish first warns that publication locks editing")
	check(flow.calls == 0 and client.terms_reads == 0,"warning alone sends no publication or consent request")
	if dialog == null:
		var pending: FaultDialog
		for child: Node in app.root_ui.get_children():
			if child is FaultDialog: pending = child
		check(pending != null and pending.confirm_button.disabled,"submitted publication window stays open while waiting")
		app.queue_free(); client.queue_free(); await process_frame
		print("PUBLICATION_CONFIRMATION_BASELINE: %d checks, %d failures" % [checks,failures])
		quit(1 if failures else 0)
		return
	await app._publish_saved_draft(str(doc.id))
	check(current() == dialog,"repeated Publish keeps one confirmation")
	await press(dialog,dialog.cancel_button)
	check(current() == null and flow.calls == 0 and FileAccess.get_sha256(app.library.directory.path_join(str(doc.id)+".json")) == original_bytes,"Cancel preserves the draft and makes no request")
	for dimensions: Vector2i in [Vector2i(1280,720),Vector2i(960,540),Vector2i(480,720)]:
		root.size = dimensions; await settle()
		flow.job = {"state":"queued","publication_id":"fixture-intent"}
		var before: int = flow.calls
		dialog = await open_warning()
		layout(dialog,"warning "+str(dimensions)); await capture("warning-%dx%d" % [dimensions.x,dimensions.y])
		await press(dialog,dialog.confirm_button,dimensions.x < 1000)
		check(current() == dialog and flow.calls == before+1 and dialog.phase == "waiting","confirmation starts exactly once in the same window")
		check(dialog.activity.visible and dialog.activity.indeterminate and not dialog.activity.show_percentage,"wait reuses the existing indeterminate loading animation")
		check(dialog.confirm_button.disabled and dialog.close_button.disabled and not dialog.cancel_button.visible,"waiting cannot be dismissed before the outcome/deadline")
		dialog._confirm(); dialog._cancel()
		var escape := InputEventKey.new(); escape.keycode = KEY_ESCAPE; escape.pressed = true; dialog._input(escape)
		await settle()
		check(current() == dialog and flow.calls == before+1,"duplicate confirmation and Escape neither dismiss nor resubmit")
		layout(dialog,"waiting "+str(dimensions)); await capture("waiting-%dx%d" % [dimensions.x,dimensions.y])
		flow.job = {"state":"finishing","receipt":{"track_id":"fixture-track","version_id":"fixture-version"}}
		flow.changed.emit(); await settle()
		check(current() == dialog and dialog.phase == "outcome" and dialog.heading.text == "Track published","authoritative success appears in the same window before local download finishes")
		check(not dialog.activity.visible and not dialog.confirm_button.disabled and not dialog.close_button.disabled,"success stops activity and restores dismissal")
		await capture("success-%dx%d" % [dimensions.x,dimensions.y])
		await close_outcome(dialog)
		check(current() == null and flow.acknowledgements.back() == "fixture-version","success dismissal acknowledges the original receipt")
	root.size = Vector2i(1280,720)
	flow.job = {"state":"queued","publication_id":"same-intent"}
	var before: int = flow.calls
	dialog = await open_warning(); var started: int = Time.get_ticks_msec()
	dialog.confirm_button.pressed.emit(); await create_timer(4.6).timeout
	check(current() == dialog and dialog.phase == "waiting","pending window stays locked before five seconds")
	await create_timer(0.55).timeout; await settle()
	check(current() == dialog and dialog.timed_out and dialog.phase == "outcome" and Time.get_ticks_msec()-started >= 5000,"real five-second deadline resolves the bounded wait")
	check(dialog.heading.text == "Publication not confirmed" and not dialog.activity.visible and not dialog.confirm_button.disabled,"timeout is honest, stopped and dismissible")
	check(flow.calls == before+1 and flow.job.publication_id == "same-intent" and flow.job.state == "queued","timeout does not cancel, duplicate or replace the durable intent")
	await capture("timeout")
	flow.job = {"state":"published","receipt":{"version_id":"late-version","track_id":"fixture-track"}}
	flow.changed.emit(); await settle()
	check(current() == dialog and dialog.heading.text == "Track published","late acceptance updates a still-open timeout window")
	await close_outcome(dialog)
	flow.job = {"state":"local_ready"}
	dialog = await open_warning()
	var changed: Dictionary = doc.duplicate(true); changed.name = "Newer saved revision"
	check(app.library.save_document(changed) == OK,"change the saved draft behind an open warning")
	before = flow.calls; var reads: int = client.terms_reads
	dialog.confirm_button.pressed.emit(); await settle()
	check(flow.calls == before and client.terms_reads == reads and dialog.message_label.text.contains("draft changed"),"stale confirmation cannot publish a different revision")
	await close_outcome(dialog); app.library.save_document(doc)
	flow.job = {"state":"local_ready"}; flow.requested = false; flow.last_error = "No publishing slots left. Add slots, then Retry. Your track remains saved."
	dialog = await open_warning(); dialog.confirm_button.pressed.emit(); await settle()
	check(dialog.phase == "outcome" and dialog.message_label.text.contains("Add slots") and not dialog.activity.visible,"immediate admission failure replaces waiting with the actionable cause")
	await capture("failure"); await close_outcome(dialog); flow.requested = true
	dialog = await open_warning(); before = flow.calls
	flow.owner_scope = "different-owner"; await settle()
	check(current() == null and flow.calls == before,"account change closes a warning without submitting")
	flow.owner_scope = "fixture-owner"
	dialog = await open_warning(); app._show_screen("biome"); await settle()
	check(current() == null,"navigation retires the owned window")
	app._show_screen("drafts"); await settle()
	flow.job = {"state":"local_ready"}; client.hold_terms = true; client.accepted = false
	dialog = await open_warning(); before = flow.calls
	dialog.confirm_button.pressed.emit(); await create_timer(5.15).timeout; await settle()
	check(dialog.timed_out and flow.calls == before,"five-second wait also covers a held pre-publication request")
	dialog.confirm_button.pressed.emit()
	client.hold_terms = false; client.release_terms.emit(); await settle()
	check(current() == null and flow.calls == before and not app._publication_request_active,"late consent response cannot open a sheet on a dismissed window or upload a track")
	client.accepted = true
	flow.job = {"state":"queued","publication_id":"editor-intent"}
	app.document = doc.duplicate(true)
	app.editor_view = {"retained_fixture":true}
	app.history.append(doc.duplicate(true)); app.redo_history.append(doc.duplicate(true))
	app.screen = "create"
	dialog = await open_warning(); dialog.confirm_button.pressed.emit(); await settle()
	flow.job = {"state":"published","receipt":{"track_id":"fixture-track","version_id":"editor-version"}}
	flow.changed.emit(); await settle()
	check(dialog.heading.text == "Track published" and app.screen == "create","editor success retains its modal until acknowledgement")
	await close_outcome(dialog)
	check(app.screen == "tracks" and app.document.is_empty() and app.history.is_empty() and app.redo_history.is_empty() and app.editor_view.is_empty(),"acknowledged editor publication retires the exact editor snapshot and opens its public track")
	app.queue_free(); client.queue_free(); await process_frame
	print("PUBLICATION_CONFIRMATION: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
