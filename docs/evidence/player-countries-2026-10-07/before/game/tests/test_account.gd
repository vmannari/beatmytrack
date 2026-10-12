extends SceneTree
var checks: int = 0
var failures: int = 0
var app: Node
var folder: String
var browser_mode: String = "complete"

class WrongServiceClient extends "res://backend/backend_client.gd":
	var sent_credentials: bool = false
	func request_api(_path: String, _method: HTTPClient.Method = HTTPClient.METHOD_GET, _payload: Dictionary = {}, _key: String = "", _authenticated: bool = false) -> Dictionary:
		return {"ok":true,"data":{"api_version":"v1","service":"another-app"}}
	func developer_login(_key: String) -> Dictionary:
		sent_credentials = true
		return {"ok":false,"error":"WRONG_SERVICE"}

func open_fixture_browser(url: String) -> Error:
	if browser_mode == "cancel":
		app.online.cancel_google.call_deferred()
	else:
		complete_fixture_browser.call_deferred(url)
	return OK

func complete_fixture_browser(url: String) -> void:
	var browser := preload("res://backend/backend_client.gd").new()
	root.add_child(browser)
	browser.configure(OS.get_environment("BMT_API_URL"))
	var token: String = url.get_slice("#",1)
	var config: Dictionary = await browser.request_api("/auth/google/browser/prepare",HTTPClient.METHOD_POST,{"token":token})
	check(config.ok,"browser receives nonce challenge")
	var result: Dictionary = await browser.request_api("/auth/google/browser/complete",HTTPClient.METHOD_POST,{"token":token,"id_token":config.data.nonce})
	check(result.ok and not result.data.has("access_token"),"browser completes without receiving game credentials")
	browser.queue_free()

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, description: String) -> void:
	checks += 1
	if not value:
		failures += 1
		print("FAIL: " + description)

func capture(filename: String) -> void:
	var output: String = OS.get_environment("BMT_CAPTURE_ACCOUNT")
	if output.is_empty() or DisplayServer.get_name() == "headless": return
	DirAccess.make_dir_recursive_absolute(output)
	await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(output.path_join(filename + ".png")) == OK, "saved " + filename)

