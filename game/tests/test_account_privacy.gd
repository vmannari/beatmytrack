extends SceneTree
const Client = preload("res://backend/backend_client.gd")
const Telemetry = preload("res://backend/product_telemetry.gd")
const LocalPrivacy = preload("res://backend/privacy_local.gd")
var checks: int = 0
var failures: int = 0
var folder: String

class MockClient extends Client:
	var sent: Array[Dictionary] = []
	var lose_response: bool = true
	var expire_access: bool = false
	var replacement: Dictionary = {}
	func _send(path: String, _method: HTTPClient.Method, body: Dictionary, _authorized: bool, key: String = "", headers: PackedStringArray = [], _owner: int = 0) -> Dictionary:
		sent.append({"path":path,"body":body.duplicate(true),"key":key,"headers":headers})
		if path == "/me": return {"ok":true,"status":200,"data":{"id":player.id},"error":""}
		if path == "/privacy/account-deletion":
			if expire_access and not headers[0].contains("renewed-access"): return _failure("INVALID_SESSION",401)
			if lose_response: return _failure("NETWORK_ERROR")
			if not replacement.is_empty():
				var config := ConfigFile.new()
				for field: String in replacement: config.set_value("session",field,replacement[field])
				_write_saved_config(config)
			return {"ok":true,"status":202,"error":"","data":{"status":"requested","requested_at":1800000000,"player_id":player.id,"tracks_retained":true,"standings_retained":true,"display_name":"Removed account"}}
		if path == "/auth/refresh": return {"ok":true,"status":200,"error":"","data":{"access_token":"renewed-access-"+"a".repeat(40),"refresh_token":"renewed-refresh-"+"b".repeat(40),"player":player.duplicate(true),"expires_in":900}}
		return _failure("UNEXPECTED_REQUEST")

func _initialize() -> void: run.call_deferred()
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures += 1; print("FAIL: "+label)

func make_client() -> MockClient:
	var client := MockClient.new(); root.add_child(client)
	client.configure("http://127.0.0.1:1")
	client._capabilities = {"privacy":{"schema_version":1},"product_telemetry":{"enabled":true,"schema_version":1,"network_schema_version":1}}
	client.player = {"id":"fictional-privacy-owner","analytics_enabled":true}
	client._access_token = "fictional-access-"+"a".repeat(40)
	client._refresh_token = "fictional-refresh-"+"b".repeat(40)
	return client

