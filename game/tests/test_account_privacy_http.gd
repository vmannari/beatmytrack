extends SceneTree
const Client = preload("res://backend/backend_client.gd")
var checks: int = 0
var failures: int = 0
func _initialize() -> void: run.call_deferred()
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures += 1; print("FAIL: "+label)
func run() -> void:
	var client := Client.new(); root.add_child(client)
	check(client.configure(OS.get_environment("BMT_PRIVACY_HTTP_URL")) == OK,"owned service configured")
	check((await client.request_api("/bootstrap")).ok and client.deletion_supported(),"bootstrap advertises deletion resources")
	var signed: Dictionary = await client.development_login("privacy-http-fixture","Privacy HTTP Fixture",OS.get_environment("BMT_DEV_AUTH_KEY"))
	check(signed.ok and not client.telemetry_supported(),"new account has optional collection off")
	var original_player: String = str(client.player.get("id",""))
	var preferences: Dictionary = await client.request_api("/privacy/preferences",HTTPClient.METHOD_POST,{"analytics_enabled":true},"",true)
	check(preferences.ok and preferences.data.analytics_enabled == true,"actual consent preference commits")
	client.player.analytics_enabled = true
	check(client.telemetry_supported(),"explicit preference enables the negotiated transport")
	client.session_path = "user://privacy-http-session.cfg"
	client._save_session()
	check(not client.persistence_error,"actual Windows vault saves the fictional session")
	var removed: Dictionary = await client.delete_account()
	check(removed.ok and removed.get("account_removed") == true,"actual HTTP confirms durable account removal")
	check(not client.signed_in() and not FileAccess.file_exists(client.session_path),"acknowledgement removes local credentials")
	var fresh: Dictionary = await client.development_login("privacy-http-fixture","Privacy HTTP Fixture",OS.get_environment("BMT_DEV_AUTH_KEY"))
	check(fresh.ok and str(client.player.id) != original_player,"sign-in after deletion creates a separate identity")
	check(not client.telemetry_supported(),"recreated account has optional analytics off")
	await client.logout()
	client.queue_free(); await process_frame
	print("Account privacy HTTP: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
