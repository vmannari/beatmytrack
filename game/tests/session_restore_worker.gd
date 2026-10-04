extends SceneTree
## Separate-process helper, only for a disposable HTTP session acceptance test.
func _initialize() -> void: call_deferred("run")

func run() -> void:
	var session: String = ""
	var notify: String = ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--session="): session = argument.trim_prefix("--session=")
		if argument.begins_with("--notify="): notify = argument.trim_prefix("--notify=")
	if session.is_empty() or notify.is_empty(): quit(1); return
	var client: Node = load("res://backend/backend_client.gd").new()
	root.add_child(client)
	client.configure(OS.get_environment("BMT_API_URL"))
	client.session_path = session
	var restored: Dictionary = await client.restore_session()
	var file := FileAccess.open(notify,FileAccess.WRITE)
	if file == null: quit(1); return
	file.store_string(JSON.stringify({"ok":restored.ok and client.signed_in()}))
	file.close()
	client.queue_free()
	await process_frame
	quit(0 if restored.ok else 1)
