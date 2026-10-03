extends SceneTree
## Review regressions use fictional responses and isolated persistence only.
const Client = preload("res://backend/backend_client.gd")
const Cloud = preload("res://backend/cloud_tracks.gd")
const Pass2 = preload("res://tests/review_pass2_probes.gd")
const Pass3 = preload("res://tests/review_pass3_probes.gd")
var checks: int = 0
var failures: int = 0
var folder: String
var measurements: Dictionary = {}

class CountingCloud extends Cloud:
	var metadata_reads: int = 0
	func _read(path: String) -> Dictionary:
		if path.ends_with(".job.json"): metadata_reads += 1
		return super._read(path)

class RefreshClient extends Client:
	var refreshing: bool = false
	func _send(path: String, _method: HTTPClient.Method, _payload: Dictionary, _authorized: bool, _key: String = "", _headers: PackedStringArray = [], _owner: int = 0) -> Dictionary:
		if path == "/auth/refresh":
			refreshing = true
			await get_tree().create_timer(0.03).timeout
			return {"ok":true,"status":200,"error":"","data":{"access_token":"fictional-new-access","refresh_token":"fictional-new-refresh","player":{"id":"fixture-player"}}}
		if path == "/auth/logout": return {"ok":true,"status":200,"error":"","data":{}}
		return _failure("INVALID_SESSION",401)

class QueueClient extends Client:
	var submissions: Array[String] = []
	func request_api(path: String, _method: HTTPClient.Method = HTTPClient.METHOD_GET, payload: Dictionary = {}, _key: String = "", _authenticated: bool = false) -> Dictionary:
		if path == "/runs":
			submissions.append(str(payload.ticket_id))
			return {"ok":true,"status":201,"error":"","data":{"run_id":"run-"+str(payload.ticket_id)}}
		return {"ok":true,"status":200,"error":"","data":{"status":"queued"}}

class NavigationCloud extends Pass3.DelayedCloud:
	var client: Node

class FailingBoardClient extends Pass2.BoardClient:
	var fail_page: bool = false
	func request_api(path: String, method: HTTPClient.Method = HTTPClient.METHOD_GET, payload: Dictionary = {}, key: String = "", authenticated: bool = false) -> Dictionary:
		if fail_page and path.contains("cursor="):
			paths.append(path)
			return _failure("NETWORK_ERROR")
		return await super.request_api(path,method,payload,key,authenticated)

class StableHeadClient extends Pass2.RevisionClient:
	func request_api(path: String, method: HTTPClient.Method = HTTPClient.METHOD_GET, payload: Dictionary = {}, key: String = "", authenticated: bool = false) -> Dictionary:
		if path.contains("/head?"):
			return {"ok":true,"status":200,"error":"","data":{"version_id":head,"acknowledged_upload_version_id":"00000000-0000-0000-0000-000000000001"}}
		if path == "/tracks" and not head.is_empty() and str(payload.get("expected_head_revision_id","")) != head:
			return _failure("REVISION_CONFLICT",409)
		return await super.request_api(path,method,payload,key,authenticated)

class SilentHUD extends PlaygroundHUD:
	func _ready() -> void: pass

class RestartGame extends Node:
	var native_track: NativeTrack
	var track_session := TrackSession.new()
	var vehicle_id: String = "kart"
	var handling: HandlingConfig = VehicleCatalog.config("kart")
	var preference_records: LocalRecords
	var rating_records: LocalRecords
	var resume_ticket_id: String = "old-attempt"
	var hud := SilentHUD.new()
	var restarted: bool = false
	func _init() -> void: add_child(hud)
	func restart() -> void: restarted = true

class SnapshotClient extends Pass3.QuietClient:
	var document: Dictionary
	var issued_vehicle: String = ""
	func race_ticket(_version: String, vehicle: String, _key: String, _purpose: String = "race") -> Dictionary:
		issued_vehicle = vehicle
		return {"ok":true,"status":201,"error":"","data":{"ticket_id":"new-profile-attempt","manifest":TrackLifecycle._contract(document,vehicle)}}

func _initialize() -> void: call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: "+message)

func configure(client: Node) -> void:
	root.add_child(client)
	client.configure("http://127.0.0.1:18181")
	client._access_token = "fictional-access"
	client._refresh_token = "fictional-refresh"
	client.player = {"id":"fixture-player","display_name":"Fixture racer"}

func make_cloud(client: Node, suffix: String) -> Node:
	var cloud := CountingCloud.new()
	cloud.client = client
	cloud.root_override = folder.path_join(suffix)
	root.add_child(cloud)
	return cloud

