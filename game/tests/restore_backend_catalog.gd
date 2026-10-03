extends SceneTree
## Owner-authorized handoff of the retained named circuits, after the official seed.

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var backup: String = "res://../build/track-restoration-backup-2026-10-03"
	assert(FileAccess.file_exists(backup.path_join("database.dump")))
	assert(FileAccess.file_exists(backup.path_join("objects.tar.gz")))
	var prepared: Array = JSON.parse_string(FileAccess.get_file_as_string("res://../build/backend-restoration-prepared.json"))
	var before: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://../build/backend-restoration-before.json"))
	var config := ConfigFile.new()
	assert(config.load("user://backend.cfg") == OK)
	var client := preload("res://backend/backend_client.gd").new()
	root.add_child(client)
	client.configure("http://127.0.0.1:18181")
	var signed: Dictionary = await client.development_login("developer","developer",str(config.get_value("backend","development_key","")))
	assert(signed.ok and client.player.display_name == "Beat my track")
	var cloud := preload("res://backend/cloud_tracks.gd").new()
	cloud.client = client
	root.add_child(cloud)
	cloud.load_cached()
	await cloud.refresh(true)
	assert(cloud.entries.size() == before.items.size()+prepared.size())
	var aliases_path: String = cloud.cache_root().path_join("aliases.json")
	var aliases: Dictionary = cloud._read(aliases_path)
	assert(not aliases.has("_read_error"))
	var by_authoring: Dictionary = {}
	var documents: Dictionary = {}
	var checked: Array[Dictionary] = []
	for metadata: Dictionary in cloud.entries:
		assert(metadata.creator == "Beat my track" and metadata.creator_id == client.player.id)
		assert(not by_authoring.has(str(metadata.authoring_id)))
		by_authoring[str(metadata.authoring_id)] = metadata
		var entry: Dictionary = cloud.entry_from_metadata(metadata)
		assert(await cloud.download(entry))
		var track: NativeTrack = cloud.compile_entry(entry)
		assert(track != null and not (await cloud.ticket(track)).is_empty())
		documents[str(metadata.authoring_id)] = cloud.cached_document(entry)
		assert(documents[str(metadata.authoring_id)].creator == "Beat my track")
		checked.append({"name":metadata.name,"authoring_id":metadata.authoring_id,"track_id":metadata.track_id,
			"version_id":metadata.version_id,"creator":metadata.creator,"hash_checked":true,"compiled":true,"race_contract":true})
	for previous: Dictionary in before.items:
		assert(by_authoring[str(previous.authoring_id)].track_id == previous.track_id)
		var old: Dictionary = await client.request_api("/track-versions/"+str(previous.version_id)+"/document")
		assert(old.ok and str(old.body).sha256_text() == str(previous.content_hash))
		aliases["cloud_"+str(previous.version_id)] = "cloud_"+str(previous.track_id)
	# Verify the migration against its saved originals before any local cleanup.
	for item: Dictionary in prepared:
		var original: Dictionary = item.original
		var expected: Dictionary = item.document
		assert(original.id == expected.id)
		var physical_original: Dictionary = original.duplicate(true)
		var physical_expected: Dictionary = expected.duplicate(true)
		for key: String in ["creator","points","widths","corners","route_override","start_line"]:
			physical_original.erase(key)
			physical_expected.erase(key)
		assert(physical_original == physical_expected)
		assert(TrackLibrary.authoring_equivalent(expected,documents[str(original.id)]))
		aliases["creator_"+str(original.id)] = "cloud_"+str(by_authoring[str(original.id)].track_id)
	assert(cloud._write(aliases_path,aliases))
	var record_paths: Array[String] = ["user://local_records.json"]
	for profile: String in DirAccess.get_directories_at("user://players"):
		record_paths.append("user://players".path_join(profile).path_join("records.json"))
	for path: String in record_paths:
		if not FileAccess.file_exists(path): continue
		var records := LocalRecords.new(path)
		records.load_records()
		assert(cloud.migrate_record_identities(records) == OK)
	var transferred: int = 0
	var userdata: String = ProjectSettings.globalize_path("user://").replace("\\","/").trim_suffix("/")
	for item: Dictionary in prepared:
		var original: Dictionary = item.original
		var source_path: String = str(item.source_path).replace("\\","/").simplify_path()
		assert(source_path.begins_with(userdata+"/") and source_path.get_file() == str(original.id)+".json")
		assert(FileAccess.file_exists(backup.path_join("userdata").path_join(source_path.trim_prefix(userdata+"/"))))
		var source := TrackLibrary.new(source_path.get_base_dir())
		var current: Dictionary = source._read(source_path) if FileAccess.file_exists(source_path) else {}
		if not current.is_empty() and not TrackLibrary.authoring_equivalent(current,original):
			print("RESTORATION_PRESERVED_NEWER_EDIT: ",original.name)
			continue
		assert(source.commit_backend_binding(original,by_authoring[str(original.id)],str(client._base_url)))
		# The remote adaptation is validated above. Match cleanup against the saved
		# original so newer WIP edits still win over this one-time format migration.
		assert(source.cleanup_backend_publication(original,original) == OK)
		assert(not FileAccess.file_exists(source_path))
		transferred += 1
	var report: Dictionary = {"restored":prepared.size(),"total_publications":cloud.entries.size(),
		"local_masters_transferred":transferred,"existing_track_uids_preserved":true,
		"old_immutable_links_preserved":true,"tracks":checked}
	var output: String = ProjectSettings.globalize_path("res://../docs/evidence/track-restoration-2026-10-03/live-restoration.json")
	DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	var file := FileAccess.open(output,FileAccess.WRITE)
	assert(file != null)
	file.store_string(JSON.stringify(report,"\t"))
	file.close()
	print("LIVE_TRACK_RESTORATION: ",prepared.size()," restored; ",cloud.entries.size()," hash-checked, compiled, compatible server publications; ",transferred," matching local masters transferred")
	quit()
