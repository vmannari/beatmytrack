extends SceneTree
## Review reproductions, not production behavior or passing invariant tests.
## Uses only an isolated build directory and fictional sessions/server responses.
const Client = preload("res://backend/backend_client.gd")
const Cloud = preload("res://backend/cloud_tracks.gd")
var evidence: Dictionary = {}
var folder: String

class ReviewAccount extends "res://backend/account_controller.gd":
	func _ready() -> void: pass

class PagedClient extends Client:
	var position: int = 0
	func request_api(_path: String, _method: HTTPClient.Method = HTTPClient.METHOD_GET, _payload: Dictionary = {}, _key: String = "", _authenticated: bool = false) -> Dictionary:
		var items: Array = []
		for number: int in range(position,mini(position+100,1001)):
			items.append({"version_id":"00000000-0000-0000-0000-"+str(number).pad_zeros(12),
				"track_id":"fixture-track-"+str(number),"content_hash":"a".repeat(64),"points":[[0,0]],
				"name":"Fixture "+str(number),"creator":"Fixture","creator_id":"fixture-player",
				"theme":"pine","rating_average":null,"rating_count":0})
		position += items.size()
		return {"ok":true,"status":200,"data":{"items":items,"next_cursor":"fixture-cursor" if position < 1001 else null},"error":""}

class RevisionClient extends Client:
	var flow: TrackLifecycle
	var edited: Dictionary = {}
	var head: String = ""
	var staged_during_request: Dictionary = {}
	func request_api(path: String, _method: HTTPClient.Method = HTTPClient.METHOD_GET, payload: Dictionary = {}, _key: String = "", _authenticated: bool = false) -> Dictionary:
		if path == "/tracks":
			if not head.is_empty() and payload.get("expected_head_revision_id") == "new":
				return {"ok":false,"status":409,"data":{},"error":"REVISION_CONFLICT: the remote draft changed; both snapshots are preserved"}
			# A normal second local Save while the first upload response is outstanding.
			staged_during_request = flow.stage(edited)
			await get_tree().create_timer(0.01).timeout
			head = "00000000-0000-0000-0000-000000000001"
			return {"ok":true,"status":201,"data":{"version_id":head,"track_id":"fixture-track"},"error":""}
		return {"ok":true,"status":200,"data":{"state":"draft","manifest":{}},"error":""}

class BoardClient extends Client:
	var paths: Array[String] = []
	func request_api(path: String, _method: HTTPClient.Method = HTTPClient.METHOD_GET, _payload: Dictionary = {}, _key: String = "", _authenticated: bool = false) -> Dictionary:
		paths.append(path)
		if path.get_slice("offset=",1).to_int() > 10000:
			return {"ok":false,"status":422,"data":{},"error":"INVALID_INPUT"}
		return {"ok":true,"status":200,"error":"","data":{"population":10101,"board_id":"fixture-board",
			"items":[{"rank":10001,"display_name":"Fixture","time_ticks":12000}],
			"next_offset":10020,"next_cursor":"supported-server-cursor"}}

class BoardDialog extends "res://ui/cloud_leaderboard.gd":
	func _ready() -> void:
		rows = RichTextLabel.new()
		add_child(rows)
		previous = Button.new()
		next = Button.new()
		around = Button.new()
		for button: Button in [previous,next,around]: add_child(button)

func _initialize() -> void: call_deferred("run")

