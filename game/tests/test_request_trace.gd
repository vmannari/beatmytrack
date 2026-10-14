extends SceneTree
const Client = preload("res://backend/backend_client.gd")
const ID: String = "6ba7b810-9dad-41d1-80b4-00c04fd430c8"
var checks: int = 0
var failures: int = 0
func _initialize() -> void: run.call_deferred()
func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures += 1; print("FAIL: "+message)
func run() -> void:
	create_timer(40).timeout.connect(func() -> void: print("FAIL: trace fixture timeout"); quit(1))
	var client: Node = Client.new()
	root.add_child(client)
	check(client.configure(OS.get_environment("BMT_TRACE_TEST_URL")) == OK,"owned loopback fixture configured")
	var response: Dictionary = await client.request_api("/trace-ok")
	check(response.ok and response.get("request_id") == ID,"successful HTTP request preserves normalized request ID without telemetry")
	response = await client.request_api("/trace-error")
	check(response.status == 429 and response.get("request_id") == ID,"server rejection remains correlated")
	check(int(response.get("retry_after",0)) > 0 and int(response.get("retry_after",0)) <= 75,"actual HTTP-date Retry-After supplies a usable cooldown")
	response = await client.request_api("/trace-invalid")
	check(response.error == "INVALID_RESPONSE" and response.get("request_id") == ID,"invalid JSON response retains its header correlation")
	response = await client.request_api("/trace-cached")
	check(response.ok and response.get("request_id") == ID,"initial cacheable request is correlated")
	response = await client.request_api("/trace-cached")
	check(response.ok and response.get("not_modified",false) and response.get("request_id") == ID,"304 cache reuse retains the current request's ID")
	response = await client.request_api("/trace-bad-id")
	check(response.ok and not response.has("request_id"),"untrusted non-UUID header never reaches diagnostics")
	response = client._checked({"ok":true,"data":{},"request_id":ID},"/me",HTTPClient.METHOD_GET)
	check(response.error == "INVALID_RESPONSE" and response.get("request_id") == ID,"schema-validation failure retains correlation")
	response = client._checked({"ok":true,"data":{},"request_id":"private-header"},"/me",HTTPClient.METHOD_GET)
	check(not response.has("request_id"),"schema-validation failure rejects unsafe correlation values")
	var cancelled: Array[Dictionary] = []
	collect_cancelled(client,cancelled)
	await create_timer(0.03).timeout
	client.cancel_public_reads(91)
	while cancelled.is_empty(): await process_frame
	check(cancelled[0].error == "CANCELLED","owner cancellation finishes its own request")
	await process_frame # Deferred node release must settle before reuse.
	response = await client.request_public("/trace-fresh",92)
	check(response.ok and response.data.get("value") == "fresh-request","request node can serve a new owner after cancellation")
	await create_timer(0.4).timeout
	response = await client.request_public("/trace-fresh",92)
	check(response.ok and response.data.get("value") == "fresh-request" and cancelled.size() == 1,"old socket completion cannot satisfy or repeat a newer request")
	client.queue_free()
	await process_frame
	print("REQUEST_TRACE: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func collect_cancelled(client: Node, values: Array[Dictionary]) -> void:
	values.append(await client.request_public("/trace-slow",91))
