extends SceneTree
## One-time PC recovery using the same production lifecycle and integrity checks.
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	assert(FileAccess.file_exists("res://../build/track-lifecycle-backup-2026-10-03/database.dump"))
	var config := ConfigFile.new()
	assert(config.load("user://backend.cfg") == OK)
	var client := preload("res://backend/backend_client.gd").new()
	root.add_child(client)
	client.configure("http://127.0.0.1:18181")
	var signed: Dictionary = await client.development_login("developer","developer",str(config.get_value("backend","development_key","")))
	assert(signed.ok)
	var cloud := preload("res://backend/cloud_tracks.gd").new()
	cloud.client = client
	root.add_child(cloud)
	cloud.load_cached()
	await cloud.refresh(true)
	var aliases_path: String = cloud.cache_root().path_join("aliases.json")
	var aliases: Dictionary = cloud._read(aliases_path)
	assert(not aliases.has("_read_error"))
	var before_path: String = "res://../build/backend-lifecycle-before.json"
	if FileAccess.file_exists(before_path):
		var before: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(before_path))
		for old: Dictionary in before.items:
			var remote: Dictionary = await client.request_api("/track-versions/"+str(old.version_id))
			if remote.ok and str(remote.data.track_id) == str(old.track_id):
				aliases["cloud_"+str(old.version_id)] = "cloud_"+str(old.track_id)
	assert(cloud._write(aliases_path,aliases))
	var directory: String = "user://players".path_join((str(client._base_url)+"/"+str(client.player.id)).sha256_text())
	var flow := TrackLifecycle.new()
	flow.cloud = cloud
	flow.library = TrackLibrary.new(directory.path_join("tracks"))
	flow.records = LocalRecords.new(directory.path_join("records.json"))
	flow.records.load_records()
	flow.legacy_directories = ["user://tracks"]
	if DirAccess.dir_exists_absolute("user://players"):
		for profile: String in DirAccess.get_directories_at("user://players"):
			flow.legacy_directories.append("user://players".path_join(profile).path_join("tracks"))
	root.add_child(flow)
	await flow.process_jobs()
	var record_paths: Array[String] = ["user://local_records.json"]
	if DirAccess.dir_exists_absolute("user://players"):
		for profile: String in DirAccess.get_directories_at("user://players"):
			record_paths.append("user://players".path_join(profile).path_join("records.json"))
	for record_path: String in record_paths:
		if not FileAccess.file_exists(record_path): continue
		var history := LocalRecords.new(record_path)
		history.load_records()
		assert(cloud.migrate_record_identities(history) == OK)
	var cached: int = 0
	var compatible: int = 0
	for metadata: Dictionary in cloud.entries:
		var entry: Dictionary = cloud.entry_from_metadata(metadata)
		if await cloud.download(entry) and cloud.compile_entry(entry) != null:
			cached += 1
			if not (await cloud.ticket(cloud.compile_entry(entry))).is_empty(): compatible += 1
	print("BACKEND_RECONCILIATION: ",cloud.entries.size()," publications, ",cached," hash-checked playable caches, ",compatible," compatible race contracts; ",flow.last_error," ",cloud.last_error)
	quit(0 if cached == cloud.entries.size() and compatible == cached and flow.last_error.is_empty() else 1)
