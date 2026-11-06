extends SceneTree
func _initialize() -> void:
	var failures: int = 0
	for path: String in ["res://core/app.gd","res://core/features/race.gd","res://core/features/editor.gd","res://core/features/garage.gd","res://core/features/tracks.gd","res://core/features/rivalry.gd","res://core/features/challenges.gd","res://core/features/daily.gd","res://core/features/settings.gd","res://core/features/selected_track.gd","res://core/features/creator.gd","res://ui/profile_car_renderer.gd"]:
		var script: GDScript = load(path)
		if script == null or not script.can_instantiate(): failures += 1
	print("FEATURE_PARSE_FAILURES ",failures)
	quit(1 if failures else 0)