func run() -> void:
	folder = "user://account_test_" + TrackLibrary.unique_id()
	DirAccess.make_dir_recursive_absolute(folder)
	app = (load("res://core/app.tscn") as PackedScene).instantiate()
	app.records = LocalRecords.new(folder.path_join("records.json"))
	app.library = TrackLibrary.new(folder)
	root.add_child(app)
	while not app.startup_complete: await process_frame
	var legacy_document: Dictionary = TrackDocument.create_default()
	legacy_document.id = "legacy_playable"
	check(app.library.save_document(legacy_document) == OK, "existing local circuit fixture saved")
	var online: Node = app.online
	check(not online.client.signed_in(), "startup stays signed out")
	check(app.screen == "account", "first launch opens sign-in")
	app._show_screen("account")
	await online.refresh_options()
	check(online.show_development(), "development offered by configured test server")
	check(app.root_ui.find_child("GoogleSignIn", true, false) != null, "Google option exists")
	check(app.root_ui.find_child("DevelopmentSignIn", true, false).visible, "Development option visible")
	check(not app.root_ui.find_child("PlayerUsername", true, false).visible, "provider choice has no username field")
	check(app.root_ui.find_child("MenuNavigation", true, false) == null, "sign-in is a focused standalone screen")
	app.root_ui.find_child("ContinueWithoutSignIn", true, false).pressed.emit()
	check(app.screen == "tracks" and not online.client.signed_in(), "guest action opens Race without an account")
	app._show_screen("account")
	for physical: Vector2i in [Vector2i(1280,720), Vector2i(960,540)]:
		root.size = physical
		await process_frame
		await process_frame
		await capture("sign-in-%d" % physical.x)
	var key: String = online._development_key
	online._development_key = "incorrect"
	await online.sign_in_developer()
	check(not online.client.signed_in() and not online.busy, "wrong key never produces a local fake login")
	online._development_key = key
	await online.sign_in_developer()
	check(online.client.signed_in() and online.player_name() == "Beat my track", "actual server authenticates developer")
	await online.refresh_options()
	check(online.client.signed_in() and online.player_name() == "Beat my track", "account refresh checks authenticated profile")
	var player_id: String = online.client.player.id
	app._show_screen("tracks")
	var browser: Node = app.root_ui.find_child("TrackBrowser", true, false)
	while browser.loading: await process_frame
	var retained: Dictionary = app.guest_library.load_document("legacy_playable")
	check(not retained.is_empty() and TrackCompiler.compile(retained) != null, "existing local circuit remains intact and drivable after signing in")
	check(app.track_catalog.entries.all(func(entry: Dictionary) -> bool: return entry.source == "cloud"), "sign-in does not silently publish local drafts into Race")
	check(app.track_catalog.query({"section":"saved"}, []).is_empty(), "shared existing tracks are not claimed as My tracks")
	for entry: Dictionary in app.track_catalog.entries:
		if entry.id == "creator_legacy_playable":
			check(app.track_catalog.resolve(entry) != null, "shared circuit resolves to a drivable track")
	await capture("existing-tracks")
	app._show_screen("account")
	var developer_records_path: String = app.records.path
	app.records.settings.track_ratings = {"profile_test":5}
	check(app.records.save_records() == OK, "rating saves into developer profile")
	var owned_document: Dictionary = TrackDocument.create_blank()
	owned_document["creator"] = "Impersonated name"
	check(app.library.save_wip(owned_document) == OK, "owned draft saves: " + app.library.last_error)
	check(app.library.load_wip(owned_document.id).get("creator", "") == "Beat my track", "track storage stamps authenticated author")
	app._new_document()
	check(app.document["creator"] == "Beat my track", "new track uses racing name")
	await capture("developer-creator")
	app._show_screen("account")

	check(not online.needs_username(), "developer never needs name selection")
	check(not app.root_ui.find_child("GoogleSignIn", true, false).visible, "signed-in screen hides login actions")
	await capture("developer-960")
	app._show_screen("tracks")
	check(app.root_ui.find_child("MenuAccount", true, false).text == "Beat my track", "menu displays developer")
	app._show_screen("account")
	check(online.client.signed_in(), "session survives menu navigation")
	check(online.client.has_saved_session(), "login stores a refresh session")
	var saved_path: String = online.client.session_path
	var restarted: Node = (load("res://core/app.tscn") as PackedScene).instantiate()
	restarted.records = LocalRecords.new(folder.path_join("records.json"))
	restarted.library = TrackLibrary.new(folder)
	root.add_child(restarted)
	check(restarted.screen == "restoring", "remembered startup begins on neutral loading screen")
	var login_flashed: bool = false
	while not restarted.startup_complete:
		login_flashed = login_flashed or restarted.screen == "account" or restarted.root_ui.find_child("GoogleSignIn", true, false) != null
		await process_frame
	check(not login_flashed, "successful session restoration never constructs login controls")
	if not OS.get_environment("BMT_CAPTURE_ACCOUNT").is_empty():
		restarted._show_screen("restoring")
		await capture("remembered-startup")
		restarted._show_screen("play")
	check(restarted.records.settings.get("track_ratings",{}).get("profile_test",0) == 5, "same player recovers ratings after restart")
	check(restarted.library.load_wip(owned_document.id).get("creator", "") == "Beat my track", "same player recovers drafts after restart")
	check(restarted.screen == "tracks" and restarted.online.player_name() == "Beat my track", "fresh app restores identity and opens Race")
	check(restarted.online.client.has_saved_session(), "rotation replaces saved refresh token")
	var stored: String = FileAccess.get_file_as_string(saved_path)
	check(not restarted.online.client._refresh_token.is_empty() and restarted.online.client._refresh_token != online.client._refresh_token, "restore rotates refresh token")
	check(not restarted.online.client._access_token in stored and not key in stored, "saved session excludes access token and development key")
	restarted.root_ui.find_child("MenuAccount", true, false).pressed.emit()
	check(restarted.screen == "profile","menu account opens Profile")
	restarted.root_ui.find_child("ManageAccount",true,false).pressed.emit()
	while restarted.online.busy: await process_frame
	check(restarted.screen == "account" and restarted.root_ui.find_child("SignOut", true, false).visible, "menu account provides logout")
	await restarted.online.sign_out()
	check(not restarted.online.client.has_saved_session(), "logout removes remembered login")
	restarted.queue_free()
	await process_frame
	var after_logout: Node = (load("res://core/app.tscn") as PackedScene).instantiate()
	after_logout.records = LocalRecords.new(folder.path_join("records.json"))
	after_logout.library = TrackLibrary.new(folder)
	root.add_child(after_logout)
	while not after_logout.startup_complete: await process_frame
	check(after_logout.screen == "account" and not after_logout.online.client.signed_in(), "restart after logout requires sign-in")
	var invalid := ConfigFile.new()
	invalid.set_value("session", "url", online.client._base_url)
	invalid.set_value("session", "refresh_token", "expired-or-invalid")
	invalid.save(saved_path)
	await after_logout.online.start_session()
	check(not after_logout.online.client.signed_in() and not FileAccess.file_exists(saved_path), "invalid saved session cannot authenticate and is removed")
	after_logout.queue_free()
	await process_frame
	await online.sign_out()
	check(not online.client.signed_in() and online.client.player.is_empty(), "sign out clears session")
	await online.sign_in_developer()
	check(online.client.player.id == player_id, "repeated development sign-in reuses the account")
	check(app.records.path == developer_records_path and app.records.settings.track_ratings.profile_test == 5, "switching back restores developer data")
	await online.sign_out()
	online.open_browser = open_fixture_browser
	await online.sign_in_google()
	check(online.client.signed_in() and online.needs_username(), "Google authenticates before name selection")
	check(app.records.path != developer_records_path and app.records.settings.get("track_ratings",{}).is_empty(), "Google player cannot inherit developer ratings")
	check(app.library.load_wip(owned_document.id).is_empty() and app.document.is_empty(), "Google player cannot inherit developer draft or editor state")
	check(app.root_ui.find_child("PlayerUsername", true, false).visible, "only new authenticated players see name field")
	check(not app.root_ui.find_child("GoogleSignIn", true, false).visible, "name selection does not mix provider choices")
	await capture("choose-name-960")
	await online.save_username("   ")
	check(online.needs_username() and not online.busy, "blank name cannot finish onboarding")
	app.root_ui.find_child("PlayerUsername", true, false).text = "beat my track"
	await online.save_username("beat my track")
	check(online.needs_username() and "already taken" in online.message, "duplicate name remains in onboarding with useful feedback")
	await capture("name-taken")
	await online.save_username("Chosen racer")
	check(online.player_name() == "Chosen racer" and not online.needs_username(), "profile saves chosen name after Google authentication")
	check(online.client.player.id != player_id, "Google identity is independent of developer")
	await capture("google-player-960")
	await online.sign_out()
	await online.sign_in_google()
	check(online.player_name() == "Chosen racer" and not online.needs_username(), "returning Google player skips name selection")
	await online.sign_out()
	browser_mode = "cancel"
	await online.sign_in_google()
	check(not online.client.signed_in() and not online.busy, "cancelled Google login stays signed out")
	online.capabilities.development_auth = false
	online.changed.emit()
	check(not app.root_ui.find_child("DevelopmentSignIn", true, false).visible, "removing server development option hides button")
	await capture("google-only-960")
	var real_client: Node = online.client
	var wrong := WrongServiceClient.new()
	root.add_child(wrong)
	online.client = wrong
	online.capabilities = {"development_auth":true}
	await online.sign_in_developer()
	check(not wrong.sent_credentials and online.capabilities.is_empty(), "wrong service never receives development credentials")
	check("another service" in online.message, "wrong service gives actionable feedback")
	online.client = real_client
	wrong.queue_free()
	app.queue_free()
	await process_frame
	# Only files created in the isolated test folder are removed.
	for filename: String in DirAccess.get_files_at(folder): DirAccess.remove_absolute(folder.path_join(filename))
	DirAccess.remove_absolute(folder)
	print("ACCOUNT_UI: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
