extends Node
## Composition root. Vehicle, race and presentation modules will be wired here.
## This scene deliberately makes no claim that a drivable slice exists yet.


func _ready() -> void:
	print("BOOTSTRAP_READY")
	if OS.is_debug_build():
		for argument: String in OS.get_cmdline_user_args():
			if argument.begins_with("--capture="):
				_capture_frame(argument.trim_prefix("--capture="))


func _capture_frame(destination: String) -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Screenshot capture needs a graphical display.")
		get_tree().quit(1)
		return
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var screenshot: Image = get_viewport().get_texture().get_image()
	var error: Error = screenshot.save_png(destination)
	if error != OK:
		push_error("Screenshot save failed: %s" % error_string(error))
		get_tree().quit(1)
		return
	print("CAPTURE_SAVED: " + destination)
	get_tree().quit()
