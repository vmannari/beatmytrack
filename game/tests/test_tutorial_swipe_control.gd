extends SceneTree
## Run the unchanged swipe suite with task-start scripts reloaded only in this process.
func _initialize() -> void: run.call_deferred()

func run() -> void:
	if "--original-runtime" in OS.get_cmdline_user_args() or "--original-garage" in OS.get_cmdline_user_args():
		for path: String in ["game/core/game.gd","game/ui/settings_page.gd","game/ui/track_carousel.gd","game/ui/menu_page_swipe.gd","game/core/app.gd"]:
			var script: GDScript = load("res://"+path.trim_prefix("game/"))
			script.source_code = FileAccess.get_file_as_string("res://../docs/evidence/first-play-tutorial-2026-10-24/before/"+path)
			if script.reload() != OK:
				print("CONTROL_RELOAD_FAILED: "+path)
				quit(2)
				return
		print("TUTORIAL_SWIPE_CONTROL: five exact task-start scripts restored in isolated memory")
	var garage: bool = "--garage-control" in OS.get_cmdline_user_args() or "--original-garage" in OS.get_cmdline_user_args()
	var suite: GDScript = load("res://tests/test_garage_carousel.gd" if garage else "res://tests/test_menu_page_swipe.gd")
	set_script(suite)
	call_deferred("_run" if garage else "run")
