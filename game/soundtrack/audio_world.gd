class_name GameSoundtrack
extends Node
## Recorded music and interface feedback, entirely outside canonical simulation.
const BANK: String = "res://assets/audio/locked_in_v1/"
const MENU_ASSET: String = "res://assets/audio/menu_exploration_v1/exploration_menu_loop.wav"
const LAYERS: Array[String] = ["pulse", "lock", "groove", "hook", "wide", "soar"]
const DEFAULTS: Dictionary = {"music_volume": 0.7, "vehicle_volume": 1.0, "interface_volume": 0.7}
const BPM: float = 160.0
const BAR_SECONDS: float = 240.0 / BPM
const FADE_SECONDS: float = BAR_SECONDS * 2.0
var menu_player: AudioStreamPlayer
var race_player: AudioStreamPlayer
var event_player: AudioStreamPlayer
var ui_players: Array[AudioStreamPlayer] = []
var ui_streams: Dictionary = {}
var synced: AudioStreamSynchronized
var progress := DrivingScoreProgress.new()
var race_owner: WeakRef
var mode: String = "silent"
var family: String = "pine"
var gains: Array[float] = [1.0, 0.0, 0.0, 0.0, 0.0, 0.0]
var fade_from: Array[float] = [1.0, 0.0, 0.0, 0.0, 0.0, 0.0]
var target_layer: int = 0
var fade_elapsed: float = FADE_SECONDS
var last_bar: int = -1
var menu_gain: float = 0.0
var race_gain: float = 0.0
var menu_target: float = 0.0
var race_target: float = 0.0
var blocked: bool = false
var app_suspended: bool = false
var _ui_cursor: int = 0
var _last_press_ms: int = -1000
var _exiting: bool = false
var output_enabled: bool = true
var personal_reference := ScorePaceReference.new()
var rival_reference := ScorePaceReference.new()
var pace_configured: bool = false
var breath_queued: bool = false
var breath_elapsed: float = -1.0
var breath_count: int = 0
var retreat_wait: float = 0.0
var event_kind: String = ""
var event_elapsed: float = 0.0
var event_length: float = 0.0
var results_improvement: float = 0.0


static func instance() -> GameSoundtrack:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	return tree.root.get_node("AudioWorld") as GameSoundtrack


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Headless verifier/tests have no output device; do not allocate decoder playbacks there.
	output_enabled = DisplayServer.get_name() != "headless"
	menu_player = _player("MenuScore", "Music")
	menu_player.stream = _menu_loop()
	menu_player.volume_db = -80.0
	race_player = _player("RaceScore", "Music")
	race_player.volume_db = -80.0
	event_player = _player("MusicalEvent", "Music")
	for cue: String in ["select", "confirm", "back"]:
		ui_streams[cue] = load(BANK + "ui_" + cue + ".wav")
	for i: int in range(3): ui_players.append(_player("InterfaceVoice%d" % i, "Interface"))
	apply_settings({})
	get_tree().node_added.connect(_node_added)
	_scan_buttons(get_tree().root)


func _player(label: String, bus_name: String) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = label
	player.bus = bus_name
	add_child(player)
	return player


func _loop(file: String) -> AudioStreamOggVorbis:
	var stream: AudioStreamOggVorbis = load(BANK + file).duplicate()
	stream.loop = true
	stream.loop_offset = 0.0
	return stream


func _menu_loop() -> AudioStreamWAV:
	return PcmAudioLoop.prepare(load(MENU_ASSET) as AudioStreamWAV)


func apply_settings(settings: Dictionary) -> void:
	for item: Array in [["Music", "music_volume"], ["Vehicle", "vehicle_volume"], ["Impacts", "vehicle_volume"], ["Interface", "interface_volume"]]:
		var level: float = preference(settings, item[1])
		var index: int = AudioServer.get_bus_index(item[0])
		if index < 0: continue
		AudioServer.set_bus_volume_db(index, linear_to_db(maxf(level, 0.0001)))
		AudioServer.set_bus_mute(index, level <= 0.0)


static func preference(settings: Dictionary, key: String) -> float:
	var value: Variant = settings.get(key, DEFAULTS.get(key, 1.0))
	if not (value is float or value is int) or not is_finite(float(value)): return float(DEFAULTS.get(key, 1.0))
	return clampf(float(value), 0.0, 1.0)