func run() -> void:
	folder = ProjectSettings.globalize_path("res://../build/review-pass2-"+TrackLibrary.unique_id())
	DirAccess.make_dir_recursive_absolute(folder)
	var account := ReviewAccount.new()
	root.add_child(account)
	root.add_child(account.client)
	account.client.configure("http://127.0.0.1:18181")
	account.client.session_path = folder.path_join("fixture-session.cfg")
	account.client._access_token = "fictional-access"
	account.client._refresh_token = "fictional-refresh"
	account.client.player = {"id":"fixture-player"}
	account.client._save_session()
	account.client._busy = true
	var panel := preload("res://ui/account_panel.gd").new()
	panel.account = account
	root.add_child(panel)
	var logout_enabled: bool = not panel.logout_button.disabled
	await account.sign_out()
	evidence.busy_sign_out = {"button_enabled":logout_enabled,"message":account.message,
		"still_signed_in":account.client.signed_in(),"saved_session_retained":account.client.has_saved_session()}
	account.client._busy = false
	panel.free()
	account.client.free()
	account.free()

	var paged := PagedClient.new()
	root.add_child(paged)
	paged.configure("http://127.0.0.1:18181")
	var cloud := Cloud.new()
	cloud.client = paged
	cloud.root_override = folder.path_join("catalog")
	root.add_child(cloud)
	cloud.load_cached()
	var page_sizes: Array = []
	for iteration: int in range(4):
		await cloud.refresh(true)
		page_sizes.append(cloud.entries.size())
	evidence.catalog_snapshot = {"configured_entry_cap":cloud.MAX_CATALOG_ENTRIES,
		"sizes_after_refresh":page_sizes,"snapshot_entries":cloud._snapshot_entries.size(),
		"persisted_entries":cloud._read(cloud.cache_root().path_join("index.json")).entries.size()}
	cloud.free()
	paged.free()

	var history_client := Client.new()
	root.add_child(history_client)
	history_client.configure("http://127.0.0.1:18181")
	history_client._access_token = "fictional-access"
	history_client.player = {"id":"fixture-history"}
	var history_cloud := Cloud.new()
	history_cloud.client = history_client
	history_cloud.root_override = folder.path_join("history")
	root.add_child(history_cloud)
	var history_directory: String = history_cloud.outbox_path().get_base_dir().path_join("runs")
	var history_results: Array = []
	var written: int = 0
	for population: int in [500,2000]:
		for number: int in range(written,population):
			var ticket: String = "fixture-history-"+str(number)
			var digest: String = ticket.sha256_text()
			if not history_cloud._write(history_directory.path_join(digest+".job.json"),
				{"ticket":ticket,"key":"fixture-operation-key","run_id":"fixture-run-"+str(number),
				"replay":digest+".replay.json","replay_hash":"a".repeat(64),"publish":"","publish_key":"fixture-publish-key","done":true}):
				print("PROBE_SETUP_FAILED: fixture history write")
				quit(1)
				return
		written = population
		var samples: Array = []
		var loaded: int = 0
		for sample: int in range(3):
			var began: int = Time.get_ticks_usec()
			loaded = history_cloud.upload_jobs().size()
			samples.append(float(Time.get_ticks_usec()-began)/1000.0)
		var began: int = Time.get_ticks_usec()
		await history_cloud.flush_outbox()
		history_results.append({"completed_receipts":population,"loaded":loaded,"scan_ms":samples,
			"flush_without_pending_jobs_ms":float(Time.get_ticks_usec()-began)/1000.0})
	evidence.completed_outbox_cost = history_results
	history_cloud.free()
	history_client.free()

	var revisions := RevisionClient.new()
	root.add_child(revisions)
	revisions.configure("http://127.0.0.1:18181")
	revisions._access_token = "fictional-access"
	revisions.player = {"id":"fixture-editor"}
	var lifecycle_cloud := Cloud.new()
	lifecycle_cloud.client = revisions
	lifecycle_cloud.root_override = folder.path_join("revisions")
	root.add_child(lifecycle_cloud)
	var flow := TrackLifecycle.new()
	flow.cloud = lifecycle_cloud
	flow.library = TrackLibrary.new(folder.path_join("tracks"))
	flow.records = LocalRecords.new(folder.path_join("fixture-records.json"))
	root.add_child(flow)
	flow._restored_scope = flow.scope()
	revisions.flow = flow
	var first: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/knit_bridge_regression.json"))
	first.id = "review_revision"
	first.name = "First fixture revision"
	revisions.edited = first.duplicate(true)
	revisions.edited.name = "Second fixture revision"
	var first_stage: Dictionary = flow.stage(first)
	if first_stage.is_empty():
		print("PROBE_SETUP_FAILED: "+flow.last_error)
		quit(1)
		return
	await flow.process_jobs()
	await flow.process_jobs()
	var second: Dictionary = flow.status_for(revisions.edited)
	evidence.local_revision_during_upload = {"expected_head":second.get("expected_head"),
		"remote_head":revisions.head,"failure":second.get("failure"),"can_retry":flow.can_retry(revisions.edited)}
	flow.free()
	lifecycle_cloud.free()
	revisions.free()

	var board_client := BoardClient.new()
	root.add_child(board_client)
	board_client._access_token = "fictional-access"
	var board_dialog := BoardDialog.new()
	board_dialog.client = board_client
	board_dialog.version = "fixture-version"
	board_dialog.vehicle = "compact"
	root.add_child(board_dialog)
	board_dialog.offset = 10000
	await board_dialog.load_page()
	var offered_next: int = int(board_dialog.next_offset)
	board_dialog.offset = offered_next
	await board_dialog.load_page()
	var next_error: String = board_dialog.rows.text
	await board_dialog.load_page(true)
	evidence.leaderboard_cursor_unused = {"offered_next_offset":offered_next,"next_error":next_error,
		"requested_paths":board_client.paths,"around_me_requested":board_client.paths.any(func(path: String) -> bool: return path.ends_with("/around-me"))}
	board_dialog.free()
	board_client.free()
	await process_frame
	var file := FileAccess.open("res://../docs/evidence/code-review-pass2-2026-10-03/client-probes.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(evidence,"\t")+"\n")
	file.close()
	print("REVIEW_PASS2_PROBES "+JSON.stringify(evidence))
	quit(0)
