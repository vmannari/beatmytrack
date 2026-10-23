extends SceneTree
## Real journals, held local download, restart/dismissal and native banner inputs.
const Client = preload("res://backend/backend_client.gd")
const Cloud = preload("res://backend/cloud_tracks.gd")
var app: Node
var checks: int = 0
var failures: int = 0
var evidence: String = "res://../docs/evidence/publication-notification-2026-10-18/headless"
var sequence: int = 0

class PublishingClient extends Client:
	var receipt: Dictionary = {}
	var reply_state: String = "queued"
	var status_reads: int = 0
	func request_api(path: String, _method: int = HTTPClient.METHOD_GET, _body: Dictionary = {}, _key: String = "", _authenticated: bool = false) -> Dictionary:
		if path == "/bootstrap": return {"ok":true,"data":{"publication_workflow_version":2}}
		if path == "/community/terms": return {"ok":true,"data":{"accepted":true}}
		if path == "/me/entitlements": return {"ok":true,"data":{"publishing_slots":3}}
		if path.begins_with("/me/publications/"):
			status_reads += 1
			return {"ok":true,"data":{"state":reply_state,"receipt":receipt,"poll_after_ms":30000}}
		return {"ok":false,"status":503,"error":"isolated notification fixture","data":{}}
	func request_public(_path: String, _owner: int) -> Dictionary:
		return {"ok":true,"data":{"items":[],"population":0,"next_cursor":null},"error":""}

class HeldCloud extends Cloud:
	signal release_download
	var downloading: bool = false
	var hold: bool = true
	var fail_seen_write: bool = false
	func download(_entry: Dictionary) -> bool:
		downloading = true
		if hold: await release_download
		return false # Deliberately leave local caching unfinished.
	func _write(path: String, value: Dictionary) -> bool:
		if fail_seen_write and path.ends_with(".seen.json"): return false
		return super._write(path,value)

class NotificationApp extends "res://core/app.gd":
	var opened_receipt: Dictionary = {}
	func _open_published_track(receipt: Dictionary) -> void:
		opened_receipt = receipt.duplicate(true)
		super._open_published_track(receipt)

func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ",label)

func settle() -> void:
	for frame: int in range(5): await process_frame
	if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw

func current_dialog() -> FaultDialog:
	for child: Node in app.root_ui.get_children():
		if child is FaultDialog: return child
	return null

func seed_publication(flow: TrackLifecycle, state: String, label: String, notify: bool = true) -> Dictionary:
	sequence += 1
	var document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://../backend/tests/fixtures/verified_oval.json")).document
	document.id = "notification_"+str(sequence)
	document.name = label
	check(flow.library.save_document(document) == OK,"fixture draft saved")
	var staged: Dictionary = flow.stage(document)
	var job: Dictionary = staged.job
	var receipt: Dictionary = {"track_id":"fixture-track-"+str(sequence),"version_id":"00000000-0000-4000-8000-"+str(sequence).pad_zeros(12),"name":label,"creator":"Fixture Author","creator_id":"fixture-owner","content_hash":JSON.stringify(document).sha256_text(),"points":document.points,"theme":"grass","published_at":sequence,"rating_count":0,"rating_average":null}
	receipt = JSON.parse_string(JSON.stringify(receipt)) # Match actual API/journal numeric types.
	job.state = state
	job.publication_id = "publication-"+str(sequence)
	job.publish_requested = true
	job.publish_workflow = 2
	job.proof_file = "fixture.proof.json"
	job.contract = {"tick_rate":120}
	if state in ["finishing","published"]:
		job.receipt = receipt
		if notify:
			job.publication_notification = true
			job.publication_name = label
	check(flow._save(staged.path,job),"fixture journal saved")
	return {"document":document,"receipt":receipt,"path":staged.path,"job":job}

func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await settle()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(evidence))
	root.get_texture().get_image().save_png(evidence.path_join(label+".png"))

func press(point: Vector2, touch: bool = false, drag: bool = false) -> void:
	var event: InputEvent
	if touch:
		var contact := InputEventScreenTouch.new()
		contact.index = 3
		contact.position = point
		contact.pressed = true
		event = contact
	else:
		var mouse := InputEventMouseButton.new()
		mouse.button_index = MOUSE_BUTTON_LEFT
		mouse.position = point
		mouse.pressed = true
		event = mouse
	root.push_input(event,true)
	if drag:
		var motion := InputEventScreenDrag.new()
		motion.index = 3
		motion.position = point+Vector2(28,0)
		motion.relative = Vector2(28,0)
		root.push_input(motion,true)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event,true)
	await settle()