func show_menu() -> void:
	if _exiting: return
	mode = "menu"
	race_owner = null
	blocked = false
	menu_target = 1.0
	race_target = 0.0
	menu_player.stream_paused = app_suspended
	race_player.stream_paused = app_suspended
	if output_enabled and not menu_player.playing: menu_player.play()


func begin_race(owner: Node, theme: String, state: VehicleState) -> void:
	# Owner removed background music from every driving biome, including practice.
	race_player.stream_paused = false
	race_player.stop()
	race_player.stream = null
	synced = null
	menu_player.stop()
	menu_gain = 0.0
	race_owner = weakref(owner)
	mode = "race"
	blocked = false
	menu_target = 0.0
	race_target = 0.0
	family = theme if theme in TrackTheme.IDS else "pine"
	progress.reset(state)
	gains = [1.0, 0.0, 0.0, 0.0, 0.0, 0.0]
	fade_from = gains.duplicate()
	target_layer = 0
	fade_elapsed = FADE_SECONDS
	last_bar = -1
	pace_configured = false
	personal_reference = ScorePaceReference.new()
	rival_reference = ScorePaceReference.new()
	breath_queued = false
	breath_elapsed = -1.0
	breath_count = 0
	retreat_wait = 0.0
	event_kind = ""
	event_player.stop()
	event_player.stream = null
	race_player.stream_paused = app_suspended
	race_gain = 0.0
	race_player.volume_db = -80.0


func is_race_owner(owner: Node) -> bool:
	return race_owner != null and race_owner.get_ref() == owner


func present_race(owner: Node, _state: VehicleState, _track: NativeTrack, _config: HandlingConfig, _session: TrackSession, paused: bool, _countdown: bool, _finished: bool, _context: Dictionary = {}) -> void:
	if not is_race_owner(owner): return
	blocked = paused
	race_player.stream_paused = paused or app_suspended
	menu_player.stream_paused = paused or app_suspended or menu_gain <= 0.0
	event_player.stream_paused = paused or app_suspended
	# Stay silent through countdown, driving, rewind and the finish coast.


func leave_race(owner: Node) -> void:
	if is_race_owner(owner): show_menu()


func notify_collision(owner: Node, strength: float) -> void:
	if is_race_owner(owner): progress.notify_impact(strength)


func _process(delta: float) -> void:
	if app_suspended: return
	if race_owner != null and race_owner.get_ref() == null: show_menu()
	if blocked: return
	event_elapsed += delta
	if event_player.playing:
		var tail: float = minf(1.0, maxf(0.0, event_length - event_elapsed) / 0.15)
		event_player.volume_db = linear_to_db(maxf(0.0001, tail * (0.6 if event_kind == "breath" else 1.0)))
	var event_duck: float = 0.30 if event_player.playing and event_kind != "breath" else 1.0
	menu_gain = move_toward(menu_gain, menu_target, delta / 0.85)
	race_gain = move_toward(race_gain, race_target, delta / 0.85)
	menu_player.volume_db = linear_to_db(maxf(menu_gain * event_duck, 0.0001))
	var breath_gain: float = 1.0
	if breath_elapsed >= 0.0:
		breath_elapsed += delta
		if breath_elapsed < 0.08: breath_gain = 1.0 - smoothstep(0.0, 0.08, breath_elapsed)
		elif breath_elapsed < 120.0 / BPM: breath_gain = 0.0
		elif breath_elapsed < 120.0 / BPM + 0.18: breath_gain = smoothstep(120.0 / BPM, 120.0 / BPM + 0.18, breath_elapsed)
		else: breath_elapsed = -1.0
	var wobble_gain: float = 1.0 - progress.wobble * 0.07
	race_player.volume_db = linear_to_db(maxf(race_gain * breath_gain * event_duck * wobble_gain, 0.0001))
	if menu_gain == 0.0 and menu_target == 0.0: menu_player.stream_paused = true
	if menu_target > 0.0: menu_player.stream_paused = false
	if race_gain == 0.0 and race_target == 0.0 and race_player.playing: race_player.stop()
	if mode != "race" or not race_player.playing: return
	advance_arrangement(delta, race_player.get_playback_position())


