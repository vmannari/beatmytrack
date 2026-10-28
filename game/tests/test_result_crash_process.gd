extends SceneTree
const Cloud = preload("res://backend/cloud_tracks.gd")
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var phase: String = "payload"
	var mode: String = "write"
	var batch: String = "trial2"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--phase="): phase = arg.trim_prefix("--phase=")
		if arg.begins_with("--mode="): mode = arg.trim_prefix("--mode=")
		if arg.begins_with("--batch="): batch = arg.trim_prefix("--batch=")
	var folder: String = ProjectSettings.globalize_path("res://../build/runtime-correctness-2026-10-26/crash-"+batch+"-"+phase)
	var ticket: Dictionary = {"ticket_id":"process-"+phase,"_submit_key":"original-process-"+phase,"_origin":"https://fixture.invalid","manifest":{"fixture":true}}
	var owner: String = "owned-process-fixture"
	var directory: String = folder.path_join("players").path_join(owner.sha256_text()).path_join("runs")
	if mode == "write":
		Cloud._queue_run_io(ticket,[[0,255,0,0,2],[127,0,255,255]],"",[],folder,owner,456,phase)
		var ready := FileAccess.open(folder+".ready",FileAccess.WRITE)
		ready.store_string("ready"); ready.close()
		print("CRASH_PROCESS_READY ",phase)
		while true: await process_frame
	Cloud._discover_pending(directory)
	var path: String = directory.path_join(str(ticket.ticket_id).sha256_text()+".job.json")
	var job: Dictionary = Cloud._read_file(path)
	if phase == "manifest" and job.is_empty():
		if not Cloud._queue_run_io(ticket,[[0,255,0,0,2],[127,0,255,255]],"",[],folder,owner,789): quit(1); return
		job = Cloud._read_file(path)
	var valid: bool = job.get("key")==ticket._submit_key and job.get("queued_server_at")==456 and Cloud._replay_integrity(directory.path_join(str(job.get("replay",""))),str(job.get("replay_hash","")))
	print("CRASH_PROCESS_RECOVERED ",phase," ",valid)
	quit(0 if valid else 1)
