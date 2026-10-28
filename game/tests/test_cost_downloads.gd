extends SceneTree
var checks: int = 0
var failures: int = 0
var directory: String = ""
const CACHE = preload("res://backend/recording_cache.gd")
const PREVIEWS = preload("res://backend/preview_dictionary.gd")
var completed: Array = []
var reads: Array = []

class ReadTransport extends "res://backend/backend_client.gd":
	var calls: int = 0
	var change_account: bool = false
	func _ready() -> void: pass
	func _send(_path: String, _method: HTTPClient.Method, _payload: Dictionary, _authorized: bool, _key: String = "", _headers: PackedStringArray = [], _owner: int = 0) -> Dictionary:
		calls += 1
		await get_tree().process_frame
		await get_tree().process_frame
		if change_account:
			player = {"id":"changed"}
			_session_generation += 1
		return {"ok":true,"status":200,"data":{"value":[1,2,3]}}

class Transport extends "res://backend/backend_client.gd":
	var metadata_calls: int = 0
	var body_calls: int = 0
	var denied: bool = false
	var target: String = "first-run"
	var recording_hash: String = "a".repeat(64)
	var switch_identity: bool = false
	var value: Dictionary = {"ticks":120,"poses":[[0,0.125,-0.5,0.0,1.0,0.0,0.0],[120,2.0,3.0,0.0,1.5,0.0,0.0]]}
	func _ready() -> void: pass
	func request_api(path: String, _method: HTTPClient.Method = HTTPClient.METHOD_GET, _payload: Dictionary = {}, _key: String = "", _authenticated: bool = true) -> Dictionary:
		await get_tree().process_frame
		if denied: return {"ok":false,"status":404,"error":"unavailable"}
		var metadata: bool = "metadata=true" in path
		if metadata: metadata_calls += 1
		else: body_calls += 1
		if switch_identity:
			player = {"id":"other-account"}
			_session_generation += 1
		return {"ok":true,"data":{"run_id":target,"content_hash":recording_hash,"player_id":"rival","recording":{} if metadata else value.duplicate(true)}}
	func _background(work: Callable) -> Variant:
		await get_tree().process_frame
		return work.call()

func _initialize() -> void: call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: "+message)

func client() -> Transport:
	var value := Transport.new()
	value._base_url = "http://cost-fixture"
	value.player = {"id":"account"}
	value._capabilities = {"ghost_identity_version":1}
	value.recording_cache_directory = directory
	root.add_child(value)
	return value

func simultaneous(value: Transport) -> void:
	completed.append(await value.fetch_recording("/challenges/shared/ghost",false))

func simultaneous_read(value: ReadTransport) -> void:
	reads.append(await value.request_api("/fixture",HTTPClient.METHOD_GET))