func advance_arrangement(delta: float, playback_seconds: float) -> void:
	var bar: int = floori(playback_seconds / BAR_SECONDS)
	if bar != last_bar:
		last_bar = bar
		var requested: int = progress.requested_layer()
		if requested < target_layer and progress.recovery_seconds <= 0.0:
			retreat_wait += BAR_SECONDS
			if retreat_wait < 4.0: requested = target_layer
		else: retreat_wait = 0.0
		if breath_queued and breath_elapsed < 0.0:
			breath_queued = false
			breath_elapsed = 0.0
			breath_count += 1
			play_musical_event("breath")
		if requested != target_layer:
			target_layer = requested
			fade_from = gains.duplicate()
			fade_elapsed = 0.0
	fade_elapsed = minf(FADE_SECONDS, fade_elapsed + delta)
	var blend: float = smoothstep(0.0, FADE_SECONDS, fade_elapsed)
	for i: int in range(LAYERS.size()):
		gains[i] = lerpf(fade_from[i], 1.0 if i <= target_layer else 0.0, blend)
		if synced != null: synced.set_sync_stream_volume(i, linear_to_db(maxf(gains[i], 0.0001)))


func play_musical_event(kind: String) -> void:
	if kind not in ["finish", "personal_best", "breath"]: return
	if kind == "breath" and mode == "race": return
	event_kind = kind
	event_elapsed = 0.0
	event_player.stream = load(BANK + kind + ".wav")
	event_length = event_player.stream.get_length()
	event_player.stream_paused = app_suspended or blocked
	if output_enabled: event_player.play()


func results_feedback(improvement_seconds: float, eligible: bool) -> void:
	# The actual summary, rather than the in-world finish coast, restores menus.
	if mode == "race": show_menu()
	results_improvement = improvement_seconds if is_finite(improvement_seconds) else 0.0
	play_musical_event("personal_best" if eligible and results_improvement > 0.0005 else "finish")


func play_ui(cue: String = "select") -> void:
	if not output_enabled or app_suspended or not ui_streams.has(cue): return
	var now: int = Time.get_ticks_msec()
	if now - _last_press_ms < 65: return
	_last_press_ms = now
	var player: AudioStreamPlayer = ui_players[_ui_cursor]
	_ui_cursor = (_ui_cursor + 1) % ui_players.size()
	player.stream = ui_streams[cue]
	player.volume_db = -3.0
	player.play()


func _node_added(node: Node) -> void:
	if node is BaseButton: _wire_button_id.call_deferred(node.get_instance_id())


func _wire_button_id(id: int) -> void:
	var button: BaseButton = instance_from_id(id) as BaseButton
	if is_instance_valid(button): _wire_button(button)


func _scan_buttons(node: Node) -> void:
	if node is BaseButton: _wire_button(node)
	for child: Node in node.get_children(): _scan_buttons(child)


func _wire_button(button: BaseButton) -> void:
	if not is_instance_valid(button) or button.has_meta("audio_world_wired"): return
	button.set_meta("audio_world_wired", true)
	# Down happens before the action removes a page or starts the race.
	button.button_down.connect(_button_pressed.bind(button))


func _button_allowed(button: BaseButton) -> bool:
	if button.disabled or not button.is_visible_in_tree(): return false
	var ancestor: Node = button
	while ancestor != null:
		if ancestor is TouchControls or bool(ancestor.get_meta("silent_ui_audio", false)): return false
		ancestor = ancestor.get_parent()
	return true


func _button_pressed(button: BaseButton) -> void:
	if not _button_allowed(button): return
	var cue: String = str(button.get_meta("audio_cue", "select"))
	if button is Button:
		var label: String = (button as Button).text.to_lower()
		if label.begins_with("back") or label.begins_with("cancel") or label.begins_with("close"): cue = "back"
	play_ui(cue)


func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED]:
		app_suspended = true
		if menu_player != null: menu_player.stream_paused = true
		if race_player != null: race_player.stream_paused = true
		if event_player != null: event_player.stream_paused = true
		for player: AudioStreamPlayer in ui_players: player.stop()
	elif what in [NOTIFICATION_APPLICATION_FOCUS_IN, NOTIFICATION_APPLICATION_RESUMED]:
		app_suspended = false
		if menu_player != null: menu_player.stream_paused = menu_target <= 0.0
		if race_player != null: race_player.stream_paused = blocked
		if event_player != null: event_player.stream_paused = blocked


func _exit_tree() -> void:
	_exiting = true
	race_owner = null
	for player: AudioStreamPlayer in ui_players:
		player.stop()
		player.stream = null
	ui_streams.clear()
	if menu_player != null:
		menu_player.stream_paused = false
		menu_player.stop()
		menu_player.stream = null
	if race_player != null:
		race_player.stream_paused = false
		race_player.stop()
		race_player.stream = null
	synced = null
	if event_player != null:
		event_player.stop()
		event_player.stream = null
