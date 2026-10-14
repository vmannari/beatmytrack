extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var folder: String = ""
	var notify: String = ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--folder="): folder = argument.trim_prefix("--folder=")
		elif argument.begins_with("--notify="): notify = argument.trim_prefix("--notify=")
	if folder.is_empty() or notify.is_empty(): quit(1); return
	var client: Node = preload("res://backend/backend_client.gd").new()
	root.add_child(client)
	client.configure("http://127.0.0.1:1")
	client.player = {"id":"actual-process-pause-owner"}
	client._access_token = "fictional-fixture"
	client._sample_time(1800000000)
	var cloud: Node = preload("res://backend/cloud_tracks.gd").new()
	cloud.client = client
	root.add_child(cloud)
	var flow := TrackLifecycle.new()
	flow.cloud = cloud
	flow.library = TrackLibrary.new(folder.path_join("drafts"))
	root.add_child(flow)
	var file := FileAccess.open(notify+".ready",FileAccess.WRITE)
	if file == null: quit(1); return
	file.store_string(str(OS.get_process_id())); file.close()
	var began: int = Time.get_ticks_msec()
	while not FileAccess.file_exists(folder.path_join("publication-go")):
		if Time.get_ticks_msec()-began > 15000: quit(1); return
		await process_frame
	flow._pause_batch({"status":429,"retry_after":90})
	file = FileAccess.open(notify,FileAccess.WRITE)
	if file == null: quit(1); return
	file.store_string(JSON.stringify({"pid":OS.get_process_id(),"root":flow._wait_root(),"blocked":not flow._batch_ready()})); file.close()
	client.queue_free(); cloud.queue_free(); flow.queue_free()
	await process_frame
	quit(0)
