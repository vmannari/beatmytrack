extends SceneTree
## Actual shared files and real child processes; every API response is fictional.
const Recovery = preload("res://backend/resume_recovery.gd")
const Files = preload("res://backend/atomic_json.gd")
var workspace: String
var checks: int = 0
var failures: int = 0

class API extends Node:
	var player: Dictionary = {"id":"shared-recovery-fixture"}
	var _capabilities: Dictionary = {"resume_recovery":true}
	var session_path: String = ""
	var bodies: Array[Dictionary] = []
	var hold_directory: String = ""
	var reply: Dictionary = {"ok":true,"status":200,"data":{"state":"abandoned"},"error":""}
	func signed_in() -> bool: return true
	func base_url() -> String: return "https://shared-recovery-fixture.invalid"
	func server_now() -> int: return 1900000000
	func request_api(_path: String, _method: int, body: Dictionary, _key: String, _auth: bool) -> Dictionary:
		bodies.append(body.duplicate(true))
		if not hold_directory.is_empty():
			Files.write(hold_directory.path_join("rpc-ready.json"),{"pid":OS.get_process_id()})
			var deadline: int = Time.get_ticks_msec()+30000
			while not FileAccess.file_exists(hold_directory.path_join("release.json")) and Time.get_ticks_msec() < deadline:
				await get_tree().process_frame
		return reply.duplicate(true)

func _initialize() -> void:
	Engine.max_fps = 200
	call_deferred("run")

func check(value: bool, description: String) -> void:
	checks += 1
	if not value:
		failures += 1
		print("FAIL: ",description)

func journal() -> Dictionary:
	return {"owner":"shared-recovery-fixture","origin":"https://shared-recovery-fixture.invalid","begin_key":"shared-begin-key","consume_key":"shared-consume-key","stage":"pending","race_id":"cccccccc-cccc-cccc-cccc-cccccccccccc","ticket_id":"bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb","selection":{"ordinal":1,"input_offset":100,"from_tick":100,"to_tick":50,"recovery":"v1"}}

func adapter(api: API, name: String) -> Node:
	var recovery: Node = Recovery.new()
	recovery.client = api
	recovery.root_override = workspace.path_join(name)
	root.add_child(recovery)
	recovery.set_process(false)
	return recovery

func directory(api: API, recovery: Node) -> String:
	return recovery._directory(str(api.player.id),api.base_url())

func wait_file(path: String, timeout_msec: int = 15000) -> bool:
	var deadline: int = Time.get_ticks_msec()+timeout_msec
	while not FileAccess.file_exists(path) and Time.get_ticks_msec() < deadline: await process_frame
	return FileAccess.file_exists(path)

func wait_done(state: Dictionary) -> void:
	var deadline: int = Time.get_ticks_msec()+15000
	while not state.done and Time.get_ticks_msec() < deadline: await process_frame
	check(state.done,"waiting reconciliation releases its latch")

func finish_reconcile(recovery: Node, state: Dictionary) -> void:
	await recovery.reconcile()
	state.done = true

func spawn(role: String, root_path: String) -> int:
	return OS.create_process(OS.get_executable_path(),PackedStringArray(["--headless","--quiet","--path",ProjectSettings.globalize_path("res://"),"--script","res://tests/test_shared_resume_recovery.gd","--log-file",root_path.path_join(role+".log"),"--","--review-child="+role,"--review-root="+root_path]))

func child(role: String) -> void:
	var api := API.new()
	root.add_child(api)
	var recovery: Node = adapter(api,"profile")
	var entry: Dictionary = journal()
	entry.stage = "confirm" if role == "rpc" else "pending"
	recovery.register_race(str(entry.begin_key))
	if not recovery.save(entry): quit(2); return
	if role == "rpc":
		api.hold_directory = workspace
		api.reply = {"ok":false,"status":503,"data":{},"error":"TEMPORARY","retry_after":60}
		await recovery.reconcile()
		Files.write(workspace.path_join("rpc-finished.json"),{"pid":OS.get_process_id()})
	else:
		Files.write(workspace.path_join("owner-ready.json"),{"pid":OS.get_process_id()})
		var deadline: int = Time.get_ticks_msec()+30000
		while Time.get_ticks_msec() < deadline: await process_frame
	quit(0)

