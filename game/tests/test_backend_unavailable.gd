extends SceneTree
## Offline account/controller and visible panel regression; no real credentials.
var checks: int = 0
var failures: int = 0
var output: String = ""

class FixtureClient extends "res://backend/backend_client.gd":
	var bootstrap: Dictionary = {"ok":false,"error":"NETWORK_ERROR","status":0}
	var restored: Dictionary = {"ok":false,"error":"NETWORK_ERROR","status":0}
	var profile: Dictionary = {"ok":false,"error":"INVALID_RESPONSE","status":503}
	var saved: bool = true
	var restore_calls: int = 0
	func discard_signed_out_session() -> void: pass
	func has_saved_session() -> bool: return saved
	func restore_session() -> Dictionary:
		restore_calls += 1
		if restored.ok:
			_access_token = "offline-fixture"
			player = {"id":"fixture","display_name":"Fixture","country_code":"FI"}
		return restored
	func request_api(path: String, _method: HTTPClient.Method = HTTPClient.METHOD_GET, _payload: Dictionary = {}, _key: String = "", _authenticated: bool = false) -> Dictionary:
		return bootstrap if path == "/bootstrap" else profile

class FixtureAccount extends "res://backend/account_controller.gd":
	func _ready() -> void:
		client.free()
		client = FixtureClient.new()
		add_child(client)
		client.identity_changed.connect(_identity_changed)
		configured = true
		_development_key = "offline-fixture"
	func _load_configuration() -> void: pass

func _initialize() -> void: run.call_deferred()

func check(value: bool, description: String) -> void:
	checks += 1
	if not value:
		failures += 1
		print("FAIL: ",description)

func run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	var transport := preload("res://backend/backend_client.gd").new()
	transport.session_path = ""
	root.add_child(transport)
	transport.configure("http://127.0.0.1:1")
	var refused: Dictionary = await transport.request_api("/bootstrap")
	check(not refused.ok and refused.get("error") == "NETWORK_ERROR", "real refused connection reports transport failure")
	transport.queue_free()
	var account := FixtureAccount.new()
	root.add_child(account)
	var client: FixtureClient = account.client
	var center := CenterContainer.new()
	center.theme = MenuStyle.theme()
	MenuStyle.fill(center)
	root.add_child(center)
	var panel := preload("res://ui/account_panel.gd").new()
	panel.account = account
	center.add_child(panel)
	for failure: Dictionary in [
		{"ok":false,"error":"NETWORK_ERROR","status":0},
		{"ok":false,"error":"REQUEST_START_FAILED","status":0},
		{"ok":false,"error":"HTTP_ERROR","status":500},
		{"ok":false,"error":"INVALID_RESPONSE","status":502},
		{"ok":false,"error":"INVALID_RESPONSE","status":503},
		{"ok":false,"error":"HTTP_ERROR","status":504}]:
		client.bootstrap = failure
		await account.start_session()
		check(account.service_unavailable and account.retry_available and not account.busy,"startup outage is explicit and retryable: "+str(failure))
		check(client.saved and client.restore_calls == 0,"unreachable bootstrap preserves saved sign-in")
		check(panel.title.text == "Service unavailable" and panel.status_label.visible and panel.status_label.text == account.message,"actual panel displays outage reason")
		check(panel.refresh_button.visible and panel.guest_button.visible,"retry and guest actions remain available")
	await account.sign_in_developer()
	check(account.service_unavailable and account.retry_available,"developer sign-in failure offers connection retry")
	await account.sign_in_google()
	check(account.service_unavailable and account.retry_available and not account.waiting_for_google,"Google sign-in outage does not launch a provider")
	for physical: Vector2i in [Vector2i(1280,720),Vector2i(960,540)]:
		root.size = physical
		for _frame: int in range(10): await process_frame
		check(panel.status_label.get_global_rect().position.y < panel.google_button.get_global_rect().position.y,"failure reason precedes providers")
		check(root.get_visible_rect().encloses(panel.get_global_rect()),"outage card fits viewport: "+str(physical)+" card="+str(panel.get_global_rect())+" viewport="+str(root.get_visible_rect()))
		if not output.is_empty() and DisplayServer.get_name() != "headless":
			DirAccess.make_dir_recursive_absolute(output)
			await RenderingServer.frame_post_draw
			check(root.get_texture().get_image().save_png(output.path_join("outage-%d.png" % physical.x)) == OK,"native screenshot saved")
	client.bootstrap = {"ok":true,"data":{"service":"beat-my-track","api_version":"v1"}}
	await account.refresh_options()
	check(account.service_unavailable and account.retry_available and not account.message.is_empty(),"retry retains failed saved-session restoration reason")
	client.restored = {"ok":true}
	await account.refresh_options()
	check(account.service_unavailable and account.retry_available,"failed /me after restoration is visible")
	client.profile = {"ok":true,"data":{"id":"fixture","display_name":"Fixture","country_code":"FI"}}
	await account.refresh_options()
	check(not account.service_unavailable and not account.retry_available and account.profile_ready(),"successful retry clears outage and restores account")
	check(panel.title.text == "Your account" and not panel.refresh_button.visible,"recovered UI returns to normal")
	client._access_token = ""
	client.player = {}
	client.restored = {"ok":false,"error":"ACCOUNT_DISABLED","status":403}
	await account.refresh_options()
	check(not account.service_unavailable and account.message == "This account is disabled.","rejected sign-in keeps its distinct reason")
	client.saved = false
	await account.refresh_options()
	check(not account.service_unavailable and not account.retry_available and account.message.is_empty(),"reachable first-time sign-in has no outage warning")
	center.queue_free()
	account.queue_free()
	await process_frame
	print("BACKEND_UNAVAILABLE checks=",checks," failures=",failures)
	quit(1 if failures else 0)
