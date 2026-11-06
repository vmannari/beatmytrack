extends "res://tests/test_shared_graphics_first_laps.gd"
func run() -> void:
	check(GDExtensionManager.load_extension(OS.get_environment("BMT_NATIVE_EXTENSION")) == GDExtensionManager.LOAD_STATUS_OK,"usage diagnostic loads")
	await super.run()
func first_emission(game: Node) -> void:
	print("USAGE_PHASE ready ",int(Time.get_unix_time_from_system()*1000000.0))
	await super.first_emission(game)
	print("USAGE_PHASE driven ",int(Time.get_unix_time_from_system()*1000000.0))