func run() -> void:
	directory = OS.get_environment("BMT_COST_TEST_DIR").path_join("recordings-"+TrackLibrary.unique_id())
	var read := ReadTransport.new()
	root.add_child(read)
	simultaneous_read.call_deferred(read)
	simultaneous_read.call_deferred(read)
	while reads.size() < 2: await process_frame
	check(read.calls == 1 and reads[0].ok and reads[1].ok,"duplicate ordinary GET consumers share one transport call")
	reads[0].data.value[0] = 99
	check(reads[1].data.value[0] == 1,"coalesced readers own independent response dictionaries")
	reads.clear()
	read.change_account = true
	simultaneous_read.call_deferred(read)
	simultaneous_read.call_deferred(read)
	while reads.size() < 2: await process_frame
	check(not reads[0].ok and not reads[1].ok,"coalesced GET late responses respect account switches")
	var a: Transport = client()
	var first: Dictionary = await a.fetch_recording("/rivalry/group/tracks/0/ghosts/rival")
	check(first == a.value and a.body_calls == 1 and a.metadata_calls == 1,"cold recording downloads after metadata")
	var again: Dictionary = await a.fetch_recording("/rivalry/group/tracks/0/ghosts/rival")
	check(again == first and a.body_calls == 1 and a.metadata_calls == 2,"repeat rechecks access without downloading recording")
	var restarted: Transport = client()
	check(await restarted.fetch_recording("/challenges/new/ghost",false) == first,"recording is reused across modes and adapter restart")
	check(restarted.body_calls == 0 and restarted.recording_cache_hits == 1,"restart uses durable recording bytes")
	restarted.denied = true
	check((await restarted.fetch_recording("/challenges/new/ghost",false)).is_empty(),"withdrawn recording is not reused")
	restarted.denied = false
	restarted.target = "second-run"
	restarted.recording_hash = "b".repeat(64)
	restarted.value.poses[1][1] = 6.25
	check(await restarted.fetch_recording("/challenges/new/ghost",false) == restarted.value,"changed target downloads new immutable content")
	check(restarted.body_calls == 1,"exactly one body for changed target")
	check((await restarted.fetch_recording("/rivalry/group/tracks/0/ghosts/rival",true,"old-model-run")).is_empty(),"changed Rivalry target is never cached under an old model run ID")
	restarted.switch_identity = true
	check((await restarted.fetch_recording("/challenges/new/ghost",false)).is_empty(),"late old-account response cannot enter new account")
	var concurrent: Transport = client()
	concurrent.target = "shared-run"
	concurrent.recording_hash = "c".repeat(64)
	simultaneous.call_deferred(concurrent)
	simultaneous.call_deferred(concurrent)
	while completed.size() < 2: await process_frame
	check(completed[0] == concurrent.value and completed[1] == concurrent.value,"simultaneous consumers receive the same recording")
	check(concurrent.metadata_calls == 1 and concurrent.body_calls == 1,"simultaneous consumers share metadata and body fetch")
	var legacy: Transport = client()
	legacy._capabilities = {}
	check(await legacy.fetch_recording("/challenges/legacy/ghost",false) == legacy.value,"older servers retain their ordinary recording path")
	check(legacy.metadata_calls == 0 and legacy.body_calls == 1,"no unsupported metadata request to old server")
	check(CACHE.read(directory,"other-scope","shared-run/"+"c".repeat(64)).is_empty(),"disk recordings do not cross account scope")
	var damaged: Dictionary = {"ticks":120,"poses":[[0,0,0,0,0,0,0],[120,INF,0,0,0,0,0]]}
	check(CACHE.valid(damaged).is_empty(),"nonfinite presentation data rejected")
	var cache_path: String = CACHE._path(directory,"http://cost-fixture/account","shared-run/"+"c".repeat(64))
	var file := FileAccess.open(cache_path,FileAccess.WRITE)
	file.store_string("corrupt")
	file.close()
	check(await concurrent.fetch_recording("/challenges/shared/ghost",false) == concurrent.value,"corrupt cache falls back to download")
	check(concurrent.body_calls == 2,"corrupt cache redownloads once")
	for index: int in range(70):
		check(CACHE.write(directory,"budget",str(index),first),"bounded cache write "+str(index))
	var ghost_files: int = 0
	for name: String in DirAccess.get_files_at(directory):
		if name.ends_with(".ghost"): ghost_files += 1
	check(ghost_files <= CACHE.MAX_FILES,"disk cache file count remains bounded")
	var previews := PREVIEWS.new()
	previews.configure(directory.path_join("previews"),"private-scope")
	var hash: String = "d".repeat(64)
	var page: Dictionary = {"items":[{"preview_hash":hash,"points":[[0,0],[4,5]]}]}
	check(previews.restore(page) and hash in previews.known(),"full preview enters reusable dictionary")
	var compact: Dictionary = {"items":[{"preview_hash":hash,"rating_count":5}]}
	check(previews.restore(compact) and compact.items[0].points == [[0,0],[4,5]] and compact.items[0].rating_count == 5,"compact preview preserves fresh volatile fields")
	check(not previews.restore({"items":[{"preview_hash":"e".repeat(64)}]}),"missing preview requests full fallback")
	var bundled: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://resources/cloud_tracks/index.json"))
	check(bundled is Dictionary and bundled.documents.size() == 26,"trusted bundled catalogue excludes the retired Starter Circuit")
	for identity: String in bundled.documents:
		var document: Dictionary = preload("res://backend/cloud_tracks.gd").cached_document({"cache_path":directory.path_join("absent.json"),"content_hash":identity})
		check(not document.is_empty(),"bundled exact-hash document is valid "+identity)
	check(preload("res://backend/bundled_tracks.gd").path("wrong").is_empty(),"invalid content hash cannot select bundled content")
	var wire_fixture: String = OS.get_environment("BMT_GHOST_WIRE_FIXTURE")
	if not wire_fixture.is_empty():
		var wire: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(wire_fixture))
		var decoded: Dictionary = preload("res://backend/ghost_wire.gd").decode(wire.packed)
		check(decoded == wire.original,"packed wire preserves every exact numeric pose and duration")
		var malformed: Dictionary = wire.packed.duplicate(true)
		malformed.count = int(malformed.count)+1
		check(preload("res://backend/ghost_wire.gd").decode(malformed).is_empty(),"packed wire rejects truncated sample arrays")
	while not preload("res://backend/menu_snapshot_writer.gd").idle(): await process_frame
	for value: Node in [a,restarted,concurrent,legacy,read]: value.queue_free()
	await process_frame
	print("Cost downloads: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
