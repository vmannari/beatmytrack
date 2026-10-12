class_name GameSoundtrack
extends Node
## Recorded music and interface feedback, entirely outside canonical simulation.
const BANK: String = "res://assets/audio/score_v1/"
const LAYERS: Array[String] = ["foundation", "current", "motion", "flight", "arrival"]
const DEFAULTS: Dictionary = {"music_volume": 0.7, "vehicle_volume": 1.0, "interface_volume": 0.7}
const BAR_SECONDS: float = 2.0
const FADE_SECONDS: float = 4.0
var menu_player: AudioStreamPlayer
var race_player: AudioStreamPlayer
var ui_players: Array[AudioStreamPlayer] = []
var ui_streams: Dictionary = {}
var synced: AudioStreamSynchronized
var progress := DrivingScoreProgress.new()
var race_owner: WeakRef
var mode: String = "silent"
var family: String = "horizon"
var gains: Array[float] = [1.0, 0.0, 0.0, 0.0, 0.0]
var fade_from: Array[float] = [1.0, 0.0, 0.0, 0.0, 0.0]
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


static func instance() -> GameSoundtrack:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	return tree.root.get_node("AudioWorld") as GameSoundtrack


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Headless verifier/tests have no output device; do not allocate decoder playbacks there.
	output_enabled = DisplayServer.get_name() != "headless"
	menu_player = _player("MenuScore", "Music")
	menu_player.stream = _loop("menu_workshop.ogg")
	menu_player.volume_db = -80.0
	race_player = _player("RaceScore", "Music")
	race_player.volume_db = -80.0
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


func apply_settings(settings: Dictionary) -> void:
	for item: Array in [["Music", "music_volume"], ["Vehicle", "vehicle_volume"], ["Interface", "interface_volume"]]:
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
	race_owner = weakref(owner)
	mode = "race"
	blocked = false
	menu_target = 0.0
	race_target = 1.0
	family = "daybreak" if theme == "desert" else "horizon"
	progress.reset(state)
	gains = [1.0, 0.0, 0.0, 0.0, 0.0]
	fade_from = gains.duplicate()
	target_layer = 0
	fade_elapsed = FADE_SECONDS
	last_bar = -1
	synced = AudioStreamSynchronized.new()
	synced.stream_count = LAYERS.size()
	for i: int in range(LAYERS.size()):
		synced.set_sync_stream(i, _loop(family + "_" + LAYERS[i] + ".ogg"))
		synced.set_sync_stream_volume(i, 0.0 if i == 0 else -80.0)
	race_player.stream = synced
	race_player.stream_paused = app_suspended
	race_gain = 0.0
	race_player.volume_db = -80.0
	if output_enabled: race_player.play()


func is_race_owner(owner: Node) -> bool:
	return race_owner != null and race_owner.get_ref() == owner


func present_race(owner: Node, state: VehicleState, track: NativeTrack, config: HandlingConfig, session: TrackSession, paused: bool, countdown: bool, finished: bool) -> void:
	if not is_race_owner(owner): return
	if finished:
		show_menu()
		return
	blocked = paused
	race_player.stream_paused = paused or app_suspended
	menu_player.stream_paused = paused or app_suspended or menu_gain <= 0.0
	if paused or countdown: return
	progress.observe(state, track, config, session)


func leave_race(owner: Node) -> void:
	if is_race_owner(owner): show_menu()


func notify_collision(owner: Node, strength: float) -> void:
	if is_race_owner(owner): progress.notify_impact(strength)


func _process(delta: float) -> void:
	if app_suspended: return
	if race_owner != null and race_owner.get_ref() == null: show_menu()
	if blocked: return
	menu_gain = move_toward(menu_gain, menu_target, delta / 0.85)
	race_gain = move_toward(race_gain, race_target, delta / 0.85)
	menu_player.volume_db = linear_to_db(maxf(menu_gain, 0.0001))
	race_player.volume_db = linear_to_db(maxf(race_gain, 0.0001))
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
		if requested != target_layer:
			target_layer = requested
			fade_from = gains.duplicate()
			fade_elapsed = 0.0
	fade_elapsed = minf(FADE_SECONDS, fade_elapsed + delta)
	var blend: float = smoothstep(0.0, FADE_SECONDS, fade_elapsed)
	for i: int in range(LAYERS.size()):
		gains[i] = lerpf(fade_from[i], 1.0 if i <= target_layer else 0.0, blend)
		if synced != null: synced.set_sync_stream_volume(i, linear_to_db(maxf(gains[i], 0.0001)))


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
		for player: AudioStreamPlayer in ui_players: player.stop()
	elif what in [NOTIFICATION_APPLICATION_FOCUS_IN, NOTIFICATION_APPLICATION_RESUMED]:
		app_suspended = false
		if menu_player != null: menu_player.stream_paused = menu_target <= 0.0
		if race_player != null: race_player.stream_paused = blocked


func _exit_tree() -> void:
	_exiting = true
	race_owner = null
	for player: AudioStreamPlayer in ui_players:
		player.stop()
		player.stream = null
	ui_streams.clear()
	if menu_player != null:
		menu_player.stop()
		menu_player.stream = null
	if race_player != null:
		race_player.stop()
		race_player.stream = null
	synced = null
