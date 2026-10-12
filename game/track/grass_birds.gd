class_name GrassBirds
extends Node
## Shuffled field recordings and local presentation randomness; never simulation RNG.
const CLIPS: Array[AudioStreamWAV] = [
	preload("res://assets/audio/ambience/grass_blackbird_13.wav"),
	preload("res://assets/audio/ambience/grass_blackbird_23.wav"),
	preload("res://assets/audio/ambience/grass_blackcap_7.wav"),
]
const MIN_GAP: float = 2.5
const MAX_GAP: float = 8.0
const FINISH_FADE: float = 0.4
var rng := RandomNumberGenerator.new()
var player: AudioStreamPlayer
var enabled: bool = false
var suspended: bool = false
var gap_scale: float = 1.0
var wait_seconds: float = 0.0
var remaining: float = 0.0
var elapsed: float = 0.0
var gain: float = 0.0
var call_level: float = 0.0
var last_clip: int = -1
var calls_started: int = 0
var bag: Array[int] = []


func _init() -> void:
	rng.randomize()


func configure(theme: String) -> void:
	enabled = theme == "pine"
	if enabled and player == null:
		player = AudioStreamPlayer.new()
		player.name = "GrassBirdsong"
		player.bus = "Vehicle"
		add_child(player)
	reset()


func reset() -> void:
	if player != null:
		player.stop()
		player.stream_paused = suspended
		player.volume_linear = 0.0
	remaining = 0.0
	elapsed = 0.0
	gain = 0.0
	bag.clear()
	if not enabled: return
	# Fresh density, opening delay and order for every attempt, including Retry.
	gap_scale = rng.randf_range(0.85, 1.25)
	wait_seconds = rng.randf_range(0.6, 2.8)


func present(delta: float, paused: bool, finished: bool) -> void:
	if not enabled or player == null: return
	player.stream_paused = paused or suspended
	if paused or suspended or not is_finite(delta) or delta <= 0.0: return
	# A stalled rendering frame never catches up with a burst of missed calls.
	var step: float = minf(delta, 0.25)
	if finished:
		gain = move_toward(gain, 0.0, step * 0.38 / FINISH_FADE)
		player.volume_linear = gain
		if gain <= 0.0:
			player.stop()
			remaining = 0.0
		return
	if remaining > 0.0:
		remaining = maxf(0.0, remaining - step)
		elapsed += step
		gain = call_level * minf(smoothstep(0.0, 0.08, elapsed), smoothstep(0.0, 0.18, remaining))
		player.volume_linear = gain
		if remaining <= 0.0: player.stop()
		return
	wait_seconds -= step
	if wait_seconds <= 0.0: _start_call()


func _start_call() -> void:
	if bag.is_empty():
		for index: int in range(CLIPS.size()): bag.append(index)
		for index: int in range(bag.size() - 1, 0, -1):
			var other: int = rng.randi_range(0, index)
			var swap: int = bag[index]
			bag[index] = bag[other]
			bag[other] = swap
		if bag.back() == last_clip:
			var swap: int = bag[0]
			bag[0] = bag[bag.size() - 1]
			bag[bag.size() - 1] = swap
	last_clip = bag.pop_back()
	player.stream = CLIPS[last_clip]
	player.pitch_scale = rng.randf_range(0.98, 1.02)
	call_level = rng.randf_range(0.216, 0.304) # 20% softer; same call variation.
	gain = 0.0
	elapsed = 0.0
	remaining = player.stream.get_length() / player.pitch_scale
	wait_seconds = rng.randf_range(MIN_GAP, MAX_GAP) * gap_scale
	player.volume_linear = 0.0
	calls_started += 1
	if DisplayServer.get_name() != "headless": player.play()


func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED]:
		suspended = true
		if player != null: player.stream_paused = true
	elif what in [NOTIFICATION_APPLICATION_FOCUS_IN, NOTIFICATION_APPLICATION_RESUMED]:
		suspended = false
