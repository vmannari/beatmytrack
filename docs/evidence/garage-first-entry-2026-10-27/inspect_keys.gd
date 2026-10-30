extends SceneTree
func _initialize() -> void:
	var m:=StandardMaterial3D.new()
	print("NATIVE_KEY ",m.call("_get_shader_rid"))
	for method: Dictionary in m.get_method_list():
		if "shader" in str(method.name): print("MATERIAL_API ",method.name)
	for method: Dictionary in RenderingServer.get_method_list():
		if "material_get" in str(method.name): print("SERVER_API ",method.name)
	quit()
