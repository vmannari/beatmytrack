extends SceneTree
## Actual App and private data. Frame intervals are callbacks, not presentation.
const WORLDS = preload("res://track/prepared_world_cache.gd")
var checks: int = 0
var failures: int = 0
var app: Node
var intervals: Array[float] = []
var last_frame: int = 0
var measuring: bool = false
var cases: Array[Dictionary] = []
var output: String

func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; print("FAIL: ",label)
func observe() -> void:
	var now: int = Time.get_ticks_usec()
	if measuring and last_frame > 0: intervals.append(float(now-last_frame)/1000.0)
	last_frame = now
func percentile(values: Array[float], fraction: float) -> float:
	return values[clampi(ceili(values.size()*fraction)-1,0,values.size()-1)] if not values.is_empty() else 0.0
func run() -> void:
	OS.set_environment("BMT_API_URL","")
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output = argument.trim_prefix("--output=")
	if output.is_empty(): push_error("--output is required"); quit(1); return
	output = ProjectSettings.globalize_path(output)
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1280,720)
	var info: Dictionary = {"engine":Engine.get_version_info().string,"renderer":RenderingServer.get_current_rendering_method(),"adapter":RenderingServer.get_video_adapter_name(),"screen_hz":DisplayServer.screen_get_refresh_rate(),"display":DisplayServer.get_name(),"max_fps":Engine.max_fps,"window":str(root.size),"msaa":root.msaa_3d,"scale":root.scaling_3d_scale,"debug_build":OS.is_debug_build(),"interval_note":"process-frame callback intervals, not physical presentation or GPU time"}
	print("RENDERER_ENV ",JSON.stringify(info))
	var folder: String = "user://renderer-compare-"+TrackLibrary.unique_id()
	app = load("res://core/app.tscn").instantiate()
	app.records = LocalRecords.new(folder.path_join("records.json"))
	app.records.settings.music_enabled = false
	app.library = TrackLibrary.new(folder.path_join("tracks"))
	app.cloud_root_override = folder.path_join("cloud")
	app.race_profile_enabled = true
	root.add_child(app)
	while not app.startup_complete: await process_frame
	print("RENDERER_APP_READY")
	process_frame.connect(observe)
	var document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/star_spline_lap.json"))
	var track: NativeTrack = TrackCompiler.compile(document)
	track.metadata.cloud_version = "isolated-renderer-compare"
	WORLDS.entries.clear()
	for cycle: int in range(2):
		app.records.settings.camera_mode = "overhead"
		app._show_screen("tracks"); app.selected_track = track
		intervals.clear(); last_frame = Time.get_ticks_usec(); measuring = true
		var began: int = Time.get_ticks_usec()
		print("RENDERER_LOAD_BEGIN cycle=",cycle)
		await app._start_race(track,false,true)
		measuring = false
		var ready: bool = is_instance_valid(app.game) and app.game.preparation_complete
		check(ready,"actual App race reaches readiness")
		if not ready: break
		app.game.set_physics_process(false)
		var values: Array[float] = intervals.duplicate(); values.sort()
		var record: Dictionary = {"cycle":cycle,"wall_ms":float(Time.get_ticks_usec()-began)/1000.0,"samples":values.size(),"p50_callback_ms":percentile(values,.5),"p95_callback_ms":percentile(values,.95),"p99_callback_ms":percentile(values,.99),"max_callback_ms":values.back() if not values.is_empty() else 0.0,"tick":app.game.sim.state.tick,"countdown_ticks":app.game.countdown_ticks,"draw_groups":app.game.world_render_preparation.frame_groups if is_instance_valid(app.game.world_render_preparation) else -1,"render_scale":root.scaling_3d_scale,"msaa":root.msaa_3d,"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"game":app.game.preparation_costs,"world":app.game.track_ground.build_costs}
		check(record.tick == 0 and record.countdown_ticks == 360,"race readiness preserves tick and countdown")
		cases.append(record)
		print("RENDERER_LOAD ",JSON.stringify(record))
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(output.path_join("star-%d.png" % cycle)) == OK,"actual App image saved")
		if not app.game.paused: app.game.toggle_pause(false)
		for _frame: int in range(4): await process_frame
		var state: Dictionary = RewindHistory.properties(app.game.sim.state)
		for _frame: int in range(12): await process_frame
		check(RewindHistory.properties(app.game.sim.state) == state,"paused state unchanged")
		app._leave_race(); await process_frame
	app.queue_free()
	for _frame: int in range(24): await process_frame
	var report: Dictionary = {"environment":info,"cases":cases,"checks":checks,"failures":failures}
	var file := FileAccess.open(output.path_join("report.json"),FileAccess.WRITE)
	if file == null: push_error("cannot write report"); quit(1); return
	file.store_string(JSON.stringify(report,"  ")); file.close()
	print("RENDERER_COMPARISON checks=",checks," failures=",failures)
	quit(1 if failures else 0)
