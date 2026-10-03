extends SceneTree
## Observational probes with fictional responses and isolated build files.
const Client = preload("res://backend/backend_client.gd")
const Cloud = preload("res://backend/cloud_tracks.gd")
var evidence: Dictionary = {}
var folder: String

class ReviewAccount extends "res://backend/account_controller.gd":
	func _ready() -> void: pass

class ReviewApp extends "res://core/app.gd":
	var notices: Array[String] = []
	func _ready() -> void: pass
	func _show_screen(value: String) -> void: screen = value
	func _notice(value: String) -> void: notices.append(value)

class QuietClient extends Client:
	func request_api(_path: String, _method: HTTPClient.Method = HTTPClient.METHOD_GET, _payload: Dictionary = {}, _key: String = "", _authenticated: bool = false) -> Dictionary:
		return {"ok":true,"status":200,"error":"","data":{"free":1,"balance":0,"ad_preview_available":true,"ads_available":false,"purchases_available":false}}

class ExpiringClient extends Client:
	func _send(_path: String, _method: HTTPClient.Method, _payload: Dictionary, _authorized: bool, _key: String = "", _headers: PackedStringArray = [], _owner: int = 0) -> Dictionary:
		return _failure("INVALID_SESSION",401)

class DraftClient extends QuietClient:
	var uploaded: Dictionary = {}
	var posts: int = 0
	func request_api(path: String, _method: HTTPClient.Method = HTTPClient.METHOD_GET, payload: Dictionary = {}, _key: String = "", _authenticated: bool = false) -> Dictionary:
		if path == "/tracks":
			posts += 1
			uploaded = payload.document.duplicate(true)
			return {"ok":true,"status":201,"error":"","data":{"version_id":"00000000-0000-0000-0000-000000000003","track_id":"fixture-track"}}
		if path.begins_with("/me/tracks?"):
			return {"ok":true,"status":200,"error":"","data":{"items":[{"version_id":"00000000-0000-0000-0000-000000000003","track_id":"fixture-track","state":"draft","content_hash":JSON.stringify(uploaded).sha256_text()}],"next_offset":null}}
		if path.ends_with("/document"):
			return {"ok":true,"status":200,"error":"","body":JSON.stringify(uploaded),"data":uploaded.duplicate(true)}
		return {"ok":true,"status":200,"error":"","data":{"state":"draft","manifest":{}}}

class DelayedCloud extends Node:
	var app: Node
	var last_error: String = ""
	func ticket(_track: NativeTrack) -> Dictionary:
		await get_tree().create_timer(0.01).timeout
		app._show_screen("settings")
		await get_tree().create_timer(0.01).timeout
		return {"ticket_id":"fictional-ticket"}

func _initialize() -> void: call_deferred("run")

func make_account(client: Node) -> ReviewAccount:
	var account := ReviewAccount.new()
	account.client.free()
	account.client = client
	account.add_child(client)
	client.configure("http://127.0.0.1:18181")
	client._access_token = "fictional-access"
	client._refresh_token = "fictional-refresh"
	client.player = {"id":"fixture-player","display_name":"Review fixture"}
	return account

func make_app(account: ReviewAccount, suffix: String) -> ReviewApp:
	var app := ReviewApp.new()
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

func run() -> void:
	folder = ProjectSettings.globalize_path("res://../build/review-pass3-"+TrackLibrary.unique_id())
	DirAccess.make_dir_recursive_absolute(folder)
	var account: ReviewAccount = make_account(ExpiringClient.new())
	var app: ReviewApp = make_app(account,"expiry")
	var initial_scope: String = app.active_profile
	var initial_path: String = app.records.path
	var response: Dictionary = await account.client.request_api("/me",HTTPClient.METHOD_GET,{},"",true)
	app.records.settings.selected_car = "kart"
	var saved: Error = app.records.save_records()
	evidence.session_expiry_profile = {"request_status":response.status,"signed_in_after_failure":account.client.signed_in(),
		"profile_scope_unchanged":app.active_profile == initial_scope,"records_path_unchanged":app.records.path == initial_path,
		"guest_records_selected":app.records == app.guest_records,"account_button_text":app.account_button.text,
		"post_expiry_preference_saved_to_previous_profile":saved == OK}
	app.free()

	var draft_client := DraftClient.new()
	account = make_account(draft_client)
	app = make_app(account,"deletion")
	var cloud := Cloud.new()
	cloud.client = draft_client
	cloud.root_override = folder.path_join("deletion-cloud")
	app.add_child(cloud)
	app.cloud = cloud
	var flow := TrackLifecycle.new()
	flow.cloud = cloud
	flow.library = app.library
	flow.records = app.records
	app.lifecycle = flow
	app.add_child(flow)
	flow._restored_scope = flow.scope()
	var doc: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/knit_bridge_regression.json"))
	doc.id = "delete_fixture"
	doc.name = "Delete review fixture"
	if app.library.save_wip(doc) != OK:
		print("PROBE_SETUP_FAILED: "+app.library.last_error)
		quit(1)
		return
	flow.defer_sync(doc)
	app._confirm_delete_draft(str(doc.id),str(doc.name))
	var dialog: ConfirmationDialog = app.root_ui.find_child("DeleteDraftDialog",true,false)
	dialog.confirmed.emit()
	var removed: bool = app.library.load_wip(str(doc.id)).is_empty()
	await flow.process_jobs()
	var jobs: int = flow.jobs().size()
	# Simulate the next application session recovering private backend heads.
	flow._restored_scope = ""
	await flow.process_jobs()
	evidence.deleted_draft_sync = {"local_autosave_removed_by_confirmation":removed,
		"uploads_after_delete":draft_client.posts,"workflow_jobs_after_delete":jobs,
		"autosave_restored_on_next_head_recovery":not app.library.load_wip(str(doc.id)).is_empty()}
	app.free()
	await process_frame

	account = make_account(QuietClient.new())
	app = make_app(account,"navigation")
	app.lifecycle = TrackLifecycle.new()
	var delayed := DelayedCloud.new()
	delayed.app = app
	app.cloud = delayed
	app.add_child(delayed)
	# Lifecycle scope only needs the same fictional client identity/origin.
	app.lifecycle.cloud = Cloud.new()
	app.lifecycle.cloud.client = account.client
	app.lifecycle.library = app.library
	app.add_child(app.lifecycle.cloud)
	app.add_child(app.lifecycle)
	var track: NativeTrack = TrackCompiler.compile(doc)
	track.metadata.cloud_version = "fixture-version"
	app.screen = "tracks"
	await app._start_race(track,false)
	evidence.navigation_during_race_start = {"latest_menu_choice":app.screen,
		"race_created_after_navigation":is_instance_valid(app.game),"latest_menu_hidden":not app.root_ui.visible,
		"late_ticket_installed":app.cloud_ticket.get("ticket_id") == "fictional-ticket"}
	app.free()
	await process_frame
	var file := FileAccess.open("res://../docs/evidence/code-review-pass3-2026-10-03/client-probes.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(evidence,"\t")+"\n")
	file.close()
	print("REVIEW_PASS3_PROBES "+JSON.stringify(evidence))
	quit(0)
