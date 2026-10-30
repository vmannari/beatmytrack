extends SceneTree
func _initialize() -> void:
	for method: Dictionary in TranslationServer.get_method_list():
		if str(method.name).contains("country_name"):
			print("LOCALE_METADATA: "+str(method.name))
	if TranslationServer.has_method("get_country_name_localized"):
		TranslationServer.set_locale("fr")
		print("LOCALE_METADATA: FI = "+str(TranslationServer.call("get_country_name_localized","FI")))
	quit()
