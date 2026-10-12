extends SceneTree
var failures: int = 0
var checks: int = 0

class FakeClient extends "res://backend/backend_client.gd":
	var received_name: String = "unexpected"
	var submitted: bool = false
	func request_api(_path: String, _method: HTTPClient.Method = HTTPClient.METHOD_GET, _payload: Dictionary = {}, _key: String = "", _authorized: bool = false) -> Dictionary:
		return {"ok":true,"data":{"service":"beat-my-track","api_version":"v1"}}
	func google_challenge() -> Dictionary:
		return {"ok":true,"data":{"challenge_id":"challenge","nonce":"server-nonce","client_id":"web-client"}}
	func google_login(token: String, challenge: String, name: String = "Racer") -> Dictionary:
		submitted = token == "fixture-token" and challenge == "challenge"
		received_name = name
		player = {"display_name":"Saved racer","needs_username":false}
		return {"ok":true}

class FakeNative extends RefCounted:
	var response: String = "token:fixture-token"
	var received: bool = false
	var cancelled: bool = false
	func startSignIn(client_id: String, nonce: String) -> void:
		received = client_id == "web-client" and nonce == "server-nonce"
	func takeResult() -> String: return response
	func cancelSignIn() -> void: cancelled = true

class Controller extends "res://backend/account_controller.gd":
	var native: Object
	func _google_native_plugin() -> Object: return native

func _initialize() -> void: run.call_deferred()
func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		print("FAIL: " + label)
func run() -> void:
	for response: String in ["token:fixture-token", "error:cancelled", "error:unavailable", ""]:
		var controller := Controller.new()
		controller.client.free()
		controller.client = FakeClient.new()
		var native := FakeNative.new()
		native.response = response
		controller.native = null if response.is_empty() else native
		controller.open_browser = func(_url: String) -> Error:
			check(false, "native path never opens a browser")
			return FAILED
		root.add_child(controller)
		await controller._sign_in_google_native()
		check(not controller.busy and not controller.waiting_for_google, "native flow clears busy state")
		if response.begins_with("token:"):
			check(native.received, "native picker receives pinned client and server nonce")
			check(controller.client.submitted, "token goes to server with its challenge")
			check(controller.client.received_name.is_empty(), "new accounts use racing-name onboarding")
		else:
			check(not controller.client.submitted, "cancel/missing/failed picker never submits identity")
		if response == "error:cancelled": check(controller.message == "Sign-in cancelled.", "picker cancellation clears status")
		controller.queue_free()
		await process_frame
	print("NATIVE_GOOGLE_TESTS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
