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

func run() -> void:
	var client := CLIENT.new()
	root.add_child(client)
	check(client.configure(OS.get_environment("BMT_API_URL")) == OK,"configure disposable backend")
	client.recording_cache_directory = OS.get_environment("BMT_NATIVE_COST_CACHE")
	var capabilities: Dictionary = await client.request_api("/bootstrap",HTTPClient.METHOD_GET,{},"",false)
	check(capabilities.get("ok",false) and int(client._capabilities.get("ghost_wire_version",0)) == 1,"server advertises lossless recording protocol")
	var login: Dictionary = await client.developer_login(OS.get_environment("BMT_DEV_AUTH_KEY"))
	check(login.get("ok",false),"authenticate current account")
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("BMT_GHOST_WIRE_FIXTURE")))
	var path: String = "/challenges/AAAAAAAAAAAAAAAA/ghost"
	var first: Dictionary = await client.fetch_recording(path,true)
	check(first == fixture.original,"real HTTP packed recording preserves every numeric sample")
	check(client.recording_downloads == 1,"first read downloads one recording")
	var second: Dictionary = await client.fetch_recording(path,true)
	check(second == first and client.recording_cache_hits == 1 and client.recording_downloads == 1,"real HTTP repeat downloads metadata only")
	var disable: Dictionary = await client.request_api("/cost-fixture/disable",HTTPClient.METHOD_POST,{},client.new_operation_key(),true)
	check(disable.get("ok",false),"withdraw source through disposable test fixture")
	check((await client.fetch_recording(path,true)).is_empty(),"warm cache respects current revoked access")
	client.queue_free()
	await process_frame
	print("Cost HTTP: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
