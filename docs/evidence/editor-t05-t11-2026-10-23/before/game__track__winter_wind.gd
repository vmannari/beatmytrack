class_name WinterWind
extends Node
## Continuous harsh gale with local presentation-only variation.
const CLIPS: Array[AudioStream] = [
	preload("res://assets/audio/ambience/winter_gale_a.ogg"),
	preload("res://assets/audio/ambience/winter_gale_b.ogg"),
]
const BASE: float = 0.40
const SWELL: float = 0.16
const MAX_GAIN: float = 0.616
const OPEN_FADE: float = 1.5
const FINISH_FADE: float = 0.6
var rng := RandomNumberGenerator.new()
var player: AudioStreamPlayer
var loops: Array[AudioStream] = []
var variant: int = -1
var enabled: bool = false
var suspended: bool = false
var output_enabled: bool = DisplayServer.get_name() != "headless"
var offset: float = 0.0
var scale: float = 1.0
var gain: float = 0.0
var opening: float = 0.0
var strength: float = 0.0
var gust_from: float = 0.0
var gust_to: float = 0.0
var gust_elapsed: float = 0.0
var gust_duration: float = 0.0
var gust_wait: float = 0.0
var next_high: bool = true
var gusts_started: int = 0


func _init() -> void: rng.randomize()


func configure(theme: String) -> void:
	enabled = theme == "winter"
	if enabled and player == null:
		for clip: AudioStream in CLIPS: loops.append(AudioLoop.prepare(clip))
		player = AudioStreamPlayer.new()
		player.name = "WinterGale"
		player.bus = "Vehicle"
		player.volume_linear = 0.0
		add_child(player)
	reset()


func reset() -> void:
	if player != null:
		player.stop()
		player.stream_paused = suspended
		player.volume_linear = 0.0
	gain = 0.0
	opening = 0.0
	strength = 0.0
	gust_from = 0.0
	gust_to = 0.0
	gust_elapsed = 0.0
	gust_duration = 0.0
	next_high = true
	if not enabled: return
	variant = rng.randi_range(0, loops.size() - 1) if variant < 0 else 1 - variant
	player.stream = loops[variant]
	offset = rng.randf_range(0.0, player.stream.get_length() - 0.1)
	scale = rng.randf_range(0.90, 1.10)
	gust_wait = rng.randf_range(1.5, 4.5)


func present(delta: float, paused: bool, finished: bool) -> void:
	if not enabled or player == null: return
	player.stream_paused = paused or suspended
	if paused or suspended or not is_finite(delta) or delta <= 0.0: return
	var step: float = minf(delta, 0.25)
	if finished:
		gain = move_toward(gain, 0.0, MAX_GAIN * step / FINISH_FADE)
		player.volume_linear = gain
		if gain <= 0.0: player.stop()
		return
	opening = minf(OPEN_FADE, opening + step)
	if gust_elapsed < gust_duration:
		gust_elapsed = minf(gust_duration, gust_elapsed + step)
		strength = lerpf(gust_from, gust_to, smoothstep(0.0, gust_duration, gust_elapsed))
	else:
		gust_wait -= step
		if gust_wait <= 0.0:
			gust_from = strength
			gust_to = rng.randf_range(0.65, 1.0) if next_high else rng.randf_range(0.0, 0.25)
			gust_duration = rng.randf_range(2.5, 5.0)
			gust_elapsed = 0.0
			gust_wait = rng.randf_range(1.5, 4.0) if next_high else rng.randf_range(2.0, 6.0)
			next_high = not next_high
			gusts_started += 1
	var fade: float = smoothstep(0.0, OPEN_FADE, opening)
	gain = minf(MAX_GAIN, (BASE + SWELL * strength) * scale * fade)
	player.volume_linear = gain
	if output_enabled and not player.playing: player.play(offset)


func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED]:
		suspended = true
		if player != null: player.stream_paused = true
	elif what in [NOTIFICATION_APPLICATION_FOCUS_IN, NOTIFICATION_APPLICATION_RESUMED]: suspended = false
