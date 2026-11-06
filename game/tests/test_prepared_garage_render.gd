extends "res://tests/test_garage_render_optimization.gd"
## Retain all existing Garage appearance/LOD/canopy gates in fresh evidence.
func _initialize() -> void:
	output=OS.get_environment("BMT_PREPARED_EVIDENCE")
	assert(not output.is_empty())
	var renderer: String=RenderingServer.get_current_rendering_method()
	if not FileAccess.file_exists(output.path_join("before/game/assets/garage/workshop_v1.scn")) or not DirAccess.dir_exists_absolute(output.path_join("after/"+renderer)):
		printerr("PREPARED_GARAGE_FIXTURE_MISSING: copy the retained room and paired native views before launching this check")
		quit(1);return
	run.call_deferred()
