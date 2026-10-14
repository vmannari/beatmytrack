extends SceneTree
## Disposable files and fictional network results; the Windows vault uses real DPAPI.
const Client = preload("res://backend/backend_client.gd")
const Cloud = preload("res://backend/cloud_tracks.gd")
var checks: int = 0
var failures: int = 0
var folder: String

class FakeClient extends Client:
	var uploads: Array[Dictionary] = []
	var received_logout: Dictionary = {}
	var reject: bool = true
	func _send(path: String, _method: HTTPClient.Method, body: Dictionary, _authorized: bool, _key: String = "", _headers: PackedStringArray = [], _owner: int = 0) -> Dictionary:
		if path == "/auth/logout":
			received_logout = body.duplicate(true)
			return {"ok":true,"status":204,"data":{},"error":""}
		return _failure("UNEXPECTED_REQUEST")
	func request_api(path: String, _method: HTTPClient.Method = HTTPClient.METHOD_GET, body: Dictionary = {}, key: String = "", _authorized: bool = false) -> Dictionary:
		if path == "/publications":
			uploads.append({"key":key,"body":body.duplicate(true)})
			return {"ok":false,"status":429,"error":"RATE_LIMITED","data":{},"retry_after":120} if reject else {"ok":true,"status":202,"error":"","data":{"publication_id":"publication-"+key,"state":"queued"}}
		return _failure("UNEXPECTED_REQUEST")

func _initialize() -> void: run.call_deferred()
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		print("FAIL: "+message)

func make_client(url: String = "http://127.0.0.1:1") -> FakeClient:
	var client := FakeClient.new()
	root.add_child(client)
	client.configure(url)
	client.player = {"id":"medium-fixture-owner"}
	client._access_token = "fixture-access-"+"a".repeat(43)
	client._refresh_token = "fixture-refresh-"+"b".repeat(43)
	return client

func controller(client: FakeClient) -> TrackLifecycle:
	var cloud := Cloud.new()
	cloud.client = client
	cloud.root_override = folder.path_join("cloud")
	root.add_child(cloud)
	var flow := TrackLifecycle.new()
	flow.cloud = cloud
	flow.library = TrackLibrary.new(folder.path_join("drafts"))
	root.add_child(flow)
	return flow

