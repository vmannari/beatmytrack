extends SceneTree
## Opt-in live staging diagnostic. No player/session/PB writes or saved tokens.
var checks: int = 0
var failures: int = 0
var client: Node

func _initialize() -> void:
	run.call_deferred()

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)

func run() -> void:
	var url: String = OS.get_environment("BMT_STAGING_API_URL")
	if not url.begins_with("https://bmt-stg-") or not url.ends_with(".run.app"):
		push_error("Set BMT_STAGING_API_URL to the owned disposable Cloud Run staging origin.")
		quit(1)
		return
	client = preload("res://backend/backend_client.gd").new()
	root.add_child(client)
	check(client.valid_response("/auth/google/browser/cancel", HTTPClient.METHOD_POST, {}), "empty browser cancellation contract accepted")
	check(not client.valid_response("/auth/google/browser/cancel", HTTPClient.METHOD_POST, {"access_token":"invalid"}), "malformed browser cancellation rejected")
	check(not client.valid_response("/auth/google/browser/cancel", HTTPClient.METHOD_GET, {}), "cancellation requires POST")
	check(client.configure(url) == OK, "staging URL accepted")
	for path: String in ["/health", "/ready"]:
		var request := HTTPRequest.new()
		root.add_child(request)
		request.timeout = 30.0
		var started: Error = request.request(url + path)
		check(started == OK, "health request starts")
		if started == OK:
			var response: Array = await request.request_completed
			check(int(response[0]) == HTTPRequest.RESULT_SUCCESS and int(response[1]) == 200, "TLS health check succeeds: " + path)
		request.queue_free()
	var bootstrap: Dictionary = await client.request_api("/bootstrap")
	check(bool(bootstrap.ok), "real game HTTPS bootstrap succeeds")
	if not bootstrap.ok:
		print("Cloud staging: %d checks, %d failures; bootstrap error %s" % [checks, failures, str(bootstrap.get("error", "unknown"))])
		quit(1)
		return
	check(bootstrap.data.service == "beat-my-track" and bootstrap.data.api_version == "v1", "correct cloud service")
	check(bootstrap.data.development_auth == false and bootstrap.data.test_drivers == false, "development bypasses disabled")
	check(bootstrap.data.google_configured == true and bootstrap.data.google_browser_configured == true, "real Google audiences configured")
	var catalog: Dictionary = await client.request_api("/tracks")
	check(bool(catalog.ok), "guest discovery succeeds")
	var me: Dictionary = await client.request_api("/me")
	check(not bool(me.ok) and int(me.get("status", 0)) == 401, "private profile requires real authentication")
	var developer: Dictionary = await client.developer_login("staging-diagnostic-invalid-key")
	check(not bool(developer.ok) and int(developer.get("status", 0)) == 404, "development login rejected")
	var started: Dictionary = await client.request_api("/auth/google/browser/start", HTTPClient.METHOD_POST)
	check(bool(started.ok), "Google browser handoff starts")
	if started.ok:
		var browser_url: String = str(started.data.browser_url)
		check(browser_url.begins_with(url + "/v1/auth/google/browser#"), "handoff uses the actual cloud origin")
		var prepared: Dictionary = await client.request_api("/auth/google/browser/prepare", HTTPClient.METHOD_POST, {"token":browser_url.get_slice("#", 1)})
		check(bool(prepared.ok), "browser receives its challenge")
		var pending: Dictionary = await client.request_api("/auth/google/browser/poll", HTTPClient.METHOD_POST, {"token":started.data.poll_token})
		check(bool(pending.ok) and str(pending.data.get("status", "")) == "pending", "handoff remains pending without Google proof")
		var cancelled: Dictionary = await client.request_api("/auth/google/browser/cancel", HTTPClient.METHOD_POST, {"token":started.data.poll_token})
		check(bool(cancelled.ok), "unused handoff is cancelled")
	check(not client.signed_in(), "diagnostic never creates a player session")
	print("Cloud staging: %d checks, %d failures" % [checks, failures])
	client.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
