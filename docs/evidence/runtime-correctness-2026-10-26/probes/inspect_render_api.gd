extends SceneTree
func _initialize() -> void:
	for name: String in ClassDB.class_get_integer_constant_list("Performance"):
		if name.contains("COMPIL") or name.contains("TIME"): print("MONITOR ",name)
	for method: Dictionary in RenderingServer.get_method_list():
		if str(method.name).contains("shader") or str(method.name).contains("frame_setup") or str(method.name).contains("pipeline"): print("RENDER_METHOD ",method.name)
	quit()
