extends SceneTree
## Real journals and retained browser controls, with a counted server fixture.
const Client = preload("res://backend/backend_client.gd")
const Cloud = preload("res://backend/cloud_tracks.gd")
var checks: int = 0
var failures: int = 0
var changes: int = 0
var evidence: String = "res://../docs/evidence/publishing-slots-2026-10-18/compatibility"

class SlotClient extends Client:
	var slots: Variant = 0
	var fail_slots: bool = false
	var switch_owner: bool = false
	var requests: Array[Dictionary] = []
	var remote: Dictionary = {"publication_id":"slot-intent","state":"queued","poll_after_ms":2500,"retryable":false}
	func request_api(path: String, method: int = HTTPClient.METHOD_GET, body: Dictionary = {}, key: String = "", authenticated: bool = false) -> Dictionary:
		requests.append({"path":path,"method":method,"body":body.duplicate(true),"key":key,"auth":authenticated})
		await get_tree().process_frame
		if path == "/me/entitlements":
			if switch_owner: player = {"id":"another-owner"}
			return {"ok":not fail_slots,"status":503 if fail_slots else 200,"data":{"publishing_slots":slots}}
		if path == "/bootstrap": return {"ok":true,"status":200,"data":{"publication_workflow_version":2}}
		if path == "/community/terms": return {"ok":true,"status":200,"data":{"accepted":true}}
		if path.ends_with("/retry"): remote = {"publication_id":"slot-intent","state":"queued","retryable":false,"poll_after_ms":2500}
		if path == "/publications" or path.begins_with("/me/publications/"): return {"ok":true,"status":200,"data":remote.duplicate(true)}
		return {"ok":false,"status":503,"error":"isolated slot fixture","data":{}}

func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; print("FAIL: ",label)

func settle() -> void:
	for frame: int in range(12): await process_frame
	if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw

func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await settle()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(evidence))
	check(root.get_texture().get_image().save_png(evidence.path_join(label+".png")) == OK,"native capture: "+label)

func count_path(client: SlotClient, path: String) -> int:
	return client.requests.filter(func(row: Dictionary) -> bool: return row.path == path).size()

func wait_browser(browser: Node) -> void:
	while browser.scanning: await process_frame
	await settle()