func run() -> void:
	var role: String = ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--review-child="): role = argument.trim_prefix("--review-child=")
		elif argument.begins_with("--review-root="): workspace = argument.trim_prefix("--review-root=")
	if not role.is_empty():
		await child(role)
		return
	workspace = ProjectSettings.globalize_path("res://../build/shared-recovery-"+str(OS.get_process_id())+"-"+str(Time.get_ticks_usec()))
	var api := API.new()
	var peer := API.new()
	root.add_child(api)
	root.add_child(peer)
	var owner: Node = adapter(api,"nodes")
	var observer: Node = adapter(peer,"nodes")
	owner.register_race(journal().begin_key)
	check(owner.save(journal()),"owner journal is durable")
	await observer.reconcile()
	check(peer.bodies.is_empty(),"peer adapter cannot abandon the active owner")
	observer.register_race(journal().begin_key)
	check(not observer.save(journal()),"duplicate registration cannot take ownership or charge")
	observer.leave_race(journal().begin_key)
	check(owner._race_is_active(directory(api,owner),journal().begin_key),"failed peer registration cannot remove the original lease")
	owner.leave_race(journal().begin_key)
	await observer.reconcile()
	check(peer.bodies.size() == 1 and peer.bodies[0].action == "abandon","released owner can be recovered by a peer")
	owner.free(); observer.free()
	api.bodies.clear(); peer.bodies.clear()
	owner = adapter(api,"invalid-ownership")
	var damaged_lease: String = Recovery._active_directory(directory(api,owner),journal().begin_key)
	check(Files.write(damaged_lease.path_join("owner.json"),{"pid":2147483647}),"damaged ownership fixture is preserved")
	owner.save(journal())
	await owner.reconcile()
	check(api.bodies.is_empty(),"incomplete ownership never authorizes abandonment")
	owner.free()
	owner = adapter(api,"blocked-storage")
	Files.write(owner.root_override,{"blocker":true})
	owner.register_race(journal().begin_key)
	check(not owner.save(journal()),"failed ownership storage prevents a consumption journal and charge")
	owner.free()
	api.bodies.clear(); peer.bodies.clear()
	owner = adapter(api,"cooldown")
	observer = adapter(peer,"cooldown")
	var shared: String = directory(api,owner)
	observer._ready_scope(shared)
	var entry: Dictionary = journal()
	entry.stage = "confirm"
	owner.save(entry)
	api.reply = {"ok":false,"status":503,"data":{},"error":"TEMPORARY","retry_after":60}
	await owner.reconcile()
	await observer.reconcile()
	check(api.bodies.size() == 1 and peer.bodies.is_empty(),"already-running peer reloads a changed cooldown")
	check(int(Files.read(shared.path_join(".retry.json")).retry_delay) == 60,"shared cooldown is persisted")
	owner.free(); observer.free()
	api.bodies.clear(); peer.bodies.clear()
	var actor_root: String = workspace.path_join("owner-process")
	DirAccess.make_dir_recursive_absolute(actor_root)
	var pid: int = spawn("owner",actor_root)
	check(pid > 0 and await wait_file(actor_root.path_join("owner-ready.json")),"real owner process registered its race")
	var original_workspace: String = workspace
	workspace = actor_root
	observer = adapter(peer,"profile")
	await observer.reconcile()
	check(peer.bodies.is_empty(),"real live process prevents peer abandonment")
	if pid > 0 and int(Files.read(actor_root.path_join("owner-ready.json")).get("pid",0)) == pid:
		check(OS.kill(pid) == OK,"kill only the spawned owner to reproduce a crash")
		var deadline: int = Time.get_ticks_msec()+15000
		while OS.is_process_running(pid) and Time.get_ticks_msec() < deadline: await process_frame
		check(not OS.is_process_running(pid),"spawned owner exited")
		await observer.reconcile()
		check(peer.bodies.size() == 1 and peer.bodies[0].action == "abandon","dead process recovers exactly its original operation")
	observer.free()
	peer.bodies.clear()
	workspace = original_workspace.path_join("rpc-process")
	DirAccess.make_dir_recursive_absolute(workspace)
	observer = adapter(peer,"profile")
	shared = directory(peer,observer)
	observer._ready_scope(shared)
	pid = spawn("rpc",workspace)
	check(pid > 0 and await wait_file(workspace.path_join("rpc-ready.json")),"real process holds recovery through delivery")
	observer._ready_scope(shared)
	var reservation_end: int = Time.get_ticks_msec()+5100
	while Time.get_ticks_msec() < reservation_end: await process_frame
	var state: Dictionary = {"done":false}
	finish_reconcile(observer,state)
	await process_frame
	check(not state.done and peer.bodies.is_empty(),"peer waits for the scope lock after delivery reservation expires")
	Files.write(workspace.path_join("release.json"),{})
	await wait_done(state)
	check(peer.bodies.is_empty(),"waiting peer observes the final owner cooldown instead of duplicating the RPC")
	check(int(Files.read(shared.path_join(".retry.json")).get("retry_delay",0)) == 60,"network failure wait is intact after handover")
	check(await wait_file(workspace.path_join("rpc-finished.json")),"delivery owner completed its response")
	observer.free(); api.free(); peer.free()
	print("SHARED_RESUME_RECOVERY: %d checks, %d failures"%[checks,failures])
	quit(0 if failures == 0 else 1)
