extends SceneTree
## Actual Godot mixer recordings. Qualifying signals are scripted, not a claimed perfect replay.
const OUTPUT: String = "res://../docs/evidence/adaptive-score-2026-10-07"
var checks: int = 0
var failures: int = 0
var world: GameSoundtrack
var master_record := AudioEffectRecord.new()
var music_record := AudioEffectRecord.new()
var trace: Array[Dictionary] = []
var caption: Label


func _initialize() -> void: call_deferred("run")


func check(value: bool, description: String) -> void:
	checks += 1
	if not value:
		failures += 1
		print("FAIL: " + description)


func run() -> void:
	if DisplayServer.get_name() == "headless": push_error("Real mixer capture requires -Graphical"); quit(1); return
	world = root.get_node("AudioWorld")
	world.apply_settings({})
	world.app_suspended = false
	var panel := ColorRect.new()
	panel.color = MenuStyle.INK
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(panel)
	caption = MenuStyle.label("Soundtrack verification", 36)
	caption.position = Vector2(70, 100)
	panel.add_child(caption)
	master_record.format = AudioStreamWAV.FORMAT_16_BITS
	music_record.format = AudioStreamWAV.FORMAT_16_BITS
	AudioServer.add_bus_effect(0, master_record)
	AudioServer.add_bus_effect(AudioServer.get_bus_index("Music"), music_record)
	world.show_menu()
	_start_recording()
	caption.text = "Workshop theme — recording one complete loop"
	var menu_start: int = Time.get_ticks_msec()
	var wrapped: bool = false
	var last_position: float = 0.0
	while Time.get_ticks_msec() - menu_start < 88500:
		world.app_suspended = false
		world.menu_player.stream_paused = false
		var position: float = world.menu_player.get_playback_position()
		if position < last_position - 1.0: wrapped = true
		last_position = position
		await create_timer(0.05).timeout
	check(wrapped, "actual menu player wraps its complete 85.33s loop")
	await _save_recording("godot-menu-loop")
	var owner := Node.new()
	root.add_child(owner)
	world.begin_race(owner, "pine", VehicleState.new())
	_start_recording()
	caption.text = "Open Horizon — clean driving development to 60 seconds"
	var started: int = Time.get_ticks_msec()
	var previous: float = 0.0
	var next_trace: int = 0
	var reached_full: float = -1.0
	wrapped = false
	last_position = 0.0
	while Time.get_ticks_msec() - started < 90500:
		world.app_suspended = false
		world.race_player.stream_paused = false
		var elapsed: float = float(Time.get_ticks_msec() - started) / 1000.0
		world.progress.advance(elapsed - previous, 1.0)
		previous = elapsed
		var position: float = world.race_player.get_playback_position()
		if position < last_position - 1.0: wrapped = true
		last_position = position
		if world.gains[4] > 0.999 and reached_full < 0.0: reached_full = elapsed
		if elapsed >= next_trace:
			trace.append({"time": elapsed, "position": position, "earned": world.progress.earned_seconds,
				"target": world.target_layer, "gains": world.gains.duplicate()})
			next_trace += 1
		await create_timer(0.04).timeout
	check(reached_full >= 59.0 and reached_full < 63.0, "actual output reaches full theme near one minute: %.3f" % reached_full)
	check(wrapped, "synchronized race stream wraps its 64-second loop")
	await _save_recording("godot-horizon-clean")
	# Hold the fuller desert arrangement alongside the real vehicle sound model.
	world.begin_race(owner, "desert", VehicleState.new())
	world.progress.earned_seconds = 56.0
	var vehicle := VehicleAudio.new()
	root.add_child(vehicle)
	var config: HandlingConfig = VehicleCatalog.config("compact")
	vehicle.configure("compact", config)
	var state := VehicleState.new()
	var input: DriveFrame = DriveFrame.sample(0.1, 0.8, 0.0)
	_start_recording()
	caption.text = "First Light — full arrangement with car sounds and collision recovery"
	started = Time.get_ticks_msec()
	previous = 0.0
	var collided: bool = false
	while Time.get_ticks_msec() - started < 19000:
		var elapsed: float = float(Time.get_ticks_msec() - started) / 1000.0
		var delta: float = elapsed - previous
		previous = elapsed
		world.app_suspended = false
		world.race_player.stream_paused = false
		state.tick = roundi(elapsed * 120.0)
		state.velocity = Vector2(1.0 + sin(elapsed), 17.0 + 7.0 * sin(elapsed * 0.5))
		vehicle.present(state, input, null, delta, false)
		world.progress.advance(delta, 1.0)
		if elapsed >= 8.0 and not collided:
			world.progress.advance(0.001, 1.0, 10.0)
			vehicle.collision(Vector2(10.0,0.0))
			collided = true
		await create_timer(0.04).timeout
	vehicle.present(state, input, null, 0.01, true)
	world.present_race(owner, state, null, config, null, true, false, false)
	await create_timer(0.75).timeout
	await _save_recording("godot-daybreak-car-recovery")
	root.remove_child(vehicle)
	vehicle.queue_free()
	world.show_menu()
	world.menu_target = 0.0
	await create_timer(1.0).timeout
	_start_recording()
	caption.text = "Menu sounds — focus, selection, confirmation, back"
	for cue: String in ["focus", "select", "confirm", "back"]:
		world.app_suspended = false
		world.play_ui(cue)
		await create_timer(0.9).timeout
	await _save_recording("godot-interface")
	root.remove_child(owner)
	owner.queue_free()
	AudioServer.remove_bus_effect(0, AudioServer.get_bus_effect_count(0) - 1)
	var music_bus: int = AudioServer.get_bus_index("Music")
	AudioServer.remove_bus_effect(music_bus, AudioServer.get_bus_effect_count(music_bus) - 1)
	var report := FileAccess.open(OUTPUT.path_join("runtime-trace.json"), FileAccess.WRITE)
	report.store_string(JSON.stringify({"source": "actual Godot output with scripted qualifying signals",
		"full_at_seconds": reached_full, "trace": trace, "checks": checks, "failures": failures}, "\t"))
	report.close()
	world.race_player.stop()
	world.menu_player.stop()
	await create_timer(0.1).timeout
	print("SOUNDTRACK_CAPTURE: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func _start_recording() -> void:
	master_record.set_recording_active(true)
	music_record.set_recording_active(true)


func _save_recording(label: String) -> void:
	master_record.set_recording_active(false)
	music_record.set_recording_active(false)
	await create_timer(0.1).timeout
	check(master_record.get_recording().save_to_wav(OUTPUT.path_join(label + ".wav")) == OK, "saved actual master output: " + label)
	check(music_record.get_recording().save_to_wav(OUTPUT.path_join(label + "-music.wav")) == OK, "saved isolated music bus: " + label)
	print("CAPTURED " + label)
