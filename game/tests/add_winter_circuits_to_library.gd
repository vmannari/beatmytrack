extends SceneTree
## Explicit local content installation. No HTTP, sign-in, publication or existing-file overwrite.
const IDS: Array[String] = ["frostline", "lantern_village"]

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var user_root: String = ProjectSettings.globalize_path("user://")
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--library-user-root="): user_root = arg.trim_prefix("--library-user-root=")
	user_root = user_root.replace("\\","/").simplify_path()
	var settings := ConfigFile.new()
	settings.load(user_root.path_join("backend.cfg"))
	var origin: String = str(settings.get_value("backend","url","http://127.0.0.1:18181"))
	if OS.has_environment("BMT_API_URL"): origin = OS.get_environment("BMT_API_URL")
	var client := preload("res://backend/backend_client.gd").new()
	client._base_url = origin.trim_suffix("/")
	client.session_path = user_root.path_join("account_session.cfg")
	var session := ConfigFile.new()
	var directory: String = user_root.path_join("tracks")
	if client.has_saved_session():
		var read_error: Error = client._load_saved_config(session)
		if read_error != OK:
			print("WINTER_LOCAL_IDENTITY_READ: ",error_string(read_error)," vault_available=",client.session_vault.available())
			push_error("Cannot resolve the current local account; no files were written.")
			client.free(); quit(1); return
		var owner: String = str(session.get_value("session","player_id",""))
		if str(session.get_value("session","url","")) != client._base_url or owner.is_empty():
			push_error("Saved account does not match the configured server; no files were written.")
			client.free(); quit(1); return
		directory = user_root.path_join("players/"+(client._base_url+"/"+owner).sha256_text()+"/tracks")
	client.free()
	directory = ProjectSettings.globalize_path(directory)
	print("WINTER_LOCAL_DESTINATION: ",directory)
	var documents: Array[Dictionary] = []
	for id: String in IDS:
		var document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://resources/creator_tracks/"+id+".json"))
		if not TrackDocument.validate(document).is_empty(): quit(1); return
		var path: String = directory.path_join(id+".json")
		# Preflight both destinations before the first write, including recovery files.
		for suffix: String in ["",".tmp",".bak"]:
			if FileAccess.file_exists(path+suffix):
				if suffix != "" or JSON.parse_string(FileAccess.get_file_as_string(path)) != document:
					push_error("An existing draft/recovery file occupies "+path+suffix+"; no files were written.")
					quit(1); return
		documents.append(document)
	if "--install" not in OS.get_cmdline_user_args():
		print("WINTER_LOCAL_PREFLIGHT: both new filenames are available")
		quit(); return
	var library := TrackLibrary.new(directory)
	for document: Dictionary in documents:
		var path: String = directory.path_join(document.id+".json")
		if not FileAccess.file_exists(path) and library.save_document(document) != OK:
			push_error(library.last_error); quit(1); return
		if library.load_document(document.id) != document:
			push_error("Local draft did not read back exactly."); quit(1); return
		print("WINTER_LOCAL_INSTALLED: ",document.name," ",FileAccess.get_sha256(path))
	quit()
