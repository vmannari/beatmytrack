extends SceneTree
const Routes = preload("res://backend/ipv4_fallback.gd")
var failures: int = 0
var checks: int = 0
var pending_response: Dictionary = {}

class DelayedRoutes extends "res://backend/ipv4_fallback.gd":
	func route(_origin: String, tree: SceneTree) -> Dictionary:
		await tree.process_frame
		await tree.process_frame
		return {}

class Fixture extends "res://backend/ipv4_fallback.gd":
	var addresses := PackedStringArray(["2001:db8::1", "192.0.2.1"])
	var reachable: bool = false
	var probes: int = 0
	func _addresses(_host: String, _tree: SceneTree) -> PackedStringArray: return addresses
	func _ipv6_reachable(_address: String, _port: int, _tree: SceneTree) -> bool:
		probes += 1
		return reachable

func _initialize() -> void: call_deferred("run")

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)

func pending_read(client: Node, authorized: bool = false) -> void:
	pending_response = await client._send("/bootstrap", HTTPClient.METHOD_GET, {}, authorized, "", PackedStringArray(), 42)

func run() -> void:
	var fixture := Fixture.new()
	var result: Dictionary = await fixture.route("https://api.example:8443/base", self)
	check(result.get("url") == "https://192.0.2.1:8443/base", "IPv4 keeps port and base path")
	check(result.get("host") == "api.example", "TLS verifies original DNS identity")
	check(result.get("authority") == "api.example:8443", "Host retains original authority")
	check((await fixture.route("https://api.example:8443/other", self)).get("url") == "https://192.0.2.1:8443/other", "Cached authority cannot substitute a different base path")
	await fixture.route("https://api.example:8443/base", self)
	check(fixture.probes == 2, "Fallback route cached")
	fixture.reachable = true
	fixture._routes["https://api.example:8443/base"].expires = 0
	check((await fixture.route("https://api.example:8443/base", self)).is_empty(), "Expired fallback recovers to IPv6")
	fixture = Fixture.new()
	fixture.addresses = PackedStringArray(["192.0.2.1"])
	check((await fixture.route("https://v4.example", self)).is_empty() and fixture.probes == 0, "IPv4-only uses normal transport")
	fixture.addresses = PackedStringArray(["2001:db8::1"])
	check((await fixture.route("https://v6.example", self)).is_empty(), "IPv6-only uses normal transport")
	check((await fixture.route("http://localhost:18181", self)).is_empty(), "Loopback unchanged")
	check((await fixture.route("https://[::1]:443", self)).is_empty(), "IPv6 literal unchanged")
	check((await fixture.route("https://127.0.0.1:443", self)).is_empty(), "IPv4 literal unchanged")
	fixture = Fixture.new()
	fixture.addresses = PackedStringArray()
	check((await fixture.route("https://missing.example", self)).is_empty(), "DNS failure uses normal transport error handling")
	var pending_client := preload("res://backend/backend_client.gd").new()
	root.add_child(pending_client)
	pending_client.configure("https://cancel.example")
	pending_client._ipv4_fallback = DelayedRoutes.new()
	pending_read(pending_client)
	pending_client.cancel_public_reads(42)
	while pending_response.is_empty(): await process_frame
	check(pending_response.error == "CANCELLED", "Cancellation during route selection prevents HTTP submission")
	check(pending_client._public_reads.is_empty(), "Cancelled route releases tracking")
	pending_response = {}
	pending_client._access_token = "local-fixture"
	pending_read(pending_client, true)
	pending_client._session_generation += 1
	while pending_response.is_empty(): await process_frame
	check(pending_response.error == "ACCOUNT_CHANGED", "Identity fence prevents stale authorization during route selection")
	check(pending_client._public_reads.is_empty(), "Identity change releases tracking")
	pending_client.queue_free()
	await process_frame
	if "--live" in OS.get_cmdline_user_args():
		var client := preload("res://backend/backend_client.gd").new()
		root.add_child(client)
		check(client.configure("https://bmt-stg-e7a444ab-api-tzgxkrwzva-ew.a.run.app") == OK, "Live client configured")
		for iteration: int in range(2):
			var response: Dictionary = await client.request_api("/bootstrap")
			check(response.ok and response.status == 200 and response.data.get("service") == "beat-my-track", "Actual backend client bootstrap " + str(iteration))
			print("LIVE_BOOTSTRAP ", iteration, " ok=", response.ok, " status=", response.status)
		var live_route: Dictionary = await client._ipv4_fallback.route(client.base_url(), self)
		check(not live_route.is_empty(), "This PC exercises actual IPv4 fallback")
		if not live_route.is_empty():
			var rejected := HTTPRequest.new()
			root.add_child(rejected)
			rejected.timeout = 5
			rejected.set_tls_options(TLSOptions.client(null, "wrong-host.example"))
			rejected.request(str(live_route.url) + "/v1/bootstrap", PackedStringArray(["Host: " + str(live_route.authority)]))
			var rejected_result: Array = await rejected.request_completed
			check(rejected_result[0] == HTTPRequest.RESULT_TLS_HANDSHAKE_ERROR and rejected_result[1] == 0, "IPv4 transport rejects mismatched TLS hostname")
			rejected.queue_free()
		client.queue_free()
		await process_frame
	print("IPV4_FALLBACK: ", checks, " checks, ", failures, " failures")
	quit(1 if failures else 0)
