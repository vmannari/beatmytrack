extends SceneTree
func _initialize() -> void:
	for method: Dictionary in ClassDB.class_get_method_list("RenderingServer"):
		if "shader" in str(method.name) and "default" in str(method.name): print("SHADER_DEFAULT_API ",JSON.stringify(method))
	var shader: Shader=load("res://vehicle/compact_canopy.gdshader")
	if shader!=null:
		print("DEFAULTS ",shader.get_shader_uniform_list())
	quit()