func run() -> void:
	OS.set_environment("BMT_API_URL","")
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--evidence="): evidence = arg.trim_prefix("--evidence=")
	create_timer(100).timeout.connect(func() -> void: print("FAIL: slots deadline"); quit(1))
	root.size = Vector2i(1600,720)
	root.content_scale_size = Vector2i(1600,720)
	var client := SlotClient.new()
	root.add_child(client)
	client.configure("http://127.0.0.1:1")
	client.player = {"id":"slot-owner"}
	client._access_token = "isolated-fixture"
	var cloud := Cloud.new()
	cloud.client = client
	root.add_child(cloud)
	var folder: String = ProjectSettings.globalize_path("res://../build/publishing-slots-2026-10-18/run-"+str(Time.get_ticks_usec()))
	var flow := TrackLifecycle.new()
	flow.cloud = cloud
	flow.library = TrackLibrary.new(folder.path_join("drafts"))
	flow.records = LocalRecords.new(folder.path_join("records.json"))
	root.add_child(flow)
	flow.changed.connect(func() -> void: changes += 1)
	var doc: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://../backend/tests/fixtures/verified_oval.json")).document
	doc.name = "Ancient"
	doc.theme = "desert"
	var proof: Dictionary = {"schema":"bmt-race-proof-v1","samples":[[0,0,0,0,0,0,0,0],[120,1,0,0,0,0,0,0]]}
	check(flow.library.save_document(doc) == OK and flow.library.save_wip(doc) == OK,"real draft and autosave saved")
	var staged: Dictionary = flow.stage(doc,[],"compact",null,"",proof)
	check(not staged.is_empty(),"local lap evidence saved")
	var path: String = staged.path
	var original: String = FileAccess.get_file_as_string(path)
	var proof_path: String = path.get_base_dir().path_join(staged.job.proof_file)
	var original_proof: String = FileAccess.get_file_as_string(proof_path)
	check(not await flow.request_publish(doc) and flow.last_error == TrackLifecycle.NO_SLOTS,"zero slots rejects Publish with editor guidance")
	check(count_path(client,"/publications") == 0 and count_path(client,"/community/terms") == 0,"slot denial sends no publication or terms request")
	check(FileAccess.get_file_as_string(path) == original and FileAccess.get_file_as_string(proof_path) == original_proof,"slot denial changes neither journal nor proof")
	check(not flow.ready_to_publish(doc) and flow.no_publishing_slots(),"known empty ownership disables Publish")
	check(await flow.prepare_test(doc) == doc,"local test drive stays available at zero slots")
	var previous_changes: int = changes
	var previous_reads: int = client.requests.size()
	for pass_index: int in range(8): await flow.process_jobs()
	check(changes == previous_changes and client.requests.size() == previous_reads,"idle local jobs emit no changes and make no network requests")
	for invalid: Variant in [-1,1.5,"1",null]:
		client.slots = invalid
		check(not await flow.request_publish(doc),"invalid slot count fails closed: "+str(invalid))
	client.slots = 1
	client.fail_slots = true
	check(not await flow.request_publish(doc) and count_path(client,"/publications") == 0,"unavailable ownership never queues intent")
	client.fail_slots = false
	client.switch_owner = true
	check(not await flow.request_publish(doc) and count_path(client,"/publications") == 0,"account change during ownership read cannot upload")
	check(not flow.no_publishing_slots(),"old account slot count is fenced")
	client.switch_owner = false
	client.player = {"id":"slot-owner"}
	check(await flow.request_publish(doc),"one current slot permits explicit publication")
	check(count_path(client,"/publications") == 1 and flow.status_for(doc).state == "queued","one publication intent is saved and delivered")
	var job: Dictionary = flow.status_for(doc)
	flow._retry_deadlines[str(job.upload_key)] = 0
	previous_changes = changes
	await flow.process_jobs()
	check(changes == previous_changes,"identical queued poll changes only its deadline, without UI rebuild")
	client.remote = {"publication_id":"slot-intent","state":"failed","retryable":true,"failure_code":"NO_PUBLISHING_SLOTS"}
	flow._retry_deadlines[str(job.upload_key)] = 0
	await flow.process_jobs()
	check(flow.status_for(doc).state == "failed" and not flow.can_retry(doc),"server quota race settles as saved failure with no Retry while empty")
	client.slots = 0
	original = FileAccess.get_file_as_string(path)
	await flow.retry(doc)
	check(count_path(client,"/me/publications/slot-intent/retry") == 0 and FileAccess.get_file_as_string(path) == original,"Retry with no slots preserves immutable request and sends nothing")
	var resumed := TrackLifecycle.new()
	resumed.cloud = cloud
	resumed.library = flow.library
	resumed.records = flow.records
	root.add_child(resumed)
	flow.queue_free()
	flow = resumed
	flow.changed.connect(func() -> void: changes += 1)
	await process_frame
	previous_reads = client.requests.size()
	await flow.process_jobs()
	check(flow.status_for(doc).state == "failed" and client.requests.size() == previous_reads,"restart keeps quota failure settled without automatic resubmission")
	var app: Node = load("res://core/app.tscn").instantiate()
	app.library = flow.library
	app.records.path = folder.path_join("app-records.json")
	app.cloud_root_override = folder.path_join("app-cloud")
	root.add_child(app)
	while not app.startup_complete: await process_frame
	app.online.client = client
	app.cloud.client = client
	app.lifecycle.changed.disconnect(app._lifecycle_changed)
	app.lifecycle = flow
	flow.changed.connect(app._lifecycle_changed)
	app._show_screen("drafts")
	var browser: Node = app.root_ui.find_child("DraftBrowser",true,false)
	await wait_browser(browser)
	check(browser.find_child("PublishDraft",true,false).disabled and browser.find_child("RetryPublication",true,false) == null,"failed bottom card disables Publish and removes unavailable Retry")
	check(browser.find_child("AddPublishingSlots",true,false) != null and not browser.find_child("ContinueEditing",true,false).disabled and not browser.find_child("TestDraft",true,false).disabled,"card offers Store, editing and local test drive")
	var retained: Node = browser.detail.get_child(0)
	var retained_card: Node = browser.gallery.get_child(0)
	previous_reads = client.requests.size()
	for pass_index: int in range(10):
		await flow.process_jobs()
		await process_frame
	check(browser.detail.get_child(0) == retained and browser.gallery.get_child(0) == retained_card and not browser.scanning,"idle quota failure retains the same bottom controls and gallery without flicker")
	check(client.requests.size() == previous_reads,"settled failure performs no automatic retry or polling")
	for dimensions: Vector2i in [Vector2i(1600,720),Vector2i(1280,720),Vector2i(960,540)]:
		root.size = dimensions
		root.content_scale_size = dimensions
		await settle()
		app._show_screen("drafts")
		browser = app.root_ui.find_child("DraftBrowser",true,false)
		await wait_browser(browser)
		if browser.get_parent() is ScrollContainer:
			browser.get_parent().scroll_vertical = int(browser.detail.position.y)
		await settle()
		var add: Control = browser.find_child("AddPublishingSlots",true,false)
		check(browser.detail.get_global_rect().encloses(add.get_global_rect()),"slot action fits detail at "+str(dimensions))
		check(root.get_visible_rect().encloses(add.get_global_rect()),"slot action is visible in viewport at "+str(dimensions))
		await capture("no-slots-%dx%d" % [dimensions.x,dimensions.y])
	client.slots = 1
	await flow.refresh_publishing_slots(true)
	await wait_browser(browser)
	check(flow.can_retry(doc) and browser.find_child("RetryPublication",true,false) != null,"adding a slot restores explicit Retry for the existing failure")
	await flow.retry(doc)
	check(flow.status_for(doc).state == "queued" and count_path(client,"/publications") == 1 and count_path(client,"/me/publications/slot-intent/retry") == 1,"recovery retries the existing server intent without uploading another")
	check(FileAccess.get_file_as_string(proof_path) == original_proof,"all failures and recovery preserve exact saved lap evidence")
	var another: Dictionary = doc.duplicate(true)
	another.id = "fresh_slot_check"
	check(not flow.stage(another,[],"compact",null,"",proof).is_empty() and flow.ready_to_publish(another),"available-slot display can be cached for a second local draft")
	client.slots = 0
	check(not await flow.request_publish(another) and count_path(client,"/publications") == 1,"fresh server slot check overrides stale available UI before any second upload")
	# Actual creation flow, with the same disposable account and local library.
	client.slots = 0
	app._start_new_document()
	await settle()
	app._select_creation_biome("desert")
	await settle()
	var notice: FaultDialog
	for child: Node in app.root_ui.get_children():
		if child is FaultDialog: notice = child
	check(app.screen == "create" and notice != null,"creating a track with no slots opens the actual editor and a notice")
	if notice != null:
		check(notice.heading.text == "No publishing slots left" and notice.message_label.text.contains("test drive") and notice.message_label.text.contains("race it for records"),"creation notice explains editing, publishing and racing limits")
		await capture("creation-notice")
		notice.confirmed.emit()
	await settle()
	check(app.screen == "create" and not app.document.is_empty() and app.publish_button.disabled,"dismissing notice leaves editable local track with Publish disabled")
	client.slots = 1
	app._start_new_document()
	await settle()
	app._select_creation_biome("pine")
	await settle()
	var warned: bool = false
	for child: Node in app.root_ui.get_children():
		if child is FaultDialog: warned = true
	check(app.screen == "create" and not warned,"creation with an available slot opens normally without a false warning")
	app.queue_free()
	flow.queue_free()
	cloud.queue_free()
	await process_frame
	client.queue_free()
	print("PUBLISHING_SLOTS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
