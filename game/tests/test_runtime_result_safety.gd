extends SceneTree
const Cloud = preload("res://backend/cloud_tracks.gd")
const Inputs = preload("res://race/input_record.gd")
const Queue = preload("res://backend/result_save_queue.gd")
var checks: int = 0
var failures: int = 0
var metrics: Dictionary = {}
static func slow_work(value: int) -> int:
	OS.delay_msec(20)
	return value
func background(client: Node, value: int, results: Array) -> void:
	results.append(await client._background(slow_work.bind(value)))
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; print("FAIL: ",label)

func run() -> void:
	var folder: String = "user://result-safety-"+TrackLibrary.unique_id()
	var owner: String = "fixture-owner"
	var directory: String = folder.path_join("players").path_join(owner.sha256_text()).path_join("runs")
	var inputs := PackedInt64Array()
	var frame := DriveFrame.new()
	for index: int in range(216000):
		frame.steer = index%255-127; frame.throttle = index%256
		frame.brake = (index*3)%256; frame.handbrake = (index*7)%256
		frame.launch_start = 2 if index == 0 else 0
		inputs.append(Inputs.pack(frame))
		if index%997 == 0: check(Inputs.unpack(inputs[-1],index)==frame.packed(),"packed channels "+str(index))
	metrics.input_bytes = inputs.to_byte_array().size()
	check(metrics.input_bytes==1728000,"maximum recording is exactly 8 bytes per input")
	var rewinds: Array = [{"receipt_id":"one","input_offset":1000,"from_tick":1000,"to_tick":500},{"receipt_id":"two","input_offset":2000,"from_tick":1500,"to_tick":1000},{"receipt_id":"three","input_offset":3000,"from_tick":2000,"to_tick":1500}]
	for phase: String in ["manifest","no_space","payload","marker","job"]:
		var ticket: Dictionary = {"ticket_id":"crash-"+phase,"_submit_key":"original-"+phase,"_origin":"https://fixture.invalid","manifest":{"fixture":true},"_race_proof":{"schema":"bmt-race-proof-v1","samples":[[0,0,0,0,0,0,0,0]]},"_wire_options":{"path":1,"incidents":true}}
		check(not Cloud._queue_run_io(ticket,inputs,"",rewinds,folder,owner,123,phase),phase+" interruption is never acknowledged as saved")
		var base: String = directory.path_join(str(ticket.ticket_id).sha256_text())
		Cloud._discover_pending(directory)
		var job: Dictionary = Cloud._read_file(base+".job.json")
		if phase in ["manifest","no_space"]:
			check(job.is_empty(),"manifest without payload remains uncommitted")
			ticket._submit_key = "new-key-must-not-replace-original"
			check(Cloud._queue_run_io(ticket,inputs,"",rewinds,folder,owner,999),"retry finishes staged manifest")
			job = Cloud._read_file(base+".job.json")
		check(job.get("key")=="original-"+phase and job.get("queued_server_at")==123 and job.get("wire_options")==JSON.parse_string(JSON.stringify(ticket._wire_options)),phase+" recovery retains original request identity")
		check(FileAccess.file_exists(Cloud._pending_marker(base+".job.json")) and Cloud._replay_integrity(base+".replay.json",job.get("replay_hash","")),phase+" recovery publishes valid payload and marker")
		job.run_id = "accepted-run"
		Cloud._write_file(base+".job.json",job)
		Cloud._discover_pending(directory)
		check(Cloud._read_file(base+".job.json").get("run_id")=="accepted-run",phase+" repeated recovery cannot overwrite acceptance")
	var queue := Queue.new()
	root.add_child(queue)
	queue.set_process(false)
	var samples: Array = []; var poses: Array = []
	for index: int in range(36032):
		samples.append([index*6,0.0,0.0,0.0,0.0,0.0,0,0.0])
		poses.append([index*6,0.0,0.0,0.0,0.0,0.0,0.0])
	var proof: Dictionary = {"schema":"bmt-race-proof-v1","samples":samples}
	var ghost: Dictionary = {"ticks":216000,"poses":poses}
	var began: int = Time.get_ticks_usec()
	check(queue.enqueue({"ticket_id":"owned","_race_proof":proof,"_race_ghost":ghost},inputs,"",rewinds),"maximum evidence enters owned bounded queue")
	metrics.handoff_us = Time.get_ticks_usec()-began
	metrics.evidence_bytes = queue.bytes_held()
	var packet: RefCounted = queue.jobs.owned.packet
	check(is_same(packet.proof,proof) and is_same(packet.ghost,ghost) and not queue.jobs.owned.ticket.has("_race_proof"),"large proof and ghost have one sealed owner outside ticket metadata")
	check(packet.proof.is_read_only() and packet.proof.samples.is_read_only(),"evidence containers are immutable after handoff")
	packet.seal_rows()
	check(packet.proof.samples[0].is_read_only(),"worker seals immutable scalar rows before serialization")
	inputs.clear(); rewinds.clear()
	check(packet.frames.size()==216000 and packet.rewinds.size()==3,"restart releases live inputs without changing handed-off evidence")
	var refused: bool = false
	for index: int in range(16):
		var accepted: bool = queue.enqueue({"ticket_id":"blocked-"+str(index),"_race_proof":proof,"_race_ghost":ghost},packet.frames,"",[])
		check(queue.bytes_held()+Queue.ENCODER_BYTES<=Queue.MAX_BYTES,"blocked storage stays below complete byte budget "+str(index))
		if not accepted: refused = true; break
	check(refused and not queue.can_start_attempt(),"full evidence disables another online reservation without discarding queued work")
	metrics.queue_bytes = queue.bytes_held(); metrics.ceiling_bytes = Queue.MAX_BYTES
	queue.free()
	var source := PersonalGhostRun.new()
	source.poses = poses.duplicate(); source.lap_ends.assign([43200.0,86400.0,129600.0,172800.0,216000.0])
	var expected_ghost: String = JSON.stringify(source.recording("race"))
	began = Time.get_ticks_usec()
	var owned: RefCounted = source.snapshot_for_save()
	metrics.ghost_snapshot_us = Time.get_ticks_usec()-began
	source.poses.clear(); source.lap_ends.clear()
	check(JSON.stringify(owned.recording("race"))==expected_ghost,"deferred ghost normalization preserves exact bytes after Game restart")
	var failed: Dictionary = {"ticket_id":"rename-failure","_submit_key":"rename-key"}
	check(not Cloud._queue_run_io(failed,[[0,255,0]],"",[],folder,owner,0,"payload"),"payload can be staged before an injected rename failure")
	var blocked: String = directory.path_join("rename-failure".sha256_text()+".job.json")
	DirAccess.make_dir_absolute(blocked)
	Cloud._discover_pending(directory)
	check(DirAccess.dir_exists_absolute(blocked) and FileAccess.file_exists(blocked.trim_suffix(".job.json")+".stage.json"),"failed commit preserves recoverable manifest and payload")
	DirAccess.remove_absolute(blocked)
	Cloud._discover_pending(directory)
	check(Cloud._read_file(blocked).get("key")=="rename-key","recovery completes once the rename obstacle is removed")
	var client := preload("res://backend/backend_client.gd").new()
	root.add_child(client)
	var results: Array = []
	for value: int in range(3): background(client,value,results)
	var peak: int = 0
	while results.size()<3:
		peak = maxi(peak,client._encoding_threads.size())
		await process_frame
	results.sort()
	check(peak==1 and results==[0,1,2],"save/upload background jobs share one encoder and retain every result")
	client.queue_free(); await process_frame
	var out: String = ProjectSettings.globalize_path("res://../docs/evidence/runtime-correctness-2026-10-26")
	DirAccess.make_dir_recursive_absolute(out)
	metrics.checks = checks; metrics.failures = failures
	var file := FileAccess.open(out.path_join("result-safety.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(metrics,"  "))
	print("RUNTIME_RESULT_SAFETY: ",checks," checks, ",failures," failures ",JSON.stringify(metrics))
	quit(1 if failures else 0)
