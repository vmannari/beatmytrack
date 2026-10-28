extends SceneTree
## Real persistence and request boundaries; every file belongs to this fixture.
const Client = preload("res://backend/backend_client.gd")
const Cloud = preload("res://backend/cloud_tracks.gd")
var checks: int = 0
var failures: int = 0

class Service extends Client:
	var reads: int = 0
	var writes: Array[Dictionary] = []
	var accepted: Variant = null
	func signed_in() -> bool: return true
	func request_api(path: String, method: HTTPClient.Method = HTTPClient.METHOD_GET, payload: Dictionary = {}, key: String = "", _authenticated: bool = false) -> Dictionary:
		if method == HTTPClient.METHOD_GET:
			reads += 1
			return {"ok":true,"status":200,"data":{"run":accepted},"error":""}
		writes.append({"path":path,"body":payload.duplicate(true),"key":key})
		return {"ok":true,"status":202,"data":{"run_id":"new-run","ticket_id":payload.ticket_id,"status":"queued"},"error":""}

func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)

func run() -> void:
	var folder: String = "user://legacy_cleanup_"+TrackLibrary.unique_id()
	DirAccess.make_dir_recursive_absolute(folder)
	var layout: Dictionary = {"version":1,"steering_type":"buttons"}
	for key: String in ["buttons","horizontal","joystick","accelerator","brake"]:
		layout[key] = {"x":0.1,"y":0.9,"scale":1.1,"opacity":0.7}
	var pigment: Dictionary = {"version":1,"colors":{"body":"9a3e50","accent":"e4b74c"}}
	var imported: String = "a".repeat(64)
	var old: Dictionary = {"schema":1,"records":{"b".repeat(64):{"race":54.123,"flying":20.457}},
		"settings":{"control_layout":layout,"vehicle_liveries":{"compact":pigment},"favorites":["ellipse"],
		"cosmetic_legacy":["livery/flames"],"music_record":imported,"music_records":[{"id":imported,"title":"Private LP","format":"wav"}]}}
	# Use a catalogued owned pattern without depending on any entitlement API.
	old.settings.cosmetic_legacy = []
	var path: String = folder.path_join("records.json")
	var output := FileAccess.open(path,FileAccess.WRITE)
	output.store_string(JSON.stringify(old)); output.close()
	var original_hash: String = FileAccess.get_sha256(path)
	var records := LocalRecords.new(path)
	records.load_records()
	check(records.records["b".repeat(64)].race_ms == 54123,"schema-1 PB becomes exact integer milliseconds")
	check(records.settings.control_layout.version == 2 and ControlLayout.valid(records.settings.control_layout),"saved grouped controls upgrade before entering live input")
	var colors: Dictionary = VehicleLivery.for_car(records.settings,"compact").colors
	check(colors.body == pigment.colors.body and colors.accent == pigment.colors.accent,"old body/accent pigments survive the input upgrade")
	check(records.settings.music_record == "exploration" and not records.settings.has("music_records"),"retired import metadata is removed at the read boundary")
	check(FileAccess.get_sha256(path) == original_hash,"reading an old save does not rewrite the owner file")
	check(records.settings.favorites == old.settings.favorites and records.settings.cosmetic_legacy == [],"unrelated preferences and ownership snapshot survive")
	DirAccess.make_dir_absolute(path+".tmp")
	check(records.save_records() != OK and FileAccess.get_sha256(path) == original_hash,"failed atomic upgrade preserves the exact source save")
	DirAccess.remove_absolute(path+".tmp")
	check(records.save_records() == OK,"upgraded data commits through the existing atomic writer")
	check(FileAccess.get_sha256(path+".bak") == original_hash,"first upgraded commit keeps the old bytes as a recoverable backup")
	var restored := LocalRecords.new(path)
	restored.load_records()
	check(restored.records == records.records and JSON.parse_string(JSON.stringify(restored.settings)) == JSON.parse_string(JSON.stringify(records.settings)),"current save reloads without another semantic conversion")
	check(not ControlLayout.valid(layout) and not VehicleLivery.valid(pigment),"live domain validators reject old versions")
	var malformed: Dictionary = old.duplicate(true)
	malformed.settings.control_layout.buttons.x = NAN
	check(LocalRecords._normalize(malformed).is_empty(),"corrupt migration input cannot become valid defaults")
	malformed = old.duplicate(true); malformed.records["b".repeat(64)].race = -1
	check(LocalRecords._normalize(malformed).is_empty(),"invalid historical PBs are rejected")
	var client := Service.new()
	root.add_child(client)
	client.configure("http://127.0.0.1:1")
	client.player = {"id":"fixture-owner"}
	client._capabilities = {"discovery_paging_version":2}
	var rejected: Dictionary = await client.request_discovery({"search":"course"},1)
	check(rejected.status == 426 and client.writes.is_empty(),"discovery v2 cannot start an older protocol request")
	var proof: Dictionary = {"schema":"bmt-race-proof-v1","samples":[[0,0,0,0,0,0,0,0],[12,1,2,0,0,0,0,0]]}
	var packet: Dictionary = Client._pack_trajectory(12,proof,[])
	check(packet.schema == "bmt-trajectory-v1" and packet.race_proof.samples == [[0,0,0,0],[12,1,2,0]],"current upload normalizes only bounded movement evidence")
	check(Client._pack_trajectory(216001,proof,[]).is_empty(),"the monotonic input bound remains enforced")
	check(Client._pack_trajectory(12,proof,[{"receipt_id":"x","input_offset":0.5,"from_tick":12,"to_tick":0}]).is_empty(),"fractional recovered rewind fields are rejected")
	rejected = await client.submit_run("ticket",[[0,0,0]],"operation",[],proof)
	check(rejected.error == "SUBMISSION_SERVER_UPDATE_REQUIRED" and client.writes.is_empty(),"old server capabilities cannot select a frame upload fallback")
	client._capabilities = {"trajectory_verification":true,"submission_recovery_version":1}
	await client.submit_run("ticket",[[0,0,0]],"operation",[],proof)
	check(client.writes.size() == 1 and client.writes[0].body.replay.schema == "bmt-trajectory-v1" and not client.writes[0].body.replay.has("frames"),"new submissions use only trajectory transport")
	var cloud := Cloud.new()
	cloud.client = client; cloud.root_override = folder.path_join("cloud")
	root.add_child(cloud)
	var job: Dictionary = {"ticket":"previous-ticket","key":"original-key","replay":"must-not-be-opened.json"}
	client.accepted = {"run_id":"accepted-run","ticket_id":"previous-ticket","status":"queued"}
	var before: int = client.writes.size()
	var recovered: Dictionary = await cloud._submit_saved(job,folder.path_join("previous.job.json"))
	check(recovered.ok and recovered.data.run_id == "accepted-run" and client.writes.size() == before,"lost pre-update reply is recovered without opening or reencoding its replay")
	check(job.key == "original-key" and not job.has("submission_schema"),"accepted historical recovery preserves its original operation identity")
	check(Client.valid_response("/run-tickets/previous-ticket/submission",HTTPClient.METHOD_GET,{"run":client.accepted}),"submission lookup validates its ticket binding")
	check(not Client.valid_response("/run-tickets/different-ticket/submission",HTTPClient.METHOD_GET,{"run":client.accepted}),"another ticket's result cannot satisfy the lookup")
	cloud.queue_free(); client.queue_free()
	await process_frame
	print("LEGACY_CLEANUP: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
