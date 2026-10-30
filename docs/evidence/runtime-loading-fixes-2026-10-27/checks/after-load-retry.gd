extends SceneTree
const WORLDS = preload("res://track/prepared_world_cache.gd")
var checks: int = 0
var failures: int = 0
var app: Node
var timings: Array = []
var frame_times: Array[float] = []
var last_frame: int = 0
var measuring: bool = false
var longest: Dictionary = {}
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; print("FAIL: ",label)
func observe() -> void:
	var now: int = Time.get_ticks_usec()
	if measuring and last_frame > 0:
		var duration: float = (now-last_frame)/1000.0
		frame_times.append(duration)
		if duration > float(longest.get("ms",0)):
			longest = {"ms":duration,"status":app.race_loading.status_label.text if is_instance_valid(app.race_loading) else "closed","stage":app.game.track_ground.build_stage if is_instance_valid(app.game) and is_instance_valid(app.game.track_ground) else "before world"}
	last_frame = now
func run() -> void:
	var task_config:=ConfigFile.new()
	task_config.set_value("backend","url","")
	assert(task_config.save("user://backend.cfg")==OK)
	OS.unset_environment("BMT_API_URL")

	OS.set_environment("BMT_API_URL","")
	root.size = Vector2i(1280,720)
	var folder: String = "user://runtime-profile-"+TrackLibrary.unique_id()
	app = load("res://core/app.tscn").instantiate()
	app.records = LocalRecords.new(folder.path_join("records.json"))
	app.records.settings.music_enabled = false
	app.library = TrackLibrary.new(folder.path_join("tracks"))
	app.cloud_root_override = folder.path_join("cloud")
	app.race_profile_enabled = true
	root.add_child(app)
	while not app.startup_complete: await process_frame
	process_frame.connect(observe)
	for source: String in ["res://tests/fixtures/star_spline_lap.json","res://resources/storm_tracks/storm_freight.json","res://resources/storm_tracks/storm_switchyard.json","res://resources/storm_tracks/storm_timber.json","res://resources/storm_tracks/storm_quarry.json","res://resources/storm_tracks/storm_floodgate.json"]:
		if "--only-star" in OS.get_cmdline_user_args() and not source.contains("star_spline"): continue
		var document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(source))
		var track: NativeTrack = TrackCompiler.compile(document)
		track.metadata.cloud_version = "owned-runtime-fixture"
		WORLDS.entries.clear()
		for cycle: int in range(2):
			app.records.settings.camera_mode = "overhead"
			app._show_screen("tracks"); app.selected_track = track
			frame_times.clear(); longest = {}; last_frame = Time.get_ticks_usec(); measuring = true
			var began: int = Time.get_ticks_usec()
			await app._start_race(track,false,true)
			measuring = false
			check(is_instance_valid(app.game) and app.game.preparation_complete,source+" actual App entry completes")
			if not is_instance_valid(app.game): continue
			app.game.set_physics_process(false)
			timings.append({"source":source,"cycle":cycle,"wall_ms":(Time.get_ticks_usec()-began)/1000.0,"max_frame_ms":frame_times.max() if not frame_times.is_empty() else 0,"longest":longest,"world":app.game.track_ground.build_costs,"game":app.game.preparation_costs})
			print("RUNTIME_LOAD ",JSON.stringify(timings[-1]))
			var game: Node = app.game
			if is_instance_valid(game.world_render_preparation):
				timings[-1].draw_groups = game.world_render_preparation.frame_groups
				timings[-1].draw_wait_max_us = game.world_render_preparation.draw_us_max
			if DisplayServer.get_name() != "headless":
				await RenderingServer.frame_post_draw
				var capture: String = ProjectSettings.globalize_path("res://../build/runtime-loading-fixes-2026-10-27/outputs/after-load-retry")
				DirAccess.make_dir_recursive_absolute(capture)
				root.get_texture().get_image().save_png(capture.path_join(source.get_file().get_basename()+"-"+str(cycle)+".png"))
			if not game.paused: game.toggle_pause(false)
			for _frame: int in range(4): await process_frame
			var before: int = game.presentation_world_updates
			var state: Dictionary = RewindHistory.properties(game.sim.state)
			for _frame: int in range(32): await process_frame
			check(game.presentation_world_updates == before,"idle pause performs no repeated world/HUD work")
			check(RewindHistory.properties(game.sim.state)==state,"pause presentation preserves every canonical property")
			game.set_camera_mode("follow_car" if game.camera.mode != "follow_car" else "overhead")
			await process_frame; await process_frame
			check(game.presentation_world_updates>before,"pause camera setting invalidates frozen presentation")
			game.toggle_pause(false)
			check(game.frame.throttle==0 and game.frame.steer==0,"resume clears held controls")
			app._leave_race(); await process_frame
	app.queue_free(); await process_frame
	var output: String = ProjectSettings.globalize_path("res://../build/runtime-loading-fixes-2026-10-27/outputs/after-load-retry")
	DirAccess.make_dir_recursive_absolute(output)
	var file := FileAccess.open(output.path_join("load-profile-"+RenderingServer.get_current_rendering_method()+"-"+DisplayServer.get_name()+".json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"loads":timings},"  "))
	print("RUNTIME_PROFILE: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