func run() -> void:
	folder = "user://privacy-fixture-"+str(Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(folder)
	var records := LocalRecords.new(folder.path_join("records.json"))
	var page := SettingsPage.new(); page.records = records; page.development_available = false
	root.add_child(page)
	page._show_section("privacy")
	check(not page.draft_analytics and not page.find_child("OptionalAnalytics",true,false).button_pressed,"optional sharing defaults off")
	page.draft_analytics = true
	check(page._apply(),"explicit choice is saved through validated local records")
	var restored := LocalRecords.new(records.path)
	restored.load_records()
	check(restored.settings.get("optional_analytics") == true,"choice survives restart")
	var client := make_client()
	client.session_path = folder.path_join("session.cfg")
	client._save_session()
	var first: Dictionary = await client.delete_account()
	check(not first.ok and client.signed_in(),"lost response preserves deletion recovery")
	var sent: Dictionary = client.sent[-1]
	var original_id: String = str(sent.body.request_id)
	check(original_id.length() == 36 and sent.headers[0].begins_with("Authorization: Bearer "),"request binds an opaque operation and original credential")
	check(FileAccess.get_file_as_string(client.session_path).begins_with("BMT-SESSION-1") and not FileAccess.get_file_as_string(client.session_path).contains("fictional-access"),"actual Windows vault protects deletion recovery")
	var recovered := make_client(); recovered.session_path = client.session_path; recovered.lose_response = false
	var result: Dictionary = await recovered.restore_session()
	check(result.ok and result.get("account_removed") == true and not recovered.signed_in(),"restart confirms the existing deletion without renewing credentials")
	check(recovered.sent.size() == 1 and recovered.sent[0].body.request_id == original_id and recovered.sent[0].headers == sent.headers,"restart reuses exact request ID and credential")
	check(not FileAccess.file_exists(client.session_path) and FileAccess.file_exists(client.session_path+".signed_out"),"confirmed deletion leaves a durable sign-out fence")
	check(not Client.valid_response("/privacy/account-deletion",HTTPClient.METHOD_POST,{"status":"requested"}),"malformed success cannot trigger local deletion")
	var expiring := make_client(); expiring.session_path = folder.path_join("expired.cfg"); expiring._save_session(); expiring.expire_access = true; expiring.lose_response = false
	var completed: Dictionary = await expiring.delete_account()
	check(completed.ok and expiring.sent.filter(func(item: Dictionary) -> bool: return item.path == "/auth/refresh").size() == 1,"undelivered deletion recovers from expired access under the existing lease")
	var attempts: Array = expiring.sent.filter(func(item: Dictionary) -> bool: return item.path == "/privacy/account-deletion")
	check(attempts.size() == 2 and attempts[0].body == attempts[1].body,"expiry recovery preserves the same deletion operation")
	var exchanging := make_client(); exchanging.session_path = folder.path_join("exchange.cfg"); exchanging._save_session(); exchanging.lose_response = false
	exchanging.replacement = {"url":exchanging.base_url(),"player_id":"other-profile","login_id":"other-login","access_token":"other-access","refresh_token":"other-refresh"}
	check((await exchanging.delete_account()).ok,"acknowledgement still confirms the original account's removal")
	var saved := ConfigFile.new()
	check(exchanging._load_saved_config(saved) == OK and saved.get_value("session","player_id") == "other-profile" and not FileAccess.file_exists(exchanging.session_path+".signed_out"),"deletion acknowledgement preserves another instance's newer saved login")
	expiring.queue_free(); exchanging.queue_free()
	check(not client.telemetry_supported(),"pending deletion suspends optional collection")
	var observer := make_client(); observer.player.id = "fictional-observer-owner"
	var telemetry := Telemetry.new(); telemetry.client = observer; telemetry.storage_path = folder.path_join("telemetry.json")
	root.add_child(telemetry); telemetry._timer.stop()
	while telemetry._thread != null:
		telemetry._finish_thread(); await process_frame
	check(telemetry.observe("menu_ready"),"consented fictional profile can observe")
	telemetry._save_if_needed()
	telemetry.set_enabled(false)
	check(not telemetry.enabled and telemetry.queue.is_empty() and not FileAccess.file_exists(telemetry.storage_path),"withdrawal joins pending IO and erases its outbox")
	check(not observer.network_supported() and not telemetry.observe("menu_ready"),"withdrawal stops observations and network RAM capture")
	var account_dir: String = folder.path_join("players").path_join("account".sha256_text())
	DirAccess.make_dir_recursive_absolute(account_dir.path_join("runs"))
	var file := FileAccess.open(account_dir.path_join("runs/job.json"),FileAccess.WRITE); file.store_string("fictional job"); file.close()
	check(LocalPrivacy.erase_account_tree(account_dir) and not DirAccess.dir_exists_absolute(account_dir),"only the hashed account recovery tree is removed")
	check(not LocalPrivacy.erase_account_tree(folder) and FileAccess.file_exists(records.path),"authored records outside recovery roots remain")
	var document: Dictionary = TrackDocument.create_default(); document["creator"] = "Original name"
	check(TrackDocument.validate(document).is_empty(),"redaction fixture is a valid current track: "+str(TrackDocument.validate(document)))
	var original: NativeTrack = TrackCompiler.compile(document)
	var redacted: Dictionary = document.duplicate(true); redacted.creator = "Removed account"
	var changed: NativeTrack = TrackCompiler.compile(redacted)
	check(original != null and changed != null and original.content_hash != changed.content_hash,"creator redaction changes only the source/compiled hash")
	if original == null or changed == null:
		print("Account privacy: ",checks," checks, ",failures," failures")
		quit(1)
		return
	var entry: Dictionary = {"id":"fixture","content_hash":"a".repeat(64),"version_id":"version","track_id":"track","name":document.name,"creator":"Removed account","redacted_track_hash":changed.content_hash,"manifest":{"track_content_hash":original.content_hash}}
	var compiled: NativeTrack = preload("res://backend/cloud_tracks.gd").compile_document(entry,redacted)
	check(compiled != null and compiled.content_hash == original.content_hash,"validated redacted compile retains the existing online contract")
	check(compiled.cells == original.cells and compiled.route == original.route and compiled.hazard_objects == original.hazard_objects and compiled.checkpoints == original.checkpoints,"redaction preserves actual canonical geometry and hazards")
	entry["canonical_track_hash"] = original.content_hash
	entry.erase("manifest")
	check(preload("res://backend/cloud_tracks.gd").compile_document(entry,redacted) != null,"compact discovery metadata supports redacted tracks without a full manifest")
	var other_document: Dictionary = document.duplicate(true); other_document.creator = "Other owner"
	var other: NativeTrack = TrackCompiler.compile(other_document)
	entry.canonical_track_hash = other.content_hash
	check(preload("res://backend/cloud_tracks.gd").compile_document(entry,redacted).content_hash == other.content_hash,"identical redacted sources cannot borrow another account's contract from the cache")
	entry.content_hash = "b".repeat(64); entry.redacted_track_hash = "invalid"
	check(preload("res://backend/cloud_tracks.gd").compile_document(entry,redacted) == null,"wrong redacted hash cannot alias a contract")
	if not OS.get_environment("BMT_PRIVACY_CAPTURE").is_empty() and DisplayServer.get_name() != "headless":
		var output: String = OS.get_environment("BMT_PRIVACY_CAPTURE")
		DirAccess.make_dir_recursive_absolute(output)
		page.theme = MenuStyle.theme()
		page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		page._show_section("privacy")
		for dimensions: Vector2i in [Vector2i(1280,720),Vector2i(960,540)]:
			root.size = dimensions
			page.size = root.get_visible_rect().size
			page._show_section("privacy")
			for _frame: int in range(4): await process_frame
			await RenderingServer.frame_post_draw
			check(root.get_texture().get_image().save_png(output.path_join("settings-privacy-%dx%d.png" % [dimensions.x,dimensions.y])) == OK,"actual settings privacy capture")
		page.hide()
		client.player.display_name = "Privacy fixture"
		var controller := preload("res://backend/account_controller.gd").new()
		controller.client.free(); controller.client = client; controller.configured = true
		var panel := preload("res://ui/account_panel.gd").new(); panel.account = controller; panel.theme = MenuStyle.theme()
		root.add_child(panel); panel.position = Vector2(140,10); panel.size = Vector2(640,520)
		panel._confirm_deletion()
		for _frame: int in range(4): await process_frame
		var dialog: ConfirmationDialog = panel.find_child("DeleteAccountConfirmation",true,false)
		var copy: Label = dialog.find_child("DeleteAccountCopy",true,false)
		check(copy.get_global_rect().end.y < dialog.get_ok_button().get_global_rect().position.y,"confirmation copy stays above its actions")
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(output.path_join("delete-confirmation-960.png")) == OK,"actual account deletion confirmation capture")
		panel.queue_free(); controller.queue_free()
	page.queue_free(); telemetry.queue_free(); client.queue_free(); recovered.queue_free(); observer.queue_free()
	await process_frame
	print("Account privacy: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
