extends SceneTree
## Real mixer output, explicitly scripted confidence/sector/PB signals and car bed.
var OUTPUT: String = "res://../docs/evidence/locked-in-score-2026-10-07"
var world: GameSoundtrack
var master_record := AudioEffectRecord.new()
var music_record := AudioEffectRecord.new()
var checks: int = 0
var failures: int = 0
var trace: Array[Dictionary] = []
var segment: String = OS.get_environment("BMT_SCORE_CAPTURE_SEGMENT")


func _initialize() -> void: call_deferred("run")


func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures += 1; print("FAIL: " + message)


func run() -> void:
	var evidence_override: String = OS.get_environment("BMT_MUSIC_EVIDENCE")
	if not evidence_override.is_empty(): OUTPUT = evidence_override
	if DisplayServer.get_name() == "headless": push_error("Capture needs -Graphical"); quit(1); return
	world = root.get_node("AudioWorld")
	world.apply_settings({})
	world.app_suspended = false
	var background := ColorRect.new()
	background.color = MenuStyle.INK
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(background)
	var caption: Label = MenuStyle.label("The music locks in with you - actual mixer capture", 30)
	caption.position = Vector2(60,80)
	background.add_child(caption)
	master_record.format = AudioStreamWAV.FORMAT_16_BITS
	music_record.format = AudioStreamWAV.FORMAT_16_BITS
	AudioServer.add_bus_effect(0, master_record)
	AudioServer.add_bus_effect(AudioServer.get_bus_index("Music"), music_record)
	world.show_menu()
	_start()
	var started: int = Time.get_ticks_msec()
	var previous_position: float = 0.0
	var wrapped: bool = false
	while segment in ["", "menu"] and Time.get_ticks_msec() - started < 42000:
		world.app_suspended = false
		world.menu_player.stream_paused = false
		var position: float = world.menu_player.get_playback_position()
		if position < previous_position - 1: wrapped = true
		previous_position = position
		await create_timer(0.05).timeout
	if segment in ["", "menu"]:
		check(wrapped, "actual guitar menu loop wraps at 34.286s")
		await _save("godot-menu")
	else: master_record.set_recording_active(false); music_record.set_recording_active(false)
	var owner := Node.new()
	root.add_child(owner)
	var state := VehicleState.new()
	var config: HandlingConfig = VehicleCatalog.config("compact")
	var vehicle := VehicleAudio.new()
	root.add_child(vehicle)
	vehicle.configure("compact", config)
	var input: DriveFrame = DriveFrame.sample(0.05,0.8,0.0)
	world.begin_race(owner,"pine",state)
	_start()
	started = Time.get_ticks_msec()
	var previous: float = 0.0
	var sector_time: float = 5.0
	var trace_time: float = 0.0
	var full_at: float = -1.0
	var breath_requested: bool = false
	previous_position = 0.0
	wrapped = false
	while segment in ["", "story"] and Time.get_ticks_msec() - started < 90500:
		var elapsed: float = float(Time.get_ticks_msec() - started) / 1000.0
		var delta: float = elapsed - previous
		previous = elapsed
		world.app_suspended = false
		world.race_player.stream_paused = false
		world.event_player.stream_paused = false
		world.progress.advance(delta,1.0)
		if elapsed >= sector_time: world.progress.sector_completed(true); sector_time += 5.0
		if elapsed >= 70.0 and not breath_requested:
			world.breath_queued = true
			breath_requested = true
		state.tick = roundi(elapsed * 120)
		state.velocity = Vector2(0.8,20.0+2.0*sin(elapsed*.4))
		vehicle.present(state,input,null,delta,false)
		if world.gains[5] > 0.999 and full_at < 0: full_at = elapsed
		var position: float = world.race_player.get_playback_position()
		if position < previous_position - 1: wrapped = true
		previous_position = position
		if elapsed >= trace_time:
			trace.append({"time":elapsed,"position":position,"confidence":world.progress.confidence,"sectors":world.progress.clean_sectors,"layer":world.target_layer,"gains":world.gains.duplicate(),"breath":world.breath_elapsed,"music_db":world.race_player.volume_db})
			trace_time += 0.25
		await create_timer(0.035).timeout
	if segment in ["", "story"]:
		check(full_at >= 59 and full_at < 63,"recorded exceptional payoff near one minute: %.3f" % full_at)
		check(wrapped and world.breath_count == 1,"race wraps and one scripted PB breath plays")
		var story_report := FileAccess.open(OUTPUT.path_join("runtime-trace.json"),FileAccess.WRITE)
		story_report.store_string(JSON.stringify({"source":"actual Godot mixer with scripted clean sectors/PB signals and recorded-car model","full_at_seconds":full_at,"trace":trace,"checks":checks,"failures":failures},"\t"))
		story_report.close()
		await _save("godot-flow-story")
	else: master_record.set_recording_active(false); music_record.set_recording_active(false)
	vehicle.present(state,input,null,0.01,true)
	for biome: String in (TrackTheme.IDS if segment in ["", "palettes"] else []):
		world.begin_race(owner,biome,state)
		world.progress.confidence = 1.0
		world.progress.clean_sectors = 4
		world.progress.clean_seconds = 20.0
		world.progress.earned_seconds = 56.0
		_start()
		started = Time.get_ticks_msec()
		while Time.get_ticks_msec() - started < 10000:
			world.app_suspended = false
			world.race_player.stream_paused = false
			await create_timer(.04).timeout
		world.blocked = true
		world.race_player.stream_paused = true
		world.menu_player.stream_paused = true
		await create_timer(.65).timeout
		await _save("godot-palette-"+biome)
	if segment in ["", "events"]:
		world.show_menu()
		world.results_feedback(.08,true)
		_start()
		await create_timer(4.8).timeout
		check(world.event_kind == "personal_best","recorded 0.08s improvement selects the PB resolution")
		await _save("godot-pb-80ms")
		world.menu_target = 0
		await create_timer(1.0).timeout
		_start()
		world.play_ui("focus")
		await create_timer(1.0).timeout
		for cue: String in ["select","confirm","back"]:
			world.play_ui(cue)
			await create_timer(.9).timeout
		await _save("godot-interface")
	world._exiting = true
	world.race_owner = null
	world.mode = "silent"
	world.blocked = false
	world.menu_target = 0.0
	world.race_target = 0.0
	world.menu_player.stream_paused = false
	world.race_player.stream_paused = false
	world.menu_player.stop(); world.race_player.stop(); world.event_player.stop()
	world.menu_player.stream = null
	world.race_player.stream = null
	world.event_player.stream = null
	world.synced = null
	AudioServer.remove_bus_effect(0,AudioServer.get_bus_effect_count(0)-1)
	var music_bus: int = AudioServer.get_bus_index("Music")
	AudioServer.remove_bus_effect(music_bus,AudioServer.get_bus_effect_count(music_bus)-1)
	root.remove_child(owner); owner.queue_free()
	root.remove_child(vehicle); vehicle.queue_free()
	await create_timer(.15).timeout
	print("LOCKED_IN_CAPTURE: %d checks, %d failures" % [checks,failures])
	quit(1 if failures>0 else 0)


func _start() -> void:
	master_record.set_recording_active(true)
	music_record.set_recording_active(true)


func _save(label: String) -> void:
	master_record.set_recording_active(false)
	music_record.set_recording_active(false)
	await create_timer(.1).timeout
	check(master_record.get_recording().save_to_wav(OUTPUT.path_join(label+".wav"))==OK,"saved actual master: "+label)
	check(music_record.get_recording().save_to_wav(OUTPUT.path_join(label+"-music.wav"))==OK,"saved actual music: "+label)
	print("CAPTURED "+label)
