extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
	GameSoundtrack.instance().show_menu()
	await create_timer(1.0).timeout
	print("MENU_AUDIO_ONLY: no editor or app instantiated")
	quit()
