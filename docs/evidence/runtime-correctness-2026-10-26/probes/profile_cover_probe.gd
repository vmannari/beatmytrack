extends "res://tests/profile_runtime_correctness.gd"
## Instrument loaded script resources in this isolated process only.
func _initialize() -> void:
	var source: Script = load("res://core/app.gd")
	var code: String = source.source_code
	code = code.replace("func _open_race_loading(track: NativeTrack = null, practice: bool = false) -> RaceLoading:\n", "func _open_race_loading(track: NativeTrack = null, practice: bool = false) -> RaceLoading:\n\tvar probe_at: int = Time.get_ticks_usec()\n")
	code = code.replace("\treturn race_loading\n", "\tprint(\"COVER_SETUP_US \",Time.get_ticks_usec()-probe_at)\n\treturn race_loading\n")
	code = code.replace("func _present_race_loading() -> bool:\n", "func _present_race_loading() -> bool:\n\tvar probe_at: int = Time.get_ticks_usec()\n")
	code = code.replace("\treturn drawn.done\n", "\tprint(\"COVER_DRAW_WAIT_US \",Time.get_ticks_usec()-probe_at)\n\treturn drawn.done\n")
	source.source_code = code
	if source.reload(true) != OK: quit(1); return
	var overlay: Script = load("res://ui/race_loading.gd")
	code = overlay.source_code.replace("func _draw_route() -> void:\n", "func _draw_route() -> void:\n\tvar probe_at: int = Time.get_ticks_usec()\n")
	code = code.replace("\nfunc _input(", "\n\tprint(\"COVER_ROUTE_US \",Time.get_ticks_usec()-probe_at,\" points \",route.size())\n\nfunc _input(")
	overlay.source_code = code
	if overlay.reload(true) != OK: quit(1); return
	run.call_deferred()
