extends SceneTree
## Musical timing, real app/lifecycle wiring, saved settings and simulation separation.
var checks: int = 0
var failures: int = 0
var EVIDENCE: String = "res://../docs/evidence/locked-in-score-2026-10-07"
var app: Node


func _initialize() -> void: call_deferred("run")


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		print("FAIL: " + message)


func run() -> void:
	var evidence_override: String = OS.get_environment("BMT_MUSIC_EVIDENCE")
	if not evidence_override.is_empty(): EVIDENCE = evidence_override
	OS.set_environment("BMT_API_URL", "")
	var world: GameSoundtrack = root.get_node("AudioWorld")
	world.app_suspended = false
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(world.BANK + "manifest.json"))
	check(manifest.outputs.size() == 37 and manifest.packages.size() == 5, "five band palettes, shared menu/events and activation-only interface sounds")
	check(not world.ui_streams.has("focus"), "hover/focus cue is absent")
	check(not manifest.approval.user_approved, "artistic acceptance is explicitly pending")
	for asset: Dictionary in manifest.outputs:
		check(FileAccess.get_sha256(world.BANK + asset.file) == asset.sha256, "traceable master export: " + asset.file)
		if asset.loop:
			var stream: AudioStream = load(world.BANK + asset.file)
			check(absf(stream.get_length() - float(asset.duration_seconds)) < 0.0001, "encoded musical length: " + asset.file)
			check(float(asset.seam_delta) < 0.008, "continuous encoded seam: " + asset.file)
			check(float(asset.mono_rms_ratio) > 0.85, "mono-safe score: " + asset.file)
		else:
			var sample: AudioStreamWAV = load(world.BANK + asset.file)
			check(sample.mix_rate == 44100 and (not sample.stereo if asset.role == "interface" else sample.stereo), "portable event/interface sound: " + asset.file)
	for package: Dictionary in manifest.packages:
		check(package.frames == 2116800 and package.bars == 32 and package.bpm == 160, "new performed score's exact racing grid: " + package.id)
		check(float(package.combined.peak_dbfs) < -5.5, "combined score retains headroom: " + package.id)
	var menu: AudioStreamOggVorbis = world.menu_player.stream
	var menu_manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/audio/menu_exploration_v1/manifest.json"))
	var menu_frames: int = int(menu_manifest.output.frames)
	check(FileAccess.get_sha256(world.MENU_ASSET.replace(".ogg", ".wav")) == menu_manifest.output.sha256, "owner-selected menu export is traceable")
	check(menu_frames == 4888591 and float(menu_manifest.output.seam_delta) < .008, "prepared source loop duration and seam remain pinned")
	check(menu.packet_sequence.sampling_rate == 44100, "compressed menu retains original sample rate")
	check(menu.loop and menu.loop_offset == 0.0 and absf(menu.get_length() - menu_frames / 44100.0) < 1.0 / 44100.0, "complete original menu duration with native Vorbis looping")
	var compression: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/audio/compressed/manifest.json"))
	var traceable: bool = false
	for asset: Dictionary in compression.outputs:
		if asset.encoded == "game/" + world.MENU_ASSET.trim_prefix("res://"):
			traceable = FileAccess.get_sha256(world.MENU_ASSET) == asset.encoded_sha256 and asset.master_sha256 == menu_manifest.output.sha256 and float(asset.snr_db) >= 30.0
	check(traceable, "compressed menu is pinned to unchanged master and measured quality")
	_test_progress(world)
	_test_qualities()
	_test_equivalence()
	await _test_lifecycle(world)
	await _test_settings(world)
	world.show_menu()
	world.apply_settings({})
	print("SOUNDTRACK_TESTS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func _test_progress(world: GameSoundtrack) -> void:
	var score := DrivingScoreProgress.new()
	world.progress = score
	world.gains = [1.0, 0.0, 0.0, 0.0, 0.0, 0.0]
	world.fade_from = world.gains.duplicate()
	world.last_bar = -1
	world.target_layer = 0
	world.fade_elapsed = 4.0
	var full_at: float = -1.0
	for tick: int in range(1, 90 * 120 + 1):
		score.advance(1.0 / 120.0, 1.0)
		if tick % 600 == 0: score.sector_completed(true)
		world.advance_arrangement(1.0 / 120.0, float(tick) / 120.0)
		if full_at < 0 and world.gains[5] > 0.999: full_at = float(tick) / 120.0
	check(full_at >= 59.8 and full_at <= 60.2, "perfect qualifying drive reaches full theme near 60s: %.3f" % full_at)
	check(score.earned_seconds == 56.0 and world.target_layer == 5, "exceptional final theme holds through a 90-second race")
	var before: float = score.earned_seconds
	score.advance(0.05, 1.0, 0.8)
	check(score.earned_seconds == before and score.recovery_seconds == 0.0 and score.wobble > 0.0, "minor contact keeps momentum and gives a small wobble")
	score.advance(0.05, 1.0, 10.0)
	check(score.earned_seconds > 25.0 and score.earned_seconds < before and score.confidence < 0.8 and score.recovery_seconds > 0.0, "major contact knocks down confidence without restarting the clock")
	var requested: int = score.requested_layer()
	world.advance_arrangement(0.1, 90.25)
	check(world.target_layer == 5, "contact does not cut instruments mid-bar")
	world.advance_arrangement(0.1, 92.0)
	check(world.target_layer == requested and world.gains[5] > 0.9, "next bar begins a smooth retreat")
	for i: int in range(40): world.advance_arrangement(0.1, 92.0 + i * 0.1)
	check(world.gains[0] == 1.0 and world.gains[5] < 0.001, "pulse remains continuous through a retreat")
	var imperfect := DrivingScoreProgress.new()
	for i: int in range(60 * 120): imperfect.advance(1.0 / 120.0, 0.6)
	check(imperfect.requested_layer() < 4, "imperfect driving does not receive a time-only finale")
	var idle_before: float = imperfect.earned_seconds
	imperfect.advance(10.0, 0.0)
	check(imperfect.earned_seconds < idle_before, "stopping gradually reduces momentum")
	for i: int in range(100):
		imperfect.advance(0.5, 1.0)
		if i % 10 == 0: imperfect.sector_completed(true)
	check(imperfect.requested_layer() == 5, "clean sectors rebuild exceptional confidence")
	imperfect.reset()
	check(imperfect.requested_layer() == 0, "retry starts at the composed foundation")
	var state := VehicleState.new()
	state.velocity = Vector2(0, 20)
	state.tick = 120
	imperfect.reset(state)
	state.tick = 240
	state.position.y += 20
	imperfect.observe(state, null, VehicleCatalog.config("compact"), null)
	var earned_before_rewind: float = imperfect.earned_seconds
	state.tick = 120
	imperfect.observe(state, null, VehicleCatalog.config("compact"), null)
	state.tick = 240
	imperfect.observe(state, null, VehicleCatalog.config("compact"), null)
	check(imperfect.earned_seconds == earned_before_rewind, "rewind keeps musical momentum without double-earning scrubbed time")


func _test_qualities() -> void:
	var track: NativeTrack = NativeTrack.read("res://resources/tracks/starter_circuit.json")
	var config: HandlingConfig = VehicleCatalog.config("compact")
	var state := VehicleState.new()
	state.position = track._race_route_point(20.0)
	var previous: Vector2 = track._race_route_point(19.0)
	var forward: Vector2 = (track._race_route_point(23.0) - track._race_route_point(17.0)).normalized()
	state.heading = atan2(forward.x, forward.y)
	state.velocity = forward * 25.0
	var session := TrackSession.new()
	check(DrivingScoreProgress.driving_quality(state, track, config, session, previous) > 0.99, "clean forward driving qualifies")
	state.velocity = Vector2.ZERO
	check(DrivingScoreProgress.driving_quality(state, track, config, session, previous) == 0.0, "stationary throttle cannot earn music")
	state.velocity = -forward * 15.0
	check(DrivingScoreProgress.driving_quality(state, track, config, session, previous) == 0.0, "wrong-way motion cannot earn music")
	state.velocity = forward * 25.0
	session.missed_checkpoint = 2
	check(DrivingScoreProgress.driving_quality(state, track, config, session, previous) == 0.0, "missing a road gate interrupts musical credit")
	session.missed_checkpoint = -1
	state.roll_ticks = 120
	check(DrivingScoreProgress.driving_quality(state, track, config, session, previous) == 0.0, "rolling car cannot earn music")
	state.roll_ticks = 0
	check(DrivingScoreProgress.driving_quality(state, track, config, session, state.position) == 0.0, "spinning without route movement cannot earn music")
	# Find an actual sharp bend and verify that braking to its lower expected speed still qualifies.
	var checked_bend: bool = false
	for i: int in range(track.route.size()):
		var at: float = track.route_cumulative[i]
		var direction: Vector2 = (track._race_route_point(at + 3.0) - track._race_route_point(at - 3.0)).normalized()
		var ahead: Vector2 = track._race_route_point(at + 12.0) - track._race_route_point(at + 3.0)
		var bend: float = absf(direction.angle_to(ahead.normalized()))
		if bend < 0.25: continue
		state.position = track._race_route_point(at)
		state.heading = atan2(direction.x, direction.y)
		state.velocity = direction * 11.5
		var good: float = DrivingScoreProgress.driving_quality(state, track, config, session, track._race_route_point(at - 1.0))
		check(good > 0.9, "slow legitimate corner earns musical progress")
		checked_bend = true
		break
	check(checked_bend, "corner qualification uses real track geometry")


func _test_equivalence() -> void:
	var track: NativeTrack = NativeTrack.read("res://resources/tracks/starter_circuit.json")
	var config: HandlingConfig = VehicleCatalog.config("compact")
	var plain := VehicleSimulation.new(config)
	var observed := VehicleSimulation.new(config)
	plain.reset(track.spawn, track.spawn_heading)
	observed.reset(track.spawn, track.spawn_heading)
	var music := DrivingScoreProgress.new()
	music.reset(observed.state)
	for i: int in range(960):
		var input: DriveFrame = DriveFrame.sample(sin(float(i) / 90.0) * 0.4, 0.8, 0.0)
		plain.step(input, track)
		observed.step(input, track)
		var packed: Array = input.packed()
		music.observe(observed.state, track, config, null)
		check(observed.state.snapshot() == plain.state.snapshot() and input.packed() == packed, "music leaves canonical state/input identical at tick %d" % i)


func _test_lifecycle(world: GameSoundtrack) -> void:
	world.show_menu()
	var game: Node = load("res://core/game.tscn").instantiate()
	game.initial_track = NativeTrack.read("res://resources/tracks/starter_circuit.json")
	game.production_mode = true
	root.add_child(game)
	game.set_physics_process(false)
	check(world.is_race_owner(game) and world.mode == "race", "actual race owns its silent music context")
	check(world.synced == null and world.race_player.stream == null, "race allocates no biome score decoders")
	check(not world.race_player.playing and not world.menu_player.playing, "race has no score or menu fade leakage")
	game._process(0.0)
	check(world.progress.earned_seconds == 0, "countdown earns no progress")
	game.paused = true
	game._process(0.0)
	check(world.blocked, "pause suspends music progression")
	if world.output_enabled: check(world.race_player.stream_paused and world.menu_player.stream_paused, "pause suspends both real music players")
	game.paused = false
	game.countdown_ticks = 0
	game._process(0.0)
	check(not world.race_player.stream_paused, "resume continues the existing clock")
	world.progress.earned_seconds = 44.0
	game.restart()
	check(world.progress.earned_seconds == 0 and world.gains[4] == 0, "actual retry resets only this score")
	game._begin_finish()
	game._process(0.0)
	check(world.mode == "race" and world.menu_target == 0.0 and not world.menu_player.playing, "finish coast remains silent until actual result UI")
	world.results_feedback(0.0,false)
	check(world.mode == "menu" and world.menu_target == 1.0, "actual results restore menu music")
	world.begin_race(game, "desert", game.sim.state)
	check(world.family == "desert", "desert chooses its dry/tremolo band palette")
	root.remove_child(game)
	game.queue_free()
	await process_frame
	check(world.mode == "menu", "leaving a live race returns to the menu score")
	check(world.ui_players.size() == 3 and world.get_child_count() == 6, "music, one event voice and UI voices remain bounded")


func _test_settings(world: GameSoundtrack) -> void:
	var directory: String = "user://soundtrack_test_" + TrackLibrary.unique_id()
	DirAccess.make_dir_recursive_absolute(directory)
	app = load("res://core/app.tscn").instantiate()
	app.records = LocalRecords.new(directory.path_join("records.json"))
	app.library = TrackLibrary.new(directory.path_join("tracks"))
	root.add_child(app)
	while not app.startup_complete: await process_frame
	app._show_screen("settings")
	await process_frame
	var page: SettingsPage = app.root_ui.find_child("SettingsPage", true, false)
	check(page != null and page.categories.has("audio"), "Audio is reachable from actual Settings")
	page._show_section("audio")
	await process_frame
	for key: String in world.DEFAULTS:
		var slider: HSlider = page.find_child("AudioVolume_" + key, true, false)
		check(slider != null and slider.step == 1.0 and slider.custom_minimum_size.y >= 52, "reachable precise volume control: " + key)
	(page.find_child("AudioVolume_music_volume", true, false) as HSlider).value = 0
	(page.find_child("AudioVolume_interface_volume", true, false) as HSlider).value = 31
	check(page._apply(), "audio preferences save through atomic local records")
	var reload := LocalRecords.new(app.records.path)
	reload.load_records()
	check(float(reload.settings.music_volume) == 0 and float(reload.settings.interface_volume) == 0.31, "audio levels survive reload")
	check(AudioServer.is_bus_mute(AudioServer.get_bus_index("Music")) and not AudioServer.is_bus_mute(AudioServer.get_bus_index("Vehicle")), "music mute preserves vehicle feedback")
	page._reset()
	check(page.draft_audio == world.DEFAULTS, "Reset audio restores only the audio defaults")
	check(page._apply(), "reset audio applies")
	var button: Button = page.find_child("ApplySettings", true, false)
	check(button.has_meta("audio_world_wired"), "new menu buttons automatically receive audio")
	for voice: AudioStreamPlayer in world.ui_players: voice.stop()
	var cursor_before: int = world._ui_cursor
	button.mouse_entered.emit()
	button.focus_entered.emit()
	world.play_ui("focus")
	await process_frame
	check(world._ui_cursor == cursor_before, "hover and keyboard focus do not request sound voices")
	if world.output_enabled: check(world.ui_players.all(func(voice: AudioStreamPlayer) -> bool: return not voice.playing), "actual hover/focus output remains silent")
	# This programmatic fixture may run while another desktop window has focus.
	# Actual background suppression remains covered by the lifecycle checks.
	world.app_suspended = false
	world._last_press_ms = -1000
	button.button_down.emit()
	if world.output_enabled: check(world.ui_players.any(func(voice: AudioStreamPlayer) -> bool: return voice.playing), "activation plays real interface feedback before navigation")
	var touch := TouchControls.new()
	var quiet_button := Button.new()
	touch.add_child(quiet_button)
	root.add_child(touch)
	check(not world._button_allowed(quiet_button), "steering controls do not emit menu clicks")
	root.remove_child(touch)
	touch.queue_free()
	if DisplayServer.get_name() != "headless":
		for dimensions: Vector2i in [Vector2i(1280,720), Vector2i(960,540)]:
			root.size = dimensions
			await process_frame
			await RenderingServer.frame_post_draw
			var path: String = EVIDENCE.path_join("settings-audio-%dx%d.png" % [dimensions.x, dimensions.y])
			check(root.get_texture().get_image().save_png(path) == OK, "actual Audio settings screenshot")
	root.remove_child(app)
	app.queue_free()
	await process_frame