func run() -> void:
	create_timer(30).timeout.connect(func() -> void: print("FAIL: medium communication deadline"); quit(1))
	folder = ProjectSettings.globalize_path("res://../build/medium-communication-native-"+str(Time.get_ticks_usec()))
	DirAccess.make_dir_recursive_absolute(folder)
	var client: FakeClient = make_client()
	client.session_path = folder.path_join("session.cfg")
	check(client.session_vault.available(),"platform vault is available for persistence")
	var refresh: String = client._refresh_token
	var access: String = client._access_token
	client._save_session()
	var protected: String = FileAccess.get_file_as_string(client.session_path)
	check(not client.persistence_error and protected.begins_with("BMT-SESSION-1\n"),"new session is stored in a protected envelope")
	check(not access in protected and not refresh in protected,"disk envelope contains neither credential in plaintext")
	var config := ConfigFile.new()
	check(client._load_saved_config(config) == OK and config.get_value("session","refresh_token") == refresh,"protected credentials round-trip through the actual platform")
	var changed := make_client("http://127.0.0.1:2")
	changed.session_path = client.session_path
	check(FileAccess.file_exists(client.session_path) and changed._load_saved_config(ConfigFile.new()) != OK,"different backend context cannot open existing credentials")
	check(client.session_vault.open(protected,client._vault_context()+"other-profile").is_empty(),"different profile context cannot open the same envelope")
	var cipher: PackedByteArray = Marshalls.base64_to_raw(protected.trim_prefix("BMT-SESSION-1\n"))
	cipher[cipher.size()/2] = cipher[cipher.size()/2] ^ 1
	check(client.session_vault.open("BMT-SESSION-1\n"+Marshalls.raw_to_base64(cipher),client._vault_context()).is_empty(),"tampering is rejected before credentials are parsed")
	# Legacy files are deliberately created only within this disposable fixture.
	config.save(client.session_path)
	check(client._load_saved_config(ConfigFile.new(),true) == OK,"legacy session migrates without changing its credentials")
	check(FileAccess.get_file_as_string(client.session_path).begins_with("BMT-SESSION-1\n"),"migration atomically replaces the plaintext file")
	var response: Dictionary = await client.logout()
	check(response.ok and client.received_logout.get("refresh_token") == refresh,"logout captures refresh possession before clearing memory")
	check(not client.signed_in() and not client.has_saved_session(),"logout clears credentials and fences saved sessions")
	var unsupported := make_client()
	unsupported.session_path = folder.path_join("unavailable.cfg")
	unsupported.session_vault.adapter = null
	unsupported._save_session()
	check(unsupported.persistence_error and not unsupported.has_saved_session() and unsupported.signed_in(),"unavailable platform protection permits only in-memory authentication")
	var no_access := make_client()
	no_access._access_token = ""
	response = await no_access.logout()
	check(response.ok and no_access.received_logout.has("refresh_token"),"logout revokes with a refresh credential alone")
	var pool: Node = Client.new()
	root.add_child(pool)
	var first: HTTPRequest = pool._take_request()
	var second: HTTPRequest = pool._take_request()
	check(first != second,"active requests never share a node")
	first.set_meta("cancelled",true)
	first.set_meta("owner_id",17)
	pool._release_request(first)
	var reused: HTTPRequest = pool._take_request()
	check(reused == first and not reused.get_meta("cancelled") and reused.get_meta("owner_id") == 0,"node reuse clears the previous owner's cancellation state")
	pool._release_request(reused); pool._release_request(second)
	var nodes: Array[HTTPRequest] = []
	for _index: int in range(8): nodes.append(pool._take_request())
	for node: HTTPRequest in nodes: pool._release_request(node)
	check(pool._idle_requests.size() == 4,"idle request nodes remain bounded")
	client = make_client()
	var flow: TrackLifecycle = controller(client)
	var base: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://../backend/tests/fixtures/verified_oval.json")).document
	var paths: Array[String] = []
	var proof_hashes: Array[String] = []
	var proof := {"input_count":3,"race_proof":{"schema":"bmt-race-proof-v1","samples":[[0,0,0,0,0,0,0,0],[3,0,0,0,0,0,0,0]]}}
	for index: int in range(3):
		var document: Dictionary = base.duplicate(true)
		document.id = TrackLibrary.unique_id()
		var path: String = flow._root().path_join(str(index)+".job.json")
		paths.append(path)
		flow.cloud._write(flow._root().path_join(str(index)+".proof.json"),proof)
		proof_hashes.append(FileAccess.get_file_as_bytes(flow._root().path_join(str(index)+".proof.json")).hex_encode().sha256_text())
		var job := {"schema":"track-lifecycle-1","scope":flow.scope(),"library_directory":flow.library.directory,"fingerprint":str(index),"upload_key":"operation-"+str(index),"publish_key":"publish-"+str(index),"ticket_key":"ticket-"+str(index),"state":"ready","created_at":index,"document":document,"vehicle":"compact","contract":{},"proof_file":str(index)+".proof.json","publish_requested":true,"publish_workflow":2}
		check(flow._save(path,job),"disposable publication job saved")
	await flow.process_jobs()
	check(client.uploads.size() == 1,"first 429 stops remaining publication POSTs")
	await flow.process_jobs()
	check(client.uploads.size() == 1,"subsequent idle processing observes the shared cooldown")
	var restart: TrackLifecycle = controller(client)
	await restart.process_jobs()
	check(client.uploads.size() == 1,"publication scope cooldown survives controller restart")
	check(restart.jobs().size() == 3 and paths.all(func(path: String) -> bool: return FileAccess.file_exists(path)),"all jobs and their permanent keys survive rate limiting")
	for index: int in range(3): check(FileAccess.get_file_as_bytes(flow._root().path_join(str(index)+".proof.json")).hex_encode().sha256_text() == proof_hashes[index],"rate limiting preserves exact creator evidence bytes")
	var other := make_client()
	other.player = {"id":"other-fixture-owner"}
	check(controller(other)._batch_ready(),"another account has an independent publication budget")
	var isolated: TrackLifecycle = controller(other)
	isolated._pause_batch({"status":429,"retry_after":90})
	var wait_path: String = isolated._wait_root().path_join(DirAccess.get_files_at(isolated._wait_root())[0])
	check(DirAccess.rename_absolute(wait_path,wait_path+".tmp") == OK,"disposable interrupted retry replacement prepared")
	check(not controller(other)._batch_ready(),"interrupted retry replacement survives restart")
	var corrupt := FileAccess.open(wait_path+".tmp",FileAccess.WRITE)
	corrupt.store_string(JSON.stringify({"schema":"publication-retry-1","scope":isolated.scope()})); corrupt.close()
	check(not controller(other)._batch_ready(),"incomplete retry metadata cannot erase an unknown cooldown")
	# Advance only disposable monotonic deadlines; don't wait a real two minutes.
	for deadline: String in restart._batch_deadlines: restart._batch_deadlines[deadline] = 0
	for job: Dictionary in restart.jobs(): restart._retry_deadlines[str(job.upload_key)] = 0
	client.reject = false
	await restart.process_jobs()
	check(client.uploads.size() == 4 and client.uploads[0] == client.uploads[1],"eligible retry sends the exact first package/key, then processes untouched jobs")
	for child: Node in root.get_children():
		if child != root.get_node_or_null("AudioWorld"): child.queue_free()
	await process_frame
	print("MEDIUM_COMMUNICATION: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
