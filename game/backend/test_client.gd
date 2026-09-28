extends SceneTree
const Client = preload("res://backend/backend_client.gd")
var failures: int = 0
var checks: int = 0

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures += 1; print("FAIL: "+label)

func run() -> void:
	var endpoint: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--endpoint="): endpoint = arg.trim_prefix("--endpoint=")
	var client := Client.new()
	root.add_child(client)
	check(client.configure("http://untrusted.example") == ERR_INVALID_PARAMETER,"credentials need TLS beyond loopback")
	check(client.configure(endpoint) == OK,"explicit localhost endpoint")
	check(Client.new_idempotency_key().length() == 48,"cryptographic idempotency key")
	check(Client.new_idempotency_key() != Client.new_idempotency_key(),"independent keys")
	var anonymous: Dictionary = await client.request_api("/me",HTTPClient.METHOD_GET,{},"",true)
	check(anonymous.error == "SIGN_IN_REQUIRED","no implicit sign-in")
	var auth: Dictionary = await client.development_login("adapter_test","Adapter test","test-development-key")
	check(auth.ok and client.signed_in(),"explicit development sign-in")
	check(not auth.data.has("access_token") and not auth.data.has("refresh_token"),"sign-in result does not expose bearer credentials")
	var key: String = Client.new_idempotency_key()
	var uploaded: Dictionary = await client.upload_track("Adapter test",{"schema":"test"},key)
	check(uploaded.ok and uploaded.data.get("track_id") == "track-test","401 refresh then retry succeeds")
	check(uploaded.data.get("idempotency_key") == key,"retry keeps mutation key")
	var redirected: Dictionary = await client.request_api("/redirect",HTTPClient.METHOD_GET,{},"",true)
	check(not redirected.ok,"redirect is not followed with credentials")
	var logged_out: Dictionary = await client.logout()
	check(logged_out.ok and not client.signed_in() and client.player.is_empty(),"logout clears memory session")
	print("BACKEND_CLIENT_TESTS: %s checks, %s failures" % [checks,failures])
	client.queue_free()
	quit(1 if failures else 0)
