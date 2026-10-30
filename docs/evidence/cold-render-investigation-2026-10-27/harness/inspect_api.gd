extends SceneTree
func _initialize() -> void:
	for item: Dictionary in RenderingServer.get_method_list():
		if "native_source" in str(item.name): print("NATIVE_API ",item)
	for class_name_text: String in ["Material","ShaderNativeSourceCode","Shader"]:
		if not ClassDB.class_exists(class_name_text): continue
		for item: Dictionary in ClassDB.class_get_method_list(class_name_text,true):
			if "shader" in str(item.name) or class_name_text=="ShaderNativeSourceCode": print("CLASS_API ",class_name_text," ",item)
	quit()
