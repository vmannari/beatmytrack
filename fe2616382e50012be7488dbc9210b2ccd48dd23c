extends SceneTree
var checks: int = 0
var failures: int = 0
const CLIENT = preload("res://backend/backend_client.gd")

func _initialize() -> void: call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: "+message)

func configure_client() -> Node:
	var client := CLIENT.new()
	root.add_child(client)
	check(client.configure(OS.get_environment("BMT_API_URL")) == OK,"configure disposable backend")
	client.recording_cache_directory = OS.get_environment("BMT_NATIVE_COST_CACHE")
	var capabilities: Dictionary = await client.request_api("/bootstrap",HTTPClient.METHOD_GET,{},"",false)
	check(capabilities.get("ok",false) and int(client._capabilities.get("ghost_wire_version",0)) == 1,"current lossless recording capability")
	var login: Dictionary = await client.developer_login(OS.get_environment("BMT_DEV_AUTH_KEY"))
	check(login.get("ok",false),"authenticate invented local account")
	return client

func run() -> void:
	var client: Node = await configure_client()
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("BMT_GHOST_WIRE_FIXTURE")))
	var path: String = "/challenges/AAAAAAAAAAAAAAAA/ghost"
	for index: int in range(10):
		var recording: Dictionary = await client.fetch_recording(path,true)
		check(recording == fixture.original,"every Float64 sample remains exact on access "+str(index+1))
	check(client.recording_downloads == 1 and client.recording_cache_hits == 9,"ten accesses download one body and reuse nine")
	var fresh: Node = await configure_client()
	var restored: Dictionary = await fresh.fetch_recording(path,true)
	check(restored == fixture.original,"a fresh client recovers exact persistent cached recording")
	check(fresh.recording_downloads == 0 and fresh.recording_cache_hits == 1,"fresh client needs no recording body")
	fresh.queue_free()
	var disable: Dictionary = await client.request_api("/cost-fixture/disable",HTTPClient.METHOD_POST,{},client.new_operation_key(),true)
	check(disable.get("ok",false),"withdraw source in local fixture")
	check((await client.fetch_recording(path,true)).is_empty(),"warm cache obeys current source withdrawal")
	client.queue_free()
	await process_frame
	print("Local cost native: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
