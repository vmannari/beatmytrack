extends SceneTree
## Restore only the recorded App implementation in memory for a focused control.
func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.is_empty(): quit(2); return
	var app_script: GDScript = load("res://core/app.gd")
	app_script.source_code = FileAccess.get_file_as_string("res://../docs/evidence/startup-shell-2026-11-04/before/game/core/app.gd")
	if app_script.reload() != OK: quit(2); return
	var suite: GDScript = load(args[0])
	if suite == null or not suite.can_instantiate(): quit(2); return
	set_script(suite)
	call_deferred("run")
