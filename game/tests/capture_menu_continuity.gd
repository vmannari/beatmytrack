extends SceneTree
## Real menu workload, two natural score wraps, isolated player data.
var output: String = "res://../docs/evidence/menu-loop-repair-2026-10-08"
var phase: String = OS.get_environment("BMT_MENU_CAPTURE_PHASE")
var world: GameSoundtrack
var recorder := AudioEffectRecord.new()
var trace: Array[Dictionary] = []
var failures: int = 0


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Menu continuity capture needs -Graphical")
		quit(1)
		return
	if phase.is_empty(): phase = "after"
	OS.set_environment("BMT_API_URL", "")
	var fixture: String = "user://menu_continuity_" + TrackLibrary.unique_id()
	DirAccess.make_dir_recursive_absolute(fixture)
	var scene: PackedScene = load("res://core/app.tscn")
	var app: Node = scene.instantiate()
	app.set("library", TrackLibrary.new(fixture))
	app.set("cloud_root_override", fixture.path_join("cloud"))
	(app.get("records") as LocalRecords).path = fixture.path_join("records.json")
	root.add_child(app)
	var deadline: int = Time.get_ticks_msec() + 12000
	while not bool(app.get("startup_complete")) and Time.get_ticks_msec() < deadline:
		await process_frame
	if not bool(app.get("startup_complete")): failures += 1
	app.call("_show_screen", "tracks")
	world = root.get_node("AudioWorld")
	world.apply_settings({})
	world.app_suspended = false
	world.menu_player.stream_paused = false
	world.menu_player.stop()
	world.menu_gain = 0.0
	world.menu_player.volume_db = -80.0
	recorder.format = AudioStreamWAV.FORMAT_16_BITS
	var bus: int = AudioServer.get_bus_index("Music")
	AudioServer.add_bus_effect(bus, recorder)
	recorder.set_recording_active(true)
	world.show_menu()
	var started: int = Time.get_ticks_msec()
	var previous_position: float = 0.0
	var wraps: int = 0
	var next_navigation: float = 5.0
	var navigation: int = 0
	var pages: Array[String] = ["garage", "settings", "account", "tracks"]
	while Time.get_ticks_msec() - started < 71000:
		var elapsed: float = (Time.get_ticks_msec() - started) / 1000.0
		# Other automated windows can steal focus; retain explicit foreground playback.
		world.app_suspended = false
		world.menu_player.stream_paused = false
		var position: float = world.menu_player.get_playback_position()
		if position < previous_position - 1.0: wraps += 1
		previous_position = position
		trace.append({"elapsed": elapsed, "position": position, "screen": app.get("screen"), "mix_time": AudioServer.get_time_since_last_mix()})
		if navigation < pages.size() and elapsed >= next_navigation:
			app.call("_show_screen", pages[navigation])
			navigation += 1
			next_navigation += 5.0
		await create_timer(0.04).timeout
	if wraps != 2: failures += 1
	recorder.set_recording_active(false)
	await create_timer(0.1).timeout
	if recorder.get_recording().save_to_wav(output.path_join("menu-" + phase + ".wav")) != OK: failures += 1
	var report := FileAccess.open(output.path_join("runtime-" + phase + ".json"), FileAccess.WRITE)
	report.store_string(JSON.stringify({"wraps": wraps, "navigation": navigation, "failures": failures, "trace": trace}, "\t"))
	report.close()
	world.menu_player.stream_paused = false
	world.menu_player.stop()
	world.mode = "silent"
	world.menu_target = 0.0
	AudioServer.remove_bus_effect(bus, AudioServer.get_bus_effect_count(bus) - 1)
	root.remove_child(app)
	app.queue_free()
	await create_timer(0.2).timeout
	print("MENU_CONTINUITY_CAPTURE: 2 natural wraps, %d navigations, %d failures" % [navigation, failures])
	quit(1 if failures else 0)
