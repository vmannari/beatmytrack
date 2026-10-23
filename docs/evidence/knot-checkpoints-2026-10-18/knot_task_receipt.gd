extends SceneTree

func _initialize() -> void:
	for path: String in ["res://tests/test_knot_checkpoint_notices.gd","res://tests/capture_knot_checkpoint_notice.gd"]:
		if FileAccess.file_exists(path+".uid"): continue
		var file := FileAccess.open(path+".uid",FileAccess.WRITE)
		if file == null: quit(1); return
		file.store_string(ResourceUID.id_to_text(ResourceUID.create_id())+"\n")
	print("KNOT_SCRIPT_UIDS: saved")
	quit()
