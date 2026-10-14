extends SceneTree
## Native Music-bus wrap/pause/mute evidence for the owner-selected menu recording.
const OUT: String = "res://../docs/evidence/media-compression-2026-10-12/menu-native"
var checks: int = 0
var failures: int = 0
var keep_active: bool = false

func hold_capture_focus() -> void:
	if keep_active:
		var world: GameSoundtrack = GameSoundtrack.instance()
		world.app_suspended = false
		world.menu_player.stream_paused = false

func _initialize() -> void:
	process_frame.connect(hold_capture_focus)
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: " + message)

func run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Native capture requires -Graphical")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var world: GameSoundtrack = GameSoundtrack.instance()
	world.app_suspended = false
	world.apply_settings({})
	world.show_menu()
	world._process(1.0)
	var bus: int = AudioServer.get_bus_index("Music")
	var record := AudioEffectRecord.new()
	record.format = AudioStreamWAV.FORMAT_16_BITS
	AudioServer.add_bus_effect(bus, record)
	keep_active = true
	for pass_id: int in range(2):
		world.app_suspended = false
		world.menu_player.stream_paused = false
		world.menu_player.seek(world.menu_player.stream.get_length() - 3.0)
		await create_timer(.15).timeout
		record.set_recording_active(true)
		var previous: float = world.menu_player.get_playback_position()
		var wrapped: bool = false
		for tick: int in range(120):
			# Automation may lose desktop focus to another window during capture.
			world.app_suspended = false
			world.menu_player.stream_paused = false
			await create_timer(.05).timeout
			var position: float = world.menu_player.get_playback_position()
			if position < previous - 1.0: wrapped = true
			previous = position
		check(wrapped and world.menu_player.playing, "native compressed loop wraps continuously: %d" % pass_id)
		record.set_recording_active(false)
		check(record.get_recording().save_to_wav(OUT.path_join("godot-wrap-%d.wav" % pass_id)) == OK, "saved native wrap capture")
	keep_active = false
	world._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(world.menu_player.stream_paused, "focus loss pauses menu")
	world._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	check(not world.menu_player.stream_paused, "focus return resumes menu")
	world.apply_settings({"music_volume": 0.0})
	check(AudioServer.is_bus_mute(bus), "music setting mutes menu")
	# Music-bus effects see input before its mute; record the delivered Master.
	AudioServer.remove_bus_effect(bus, AudioServer.get_bus_effect_count(bus) - 1)
	AudioServer.add_bus_effect(0, record)
	await create_timer(.2).timeout
	record.set_recording_active(true)
	await create_timer(.4).timeout
	record.set_recording_active(false)
	var silence: AudioStreamWAV = record.get_recording()
	var peak: int = 0
	for i: int in range(0, silence.data.size(), 2): peak = maxi(peak, absi(silence.data.decode_s16(i)))
	check(peak == 0, "native muted Music bus is exactly silent")
	check(silence.save_to_wav(OUT.path_join("godot-muted.wav")) == OK, "saved mute capture")
	AudioServer.remove_bus_effect(0, AudioServer.get_bus_effect_count(0) - 1)
	world.menu_player.stop()
	world.apply_settings({})
	world.menu_player.stop()
	world.menu_player.stream = null
	record = null
	await process_frame
	await process_frame
	print("MENU_EXPLORATION_CAPTURE: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)
