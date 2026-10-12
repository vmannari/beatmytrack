class_name DesertAmbience
extends Node
## Open wind and wind-blown dune sand; local presentation RNG, independent of driving.
const WIND_CLIPS: Array[AudioStreamWAV] = [
	preload("res://assets/audio/ambience/desert_wind.wav"),
	preload("res://assets/audio/ambience/desert_wind_b.wav"),
	preload("res://assets/audio/ambience/desert_wind_c.wav"),
]
const WIND_BASE: float = 0.38
const WIND_SWELL: float = 0.12
const WIND_MAX: float = 0.55
const SAND_BASE: float = 0.0125
const SAND_SWELL: float = 0.05
const SAND_MAX: float = 0.065625
const OPEN_FADE: float = 2.0
const FINISH_FADE: float = 0.6
var rng := RandomNumberGenerator.new()
var wind: AudioStreamPlayer
var sand: AudioStreamPlayer
var enabled: bool = false
var suspended: bool = false
var output_enabled: bool = DisplayServer.get_name() != "headless"
var wind_offset: float = 0.0
var sand_offset: float = 0.0
var wind_scale: float = 1.0
var sand_scale: float = 1.0
var wind_gain: float = 0.0
var sand_gain: float = 0.0
var opening: float = 0.0
var strength: float = 0.0
var gust_from: float = 0.0
var gust_to: float = 0.0
var gust_elapsed: float = 0.0
var gust_duration: float = 0.0
var gust_wait: float = 0.0
var next_high: bool = true
var gusts_started: int = 0
var wind_loops: Array[AudioStreamWAV] = []
var wind_bag: Array[int] = []
var wind_variant: int = -1


func _init() -> void:
	rng.randomize()


func configure(theme: String) -> void:
	enabled = theme == "desert"
	if enabled and wind == null:
		for source: AudioStreamWAV in WIND_CLIPS: wind_loops.append(PcmAudioLoop.prepare(source))
		wind = _voice("DesertWind", wind_loops[0])
		sand = _voice("DuneSand", PcmAudioLoop.prepare(preload("res://assets/audio/ambience/desert_dune_sand.wav")))
	reset()


func _voice(label: String, stream: AudioStreamWAV) -> AudioStreamPlayer:
	var voice := AudioStreamPlayer.new()
	voice.name = label
	voice.bus = "Vehicle"
	voice.stream = stream
	voice.volume_linear = 0.0
	add_child(voice)
	return voice


func reset() -> void:
	for voice: AudioStreamPlayer in [wind, sand]:
		if voice == null: continue
		voice.stop()
		voice.stream_paused = suspended
		voice.volume_linear = 0.0
	wind_gain = 0.0
	sand_gain = 0.0
	opening = 0.0
	strength = 0.0
	gust_from = 0.0
	gust_to = 0.0
	gust_elapsed = 0.0
	gust_duration = 0.0
	next_high = true
	if not enabled: return
	_select_wind()
	wind_offset = rng.randf_range(0.0, wind.stream.get_length() - 0.1)
	sand_offset = rng.randf_range(0.0, 28.9)
	wind_scale = rng.randf_range(0.90, 1.10)
	sand_scale = rng.randf_range(0.85, 1.05)
	gust_wait = rng.randf_range(2.0, 6.0)


func _select_wind() -> void:
	if wind_bag.is_empty():
		for index: int in range(wind_loops.size()): wind_bag.append(index)
		for index: int in range(wind_bag.size() - 1, 0, -1):
			var other: int = rng.randi_range(0, index)
			var swap: int = wind_bag[index]
			wind_bag[index] = wind_bag[other]
			wind_bag[other] = swap
		if wind_bag.back() == wind_variant:
			var swap: int = wind_bag[0]
			wind_bag[0] = wind_bag[wind_bag.size() - 1]
			wind_bag[wind_bag.size() - 1] = swap
	wind_variant = wind_bag.pop_back()
	wind.stream = wind_loops[wind_variant]


func present(delta: float, paused: bool, finished: bool) -> void:
	if not enabled or wind == null: return
	for voice: AudioStreamPlayer in [wind, sand]: voice.stream_paused = paused or suspended
	if paused or suspended or not is_finite(delta) or delta <= 0.0: return
	var step: float = minf(delta, 0.25)
	if finished:
		wind_gain = move_toward(wind_gain, 0.0, WIND_MAX * step / FINISH_FADE)
		sand_gain = move_toward(sand_gain, 0.0, SAND_MAX * step / FINISH_FADE)
		wind.volume_linear = wind_gain
		sand.volume_linear = sand_gain
		if wind_gain <= 0.0: wind.stop()
		if sand_gain <= 0.0: sand.stop()
		return
	opening = minf(OPEN_FADE, opening + step)
	if gust_elapsed < gust_duration:
		gust_elapsed = minf(gust_duration, gust_elapsed + step)
		strength = lerpf(gust_from, gust_to, smoothstep(0.0, gust_duration, gust_elapsed))
	else:
		gust_wait -= step
		if gust_wait <= 0.0:
			gust_from = strength
			gust_to = rng.randf_range(0.55, 1.0) if next_high else rng.randf_range(0.0, 0.20)
			gust_duration = rng.randf_range(3.5, 7.0)
			gust_elapsed = 0.0
			gust_wait = rng.randf_range(2.0, 5.0) if next_high else rng.randf_range(3.0, 8.0)
			next_high = not next_high
			gusts_started += 1
	var fade: float = smoothstep(0.0, OPEN_FADE, opening)
	wind_gain = minf(WIND_MAX, (WIND_BASE + WIND_SWELL * strength) * wind_scale * fade)
	sand_gain = minf(SAND_MAX, (SAND_BASE + SAND_SWELL * smoothstep(0.2, 1.0, strength)) * sand_scale * fade)
	wind.volume_linear = wind_gain
	sand.volume_linear = sand_gain
	if output_enabled:
		if not wind.playing: wind.play(wind_offset)
		if not sand.playing: sand.play(sand_offset)


func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED]:
		suspended = true
		for voice: AudioStreamPlayer in [wind, sand]:
			if voice != null: voice.stream_paused = true
	elif what in [NOTIFICATION_APPLICATION_FOCUS_IN, NOTIFICATION_APPLICATION_RESUMED]:
		suspended = false