func run() -> void:
	folder = ProjectSettings.globalize_path("res://../build/review-followups-"+TrackLibrary.unique_id())
	DirAccess.make_dir_recursive_absolute(folder)
	var document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://../backend/tests/fixtures/verified_oval.json")).document

	var client := StableHeadClient.new()
	configure(client)
	var cloud: Node = make_cloud(client,"revisions")
	var flow := TrackLifecycle.new()
	flow.cloud = cloud
	flow.library = TrackLibrary.new(folder.path_join("drafts"))
	root.add_child(flow)
	flow._restored_scope = flow.scope()
	client.flow = flow
	client.edited = document.duplicate(true)
	client.edited.name = "Second save"
	var first: Dictionary = flow.stage(document)
	await flow._advance(first.path,first.job,flow.scope())
	var second: Dictionary = client.staged_during_request
	check(second.job.expected_head == "new","overlap fixture stages the second Save before the first response")
	await flow._advance(second.path,flow._read(second.path),flow.scope())
	check(not flow._read(second.path).has("failure"),"a confirmed local predecessor rebases the unsent successor")
	check(flow._read(second.path).expected_head == client.head,"successor pins the acknowledged predecessor")
	var key: String = str(flow._read(second.path).upload_key)
	check(key == str(second.job.upload_key),"first transmission preserves its durable idempotency key")
	var legacy: Dictionary = document.duplicate(true)
	legacy.name = "Legacy false conflict"
	var failed: Dictionary = flow.stage(legacy)
	failed.job.failure = "REVISION_CONFLICT"
	failed.job.expected_head = "new"
	failed.job.upload_attempted = true
	flow._save(failed.path,failed.job)
	var rejected_key: String = failed.job.upload_key
	await flow.retry(legacy)
	check(not flow._read(failed.path).has("failure") and flow._read(failed.path).upload_key != rejected_key,"confirmed own-head conflict recovery uses a fresh request key")
	var foreign: Dictionary = document.duplicate(true)
	foreign.name = "Another device changed the head"
	var conflicting: Dictionary = flow.stage(foreign)
	client.head = "another-device-revision"
	await flow._advance(conflicting.path,conflicting.job,flow.scope())
	check(flow._read(conflicting.path).has("failure"),"a real other-device head conflict remains explicit")
	var conflict_key: String = flow._read(conflicting.path).upload_key
	await flow.retry(foreign)
	check(flow._read(conflicting.path).has("failure") and flow._read(conflicting.path).upload_key == conflict_key,"Retry cannot rebase onto another device's head")
	check(flow.archive_draft(str(document.id)),"archive intent is durable before local deletion")
	flow.defer_sync(document)
	check(flow._pending.is_empty() and flow.stage(document).is_empty(),"deleted drafts cannot stage or defer new sync work")
	flow.free(); cloud.free(); client.free()

	var refresh := RefreshClient.new()
	configure(refresh)
	refresh.session_path = folder.path_join("session.cfg")
	refresh._save_session()
	refresh.request_api("/me",HTTPClient.METHOD_GET,{},"",true)
	await process_frame
	check(refresh.refreshing,"fixture refresh is in flight")
	await refresh.logout()
	check(not refresh.signed_in() and not refresh.has_saved_session(),"busy sign-out immediately clears persisted and in-memory credentials")
	await create_timer(0.06).timeout
	check(not refresh.signed_in() and not refresh.has_saved_session(),"late refresh cannot resurrect a signed-out session")
	var stale := ConfigFile.new()
	stale.set_value("session","url",refresh.base_url())
	stale.set_value("session","refresh_token","fictional-stale-refresh")
	stale.save(refresh.session_path)
	var restarted := RefreshClient.new()
	root.add_child(restarted)
	restarted.configure(refresh.base_url())
	restarted.session_path = refresh.session_path
	await restarted.restore_session()
	check(not restarted.signed_in() and not restarted.refreshing,"a restart cannot restore credentials behind the durable sign-out fence")
	restarted._remember({"ok":true,"status":200,"error":"","data":{"access_token":"fictional-new-access","refresh_token":"fictional-new-refresh","player":{"id":"fixture-player"}}})
	check(restarted.has_saved_session() and not FileAccess.file_exists(restarted.session_path+".signed_out"),"a later successful sign-in removes the sign-out fence")
	restarted.free()
	refresh.free()

	var paged := Pass2.PagedClient.new()
	configure(paged)
	cloud = make_cloud(paged,"catalog")
	cloud.load_cached()
	for iteration: int in range(4):
		await cloud.refresh(true)
		check(cloud.entries.size() <= cloud.MAX_CATALOG_ENTRIES and cloud._snapshot_entries.size() <= cloud.MAX_CATALOG_ENTRIES,"catalog temporary and final snapshots stay bounded")
	check(cloud._read(cloud.cache_root().path_join("index.json")).entries.size() <= 1000,"completed catalog stays bounded on disk")
	cloud.load_cached()
	check(cloud.entries.size() <= 1000,"catalog reload enforces the cap")
	var retained: Dictionary = cloud.entries[0].duplicate(true)
	check(cloud._retain_metadata(retained),"downloaded publication metadata is retained independently of the preview cap")
	cloud.entries.clear()
	var catalog := TrackCatalog.new(TrackLibrary.new(folder.path_join("retained-library")))
	cloud.add_to_catalog(catalog,null,["cloud_"+str(retained.track_id)])
	check(catalog.entries.size() == 1 and catalog.entries[0].track_id == retained.track_id,"an evicted favorite remains discoverable from retained metadata")
	cloud.free(); paged.free()

	var board_client := FailingBoardClient.new()
	configure(board_client)
	var board := Pass2.BoardDialog.new()
	board.client = board_client
	board.version = "fixture-version"
	board.vehicle = "compact"
	root.add_child(board)
	board.offset = 10020
	board.page_cursors.append("supported-server-cursor")
	board.page_index = 1
	await board.load_page()
	check(board_client.paths[-1].contains("cursor=") and not board_client.paths[-1].contains("offset="),"leaderboard paging uses a cursor beyond the legacy offset cap")
	await board.load_page(true)
	check(board_client.paths[-1] == "/boards/fixture-board/around-me","Around me uses the retained board independently of page offset")
	board_client.fail_page = true
	await board.load_page()
	check(board.rows.text.contains("Could not load"),"fixture page failure is visible")
	var requests: int = board_client.paths.size()
	await board.load_page(true)
	check(board_client.paths.size() == requests+1 and board_client.paths[-1].ends_with("/around-me"),"Around me still loads directly after a page request fails")
	board.free(); board_client.free()

	var queue := QueueClient.new()
	configure(queue)
	cloud = make_cloud(queue,"history")
	var directory: String = cloud.outbox_path().get_base_dir().path_join("runs")
	for index: int in range(2000):
		var ticket_id: String = "done-"+str(index)
		cloud._write(directory.path_join(ticket_id.sha256_text()+".job.json"),{"ticket":ticket_id,"key":"fictional-key","done":true,"publish":""})
	await cloud.flush_outbox() # One-time background discovery of pre-index receipts.
	cloud.metadata_reads = 0
	var before: int = Time.get_ticks_usec()
	await cloud.flush_outbox()
	measurements.history_2000_idle_flush_usec = Time.get_ticks_usec()-before
	check(cloud.metadata_reads == 0,"ordinary polling reads no completed receipt metadata")
	for index: int in range(40): check(cloud.queue_run({"ticket_id":"pending-"+str(index)},[[0,0,0]]),"pending replay is durably indexed")
	cloud.metadata_reads = 0
	await cloud.flush_outbox()
	check(queue.submissions.size() == 16 and cloud.metadata_reads <= 16,"one poll processes at most sixteen indexed jobs")
	await cloud.flush_outbox()
	check(queue.submissions.size() == 32,"subsequent polls advance past the first pending batch")
	await cloud.flush_outbox()
	check(queue.submissions.size() == 40,"pending traversal does not skip a boundary job")
	var pinned: Dictionary = {"ticket_id":"original-owner-race","_owner_id":"fixture-player","_origin":queue.base_url()}
	queue.clear_session()
	check(cloud.queue_run(pinned,[[0,0,0]]),"a completed original-owner race survives session expiry")
	check(FileAccess.file_exists(directory.path_join("original-owner-race".sha256_text()+".job.json")),"expired-session race remains in the original owner's outbox")
	check(cloud.upload_jobs().is_empty(),"Guest cannot read the previous owner's upload jobs")
	cloud.free(); queue.free()

	await check_expiry_and_navigation(document)
	await check_restart_ownership(document)
	var evidence_path: String = ProjectSettings.globalize_path("res://../build/review-followups-client.json")
	var file := FileAccess.open(evidence_path,FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"measurements":measurements},"\t"))
	file.close()
	print("REVIEW_FOLLOWUPS: %d checks, %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)

func make_app(client: Node, suffix: String) -> Node:
	var account := Pass3.ReviewAccount.new()
	account.client.free()
	account.client = client
	account.add_child(client)
	client.configure("http://127.0.0.1:18181")
	client._access_token = "fictional-access"
	client._refresh_token = "fictional-refresh"
	client.player = {"id":"fixture-player","display_name":"Fixture racer"}
	client.identity_changed.connect(account._identity_changed)
	var app := Pass3.ReviewApp.new()
	app.profile_root = folder.path_join(suffix)
	app.guest_records = LocalRecords.new(folder.path_join(suffix+"-guest.json"))
	app.guest_library = TrackLibrary.new(folder.path_join(suffix+"-guest-tracks"))
	app.records = app.guest_records
	app.library = app.guest_library
	app.online = account
	root.add_child(app)
	app.add_child(account)
	app.root_ui = Control.new()
	app.add_child(app.root_ui)
	app.account_button = Button.new()
	app.root_ui.add_child(app.account_button)
	account.changed.connect(app._account_changed)
	app._account_changed()
	return app

func check_expiry_and_navigation(document: Dictionary) -> void:
	var app: Node = make_app(Pass3.ExpiringClient.new(),"expiry")
	var outgoing_library: TrackLibrary = app.library
	app.document = document.duplicate(true)
	await app.online.client.request_api("/me",HTTPClient.METHOD_GET,{},"",true)
	check(app.records == app.guest_records,"expired-session callers immediately see the Guest storage scope")
	await process_frame
	check(app.records == app.guest_records and app.active_profile.is_empty(),"session expiry switches records and authoring scope to Guest")
	check(app.account_button.text == "Guest","session expiry updates the account badge")
	check(not outgoing_library.load_wip(str(document.id)).is_empty(),"outgoing editor work is saved under its original owner")
	app.free()
	var draft_client := Pass3.DraftClient.new()
	app = make_app(draft_client,"deletion")
	var draft_cloud: Node = make_cloud(draft_client,"deletion-cloud")
	var deleting := TrackLifecycle.new()
	deleting.cloud = draft_cloud
	deleting.library = app.library
	app.add_child(deleting)
	draft_client.uploaded = document.duplicate(true)
	app.library.save_wip(document)
	deleting.defer_sync(document)
	deleting.stage(document)
	check(deleting.archive_draft(str(document.id)) and app.library.delete_editable(str(document.id)) == OK,"Delete records its intent before removing authoring files")
	await deleting.process_jobs()
	check(draft_client.posts == 0 and app.library.load_wip(str(document.id)).is_empty(),"pending sync and remote restore cannot recreate a deleted draft")
	deleting._restored_scope = ""
	await deleting.process_jobs()
	check(app.library.load_wip(str(document.id)).is_empty(),"durable archive intent also fences later restore passes")
	app.free(); draft_cloud.free()
	app = make_app(Pass3.QuietClient.new(),"navigation")
	var cloud := NavigationCloud.new()
	cloud.app = app
	cloud.client = app.online.client
	app.add_child(cloud)
	app.cloud = cloud
	app.lifecycle = TrackLifecycle.new()
	app.lifecycle.cloud = cloud
	app.add_child(app.lifecycle)
	var track: NativeTrack = TrackCompiler.compile(document)
	track.metadata.cloud_version = "fixture-version"
	app.selected_track = track
	await app._start_race(track,false)
	check(app.screen == "settings" and app.game == null and app.root_ui.visible,"late race ticket cannot override navigation to Settings")
	check(app.cloud_ticket.is_empty(),"cancelled start does not install a stale ticket")
	app.free()

func check_restart_ownership(document: Dictionary) -> void:
	var client := SnapshotClient.new()
	client.document = document
	var app: Node = make_app(client,"restart-owner")
	var cloud: Node = make_cloud(client,"restart-cloud")
	app.cloud = cloud
	var running := RestartGame.new()
	running.native_track = TrackCompiler.compile(document)
	running.native_track.metadata.cloud_version = "fixture-version"
	running.preference_records = app.records
	app.game = running
	app.add_child(running)
	var original_records: LocalRecords = running.preference_records
	client.clear_session()
	await app._retry_race()
	check(running.restarted and running.preference_records == app.guest_records and running.preference_records != original_records,"a confirmed Guest restart begins a new attempt in Guest records")
	check(running.resume_ticket_id.is_empty(),"an offline new attempt cannot reuse the previous race ticket")
	client._access_token = "fictional-current-access"
	client.player = {"id":"second-fixture-player","display_name":"Second fixture"}
	client.identity_changed.emit()
	VehicleCatalog.selected = "pickup"
	await app._retry_race()
	check(client.issued_vehicle == "kart" and not app.cloud_ticket.is_empty(),"verified retry pins the existing game's vehicle/handling despite the new profile selection")
	check(running.preference_records == app.records and app.cloud_ticket.get("_owner_id") == "second-fixture-player","the verified new attempt uses current-profile records and upload owner")
	app.free(); cloud.free()