func run() -> void:
	OS.set_environment("BMT_API_URL", "")
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--evidence="): evidence = argument.trim_prefix("--evidence=")
	create_timer(100).timeout.connect(func() -> void: print("FAIL: publication notification deadline"); quit(1))
	root.size = Vector2i(1280,720)
	var folder: String = "user://publication_notification_"+TrackLibrary.unique_id()
	app = NotificationApp.new()
	app.library = TrackLibrary.new(folder)
	app.records = LocalRecords.new(folder.path_join("records.json"))
	app.cloud_root_override = folder.path_join("cloud")
	root.add_child(app)
	while not app.startup_complete: await process_frame
	app._show_screen("drafts")
	await settle()
	var client := PublishingClient.new()
	client.configure("http://127.0.0.1:1")
	root.add_child(client)
	client.player = {"id":"fixture-owner"}
	client._access_token = "isolated-fixture"
	var cloud := HeldCloud.new()
	cloud.client = client
	cloud.root_override = folder.path_join("held-cloud")
	root.add_child(cloud)
	app.online.client = client
	app.cloud = cloud
	app.lifecycle.changed.disconnect(app._lifecycle_changed)
	var flow := TrackLifecycle.new()
	flow.library = app.library
	flow.records = app.records
	flow.cloud = cloud
	app.add_child(flow)
	app.lifecycle = flow
	flow.changed.connect(app._lifecycle_changed)
	var fixture: Dictionary = seed_publication(flow,"queued","Mountain Run")
	client.receipt = fixture.receipt
	await app._publish_saved_draft(str(fixture.document.id))
	await settle()
	check(current_dialog() != null and current_dialog().heading.text == "Not published yet","actual Publish opens the pending receipt dialog")
	current_dialog().confirm_button.pressed.emit()
	await settle()
	check(current_dialog() == null and flow.publication_notifications().is_empty(),"closing pending dialog does not create a false acceptance")
	client.reply_state = "published"
	flow._retry_deadlines[str(fixture.job.upload_key)] = 0
	flow.process_jobs() # Intentionally wait inside local download, after acceptance.
	await settle()
	var banner: PanelContainer = app.publication_notification
	check(cloud.downloading and flow.busy and flow.status_for(fixture.document).state == "finishing","server receipt is durable before held local download finishes")
	check(banner.visible and banner.track_name.text == "Mountain Run","accepted track notifies after pending dialog was closed")
	check(flow.publication_notifications().size() == 1,"publication creates one durable unread notification")
	var reads_before: int = client.status_reads
	await settle()
	check(client.status_reads == reads_before,"banner visibility adds no status request or reupload")
	for dimensions: Vector2i in [Vector2i(1280,720),Vector2i(960,540),Vector2i(1600,720),Vector2i(480,720)]:
		root.size = dimensions
		await settle()
		check(root.get_visible_rect().encloses(banner.get_global_rect()),"notification fits viewport: "+str(dimensions))
		check(banner.get_global_rect().encloses(banner.view_button.get_global_rect()) and banner.get_global_rect().encloses(banner.dismiss_button.get_global_rect()),"actions fit notification: "+str(dimensions))
		check(banner.view_button.size.y >= 52 and banner.dismiss_button.size.x >= 52,"notification touch targets retained: "+str(dimensions))
		await capture("published-%dx%d" % [dimensions.x,dimensions.y])
	root.size = Vector2i(1280,720)
	app._show_screen("biome")
	await settle()
	check(app.publication_notification == banner and banner.visible,"notification survives an ordinary menu change")
	app._notice("Saved on this device.")
	await settle()
	check(not banner.visible and flow.publication_notifications().size() == 1,"other modal retains but temporarily hides publication banner")
	current_dialog().confirm_button.pressed.emit()
	await settle()
	check(banner.visible,"publication notification returns after another dialog closes")
	var race := Node.new()
	app.add_child(race)
	app.game = race
	app.root_ui.hide()
	await settle()
	check(not banner.visible and flow.publication_notifications().size() == 1,"notification never overlays racing and remains unread")
	app.game = null
	race.queue_free()
	app.root_ui.show()
	await settle()
	check(banner.visible,"deferred publication notification appears after racing")
	await capture("published-after-race")
	client.player = {"id":"other-owner"}
	await settle()
	check(not banner.visible and flow.publication_notifications().is_empty(),"another account cannot see the original owner's receipt")
	check(not flow.acknowledge_publication(str(fixture.receipt.version_id),"wrong-scope"),"stale owner acknowledgement is refused")
	client.player = {"id":"fixture-owner"}
	app._lifecycle_changed()
	await settle()
	await press(banner.dismiss_button.get_global_rect().get_center(),true,true)
	check(banner.visible and flow.publication_notifications().size() == 1,"drag on notification cannot dismiss it or activate the menu")
	cloud.fail_seen_write = true
	await press(banner.dismiss_button.get_global_rect().get_center())
	check(current_dialog() != null and flow.publication_notifications().size() == 1,"failed dismissal save preserves notification and reports storage cause")
	current_dialog().confirm_button.pressed.emit()
	cloud.fail_seen_write = false
	await settle()
	await press(banner.dismiss_button.get_global_rect().get_center(),true)
	check(flow.publication_notifications().is_empty() and not banner.visible,"real touch dismisses and durably acknowledges exactly once")
	cloud.hold = false
	cloud.release_download.emit()
	await settle()
	check(not flow.busy and not banner.visible,"download completion/repeated signals cannot resurrect dismissed notification")
	var restarted := TrackLifecycle.new()
	restarted.cloud = cloud
	restarted.library = flow.library
	restarted.records = flow.records
	app.add_child(restarted)
	check(restarted.publication_notifications().is_empty(),"dismissal survives controller restart")
	seed_publication(flow,"published","Historical published track",false)
	check(flow.publication_notifications().is_empty(),"already completed historical tracks do not all generate new alerts")
	var second: Dictionary = seed_publication(flow,"published","Second published track")
	var third: Dictionary = seed_publication(flow,"published","Third published track")
	app._lifecycle_changed()
	await settle()
	check(banner.visible and flow.publication_notifications().size() == 2,"multiple acceptances queue without replacing each other")
	check(restarted.publication_notifications().size() == 2,"unread acceptances survive controller restart")
	await press(banner.dismiss_button.get_global_rect().get_center())
	check(banner.visible and banner.track_name.text == "Third published track","dismissal advances to the next accepted track")
	await press(banner.view_button.get_global_rect().get_center(),true)
	check(app.opened_receipt == third.receipt and app.screen == "tracks","View track opens exactly the notified immutable publication")
	check(flow.publication_notifications().is_empty() and not banner.visible,"View track durably acknowledges its notification")
	check(cloud.entries.any(func(entry: Dictionary) -> bool: return entry.version_id == third.receipt.version_id),"View track pins accepted metadata even before local download succeeds")
	check(second.receipt.version_id != third.receipt.version_id,"different accepted revisions have independent acknowledgement identities")
	var legacy: Dictionary = seed_publication(flow,"finishing","Already accepted before update",false)
	flow._retry_deadlines[str(legacy.job.upload_key)] = Time.get_ticks_msec()+60000
	await flow.process_jobs()
	await settle()
	check(banner.visible and banner.track_name.text == "Already accepted before update","unfinished accepted receipt from earlier client is enrolled before cache retry")
	check(flow.acknowledge_publication(str(legacy.receipt.version_id),flow.scope()),"legacy acceptance can be acknowledged normally")
	var observed: Dictionary = seed_publication(flow,"queued","Watched publication")
	var dialog := FaultDialog.new()
	dialog.follow_publication(flow,observed.document)
	app._own_dialog(dialog)
	dialog.confirmed.connect(app._acknowledge_publication_dialog.bind(observed.document,flow.scope()))
	dialog.popup_message()
	client.receipt = observed.receipt
	flow._retry_deadlines[str(observed.job.upload_key)] = 0
	await flow.process_jobs()
	await settle()
	check(dialog.heading.text == "Track published" and not banner.visible,"open pending dialog shows acceptance without a duplicate banner")
	dialog.confirm_button.pressed.emit()
	await settle()
	check(not banner.visible and flow.publication_notifications().is_empty(),"closing the visible published dialog acknowledges acceptance without a second notification")
	app.queue_free()
	client.queue_free()
	cloud.queue_free()
	await process_frame
	print("PUBLICATION_NOTIFICATIONS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
