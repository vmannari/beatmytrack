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
	await process_frame
	var online: Node = app.online
	check(not online.client.signed_in(), "startup stays signed out")
	check(app.root_ui.find_child("MenuAccount", true, false).text == "Sign in", "menu offers sign in")
	app._show_screen("account")
	await online.refresh_options()
	check(online.show_development(), "development offered by configured test server")
	check(app.root_ui.find_child("GoogleSignIn", true, false) != null, "Google option exists")
	check(app.root_ui.find_child("DevelopmentSignIn", true, false).visible, "Development option visible")
	check(not app.root_ui.find_child("PlayerUsername", true, false).visible, "provider choice has no username field")
	check(app.root_ui.find_child("MenuNavigation", true, false) == null, "sign-in is a focused standalone screen")
	app.root_ui.find_child("ContinueWithoutSignIn", true, false).pressed.emit()
	check(app.screen == "play" and not online.client.signed_in(), "guest action returns to local play without an account")
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
	check(online.client.signed_in() and online.player_name() == "developer", "actual server authenticates developer")
	await online.refresh_options()
	check(online.client.signed_in() and online.player_name() == "developer", "account refresh checks authenticated profile")
	var player_id: String = online.client.player.id
	check(not online.needs_username(), "developer never needs name selection")
	check(not app.root_ui.find_child("GoogleSignIn", true, false).visible, "signed-in screen hides login actions")
	await capture("developer-960")
	app._show_screen("tracks")
	check(app.root_ui.find_child("MenuAccount", true, false).text == "developer", "menu displays developer")
	app._show_screen("account")
	check(online.client.signed_in(), "session survives menu navigation")
	await online.sign_out()
	check(not online.client.signed_in() and online.client.player.is_empty(), "sign out clears session")
	await online.sign_in_developer()
	check(online.client.player.id == player_id, "repeated development sign-in reuses the account")
	await online.sign_out()
	online.open_browser = open_fixture_browser
	await online.sign_in_google()
	check(online.client.signed_in() and online.needs_username(), "Google authenticates before name selection")
	check(app.root_ui.find_child("PlayerUsername", true, false).visible, "only new authenticated players see name field")
	check(not app.root_ui.find_child("GoogleSignIn", true, false).visible, "name selection does not mix provider choices")
	await capture("choose-name-960")
	await online.save_username("   ")
	check(online.needs_username() and not online.busy, "blank name cannot finish onboarding")
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
