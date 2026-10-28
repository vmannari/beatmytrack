extends SceneTree
func _initialize() -> void:
	for item: Dictionary in ProjectSettings.get_property_list():
		var key: String=str(item.name)
		if key.contains("shader") and (key.contains("cache") or key.contains("compil")):
			print("SHADER_SETTING ",key," ",ProjectSettings.get_setting(key))
	quit()
