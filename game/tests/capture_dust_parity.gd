extends SceneTree
var game: Node
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size = Vector2i(3000,2120)
	root.scaling_3d_scale = sqrt(1500000.0/(3000.0*2120.0))
	root.msaa_3d = Viewport.MSAA_2X
	var track: NativeTrack = TrackCompiler.compile(JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/dust_cloud.json")))
	game = load("res://core/game.tscn").instantiate()
	game.initial_track = track
	game.production_mode = true
	game.vehicle_id = "compact"
	root.add_child(game)
	var review: RefCounted = preload("res://diagnostics/dust_parity_review.gd").new()
	await review.prepare(game,track)
	var folder: String = ProjectSettings.globalize_path("res://../docs/evidence/dust-parity-2026-10-10/desktop")
	DirAccess.make_dir_recursive_absolute(folder)
	var failures: int = 0
	for feature: String in ["parity_reference","parity_scene_depth","parity_reference_no_msaa","parity_scene_depth_no_msaa","parity_no_msaa","parity_scene_depth_resolve_colour","parity_resolve_colour","parity_baseline"]:
		review.select(feature)
		for frame: int in range(5):
			game.paused = false
			game.hud.pause_menu.hide()
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(folder.path_join(feature+".png"))
		var stats: Dictionary = review.capture_stats(feature)
		print("DUST_PARITY_CAPTURE ",feature," ",stats)
		if feature=="parity_baseline":
			if stats.opaque_roof_pixels<100 or stats.changed_outside_pixels<100: failures += 1
			if stats.changed_roof_pixels!=0: failures += 1
	game.free()
	print("DUST_PARITY_CAPTURE_FAILURES ",failures)
	quit(1 if failures else 0)
